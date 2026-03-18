import json
from collections import Counter
import matplotlib.pyplot as plt

def analyze_categories_distribution(file_path):
    # 用于存储所有category和长度分布
    all_categories = []
    length_distribution = Counter()
    
    with open(file_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            try:
                data = json.loads(line.strip())
                categories = data.get('categories', [])
                
                # 记录每个category
                all_categories.extend(categories)

                if categories[0] == 'cid016':
                    print('==' * 50)
                    print(data['input']['prompt'])
                    print()
                
            except json.JSONDecodeError:
                print(f"Warning: 第{line_num}行JSON解析失败")
    
    # 统计category频率
    category_counter = Counter(all_categories)
    
    # 打印结果
    print("Category分布:")
    for category, count in category_counter.most_common():
        print(f"{category}: {count}次")
    
    # 可选：绘制图表
    if category_counter:
        plt.figure(figsize=(10, 6))
        plt.bar(category_counter.keys(), category_counter.values())
        plt.title('Category分布')
        plt.xticks(rotation=45)
        plt.tight_layout()
        plt.show()

if __name__ == "__main__":
    # file_path = "data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl"
    file_path = "data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl"
    analyze_categories_distribution(file_path)