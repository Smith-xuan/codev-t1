## 测试

本地测试流程参考`LOCAL_INFERENCE_GUIDE.md`，分为export、模型推理、import+测试三步。注意import时使用`run_samples.py`才能测多次采样的结果。（我对`run_samples.py`进行了一些修改，适配它的多次采样测试规则）

有些连外网的不方便的地方需要调整：
- `.env`里面设置一下
```bash
OSS_SIM_IMAGE=ghcr.nju.edu.cn/hdl/sim/osvb
OSS_PNR_IMAGE=ghcr.nju.edu.cn/hdl/impl/pnr
```
- `example_dataset/cvdp_v1.0.1_example_nonagentic_code_generation_no_commercial_with_solutions.jsonl`等文件里面的一个`RUN pip install cocotb-bus`需要换成国内源，例如`RUN pip install -i http://mirrors.tencentyun.com/pypi/simple --trusted-host mirrors.tencentyun.com cocotb-bus`

### 采样+测试的例子
- 首先进行export阶段，运行`bash scripts/export.sh`，得到`data/prompts.jsonl`
- 采样部分：
    - 如果调用API（可参考`/nfs_global/NeMo-Skills/README.md`）：
        - 首先`cd /nfs_global/NeMo-Skills/`
        - 运行`openmathreasoning-verilog/problem-sdg/script/data_convert_cvdp.py`
        - 在`recipes/openmathreasoning/configs/solution_sdg/`里修改对应的采样配置文件，需要改的东西大致有：
            - expname
            - suffix
            - input_name
            - output_name
            - num_random_seeds_to_generate
            - **num_chunks** (目前只要generate_solutions阶段的)
        - 如果是一个新的模型的话，还要在`cluster_configs`下面添加相应的配置，并且在`nemo_skills/inference/model`下面添加对应模型的代码，可以先试试用默认的`openai.py`行不行。
        - `python recipes/openmathreasoning/pipeline/solution_generation.py --mode (例codev-tir-claude-api-ppa) --stages generate_solutions`，**结果在`openmathreasoning-verilog/solution-sdg-xxx`里面**，其中xxx是之前配置文件里面填的suffix。
    - 如果本地推理
        - **TODO**
- 回到`/nfs_global/projects/cvdp_benchmark`进行后处理+测试
    - 如果是verl推理输出的parquet格式
        - **TODO**，可参考`scripts/eval_end_to_end.sh`
        - scripts有两个脚本，一个`extract_responses.py`提取COT，一个`extract_verilog_from_jsonl.py`提取verilog代码。
    - 如果是NeMo-Skills里面调用API
        - 可参考`scripts/eval_end_to_end_api.sh`，这边之前没沟通好俩人写重复了（这部分之前写在了NeMo-Skills文件夹里面），这里用的是`scripts/extract_verilog_answers_improved.py`和`scripts/process_cvdp_result.py`

### 采样及测试结果
采样结果在`results/claude_no_tool/`和`results/claude_tool/`里面，我在cot文件夹下面把每一题的COT给提取出来了。
测试结果在`results/experiment_no_tool/`和`results/experiment_tool/`里面，下面那个`composite_report.txt`可以看每一题的模型做的情况。具体更细的测试见下一节--单题测试。

### 单题测试
首先找到测试结果的文件夹，例如`/nfs_global/projects/cvdp_benchmark/results/experiment_tool/sample_3/cvdp_copilot_line_buffer/`。先把要测的verilog代码复制到harness下面rtl文件夹的.v文件里面，然后运行harness里面的`run_docker_harness_01-new-tb.sh`就能测单题了。

另外我在`scripts/tmp/tool_corr_cvdp.py`写了个测所有工具调用+最后代码对错的脚本，可以直接跑。

### 全流程测试（只看这个就够了！！）

整体流程在外层的`scripts/test_cvdp.sh`里面，代码生成和理解的部分都有。其中代码理解对它的评测代码做了如下适配和改进：

```
火山引擎的评分代码在CVDP的examples/sbj_score_model.py和custom_factory_ark.py里面
跑出来的结果在$RESULT_DIR/results/$NAME里面，具体每个点的报错在sample_1/raw_result.json这些文件里面
修了benchmark/CVDP/src/dataset_processor.py第1189行开始的一段，否则cid006/008跑出来结果有问题
目前CVDP的rouge实现有点问题(benchmark/CVDP/src/subjective.py的calculate_ROUGE)，自己对自己算都不是1。
对于correspondence任务，如果有多段代码的话，评测的时候是直接把每段代码外面套上`````` / ```verilog``` / ```systemverilog```拼接完了评测的。这里有一个顺序问题，但我看它应该只测了BLEU-2，那顺序应该不是问题，因为外面都给包了一层``````，拼接处没有不一致的情况。
此外调整了一些格式，除了benchmark/CVDP/src/dataset_processor.py加的code段以外还在if 'subjective_reference' in self.context[id]:那里面把reference的```给处理了一下。虽然不完善，但好歹测出来点高了点。
```