
import pandas as pd
import json

try:
    # Check train.parquet structure
    print("--- TRAIN DATA ---")
    df = pd.read_parquet("/nfs_global/S/shiwenxuan/verl/data/codev/v1/3.1k_r1_tool_with_tools/train.parquet")
    print("Columns:", df.columns.tolist())
    if 'tools' in df.columns:
        print("Tools column sample (first row):")
        print(df.iloc[0]['tools'])
    if 'prompt' in df.columns:
        print("Prompt column sample (first row):")
        print(df.iloc[0]['prompt'])
        
except Exception as e:
    print(f"Error reading train parquet: {e}")
