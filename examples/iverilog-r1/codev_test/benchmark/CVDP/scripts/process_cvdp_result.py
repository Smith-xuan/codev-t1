import json
import argparse
import os
import re

problem_file = '/nfs_global/projects/cvdp_benchmark/data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl'

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=str, default='input.jsonl')
    parser.add_argument('--output', type=str, default='output.jsonl')
    parser.add_argument('--input_cot', type=str, default=None)
    parser.add_argument('--output_cot', type=str, default=None)
    args = parser.parse_args()

    names = []
    with open(problem_file, 'r') as f:
        for line in f:
            problem = json.loads(line)
            if problem.get("categories")[0] == 'cid016':
                names.append(problem.get("id"))

    name_mapping = {i+1 : names[i] for i in range(len(names))}
    # print(name_mapping)
    # {1: 'cvdp_copilot_32_bit_Brent_Kung_PP_adder_0001', 2: 'cvdp_copilot_64b66b_encoder_0005', 3: 'cvdp_copilot_Carry_Lookahead_Adder_0005', 4: 'cvdp_copilot_String_to_ASCII_0001', 5: 'cvdp_copilot_apb_dsp_op_0002', 6: 'cvdp_copilot_arithmetic_progression_generator_0015', 7: 'cvdp_copilot_axi_alu_0001', 8: 'cvdp_copilot_cache_lru_0022', 9: 'cvdp_copilot_caesar_cipher_0024', 10: 'cvdp_copilot_cdc_pulse_synchronizer_0004', 11: 'cvdp_copilot_coffee_machine_0001', 12: 'cvdp_copilot_data_serializer_0001', 13: 'cvdp_copilot_filo_0033', 14: 'cvdp_copilot_fsm_seq_detector_0023', 15: 'cvdp_copilot_galois_encryption_0001', 16: 'cvdp_copilot_generic_nbit_counter_0036', 17: 'cvdp_copilot_grayscale_image_0014', 18: 'cvdp_copilot_image_stego_0004', 19: 'cvdp_copilot_kogge_stone_adder_0007', 20: 'cvdp_copilot_line_buffer_0003', 21: 'cvdp_copilot_manchester_enc_0005', 22: 'cvdp_copilot_modified_booth_mul_0002', 23: 'cvdp_copilot_modified_booth_mul_0005', 24: 'cvdp_copilot_montgomery_0001', 25: 'cvdp_copilot_montgomery_0002', 26: 'cvdp_copilot_morse_code_0014', 27: 'cvdp_copilot_mux_synch_0011', 28: 'cvdp_copilot_prim_max_0001', 29: 'cvdp_copilot_radix2_div_0001', 30: 'cvdp_copilot_rgb2ycbcr_0001', 31: 'cvdp_copilot_scrambler_0001', 32: 'cvdp_copilot_scrambler_0009', 33: 'cvdp_copilot_signal_correlator_0015', 34: 'cvdp_copilot_sobel_filter_0011', 35: 'cvdp_copilot_swizzler_0014'}

    with open(args.output, 'a') as fo, open(args.input, 'r') as fi:
        for line in fi:
            problem = json.loads(line)
            out = {"id": names[problem.get("problem_id") - 1], 'completion': problem.get("final_verilog_answer")}
            fo.write(json.dumps(out) + '\n')

    if args.input_cot:
        assert args.output_cot is not None
        with open(args.input_cot, 'r') as fi:
            for line in fi:
                problem = json.loads(line)
                name = names[problem.get("problem_id") - 1]
                cot = problem.get("generation")
                out_folder = os.path.join(args.output_cot, name)
                os.makedirs(out_folder, exist_ok=True)

                existing_files = os.listdir(out_folder)
                t_files = [f for f in existing_files if re.match(r't\d+\.v', f)]
                
                if t_files:
                    # 提取数字并找到最大值
                    numbers = [int(re.search(r't(\d+)\.v', f).group(1)) for f in t_files]
                    next_num = max(numbers) + 1
                else:
                    next_num = 1
                    
                # 生成新文件名
                new_filename = f't{next_num}.v'
                output_path = os.path.join(out_folder, new_filename)
                # print('=='*40)
                # print(args.input_cot)
                # print(new_filename)
                
                # 保存文件
                with open(output_path, 'w') as fo:
                    fo.write(cot)