import re

svg_path = "/Users/yager/Downloads/miloom.console.svg"
out_path = "Zifr/Assets.xcassets/miloom.console.symbolset/miloom.console.svg"

with open(svg_path, 'r', encoding='utf-8') as f:
    content = f.read()

def duplicate_id(content, old_id, new_id):
    pattern = rf'(<[^>]*\bid="{re.escape(old_id)}"[^/]*/?>)'
    match = re.search(pattern, content)
    if match:
        original = match.group(0)
        duplicate = original.replace(f'id="{old_id}"', f'id="{new_id}"')
        content = content.replace(original, original + '\n  ' + duplicate, 1)
    return content

content = duplicate_id(content, 'right-margin-Regular-S', 'right-margin-Regular-M')
content = duplicate_id(content, 'left-margin-Regular-S', 'left-margin-Regular-M')
content = duplicate_id(content, 'right-margin-Regular-S', 'right-margin-Regular-L')
content = duplicate_id(content, 'left-margin-Regular-S', 'left-margin-Regular-L')

start_tag = '<g id="Regular-S"'
start_idx = content.find(start_tag)
    
if start_idx != -1:
    depth = 0
    i = start_idx
    end_idx = -1
    while i < len(content):
        if content[i:i+2] == '<g':
            depth += 1
            i += 2
        elif content[i:i+4] == '</g>':
            depth -= 1
            if depth == 0:
                end_idx = i + 4
                break
            i += 4
        elif content[i] == '<' and content[i:i+3] != '</g' and content[i:i+2] != '<g':
            i += 1
        else:
            i += 1
    
    if end_idx != -1:
        regular_s_block = content[start_idx:end_idx]
        
        regular_m = regular_s_block.replace('id="Regular-S"', 'id="Regular-M"', 1)
        regular_l = regular_s_block.replace('id="Regular-S"', 'id="Regular-L"', 1)
        
        replacement = regular_s_block + '\n  ' + regular_m + '\n  ' + regular_l
        content = content.replace(regular_s_block, replacement, 1)
        
        with open(out_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("SUCCESS: Regular-M and Regular-L added.")
    else:
        print("ERROR: Could not find end of Regular-S group.")
else:
    print("ERROR: Could not find Regular-S group.")
