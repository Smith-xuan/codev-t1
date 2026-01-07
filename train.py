import asyncio
# 禁用uvloop防止高并发下的socket管理问题导致SIGABRT
try:
    import uvloop
    asyncio.set_event_loop_policy(asyncio.DefaultEventLoopPolicy())
    print("⚠ uvloop detected in main training script and disabled to prevent SIGABRT crashes")
except ImportError:
    pass

import ray
from sglang.srt.constants import GPU_MEMORY_TYPE_KV_CACHE, GPU_MEMORY_TYPE_WEIGHTS

try:
    from sglang.srt.constants import GPU_MEMORY_TYPE_CUDA_GRAPH
except ImportError:
    GPU_MEMORY_TYPE_CUDA_GRAPH = None

from slime.ray.placement_group import create_placement_groups, create_rollout_manager, create_training_models
from slime.utils.arguments import parse_args
from slime.utils.logging_utils import configure_logger
from slime.utils.memory_utils import print_memory
from slime.utils.misc import should_run_periodic_action
from slime.utils.tracking_utils import init_tracking


def train(args):
    configure_logger()
    # allocate the GPUs
    pgs = create_placement_groups(args)
    init_tracking(args)

    # create the rollout manager, with sglang engines inside.
    # need to initialize rollout manager first to calculate num_rollout
    rollout_manager, num_rollout_per_epoch = create_rollout_manager(args, pgs["rollout"])

    # create the actor and critic models
    actor_model, critic_model = create_training_models(args, pgs, rollout_manager)

    if args.offload_rollout:
        ray.get(rollout_manager.onload.remote(tags=[GPU_MEMORY_TYPE_WEIGHTS]))

    # always update weight first so that sglang has the loaded weights from training.
    actor_model.update_weights()

    if args.check_weight_update_equal:
        ray.get(rollout_manager.check_weights.remote(action="compare"))

    if args.offload_rollout:
        if GPU_MEMORY_TYPE_CUDA_GRAPH is not None:
            ray.get(rollout_manager.onload.remote(tags=[GPU_MEMORY_TYPE_CUDA_GRAPH]))
        ray.get(rollout_manager.onload.remote(tags=[GPU_MEMORY_TYPE_KV_CACHE]))

    # special case for eval-only
    if args.num_rollout == 0 and args.eval_interval is not None:
        ray.get(rollout_manager.eval.remote(rollout_id=0))

    def offload_train():
        if args.offload_train:
            if args.use_critic:
                print_memory(f"[Rollout {rollout_id}] BEFORE critic_model.offload()")
                critic_model.offload()
                print_memory(f"[Rollout {rollout_id}] AFTER critic_model.offload()")
                if rollout_id >= args.num_critic_only_steps:
                    print_memory(f"[Rollout {rollout_id}] BEFORE actor_model.offload()")
                    actor_model.offload()
                    print_memory(f"[Rollout {rollout_id}] AFTER actor_model.offload()")
            else:
                print_memory(f"[Rollout {rollout_id}] BEFORE actor_model.offload()")
                actor_model.offload()
                print_memory(f"[Rollout {rollout_id}] AFTER actor_model.offload()")
        else:
            print_memory(f"[Rollout {rollout_id}] BEFORE actor_model.clear_memory()")
            actor_model.clear_memory()
            print_memory(f"[Rollout {rollout_id}] AFTER actor_model.clear_memory()")

    def onload_rollout():
        if args.offload_rollout:
            ray.get(rollout_manager.onload.remote(tags=[GPU_MEMORY_TYPE_WEIGHTS]))

    # train loop.
    # note that for async training, one can change the position of the sync operation(ray.get).
    for rollout_id in range(args.start_rollout_id, args.num_rollout):
        if args.eval_interval is not None and rollout_id == 0 and not args.skip_eval_before_train:
            ray.get(rollout_manager.eval.remote(rollout_id))

        rollout_data_ref = ray.get(rollout_manager.generate.remote(rollout_id))

        if args.offload_rollout:
            print_memory(f"[Rollout {rollout_id}] BEFORE SGLang offload")
            ray.get(rollout_manager.offload.remote())
            print_memory(f"[Rollout {rollout_id}] AFTER SGLang offload")

        if args.use_critic:
            critic_train_handle = critic_model.async_train(rollout_id, rollout_data_ref)
            if rollout_id >= args.num_critic_only_steps:
                ray.get(actor_model.async_train(rollout_id, rollout_data_ref))
            ray.get(critic_train_handle)
        else:
            print_memory(f"[Rollout {rollout_id}] BEFORE actor_train (after SGLang offload)")
            ray.get(actor_model.async_train(rollout_id, rollout_data_ref))
            print_memory(f"[Rollout {rollout_id}] AFTER actor_train")

        if should_run_periodic_action(rollout_id, args.save_interval, num_rollout_per_epoch, args.num_rollout):
            if (not args.use_critic) or (rollout_id >= args.num_critic_only_steps):
                actor_model.save_model(rollout_id, force_sync=rollout_id == args.num_rollout - 1)
            if args.use_critic:
                critic_model.save_model(rollout_id, force_sync=rollout_id == args.num_rollout - 1)
            if args.rollout_global_dataset:
                ray.get(rollout_manager.save.remote(rollout_id))

        print_memory(f"[Rollout {rollout_id}] BEFORE offload_train")
        offload_train()
        print_memory(f"[Rollout {rollout_id}] AFTER offload_train")
        
        print_memory(f"[Rollout {rollout_id}] BEFORE onload_rollout")
        onload_rollout()
        print_memory(f"[Rollout {rollout_id}] AFTER onload_rollout (weights)")
        
        actor_model.update_weights()

        if args.offload_rollout:
            if GPU_MEMORY_TYPE_CUDA_GRAPH is not None:
                ray.get(rollout_manager.onload.remote(tags=[GPU_MEMORY_TYPE_CUDA_GRAPH]))
                print_memory(f"[Rollout {rollout_id}] AFTER onload_rollout (CUDA_GRAPH)")
            ray.get(rollout_manager.onload.remote(tags=[GPU_MEMORY_TYPE_KV_CACHE]))
            print_memory(f"[Rollout {rollout_id}] AFTER onload_rollout (KV_CACHE)")

        if should_run_periodic_action(rollout_id, args.eval_interval, num_rollout_per_epoch):
            ray.get(rollout_manager.eval.remote(rollout_id))

    ray.get(rollout_manager.dispose.remote())


if __name__ == "__main__":
    args = parse_args()
    train(args)
