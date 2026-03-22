import os
import ray

from slime.ray.placement_group import create_placement_groups, create_rollout_manager, create_training_models
from slime.utils.arguments import parse_args
from slime.utils.logging_utils import configure_logger
from slime.utils.misc import should_run_periodic_action
from slime.utils import tracking_utils
from slime.utils.tracking_utils import init_tracking


def _log_eval_to_primary_wandb(args, eval_metrics):
    """Re-log eval metrics from the primary process so they appear in the
    main wandb offline run (the one the user syncs).  The RolloutManager
    logs them too, but in offline mode that goes to a separate run dir."""
    if eval_metrics and args.use_wandb:
        # Strip private keys (prefixed with "_") — they are non-scalar payloads
        # (e.g. task_id lists) that cannot be logged to wandb.
        loggable = {k: v for k, v in eval_metrics.items() if not k.startswith("_")}
        print(f"[train_async] Logging {len(loggable)} eval metrics to primary wandb "
              f"(step={loggable.get('eval/step')}): {list(loggable.keys())}")
        tracking_utils.log(args, loggable, step_key="eval/step")


def _apply_curriculum_filter(args, rollout_manager, eval_metrics):
    """After eval, optionally update the training dataset to the dynamic curriculum.

    Only active when --eval-dynamic-curriculum is set.  When disabled (default),
    the training prompt set is not changed after eval — all tasks remain active.

    When enabled: problems where 1 ≤ pass_count < n_eval_samples are selected as
    the next training batch (medium difficulty for the current model).
    """
    if not getattr(args, "eval_dynamic_curriculum", False):
        return
    task_ids = (eval_metrics or {}).get("_train_filter_task_ids")
    if task_ids is None:
        return
    if not task_ids:
        print("[train_async] WARNING: curriculum filter is empty (model solves all or none); "
              "keeping previous filter unchanged.")
        return
    print(f"[train_async] Updating curriculum filter: {len(task_ids)} medium tasks")
    ray.get(rollout_manager.set_dataset_filter.remote(task_ids))


def _restore_primary_wandb_symlink():
    """In offline mode, secondary Ray actors (RolloutManager, MegatronTrainRayActor)
    each call wandb.init() which updates the 'latest-run' symlink to their own dir.
    This leaves 'latest-run' pointing at the actor's dir (training metrics only).

    After all actors are initialized, call this function from the primary process to
    redirect 'latest-run' back to the primary dir (which contains eval metrics logged
    by _log_eval_to_primary_wandb).  Syncing 'latest-run' will then show eval metrics.
    """
    try:
        import wandb as _wb
        if _wb.run is None:
            return
        # wandb.run.dir  → .../wandb/offline-run-T1-RUNID/files/
        # run_subdir     → .../wandb/offline-run-T1-RUNID
        # wandb_base     → .../wandb
        run_subdir = os.path.dirname(_wb.run.dir)
        wandb_base = os.path.dirname(run_subdir)
        latest_link = os.path.join(wandb_base, "latest-run")
        rel_target = os.path.basename(run_subdir)
        if os.path.islink(latest_link):
            os.unlink(latest_link)
        os.symlink(rel_target, latest_link)
        print(f"[train_async] Restored latest-run → {rel_target}")
        print(f"[train_async] Sync eval+rollout metrics: wandb sync {run_subdir}")
    except Exception as e:
        print(f"[train_async] Warning: could not restore latest-run symlink: {e}")


# The framework supports other asynchronous approaches such as fully async (which is shown in examples/full_async).
def train(args):
    assert not args.colocate, "Colocation is not supported for async training."
    configure_logger()
    # allocate the GPUs
    pgs = create_placement_groups(args)
    init_tracking(args)

    # create the rollout manager, with sglang engines inside.
    # need to initialize rollout manager first to calculate num_rollout
    rollout_manager, num_rollout_per_epoch = create_rollout_manager(args, pgs["rollout"])

    # create the actor and critic models
    actor_model, critic_model = create_training_models(args, pgs, rollout_manager)

    # In offline mode, RolloutManager and MegatronTrainRayActor each call
    # wandb.init() (secondary), which overwrites the 'latest-run' symlink.
    # Restore it to the primary dir so eval metrics appear when user syncs.
    if getattr(args, "wandb_mode", None) == "offline":
        _restore_primary_wandb_symlink()

    # always update weight first so that sglang has the loaded weights from training.
    actor_model.update_weights()

    if args.check_weight_update_equal:
        ray.get(rollout_manager.check_weights.remote(action="compare"))

    # Initial eval before training starts — gives a baseline to compare against.
    if args.eval_interval is not None and not args.skip_eval_before_train:
        print(f"[train_async] Running initial eval before training (start_rollout_id={args.start_rollout_id})")
        eval_metrics = ray.get(rollout_manager.eval.remote(rollout_id=args.start_rollout_id))
        _log_eval_to_primary_wandb(args, eval_metrics)
        _apply_curriculum_filter(args, rollout_manager, eval_metrics)

    # async train loop.
    rollout_data_next_future = rollout_manager.generate.remote(args.start_rollout_id)
    for rollout_id in range(args.start_rollout_id, args.num_rollout):
        # Sync the last generation
        if rollout_data_next_future is not None:
            rollout_data_curr_ref = ray.get(rollout_data_next_future)

        # Start the next rollout early.
        if rollout_id + 1 < args.num_rollout:
            rollout_data_next_future = rollout_manager.generate.remote(rollout_id + 1)

        if args.use_critic:
            critic_train_handle = critic_model.async_train(rollout_id, rollout_data_curr_ref)
            if rollout_id >= args.num_critic_only_steps:
                ray.get(actor_model.async_train(rollout_id, rollout_data_curr_ref))
            ray.get(critic_train_handle)
        else:
            ray.get(actor_model.async_train(rollout_id, rollout_data_curr_ref))

        if should_run_periodic_action(rollout_id, args.save_interval, num_rollout_per_epoch, args.num_rollout):
            actor_model.save_model(rollout_id, force_sync=rollout_id == args.num_rollout - 1)
            if args.use_critic:
                critic_model.save_model(rollout_id, force_sync=rollout_id == args.num_rollout - 1)
            if args.rollout_global_dataset:
                ray.get(rollout_manager.save.remote(rollout_id))

        if (rollout_id + 1) % args.update_weights_interval == 0:
            # sync generate before update weights to prevent update weight in the middle of generation
            rollout_data_curr_ref = ray.get(x) if (x := rollout_data_next_future) is not None else None
            rollout_data_next_future = None
            actor_model.update_weights()

        if should_run_periodic_action(rollout_id, args.eval_interval, num_rollout_per_epoch):
            eval_metrics = ray.get(rollout_manager.eval.remote(rollout_id))
            _log_eval_to_primary_wandb(args, eval_metrics)
            _apply_curriculum_filter(args, rollout_manager, eval_metrics)

    ray.get(rollout_manager.dispose.remote())


if __name__ == "__main__":
    args = parse_args()
    train(args)
