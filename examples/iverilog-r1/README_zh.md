多节点tir训练执行脚本在examples/iverilog-r1/run_qwen3_1.7b_multinode_megatron.sh
相关代码在examples/iverilog-r1

### 仿照search-r1的风格:
1. 将iverilog工具写成http服务(/nfs_global/slime/examples/iverilog-r1/local_iverilog_server.py, /nfs_global/slime/examples/iverilog-r1/iverilog_server.py)
2. 写了替换的sglang rollout代码（/nfs_global/slime/examples/iverilog-r1/generate_with_iverilog.py）和reward代码（/nfs_global/slime/examples/iverilog-r1/generate_with_iverilog.py）

## 遇到的问题：
### 环境问题：
1. 虽然官网推荐用docker，但考虑到可迁移性，这里从头构建环境

2. 由于torch版本为2.9.1，没有预编译的flash_attn whl文件，要单独编译安装。2.7.4.post1可以在torch2.9.1+cu129情况下编译（即使服务器上只有cuda12.4），但最大job数只能开4或8，更大会编译失败。

### 多节点问题：
1. 多节点启动时，由于micromamba的根目录在/root下，10.21.0.12节点需要把安装的所有不在共享内存下的目录同步迁移(比如slime和sglang路径)。

2. 多节点用ray启动时，要指明节点间通信的网卡为eth0（nccl和gloo要用到，如果不指明，worker节点会自行设置为外网节点，导致连接失败），此外sglang router启动时要单独指定端口。

### rollout阶段问题：
1. rollout时会因为/tmp下空间不足而导致deepgemm编译算子时爆内存
如果粗暴将临时文件路径从/tmp换到/nfs_global/tmp/，会直接导致程序无法启动（nfs文件系统有很多奇怪的bug）。
因此，采取的解决方法为：
禁用 DeepGEMM，会导致rollout过程的10%左右的性能损失，但没办法。
其次，把临时目录改回本地 /tmp，但把编译缓存重定向到 NFS文件目录

2. 工具服务器rollout中途卡死
由于iverilog起的时http服务没有隔离，有些超长的仿真输出（比如很大的循环）会写很大的临时文件，造成nfs文件系统io卡死
解决方法是，在iverilog起服务时，添加超时处理、输出限制，并在每次仿真结束后删除临时文件。


### 训练阶段问题：
1. 爆显存
fsdp的爆显存问题暂时还没解决，感觉是slime对fsdp后端支持不够好导致的，加了一些清理显存的操作还是会因为训练开始的时候超长上下文形成的巨大的logits张量oom
换成megatron后端后，可以开更多的并行，就好了很多。

2. 速度慢
一个是http的iverilog服务器并发数不够大，且超时时间较长，可以设大并发数和超时时间。
另一个是megatron后端要设置--sglang-cuda-graph-bs 1 2 4 8 $(seq 16 8 256)，这样可以预编译CUDA graph，减少运行时的开销

3. sglang服务器断联
```
File "/nfs_global/micromamba/envs/slime/lib/python3.12/site-packages/httpx/_transports/default.py", line 118, in map_httpcore_exceptions
raise mapped_exc(message) from exc
httpx.ReadError
```
在训练期间会报该错，推测是负载并发导致的通信抖动
可以通过给sglang引擎的http请求加上重试机制解决。

4. 工具服务器从http服务和sandbox fusion换到本地执行
iverilog工具部分尝试了很多类，slime示例的search工具直接是起了一个http服务，实测会经常因为http卡死导致rollout时候程序断开；也尝试了verl中的sandbox fusion，发现高并发的时候会有很多空白的输出，即使能正常编译也会输出空白反馈，打印出来发现没正常进行编译仿真，怀疑是高并发时的临时文件覆盖bug之类的；最后选用了直接在sglang server所在的节点进行本地的iverilog调用，加了一些限制防止不安全代码，3s超时，发现超时的还挺多，几十万次工具调用，大概有30-40%都超时。
