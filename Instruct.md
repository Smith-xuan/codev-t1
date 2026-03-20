# 任务背景

仓库 /home/i-zhangxiaoyun/codev-t1 此前是基于 slime 训练框架，在以 slurm 为资源调度系统的情况下，用于启动 verilog 多轮工具调用代码生成多轮强化学习的训练代码。其主要的执行脚本位于 /home/i-zhangxiaoyun/codev-t1/examples/iverilog-r1/run_qwen3_8b_cvdp_testbench.sh，但此脚本非常冗余，比如涉及到很多根本用不上的环境变量，比如VERL相关和SANDBOX相关。同时，当时由于slurm管理系统的环境配置问题，又引入了很多丑陋的解决措施，比如即使环境中已拥有iverlog或者yosys的执行文件，但也必须显式的给出可执行文件路径用于调用执行，因此又给出了很多代码或者可执行文件的path，又或者调用一些ulimit的命令解决bug。总体来说启动代码极其冗余和复杂。

# 任务指令

我现在已经迁移至以brainpp为资源管理训练系统的服务器环境中，slurm已经被我抛弃不用。或许可根据 slime 提供的原始 README “/home/i-zhangxiaoyun/codev-t1/README_ori.md”，以及slime提供的原生最简训练脚本，重新写一个简单有用的训练qwen3_8b_cvdp_testbench的启动代码（训练相关的超参数保持一致），同时由于 brainpp 可通过 rjob/jlaunch 利用我已经打好的镜像 hub.i.basemind.com/diversity/slime:0319 启动docker，原本一些需要提供可执行文件的环境变量（比如 VVP_PATH）和相关代码比如（vvp_bin = os.getenv("VVP_PATH", shutil.which("vvp") or "vvp")）也是应该不需要的，如果不影响的情况下也可以保留。申请资源启动的方式你可以查看Skill或者参考 /home/i-zhangxiaoyun/verl/recipe/aec/rjob 中的脚本（尽管这个脚本不是最优解，理论上应该有自动传递head节点ip的指令）。 现在请修改相关训练代码，形成新的实验入口启动脚本，rjob/jlaunch提交申请资源一键调用实验入口启动脚本的脚本。并形成新的README.md.