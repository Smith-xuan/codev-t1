import json,re
from pathlib import Path
jsonl=Path('/nfs_global/projects/cvdp_benchmark/results/test/test.jsonl')
base=Path('/nfs_global/projects/cvdp_benchmark/results/test/cot')
ids=[]
for line in jsonl.read_text().splitlines():
    if not line.strip():
        continue
    obj=json.loads(line)
    if obj.get('completion','')=='':
        ids.append(obj['id'])
cat1=[];cat2=[];cat3=[];missing=[]
think_re=re.compile(r'<think>[\s\S]*?</think>',re.M)
ans_re=re.compile(r'<answer>[\s\S]*?</answer>',re.M)
allowed_pattern=re.compile(r'^(?:\s*(?:<think>[\s\S]*?</think>|<answer>[\s\S]*?</answer>|<tool_call>\s*</tool_call>))*\s*$',re.M)
for _id in ids:
    p=base/_id/'t1.v'
    if not p.exists():
        missing.append(_id);continue
    text=p.read_text()
    if any(tag in text for tag in ('<file>','<content>','<name>')):
        cat2.append(_id)
    elif allowed_pattern.fullmatch(text) and think_re.search(text) and ans_re.search(text):
        cat1.append(_id)
    else:
        cat3.append(_id)
with open('/nfs_global/projects/cvdp_benchmark/scripts/classify.txt','w') as f:
    f.write('total %d cat1 %d cat2 %d cat3 %d missing %d\n' % (len(ids),len(cat1),len(cat2),len(cat3),len(missing)))
    f.write('\nCAT1:\n'+'\n'.join(cat1)+'\n')
    f.write('\nCAT2:\n'+'\n'.join(cat2)+'\n')
    f.write('\nCAT3:\n'+'\n'.join(cat3)+'\n')
    f.write('\nMISSING:\n'+'\n'.join(missing)+'\n')