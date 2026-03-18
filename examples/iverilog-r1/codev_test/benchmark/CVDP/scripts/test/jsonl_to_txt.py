import json
import os
from pathlib import Path

# 配置
prompts_files = [
    'data/prompts_nonagentic_code_comprehension.jsonl',
    'data/prompts_nonagentic_code_generation_no_commercial.jsonl'
]

raw_files = [
    'data/raw/cvdp_v1.0.2_nonagentic_code_comprehension.jsonl',
    'data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl'
]

output_dir = 'tmp/data'

# 创建输出目录
Path(output_dir).mkdir(parents=True, exist_ok=True)

# 加载所有raw文件的category映射
id_to_category = {}

for raw_file in raw_files:
    try:
        with open(raw_file, 'r', encoding='utf-8') as f:
            for line in f:
                if line.strip():
                    data = json.loads(line)
                    item_id = str(data.get('id', '')).strip()
                    if item_id:
                        # 获取categories[0]，如果不存在则使用"unknown"
                        categories = data.get('categories', [])
                        category = categories[0] if categories else "unknown"
                        id_to_category[item_id] = category
    except Exception as e:
        print(f"加载raw文件失败 {raw_file}: {e}")

# 处理所有prompts文件
for prompts_file in prompts_files:
    try:
        with open(prompts_file, 'r', encoding='utf-8') as f:
            for line in f:
                if line.strip():
                    data = json.loads(line)
                    item_id = str(data.get('id', '')).strip()
                    prompt = data.get('prompt', '')
                    
                    if item_id and prompt:
                        # 获取category，如果没有则用"unknown"
                        category = id_to_category.get(item_id, "unknown")
                        
                        # 创建文件名：id_category.txt
                        # 清理文件名，移除不安全字符
                        safe_id = ''.join(c for c in item_id if c.isalnum() or c in '._-')
                        safe_category = ''.join(c for c in category if c.isalnum() or c in '._-')
                        
                        if not safe_id:
                            safe_id = f"id_{hash(item_id) % 10000:04d}"
                        
                        filename = f"{safe_id}_{safe_category}.txt"
                        output_path = os.path.join(output_dir, filename)
                        
                        # 只将prompt写入文件
                        with open(output_path, 'w', encoding='utf-8') as out_f:
                            out_f.write(str(prompt))
                        
        print(f"处理完成: {prompts_file}")
    except Exception as e:
        print(f"处理文件失败 {prompts_file}: {e}")

print(f"所有文件处理完成！输出到: {output_dir}")