import wandb
from slime.utils.tensorboard_utils import _TensorboardAdapter

from . import wandb_utils


def init_tracking(args, primary: bool = True, **kwargs):
    if primary:
        wandb_utils.init_wandb_primary(args, **kwargs)
    else:
        wandb_utils.init_wandb_secondary(args, **kwargs)


# TODO further refactor, e.g. put TensorBoard init to the "init" part
def log(args, metrics, step_key: str):
    if args.use_wandb:
        try:
            # Check if wandb is initialized
            if wandb.run is None:
                import logging
                logger = logging.getLogger(__name__)
                logger.warning(
                    f"wandb.run is None, skipping log for metrics: {list(metrics.keys())}. "
                    "This usually means wandb was not initialized for this process. "
                    "Check if init_wandb_secondary was called and if wandb_run_id was set."
                )
                return
            wandb.log(metrics)
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to log metrics to wandb: {e}, metrics: {list(metrics.keys())}")

    if args.use_tensorboard:
        metrics_except_step = {k: v for k, v in metrics.items() if k != step_key}
        _TensorboardAdapter(args).log(data=metrics_except_step, step=metrics[step_key])
