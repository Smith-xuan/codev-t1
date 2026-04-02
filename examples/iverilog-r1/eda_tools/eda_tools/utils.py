import datetime
from itertools import combinations, product
import json
import math
import os
import random
import re
import shutil
import subprocess
import networkx as nx
from openai import OpenAI
try:
    # Newer siliconcompiler 版本可能不再在顶层导出 Chip
    from siliconcompiler import Chip  # 优先尝试顶层导入
except Exception:
    try:
        from siliconcompiler import Design as Chip  # 尝试导入 Design 并重命名为 Chip
    except Exception:
        try:
            from siliconcompiler.chip import Chip  # 次选：模块内导入
        except Exception:
            from siliconcompiler.core import Chip  # 兼容更老的结构
from siliconcompiler.targets import (
    freepdk45_demo,
    asap7_demo,
    skywater130_demo,
)  # import predefined technology and flow target

def llm_request(prompt, temperature=0.5):
    api_key = os.getenv("tencent_key")
    base_url = "https://api.lkeap.cloud.tencent.com/v1"
    model = "deepseek-v3"
    messages = [{"role": "user", "content": prompt}]
    client = OpenAI(
        api_key=api_key,
        base_url=base_url,
    )
    response = client.chat.completions.create(
        model=model,
        messages=messages,
        temperature=temperature,
    )
    return response.choices[0].message.content


def extract_verilog_code(file_content):
    # 去除注释
    note_pattern = r"(//[^\n]*|/\*[\s\S]*?\*/)"
    file_content = re.sub(note_pattern, "", file_content)
    file_content = re.sub(r"(?:\s*?\n)+", "\n", file_content)

    # 匹配编译指令中的define
    define_pattern = r"`define\b\s+\b([a-zA-Z_][a-zA-Z0-9_$]*|\\[!-~]+?(?:\s|$))\b.*\n"

    # TODO 匹配更多编译指令

    # TODO 匹配 task 和 function
    # task_function_pattern = r"\btask\b\s+([a-zA-Z_][a-zA-Z0-9_$]*|\\[!-~]+(?:\s|$))[\s\S]*?\bendtask\b|\bfunction\b[\s\S]*?\bendfunction\b"

    # 匹配 module 到 endmodule 之间的内容，并提取模块名
    module_pattern = r"\bmodule\s+([a-zA-Z_][a-zA-Z0-9_$]*|\\[!-~]+?(?:\s|$))\s*(?:\#\s*\([\s\S]*?\)\s*)?\((?:(?!\bmodule\b).)*?\)\s*;(?:(?!\bmodule\b).)*?\bendmodule\b"

    # 使用字典来存储，保留每个匹配的对象中最后出现的一个
    item_dict = {}
    item_order = []
    for match in re.finditer(
        f"{module_pattern}|{define_pattern}", file_content, re.DOTALL
    ):
        item_name = match.group(1)
        if item_name not in item_order:
            item_order.append(item_name)
        item_dict[item_name] = match.group(0)

    extracted = "\n".join([item_dict[item] for item in item_order])

    return extracted


class eda_tools:

    def __init__(
        self,
        golden_suffix="_gold",
        gate_suffix="_gate",
        use_directed_tests=False,
        random_seq_steps=1000,
        random_seq_num=100,
        quiet=False,
    ):
        """
        simulator: 仿真器，主要支持iverilog，verilator有bug
        golden_suffix: 参考设计在testbench中的实例名后缀，默认_gold
        gate_suffix: 待测设计在testbench中的实例名后缀，默认_gate
        use_directed_tests: 是否使用定向测试，如果为True，则使用LLM生成的定向测试，否则使用随机测试，LLM生成效果较差，默认False
        random_seq_steps: 随机测试每个序列的长度，越长越准确，运行时间越长，默认1000
        random_seq_num: 随机测试的序列数，越多越准确，运行时间越长，默认100
        quiet: 是否打印输出，默认False
        """
        self.golden_suffix = golden_suffix
        self.gate_suffix = gate_suffix
        self.use_directed_tests = use_directed_tests
        self.random_seq_steps = random_seq_steps
        self.random_seq_num = random_seq_num
        self.quiet = quiet

    def auto_top(self, verilog_code):
        """
        自动找到verilog代码中的顶层模块，当前实现为找到最大的调用子树的根节点，当两个调用字数大小相同时，选择字典序最小的

        输入：
        verilog_code: verilog代码字符串
        输出：
        top_module: 顶层模块名
        """
        instance_graph = nx.DiGraph()
        note_pattern = r"(//[^\n]*|/\*[\s\S]*?\*/)"
        new_code = re.sub(note_pattern, "", verilog_code)
        new_code = re.sub(r"(?:\s*?\n)+", "\n", new_code)
        module_def_pattern = r"(module\s+)([a-zA-Z_][a-zA-Z0-9_\$]*|\\[!-~]+?(?=\s))(\s*\#\s*\([\s\S]*?\))?(\s*(?:\([^;]*\))?\s*;)([\s\S]*?)?(endmodule)"
        module_defs = re.findall(module_def_pattern, new_code, re.DOTALL)
        if not module_defs:
            raise Exception("No module found in auto_top().")
        module_names = [m[1] for m in module_defs]
        instance_graph.add_nodes_from(module_names)
        # 匹配 module 到 endmodule 之间的内容，并提取模块名
        for mod in module_defs:
            this_mod_name = mod[1]
            this_mod_body = mod[4]
            for submod in module_names:
                if submod != this_mod_name:
                    module_instance_pattern = rf"({re.escape(submod)})(\s)(\s*\#\s*\([\s\S]*?\))?([a-zA-Z_][a-zA-Z0-9_\$]*|\\[!-~]+?(?=\s))(\s*(?:\([^;]*\))?\s*;)"
                    module_instances = re.findall(
                        module_instance_pattern, this_mod_body, re.DOTALL
                    )
                    if module_instances:
                        instance_graph.add_edge(this_mod_name, submod)
        instance_tree_size = {}
        for n in instance_graph.nodes:
            if instance_graph.in_degree(n) == 0:
                instance_tree_size[n] = nx.descendants(instance_graph, n)
        top_module = max(instance_tree_size, key=instance_tree_size.get)
        return top_module

    def process_verilog(self, verilog_code, suffix):
        """读verilog代码，在所有模块定义和调用后面加上suffix，用于区分gold和gate设计"""
        note_pattern = r"(//[^\n]*|/\*[\s\S]*?\*/)"
        new_code = re.sub(note_pattern, "", verilog_code)
        new_code = re.sub(r"(?:\s*?\n)+", "\n", new_code)
        module_def_pattern = r"(module\s+)([a-zA-Z_][a-zA-Z0-9_\$]*|\\[!-~]+?(?=\s))(\s*\#\s*\([\s\S]*?\))?(\s*(?:\([^;]*\))?\s*;)([\s\S]*?)?(endmodule)"
        module_defs = re.findall(module_def_pattern, new_code, re.DOTALL)
        module_names = [m[1] for m in module_defs]
        for submod in module_names:
            module_instance_pattern = rf"({submod})(\s+)(\#\s*\([\s\S]*?\)\s*)?([a-zA-Z_][a-zA-Z0-9_\$]*|\\[!-~]+?(?=\s))(\s*(?:\([^;]*\))?\s*;)"
            new_code = re.sub(module_instance_pattern, rf"\1{suffix}\2\3\4\5", new_code)
        new_code = re.sub(module_def_pattern, rf"\1\2{suffix}\3\4\5\6", new_code)
        return new_code

    def extract_golden_ports(self, golden_path, golden_top, timeout=60):
        """
        根据yosys的结果，提取golden模块的输入输出端口、时钟端口、复位端口。
        golden_path: 参考设计的路径
        golden_top: 参考设计的顶层模块名

        输出：
        为一个元组(input_port_width, output_port_width, clock_port_polarity, reset_port_polarity_sync)
        input_port_width: 输入端口名、位宽
        output_port_width: 输出端口名、位宽
        clock_port_polarity: 时钟端口名、上升沿/下降沿触发
        reset_port_polarity_sync: 复位端口名、高低电平有效、同步/异步复位
        """
        golden_top = golden_top.lstrip("\\")
        # Use YOSYS_PATH environment variable if available, otherwise default to "yosys"
        yosys_bin = os.getenv("YOSYS_PATH", "yosys")
        # -sv: CVDP / modern RTL often uses logic, always_comb, etc.
        yosys_script = f'read_verilog -sv "{golden_path}"; prep -top {golden_top} -flatten; opt_dff -nodffe; json -compat-int; exec -- echo \'Happy new year~\';'
        yosys_result = subprocess.run(
            [yosys_bin, "-p", yosys_script],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
        if yosys_result.stderr:
            raise Exception(yosys_result.stderr.decode("utf-8"))
        yosys_output = yosys_result.stdout.decode("utf-8")
        yosys_json_text = re.search(
            r'(\{\n\s+"creator":[\s\S]*\})\n+[\d]+\. Executing command',
            yosys_output,
            re.DOTALL,
        ).group(1)
        yosys_json = json.loads(yosys_json_text)
        ports_ids_dict = {}
        input_port_width = set()
        output_port_width = set()
        if yosys_json["modules"] == {}:
            raise Exception("No module found in yosys output after synthesis.")
        for port_name in yosys_json["modules"][golden_top]["ports"]:
            direction = yosys_json["modules"][golden_top]["ports"][port_name][
                "direction"
            ]
            bits = yosys_json["modules"][golden_top]["ports"][port_name]["bits"]
            width = len(bits)
            ports_ids_dict[port_name] = bits
            if direction == "input":
                input_port_width.add((port_name, width))
            if direction == "output":
                output_port_width.add((port_name, width))
        clock_port_polarity = set()
        reset_port_polarity_sync = set()

        def find_single_port(port_id, ports_ids_dict):
            if len(port_id) != 1:
                raise Exception("Only support single port id now.")
            for port_name, bits in ports_ids_dict.items():
                if len(bits) == 1 and bits[0] == port_id[0]:
                    return port_name
                elif len(bits) > 1 and port_id[0] in bits:
                    return f"{port_name}[{bits.index(port_id[0])}]"
            else:
                return None

        for cell_id in yosys_json["modules"][golden_top]["cells"]:
            cell = yosys_json["modules"][golden_top]["cells"][cell_id]
            for reg_ports in cell["connections"]:
                if reg_ports == "CLK":
                    port_id = cell["connections"][reg_ports]
                    port_name = find_single_port(port_id, ports_ids_dict)
                    if port_name:
                        polarity = cell["parameters"]["CLK_POLARITY"]
                        clock_port_polarity.add((port_name, polarity))
                    break
            match cell["type"]:
                case "$adff" | "$adffe" | "$adlatch":
                    for reg_ports in cell["connections"]:
                        if reg_ports == "ARST":
                            port_id = cell["connections"][reg_ports]
                            port_name = find_single_port(port_id, ports_ids_dict)
                            if port_name:
                                polarity = cell["parameters"]["ARST_POLARITY"]
                                sync = False
                                reset_port_polarity_sync.add(
                                    (port_name, polarity, sync)
                                )
                            break
                case "$sdff" | "$sdffe" | "$sdffce":
                    for reg_ports in cell["connections"]:
                        if reg_ports == "SRST":
                            port_id = cell["connections"][reg_ports]
                            port_name = find_single_port(port_id, ports_ids_dict)
                            if port_name:
                                polarity = cell["parameters"]["SRST_POLARITY"]
                                sync = True
                                reset_port_polarity_sync.add(
                                    (port_name, polarity, sync)
                                )
                            break
                case "$dffsr" | "$dffsre" | "$dlatchsr" | "$sr":
                    for reg_ports in cell["connections"]:
                        if reg_ports == "SET" or reg_ports == "CLR":
                            port_id = cell["connections"][reg_ports]
                            port_name = find_single_port(port_id, ports_ids_dict)
                            if port_name:
                                polarity = cell["parameters"][f"{reg_ports}_POLARITY"]
                                sync = False
                                reset_port_polarity_sync.add(
                                    (port_name, polarity, sync)
                                )
                            break
                case "$dlatch" | "$ff" | "$dff" | "$dffe" | "aldff" | "$aldffe":
                    pass
                case _:
                    pass
        if not self.quiet:
            print(f"Input ports:")
            for port, width in input_port_width:
                print(f"    {port}: {width}")
            print(f"Output ports:")
            for port, width in output_port_width:
                print(f"    {port}: {width}")
            print(f"Clock ports:")
            for port, polarity in clock_port_polarity:
                print(f"    {port}: {'posedge' if polarity else 'negedge'}")
            print(f"Reset ports:")
            for port, polarity, sync in reset_port_polarity_sync:
                print(
                    f"    {port}: {'high' if polarity else 'low'} {'sync' if sync else 'async'}"
                )
        return (
            input_port_width,
            output_port_width,
            clock_port_polarity,
            reset_port_polarity_sync,
        )

    def generate_testbench(
        self,
        input_port_width,
        output_port_width,
        clock_port_polarity,
        reset_port_polarity_sync,
        golden_top,
        gate_top,
    ):
        """
        根据golden模块和gate模块的输入输出端口、时钟端口、复位端口，生成testbench代码。返回值中不会带有定向测试的具体输入，定向测试的输入在write_code_testbench中添加。

        输入：
        input_port_width: 输入端口名、位宽，为一个集合，其中的元素为(port_name, width)
        output_port_width: 输出端口名、位宽，为一个集合，其中的元素为(port_name, width)
        clock_port_polarity:
            时钟端口名、上升沿/下降沿触发
            为一个集合，其中的元素为(port_name, polarity)
            port_name是端口名，字符串
            polarity是时钟信号的极性，1表示上升沿触发，0表示下降沿触发
        reset_port_polarity_sync:
            复位信号的端口名、高低电平有效、同步/异步复位
            为一个集合，其中的元素为(port_name, polarity, sync)
            port_name是端口名，字符串
            polarity是复位信号的极性，1表示高电平有效，0表示低电平有效
            sync是复位信号的同步异步，True表示同步复位，False表示异步复位
        golden_top: 参考设计的顶层模块名
        gate_top: 待测设计的顶层模块名

        输出：不包括定向测试的具体输入值的testbench代码
        """
        reset_port_names = set([p[0] for p in reset_port_polarity_sync])
        if len(clock_port_polarity) > 1:
            raise Exception(
                "Multiple clock ports or multiple triggering edge detected, currently not supported."
            )

        clock_port_name = (
            list(clock_port_polarity)[0][0] if clock_port_polarity else None
        )
        clock_port_edge = (
            list(clock_port_polarity)[0][1] if clock_port_polarity else None
        )
        input_port_names = [p[0] for p in input_port_width]
        output_port_names = [p[0] for p in output_port_width]

        # 生成输入信号定义
        input_defs = "\n    ".join(
            [f"reg [{width-1}:0] {port}_in ;" for port, width in input_port_width]
        )
        gold_output_defs = "\n    ".join(
            [
                f"wire [{width-1}:0] {port}{self.golden_suffix} ;"
                for port, width in output_port_width
            ]
        )
        gate_output_defs = "\n    ".join(
            [
                f"wire [{width-1}:0] {port}{self.gate_suffix} ;"
                for port, width in output_port_width
            ]
        )
        # 生成trigger信号，trigger信号为1时表示golden和gate输出不一致
        trigger_assign = (
            "\n    always @(*) begin\n        #5; trigger = ~( "
            + " & ".join(
                [
                    f"{port}{self.golden_suffix} === {port}{self.gate_suffix}"
                    for port in output_port_names
                ]
                + ["1'b1"]
            )
            + " );\n    end\n"
        )

        # 实例化gold和gate模块的端口赋值语句
        gold_port_mappings = ",\n        ".join(
            [f".{port}( {port}_in )" for port in input_port_names]
            + [f".{port}( {port}{self.golden_suffix} )" for port in output_port_names]
        )
        gate_port_mappings = ",\n        ".join(
            [f".{port}( {port}_in )" for port in input_port_names]
            + [f".{port}( {port}{self.gate_suffix} )" for port in output_port_names]
        )

        # 生成随机化输入信号的task
        randomize_inputs_lines = "\n            ".join(
            [
                f"{port}_in = {{{', '.join(['$random(seed)']*math.ceil(width/32))}}};"
                for port, width in input_port_width
                if port not in [clock_port_name] + list(reset_port_names)
            ]
        )
        randomize_inputs_task = f"""// task to generate random inputs
    task randomize_inputs;
        begin
            {randomize_inputs_lines}
        end
    endtask
"""
        # 根据复位信号的极性和同步异步，进行组合，生成不同组合下复位的task
        # 按照reset端口名进行分组
        grouped = {}
        for port, polarity, sync in reset_port_polarity_sync:
            if port not in grouped:
                grouped[port] = []
            grouped[port].append((port, polarity, sync))

        # 生成所有可能的组合，一个port name在一个组合中最多只能出现一次
        all_reset_combinations = []
        for r in range(1, len(grouped) + 1):
            for ports in combinations(grouped.keys(), r):
                for polarities_syncs in product(*[grouped[port] for port in ports]):
                    all_reset_combinations.append(list(polarities_syncs))
        # 根据每种组合生成复位信号的task，同步复位的task中，复位信号赋值后需要clock完成一次上升和下降沿
        reset_task_list = []
        for i, reset_comb in enumerate(all_reset_combinations):
            sync_reset_lines = []
            async_reset_lines = []
            unset_lines = []
            for port, polarity, sync in reset_comb:
                if sync:
                    sync_reset_lines.append(f"{port}_in = {polarity};")
                else:
                    async_reset_lines.append(f"{port}_in = {polarity};")
                unset_lines.append(f"{port}_in = {0 if polarity == 1 else 1};")
            reset_lines = (
                (
                    "\n            ".join(sync_reset_lines)
                    + "\n            # 10; toggle_clock; # 10; toggle_clock;\n            "
                    + "\n            ".join(unset_lines)
                )
                if sync_reset_lines
                else "" + "\n            ".join(async_reset_lines + unset_lines)
            )
            reset_task = f"""task reset_{i};
        begin
            {reset_lines}
        end
    endtask
"""
            reset_task_list.append(reset_task)
        # 生成定向测试的task，定向测试的赋值由用户改写或LLM生成
        directed_tests_task = f"""// Task for directed test. The inputs should be able to activate all functionalities in the golden design, and checks whether the gate design and the golden design are equivalent.
    task directed_tests;
        begin
            // [TODO] directed tests here.
            {'# 10; toggle_clock; # 10; toggle_clock;' if clock_port_name else ''}
        end
    endtask
"""

        # 生成翻转时钟信号的task
        toggle_clock_task = f"""// Task to toggle {clock_port_name}_in
    task toggle_clock;
        begin
            {clock_port_name}_in = ~{clock_port_name}_in ;
        end
    endtask
"""
        count_errors_task = f"""// Task to count errors
    task count_errors;
        begin
            if (trigger === 1'b1) begin
                num_errors = num_errors + 1;
            end
            num_all = num_all + 1;
        end
    endtask
"""
        # 生成随机复位信号的task
        random_reset_lines = "\n            ".join(
            [f"{port}_in = $random(seed);" for port in reset_port_names]
        )

        random_reset_task = f"""// Task for random reset
    task random_reset;
        begin
            {random_reset_lines}
        end
    endtask
"""

        # 生成 initial block
        initial_block_lines = [
            "// initial block for random tests and targed tests",
            "initial begin",
            '    if (!$value$plusargs("seed=%d", seed)) seed = 0;',
            f'    if (!$value$plusargs("outerLoopNum=%d", outerLoopNum)) outerLoopNum = {self.random_seq_num};',
            f'    if (!$value$plusargs("innerLoopNum=%d", innerLoopNum)) innerLoopNum = {self.random_seq_steps};',
            (
                f"    {clock_port_name}_in = {0 if clock_port_edge else 1};"
                if clock_port_name
                else ""
            ),
            f"    repeat (outerLoopNum) begin",
            "        random_reset;" if reset_port_names else "",
            "        #100; count_errors;",
            f"        repeat (innerLoopNum) begin",
            "            #100; randomize_inputs;",
            "            #100; toggle_clock;" if clock_port_name else "",
            "            #100; count_errors;",
            "        end",
            "    end",
        ]
        if reset_port_names:
            initial_block_lines.append("    #100;")
            for i in range(len(reset_task_list)):
                initial_block_lines.append(
                    f"    repeat (outerLoopNum) begin",
                )
                initial_block_lines.append(f"        reset_{i};")
                initial_block_lines.append(f"        #100; count_errors;")
                initial_block_lines.append(
                    f"        repeat (innerLoopNum) begin",
                )
                initial_block_lines.append(f"            #100; randomize_inputs;")
                (
                    initial_block_lines.append(f"            #100; toggle_clock;")
                    if clock_port_name
                    else ""
                )
                initial_block_lines.append(f"            #100; count_errors;")
                initial_block_lines.append(f"        end")
                initial_block_lines.append(f"    end")

        if self.use_directed_tests:
            if reset_port_names:
                for i in range(len(reset_task_list)):
                    initial_block_lines.append(f"    reset_{i};")
                    initial_block_lines.append("    #100;")
                    initial_block_lines.append("    directed_tests;")
                    initial_block_lines.append("    #100;")
            else:
                initial_block_lines.append("    directed_tests;")
        initial_block_lines += [
            '    $display("Number of all tests:  %d", num_all);',
            '    $display("Number of errors:     %d", num_errors);',
            '    $display("Error rate: %.8f", num_errors/num_all);',
            "    if (num_errors == 0) begin",
            '        $display("All tests passed.");',
            "    end",
            "    $finish;",
            "end",
        ]
        initial_block = "\n    ".join(initial_block_lines)

        # 生成监测输出信号的 always block
        monitor_block = f"""always @(trigger) begin
        if (trigger === 1'b1) begin
            $error("trigger signal is 1, which is not allowed!");
            $finish;
        end
    end
"""

        # 生成完整的 testbench 代码
        testbench_code = f"""

module testbench;
    {input_defs}
    {gold_output_defs}
    {gate_output_defs}

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    {golden_top}{self.golden_suffix} gold (
        {gold_port_mappings}
    );
    {gate_top}{self.gate_suffix} gate (
        {gate_port_mappings}
    );
    {trigger_assign}
    {toggle_clock_task if clock_port_name else ""}
    {''.join(reset_task_list) if reset_port_names else ""}
    {random_reset_task if reset_port_names else ""}
    {randomize_inputs_task}
    {directed_tests_task if self.use_directed_tests else ""}
    {count_errors_task}
    {initial_block}
endmodule
"""
        return testbench_code

    def generate_directed_test(
        self,
        golden_code,
        tb_code,
    ):
        """
        生成定向测试的输入并插入testbench代码中，返回插入后的testbench代码

        输入：
        golden_code: 参考设计的代码
        tb_code: testbench的代码

        输出：
        返回值为(renamed_golden_code, tb_module_code)
        """
        renamed_golden_code = self.process_verilog(golden_code, self.golden_suffix)
        fim_code = renamed_golden_code + tb_code
        if self.use_directed_tests:
            print("Generating directed tests with LLM...") if not self.quiet else None
            fim_prompt = f"""
Given the following Verilog design code and its testbench:
```verilog
{fim_code}
```
Please complete the directed test inputs in the testbench.  Only provide the code that replaces the "[TODO] directed tests here." section, wrapped in a ```verilog``` code block. Do not include any other content or explanations in your response.
Example of expected response format:
```verilog
// Your directed test code here
```
"""
            try:
                response = llm_request(fim_prompt)
                directed_inputs = re.findall(
                    r"```verilog(.*?)```", response, re.DOTALL
                )[0]
                tb_module_code = tb_code.replace(
                    "// [TODO] directed tests here.", directed_inputs
                )
            except Exception as e:
                print(e)
                print("Failed to generate directed tests with LLM.")
        return renamed_golden_code, tb_module_code

    def write_code_testbench(
        self,
        golden_path,
        gate_path,
        golden_top,
        gate_top,
        tb_dir,
        input_port_width,
        output_port_width,
        clock_port_polarity,
        reset_port_polarity_sync,
    ):
        """
        写gold设计和gate设计和testbench到文件，定向测试的具体输入在本函数中添加。

        输入：
        golden_path: 参考设计的path
        gate_path: 待测设计的path
        golden_top: 参考设计的顶层模块名
        gate_top: 待测设计的顶层模块名
        tb_dir: 生成的testbench所在的路径，包括Makefile，verilator在这个路径下运行

        输出：
        返回值为(renamed_golden_code, renamed_gate_code, tb_module_code)
        """
        if not os.path.exists(tb_dir):
            os.makedirs(tb_dir)
        with open(golden_path, "r") as f:
            golden_code = f.read()
        print("Processing golden code...") if not self.quiet else None
        renamed_golden_code = self.process_verilog(golden_code, self.golden_suffix)

        if gate_path is not None:
            with open(gate_path, "r") as f:
                gate_code = f.read()
            print("Processing gate code...") if not self.quiet else None
            renamed_gate_code = self.process_verilog(gate_code, self.gate_suffix)
            with open(os.path.join(tb_dir, "gate.v"), "w") as f:
                f.write(renamed_gate_code)

        tb_module_code = self.generate_testbench(
            input_port_width,
            output_port_width,
            clock_port_polarity,
            reset_port_polarity_sync,
            golden_top,
            gate_top,
        )
        fim_code = renamed_golden_code + tb_module_code
        if self.use_directed_tests:
            print("Generating directed tests with LLM...") if not self.quiet else None
            fim_prompt = f"""
Given the following Verilog design code and its testbench:
```verilog
{fim_code}
```
Please complete the directed test inputs in the testbench.  Only provide the code that replaces the "[TODO] directed tests here." section, wrapped in a ```verilog``` code block. Do not include any other content or explanations in your response.
Example of expected response format:
```verilog
// Your directed test code here
```
"""
            try:
                response = llm_request(fim_prompt)
                directed_inputs = re.findall(r"```verilog(.*?)```", response, re.DOTALL)
                tb_module_code = tb_module_code.replace(
                    "// [TODO] directed tests here.", directed_inputs
                )
            except Exception as e:
                print(e)
                print("Failed to generate directed tests with LLM.")
        with open(os.path.join(tb_dir, "tb.v"), "w") as f:
            f.write(renamed_golden_code)
            f.write("\n")
            f.write(tb_module_code)
        return renamed_golden_code, renamed_gate_code, tb_module_code

    def equiv_with_testbench(
        self,
        golden_path,
        gate_path,
        golden_top,
        gate_top,
        tb_dir,
        seed=0,
        outerLoopNum=None,
        innerLoopNum=None,
        timeout=60,
    ):
        """
        一个wrapper，用于生成testbench并运行，输出测试结果，如果运行的输出中有"all tests passed."则测试通过，否则测试失败

        输入：
        golden_path: 参考设计的path
        gate_path: 待测设计的path
        golden_top: 参考设计的顶层模块名
        gate_top: 待测设计的顶层模块名
        tb_dir: 生成的testbench所在的路径，包括Makefile，verilator在这个路径下运行
        seed: 控制testbench测试时的随机种子，默认0，和之前对齐
        outerLoopNum: 控制testbench测试时的外层循环次数，默认None，此时采用self.random_seq_num和之前对齐
        innerLoopNum: 控制testbench测试时的内层循环次数，默认None，此时采用self.random_seq_steps和之前对齐
        timeout: 仿真超时时间，默认60s

        输出：
        返回值为True或False，表示测试通过或失败
        """
        if outerLoopNum == None:
            outerLoopNum = self.random_seq_num
        if innerLoopNum == None:
            innerLoopNum = self.random_seq_steps
        (
            input_port_width,
            output_port_width,
            clock_port_polarity,
            reset_port_polarity_sync,
        ) = self.extract_golden_ports(golden_path, golden_top)
        self.write_code_testbench(
            golden_path=golden_path,
            gate_path=gate_path,
            golden_top=golden_top,
            gate_top=gate_top,
            tb_dir=tb_dir,
            input_port_width=input_port_width,
            output_port_width=output_port_width,
            clock_port_polarity=clock_port_polarity,
            reset_port_polarity_sync=reset_port_polarity_sync,
        )

        iverilog_bin = os.getenv("IVERILOG_PATH", "iverilog")
        vvp_bin = os.getenv("VVP_PATH", "vvp")
        # command = f"iverilog -g2012 -o {os.path.join(tb_dir,'tb.vvp')} -s testbench {os.path.join(tb_dir,'*.v')} && {os.path.join(tb_dir,f'tb.vvp +seed={seed} +outerLoopNum={outerLoopNum} +innerLoopNum={innerLoopNum}')}"
        command = f"{iverilog_bin} -g2012 -o {os.path.join(tb_dir,'tb.vvp')} -s testbench {os.path.join(tb_dir,'*.v')} && {vvp_bin} -n {os.path.join(tb_dir,'tb.vvp')} +seed={seed} +outerLoopNum={outerLoopNum} +innerLoopNum={innerLoopNum}"
        res = subprocess.run(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
        error_rate_pattern = r"Error rate:\s*(\d+\.\d+)\n"
        print(res.stdout.decode("utf-8")) if not self.quiet else None
        if re.search(error_rate_pattern, res.stdout.decode("utf-8")):
            error_rate = float(
                re.search(error_rate_pattern, res.stdout.decode("utf-8")).group(1)
            )
        else:
            error_rate = 1.0
        # TODO 实现得比较丑陋
        if "All tests passed." in res.stdout.decode("utf-8"):
            print("Test passed!") if not self.quiet else None
            return (
                True,
                error_rate,
                input_port_width,
                output_port_width,
                clock_port_polarity,
                reset_port_polarity_sync,
            )

        else:
            print("Test failed!") if not self.quiet else None
            return (
                False,
                error_rate,
                input_port_width,
                output_port_width,
                clock_port_polarity,
                reset_port_polarity_sync,
            )

    def synthesis_with_siliconcompiler(
        self,
        job_name: str,
        rtl_paths: list,
        top: str,
        clk: str = None,
        tech: str = "freepdk45",
        timeout=60,
        build_dir="./work/build",
    ) -> dict:
        """
        用来综合一个设计，返回综合结果，包括cell_area, peak_power, arrival_time

        输入：
        job_name: 任务名，用于区分不同的任务
        rtl_paths: rtl代码的路径，是一个list
        top: 顶层模块名
        tech: 技术库，支持freepdk45, asap7, skywater130，默认freepdk45
        rm_build: 是否删除build目录，默认True

        输出：
        返回值为一个字典，包括cell_area, peak_power, arrival_time
        """
        chip = Chip(top)  # create chip object
        chip.set("option", "builddir", build_dir)
        chip.set("option", "jobname", job_name)
        chip.set("option", "clean", True)
        chip.set("option", "loglevel", "critical" if self.quiet else "info")
        chip.set("option", "timeout", timeout)
        for path in rtl_paths:
            chip.input(path)
        if clk:
            chip.clock(clk, period=0.1)  # define clock speed of design
        match tech:
            case "freepdk45":
                chip.use(freepdk45_demo)
            case "asap7":
                chip.use(asap7_demo)
            case "skywater130":
                chip.use(skywater130_demo)
            case _:
                raise ValueError(f"Unsupported technology {tech}")
        chip.set("option", "flow", "synflow")
        chip.set("option", "remote", False)  # run remote in the cloud
        chip.run()  # run compilation of design and target
        cellarea = chip.get("metric", "cellarea", step="timing", index=0)
        peakpower = chip.get("metric", "peakpower", step="timing", index=0)
        workdir = chip.getworkdir(step="timing", index=0)
        with open(os.path.join(workdir, "reports/unconstrained.rpt"), "r") as f:
            rpt = f.read()
            at_pattern = r"^\s+(\d*\.?\d*)\s+data arrival time"
            try:
                arrival_time = float(re.search(at_pattern, rpt, re.MULTILINE).group(1))
            except:
                arrival_time = None
        ppa = {
            "cell_area": cellarea,
            "peak_power": peakpower,
            "arrival_time": arrival_time,
        }
        return ppa


###################################################################################
    def yosys_opensta_ppa(
        self,
        job_name: str,
        rtl_paths: list,
        top: str,
        clk: str = None,
        tech: str = "freepdk45",
        timeout: int = 60,
        build_dir: str = "./work/build",
        yosys_script: str = "yosys.ys"
    ) -> dict:
        base_dir = os.path.dirname(os.path.abspath(os.path.dirname(__file__)))
        
        ppa = {
            "cell_area": None,
            "peak_power": None,
            "arrival_time": None,
            "premap_cells": None,
            "premap_wires": None, 
            "postmap_cells": None, 
            "postmap_wires": None
        }
        for path in rtl_paths:
            file_path = path
        match tech:
            case "freepdk45":
                t_ech = f"{base_dir}/tech/NangateOpenCellLibrary_typical.lib"
            case _:
                raise ValueError(f"Unsupported technology {tech}")
        top_module = top
        os.makedirs("reports", exist_ok=True)
        file_id = file_path.split("/")[-1].split(".")[0]
        report_dir = os.path.join("reports", file_id)
        os.makedirs(report_dir, exist_ok=True)
        power_path = os.path.join(report_dir, "power.rpt")
        unconstrained_path = os.path.join(report_dir, "unconstrained.rpt")
        # yosys_script = yosys_script.replace("/yosys.ys", "/simple_yosys.ys")
        with open(yosys_script, "r") as f:
            ys_template = f.read()

        ys_script = ys_template.format(
            file_path=file_path,
            top_module=top_module,
            t_ech=t_ech,
            base_dir=base_dir
        )
        try:
            result = subprocess.run(
                ["yosys"],
                input=ys_script,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=True,
                timeout=timeout
            )
        except subprocess.TimeoutExpired:
            print(f"Error: Yosys command timed out after {timeout} seconds.")
            ppa["error"] = "Yosys Timeout"
            return ppa
        except subprocess.CalledProcessError as e:
            print(f"Yosys command failed with error:\n{e.stderr}")
            ppa["error"] = "Yosys error:\n" + e.stderr
            return ppa
        
        if result.returncode == 0:
            for line in result.stdout.split('\n'):
                if "Chip area for" in line:
                    match = re.search(r'\d+\.\d+', line)
                    if match:
                        chip_area = float(match.group())
                        ppa["cell_area"] = chip_area
                    else:
                        print("No valid value found:", line.strip())
            seen_premap_wires = False
            seen_premap_cells = False

            for line in result.stdout.split('\n'):
                stripped = line.strip()

                if stripped.startswith("Number of wires:"):
                    parts = stripped.split()
                    try:
                        count = int(parts[-1])
                    except (IndexError, ValueError):
                        print("No valid wire count found:", stripped)
                        continue

                    if not seen_premap_wires:
                        ppa["premap_wires"] = count
                        seen_premap_wires = True
                    else:
                        ppa["postmap_wires"] = count

                elif stripped.startswith("Number of cells:"):
                    parts = stripped.split()
                    try:
                        count = int(parts[-1])
                    except (IndexError, ValueError):
                        print("No valid cell count found:", stripped)
                        continue

                    if not seen_premap_cells:
                        ppa["premap_cells"] = count
                        seen_premap_cells = True
                    else:
                        ppa["postmap_cells"] = count            
                
        with open(f"{base_dir}/scripts/sta.ys", "r") as f:
            sta_template = f.read()
        clock_constraint = ""
        if clk is not None:
            clock_constraint = f'create_clock -name {clk} -period 10 [get_ports {clk}]\n'
        sta_script = sta_template.replace("{t_ech}", t_ech).replace("{top_module}", top_module).replace("{file_path}", file_path).replace("{file_id}", file_id).replace("{base_dir}", base_dir)
        if clock_constraint:
            sta_script = sta_script.replace(
                f'link_design $sc_design',
                f'link_design $sc_design\n{clock_constraint}'
            )
        try:
            result = subprocess.run(
                ["sta"],
                input=sta_script,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=True
            )
        except subprocess.TimeoutExpired:
            print(f"Error: STA command timed out after {timeout} seconds.")
            ppa["error"] = "STA Timeout"
            return ppa
        except subprocess.CalledProcessError as e:
            print(f"STA command failed with error:\n{e.stderr}")
            ppa["error"] = "STA error:\n" + e.stderr
            return ppa
        
        try:
            with open(power_path, 'r') as f:
                for line in f:
                    if line.startswith('Total'):
                        match = re.search(r'^Total\s+\S+\s+\S+\s+\S+\s+(\S+)', line)
                        if match:
                            ppa["peak_power"] = float(match.group(1)) * 1000
                        else:
                            print(f"No peak_power value found in {power_path}")
                        break
        except FileNotFoundError:
            print(f"File not found: {power_path}")

        try:
            with open(unconstrained_path, 'r') as f:
                for line in f:
                    if 'data arrival time' in line:
                        match = re.search(r'^\s*(\d+\.\d+)\s+data arrival time', line)
                        if match:
                            ppa["arrival_time"] = float(match.group(1))
                        else:
                            print(f"No arrival_time value found in {unconstrained_path}")
                        break
        except FileNotFoundError:
            print(f"File not found: {unconstrained_path}")

        return ppa
###################################################################################

class myLogger:
    def __init__(self):
        self.log = []

    def info(self, info_content):
        self.log.append([str(datetime.datetime.now()), "INFO", info_content])

    def debug(self, debug_content):
        self.log.append([str(datetime.datetime.now()), "DEBUG", debug_content])

    def output(self, level):
        match level:
            case "info":
                lines = [l for l in self.log if l[1] == "INFO"]
                text = "\n".join([" - ".join(l) for l in lines])
                return text
            case "debug":
                text = "\n".join([" - ".join(l) for l in self.log])
                return text
            case _:
                raise Exception("Unsupported. Only support info and debug.")


def main():
    eda = eda_tools(quiet=True)
    with open("./temp/gold.v", "r") as f:
        gold_code = f.read()
        gold_top = eda.auto_top(gold_code)
    with open("./temp/gate.v", "r") as f:
        gate_code = f.read()
        gate_top = eda.auto_top(gate_code)
    (
        input_port_width,
        output_port_width,
        clock_port_polarity,
        reset_port_polarity_sync,
    ) = eda.extract_golden_ports("./temp/gold.v", gold_top)
    tb = eda.generate_testbench(
        input_port_width,
        output_port_width,
        clock_port_polarity,
        reset_port_polarity_sync,
        gold_top,
        gate_top,
    )
    with open("./temp/tb.v", "w") as f:
        f.write(eda.process_verilog(gold_code, eda.golden_suffix))
        f.write("\n")
        f.write(eda.process_verilog(gate_code, eda.gate_suffix))
        f.write("\n")
        f.write(tb)


if __name__ == "__main__":
    main()
