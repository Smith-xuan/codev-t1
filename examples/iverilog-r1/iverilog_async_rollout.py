"""
Fully-asynchronous rollout driver for the iverilog-r1 task.

This module is a thin adapter of examples/fully_async/fully_async_rollout.py placed
inside the iverilog-r1 directory so that it is on PYTHONPATH when Ray jobs are
submitted.  The core logic is identical – the heavy lifting (multi-turn iverilog tool
calls, reward calculation) is still done by generate_with_iverilog.py via the
--custom-generate-function-path argument.

Usage in launch script
----------------------
  --rollout-function-path  iverilog_async_rollout.generate_rollout_fully_async
  --custom-generate-function-path generate_with_iverilog.generate
  --custom-rm-path         generate_with_iverilog.reward_func

How it works
------------
1. A single AsyncRolloutWorker is created on the first call and kept alive for the
   entire training run (process-level singleton).
2. The worker maintains up to `--rollout-batch-size` concurrent generate_and_rm_group
   tasks in its asyncio event loop.  Each task calls the iverilog custom generate
   function internally.
3. Completed groups are pushed into an output queue via a callback.
4. generate_rollout_fully_async() (called once per training step by train_async.py)
   drains the queue until it has collected `--rollout-batch-size` valid groups, then
   returns immediately – it does NOT wait for slow/long-tail samples.
5. Long-tail samples finish later and their results are consumed by the NEXT training
   step.  ABORTED samples are returned to the data_buffer for retry.
"""

import asyncio
import atexit
import queue
import threading
import time

from slime.rollout.filter_hub.base_types import DynamicFilterOutput
from slime.rollout.sglang_rollout import GenerateState, generate_and_rm_group
from slime.utils.async_utils import run
from slime.utils.misc import load_function
from slime.utils.types import Sample

# ---------------------------------------------------------------------------
# Global worker singleton
# ---------------------------------------------------------------------------
_global_worker = None
_worker_lock = threading.Lock()


def get_global_worker(args, data_buffer):
    """Return the existing worker, or create and start one on first call."""
    global _global_worker
    with _worker_lock:
        if _global_worker is None or not _global_worker.worker_thread.is_alive():
            print("[iverilog_async_rollout] Creating new global async worker...")
            _global_worker = AsyncRolloutWorker(
                args, data_buffer, concurrency=args.sglang_server_concurrency
            )
            _global_worker.start()
        return _global_worker


def stop_global_worker():
    """Gracefully stop the worker (called automatically at process exit)."""
    global _global_worker
    with _worker_lock:
        if _global_worker is not None:
            _global_worker.stop()
            _global_worker = None


atexit.register(stop_global_worker)


def pause_global_worker():
    """Pause the background worker (no new tasks). Safe to call if no worker."""
    if _global_worker is not None:
        _global_worker.pause()


def resume_global_worker():
    """Resume the background worker. Safe to call if no worker."""
    if _global_worker is not None:
        _global_worker.resume()


def flush_global_worker_queue() -> int:
    """Discard stale groups from the output queue. Returns count discarded."""
    if _global_worker is not None:
        return _global_worker.flush_queue()
    return 0


# ---------------------------------------------------------------------------
# Async worker
# ---------------------------------------------------------------------------
class AsyncRolloutWorker:
    """
    Persistent background worker that continuously generates rollout samples.

    The worker runs an asyncio event loop in a dedicated daemon thread.  It
    keeps up to `max_concurrent_tasks` (= rollout_batch_size) generate tasks in
    flight at all times.  Completed groups are pushed to `output_queue` via
    done-callbacks so the training side can drain them without blocking.
    """

    def __init__(self, args, data_buffer, concurrency=10):
        self.args = args
        self.data_buffer = data_buffer
        self.concurrency = concurrency
        self.running = True
        self._paused = False
        # Generous bound: prevents unbounded memory accumulation if training
        # falls behind rollout for many steps.
        self.output_queue = queue.Queue(maxsize=1000)
        self.worker_thread = None
        self.state = GenerateState(args)

    # ------------------------------------------------------------------
    # Main async loop
    # ------------------------------------------------------------------
    async def continuous_worker_loop(self):
        print("[iverilog_async_rollout] Continuous async rollout worker started")

        active_tasks: set[asyncio.Task] = set()
        max_concurrent_tasks = self.args.rollout_batch_size
        group_id_counter = 0

        while self.running:
            try:
                # ---- prune finished tasks ----
                if active_tasks:
                    done_tasks = {t for t in active_tasks if t.done()}
                    for t in done_tasks:
                        try:
                            t.result()  # results already handled by callback
                        except Exception as e:
                            print(f"[iverilog_async_rollout] Task raised exception: {e}")
                    active_tasks -= done_tasks

                # ---- fill up to the concurrency limit ----
                while (
                    len(active_tasks) < max_concurrent_tasks
                    and self.running
                    and not self._paused
                ):
                    samples = self.data_buffer.get_samples(1)
                    if not samples:
                        break

                    for group in samples:
                        gid = group_id_counter
                        group_id_counter += 1

                        task = asyncio.create_task(
                            generate_and_rm_group(
                                self.args,
                                group,
                                sampling_params=self.state.sampling_params.copy(),
                                evaluation=False,
                            )
                        )

                        def make_callback(group_id):
                            def _cb(done_task):
                                try:
                                    result = done_task.result()
                                    self.output_queue.put((group_id, result))
                                except Exception as e:
                                    print(
                                        f"[iverilog_async_rollout] Callback error for "
                                        f"group {group_id}: {e}"
                                    )

                            return _cb

                        task.add_done_callback(make_callback(gid))
                        active_tasks.add(task)
                        break  # fetch one group per inner iteration, re-check limit

                await asyncio.sleep(1)

            except Exception as e:
                print(f"[iverilog_async_rollout] Error in worker loop: {e}")
                await asyncio.sleep(1)

        # Drain remaining tasks on shutdown
        if active_tasks:
            print(
                f"[iverilog_async_rollout] Waiting for {len(active_tasks)} "
                f"in-flight tasks to finish before shutdown..."
            )
            await asyncio.wait(active_tasks)

        print("[iverilog_async_rollout] Continuous async rollout worker stopped")

    # ------------------------------------------------------------------
    # Thread management
    # ------------------------------------------------------------------
    def worker_thread_func(self):
        asyncio.run(self.continuous_worker_loop())

    def start(self):
        if self.worker_thread is None or not self.worker_thread.is_alive():
            self.worker_thread = threading.Thread(
                target=self.worker_thread_func, daemon=True
            )
            self.worker_thread.start()
            print("[iverilog_async_rollout] Worker thread started")

    def stop(self):
        self.running = False
        if self.worker_thread and self.worker_thread.is_alive():
            self.worker_thread.join(timeout=10)
        print("[iverilog_async_rollout] Worker thread stopped")

    def pause(self):
        """Stop submitting new tasks.  In-flight tasks finish naturally."""
        self._paused = True
        print(
            "[iverilog_async_rollout] Worker PAUSED — no new tasks will be "
            "submitted (in-flight tasks will finish on their own)"
        )

    def resume(self):
        """Resume submitting new tasks."""
        self._paused = False
        print("[iverilog_async_rollout] Worker RESUMED")

    def flush_queue(self) -> int:
        """Discard all completed groups in the output queue (stale data).

        Returns the number of discarded groups.
        """
        count = 0
        while True:
            try:
                self.output_queue.get_nowait()
                count += 1
            except queue.Empty:
                break
        if count:
            print(
                f"[iverilog_async_rollout] Flushed {count} stale groups "
                f"from output queue"
            )
        return count

    # ------------------------------------------------------------------
    # Result retrieval (non-blocking)
    # ------------------------------------------------------------------
    def get_completed_groups(self) -> list[tuple]:
        completed = []
        while True:
            try:
                completed.append(self.output_queue.get_nowait())
            except queue.Empty:
                break
        return completed

    def get_queue_size(self) -> int:
        return self.output_queue.qsize()


# ---------------------------------------------------------------------------
# Public rollout entry-point (called by train_async.py each step)
# ---------------------------------------------------------------------------
async def generate_rollout_async(
    args, rollout_id: int, data_buffer
) -> list[list[Sample]]:
    """
    Drain the background worker's output queue until target_data_size groups
    are collected, then return.  Does NOT block on slow/long-tail samples.
    """
    assert args.rollout_global_dataset, (
        "fully_async rollout requires --rollout-global-dataset "
        "(do not pass --disable-rollout-global-dataset)"
    )

    worker = get_global_worker(args, data_buffer)
    target_data_size = args.rollout_batch_size

    dynamic_filter = (
        load_function(args.dynamic_sampling_filter_path)
        if getattr(args, "dynamic_sampling_filter_path", None) is not None
        else None
    )

    data: list[list[Sample]] = []
    completed_groups: dict[int, list[Sample]] = {}
    do_print = True
    filtered_count = 0

    print(
        f"[iverilog_async_rollout] Step {rollout_id}: collecting "
        f"{target_data_size} groups (queue={worker.get_queue_size()})"
    )

    start_time = time.time()
    last_progress_time = start_time
    no_progress_timeout = 60.0  # warn if stalled for 60 s (iverilog can be slow)

    while len(data) < target_data_size:
        # --- drain whatever finished since last iteration ---
        for gid, group in worker.get_completed_groups():
            completed_groups[gid] = group

        made_progress = bool(completed_groups)
        if made_progress:
            last_progress_time = time.time()

        # --- process available groups ---
        processed_any = False
        for gid in list(completed_groups.keys()):
            if len(data) >= target_data_size:
                break

            group = completed_groups.pop(gid)

            # ABORTED groups go back to the buffer for retry
            try:
                any_aborted = any(
                    s.status == Sample.Status.ABORTED for s in group
                )
            except Exception:
                any_aborted = False

            if any_aborted:
                try:
                    data_buffer.add_samples([group])
                    print(
                        f"[iverilog_async_rollout] Returned aborted group "
                        f"{gid} to data buffer"
                    )
                except Exception as e:
                    print(
                        f"[iverilog_async_rollout] Failed to return group "
                        f"{gid} to buffer: {e}"
                    )
                continue

            # Apply dynamic sampling filter (e.g. zero_std check)
            if dynamic_filter is not None:
                output = dynamic_filter(args, group)
                if not isinstance(output, DynamicFilterOutput):
                    output = DynamicFilterOutput(keep=output)
                if not output.keep:
                    filtered_count += 1
                    print(
                        f"[iverilog_async_rollout] Filtered group {gid} "
                        f"(reason={output.reason}, filtered so far: {filtered_count})",
                        flush=True,
                    )
                    continue

            if do_print:
                print(
                    f"[iverilog_async_rollout] First result — "
                    f"prompt+response: "
                    f"{[group[0].prompt + group[0].response]}, "
                    f"label: {group[0].label}, reward: {group[0].reward}",
                    flush=True,
                )
                do_print = False

            data.append(group)
            processed_any = True

        # --- stall warning ---
        now = time.time()
        if now - last_progress_time > no_progress_timeout:
            print(
                f"[iverilog_async_rollout] WARNING: No progress for "
                f"{no_progress_timeout:.0f}s. "
                f"queue={worker.get_queue_size()}, "
                f"collected={len(data)}/{target_data_size}"
            )
            last_progress_time = now

        if not processed_any:
            await asyncio.sleep(0.05)

    duration = time.time() - start_time
    print(
        f"[iverilog_async_rollout] Step {rollout_id} done in {duration:.1f}s, "
        f"filtered={filtered_count}, worker queue remaining: {worker.get_queue_size()}"
    )

    # Sort by prompt index to maintain deterministic ordering for logging
    data = sorted(data, key=lambda g: g[0].index)

    _print_step_timing_breakdown(rollout_id, data, duration)

    return data


# ---------------------------------------------------------------------------
# Rollout timing breakdown
# ---------------------------------------------------------------------------

def _print_step_timing_breakdown(
    rollout_id: int, data: list[list], step_wall_time: float
) -> None:
    """
    Aggregate per-sample timing counters collected during this step and print a
    breakdown.  Each sample carries a `_timing` dict set by generate() and
    reward_func(); if timing data is absent the sample is silently skipped.

    Time categories
    ---------------
    t_llm    – wall time blocked in ``await post(url, payload)`` per turn,
               summed across turns.  This is pure LLM inference + network RTT
               to the SGLang router.
    t_tool   – wall time blocked in ``await execute_predictions()`` per turn,
               summed across turns.  Covers iverilog compile + simulate.
    t_reward – wall time for ``await asyncio.to_thread(_run_test_sync)``.
               Covers pytest/cocotb testbench execution.
    t_overhead – residual within generate() not covered by t_llm or t_tool:
               tokenization, postprocessing, length checks, loop bookkeeping.
               = t_generate_total - t_llm - t_tool
    t_unaccounted – time outside generate() and reward_func() that still
               contributes to the step wall time: async scheduling latency,
               group-assembly wait (slowest sample in a group stalls the rest),
               queue drain wait (step blocks while groups trickle in), dynamic
               filter overhead, sort, etc.

    Wall-time loss metrics
    ----------------------
    avg_group_max  – mean of max(sample_time) per group.  A group is only
               delivered to the step once its slowest sample finishes, so
               this is the per-group "delivery time" and approximates the
               lower bound on step wall time absent scheduling overhead.
    tail_factor   – avg(max / avg) per group.  1.0 = all samples identical;
               2.0 = slowest sample takes 2× the group average.
    tail_overhead – avg(max - avg) per group: extra seconds the step waits
               for the slowest sample versus perfectly-uniform samples.
    scheduling_lag – step_wall_time - avg_group_max: residual delay from
               async loop granularity (sleep(1) in worker), step-boundary
               pipeline fill/drain, queue-drain polling (sleep(0.05)),
               dynamic-filter cost, and long-tail groups that stall the
               16th slot.
    """
    all_samples = [s for group in data for s in group]
    n = len(all_samples)
    if n == 0:
        return

    timed = [s for s in all_samples if hasattr(s, '_timing')]
    if not timed:
        print(
            f"[iverilog_async_rollout] Step {rollout_id}: "
            f"no timing data available (generate_with_iverilog not patched?)."
        )
        return

    def _g(s, key):
        return s._timing.get(key, 0.0) if hasattr(s, '_timing') else 0.0

    t_llm     = sum(_g(s, 't_llm')            for s in timed)
    t_tool    = sum(_g(s, 't_tool')           for s in timed)
    t_reward  = sum(_g(s, 't_reward')         for s in timed)
    t_gen_tot = sum(_g(s, 't_generate_total') for s in timed)
    n_turns   = sum(_g(s, 'n_turns')          for s in timed)

    t_overhead   = max(0.0, t_gen_tot - t_llm - t_tool)
    t_sample_sum = t_llm + t_tool + t_reward + t_overhead  # sum across all samples

    n_t = len(timed)
    n_groups = len(data)
    avg_turns = n_turns / n_t if n_t else 0.0

    def _pct(t):
        return t / t_sample_sum * 100 if t_sample_sum > 0 else 0.0

    def _avg(t):
        return t / n_t if n_t else 0.0

    # "Serial-equivalent" time: if samples ran one-by-one on one worker.
    serial_equiv_per_sample = (t_gen_tot + t_reward) / n_t if n_t else 0.0
    # Effective parallelism: total work / wall time = how many parallel workers
    # worth of throughput was achieved.  With N samples in flight the theoretical
    # max is N; the ratio shows utilisation efficiency.
    effective_parallelism = t_sample_sum / step_wall_time if step_wall_time > 0 else 0.0

    # ── Per-group tail analysis ──────────────────────────────────────────────
    # Each group finishes only when its SLOWEST sample finishes.  The tail
    # factor (max / avg per group) quantifies how much the step wall time is
    # inflated versus perfectly-uniform samples.
    #
    # tail_overhead   = max - avg per group (extra seconds the step waits for
    #                   the slowest sample compared to the group average).
    # avg_group_max   = mean delivery time per group ≈ lower bound on step wall
    #                   time if all groups had zero scheduling lag.
    # scheduling_lag  = step_wall_time - avg_group_max (residual: async loop
    #                   granularity, pipeline fill/drain at step boundaries,
    #                   queue-drain polling, etc.)
    group_max_times: list[float] = []
    group_tail_overheads: list[float] = []
    group_tail_factors: list[float] = []
    samples_per_group: list[int] = []

    for group in data:
        times = [
            _g(s, 't_generate_total') + _g(s, 't_reward')
            for s in group if hasattr(s, '_timing')
        ]
        if not times:
            continue
        g_max = max(times)
        g_avg = sum(times) / len(times)
        group_max_times.append(g_max)
        group_tail_overheads.append(g_max - g_avg)
        if g_avg > 0:
            group_tail_factors.append(g_max / g_avg)
        samples_per_group.append(len(times))

    avg_group_max      = sum(group_max_times) / len(group_max_times) if group_max_times else 0.0
    avg_tail_overhead  = sum(group_tail_overheads) / len(group_tail_overheads) if group_tail_overheads else 0.0
    avg_tail_factor    = sum(group_tail_factors) / len(group_tail_factors) if group_tail_factors else 1.0
    scheduling_lag     = max(0.0, step_wall_time - avg_group_max)

    n_samples_per_grp  = sum(samples_per_group) / len(samples_per_group) if samples_per_group else 0.0

    lines = [
        f"[iverilog_async_rollout] Step {rollout_id} timing breakdown "
        f"— {n_t}/{n} samples timed, {n_groups} groups "
        f"(~{n_samples_per_grp:.0f} samples/group), wall={step_wall_time:.1f}s",
        f"",
        f"  {'Category':<22} {'Avg/sample':>12}  {'Total':>10}  {'% of work':>10}",
        f"  {'-'*58}",
        f"  {'LLM generation':<22} {_avg(t_llm):>10.1f}s  {t_llm:>8.0f}s  {_pct(t_llm):>9.1f}%",
        f"  {'Tool calls (iverilog)':<22} {_avg(t_tool):>10.1f}s  {t_tool:>8.0f}s  {_pct(t_tool):>9.1f}%",
        f"  {'Reward (testbench)':<22} {_avg(t_reward):>10.1f}s  {t_reward:>8.0f}s  {_pct(t_reward):>9.1f}%",
        f"  {'Generate overhead':<22} {_avg(t_overhead):>10.1f}s  {t_overhead:>8.0f}s  {_pct(t_overhead):>9.1f}%",
        f"  {'-'*58}",
        f"  {'Total work / sample':<22} {serial_equiv_per_sample:>10.1f}s  {t_sample_sum:>8.0f}s  {'100.0%':>10}",
        f"",
        f"  Avg turns / sample     : {avg_turns:.1f}",
        f"  Effective parallelism  : {effective_parallelism:.1f}x"
        f"  (total_work {t_sample_sum:.0f}s / wall {step_wall_time:.1f}s,"
        f" theoretical max {n_t}x)",
        f"",
        f"  ── Wall-time loss breakdown ──────────────────────────────",
        f"  Avg group max time     : {avg_group_max:.1f}s"
        f"  (delivery time per group = slowest sample)",
        f"  Group tail factor      : {avg_tail_factor:.2f}x"
        f"  (avg max/avg per group; 1.0 = perfectly uniform)",
        f"  Group tail overhead    : +{avg_tail_overhead:.1f}s/group avg"
        f"  (extra vs uniform samples → group delivery delay)",
        f"  Scheduling/pipeline lag: +{scheduling_lag:.1f}s"
        f"  (wall - avg_group_max; async loop gran + step boundary fill/drain)",
    ]
    print("\n".join(lines), flush=True)


def generate_rollout_fully_async(args, rollout_id, data_buffer, evaluation=False):
    """
    Synchronous entry-point called by RolloutManager in train_async.py.

    Sets up the background worker on first call, then each subsequent call
    just drains results that are already ready.
    """
    if evaluation:
        raise ValueError(
            "[iverilog_async_rollout] Evaluation mode is not supported "
            "by the fully-async driver.  Use --eval-function-path instead."
        )
    return run(generate_rollout_async(args, rollout_id, data_buffer))
