import os
import re

def process_file(filepath):
    if 'app_colors.dart' in filepath or 'app_theme.dart' in filepath:
        return
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    # Remove const from InputDecoration, BoxDecoration, Padding, EdgeInsets if they contain context.color
    # A simpler way is to just blindly remove const if the line contains context.color
    
    lines = content.split('\n')
    for i in range(len(lines)):
        if 'context.color' in lines[i] and 'const ' in lines[i]:
            lines[i] = re.sub(r'const\s+', '', lines[i])
    
    content = '\n'.join(lines)
    
    # Check if there are multi-line issues where const is on a previous line
    # For example:
    # const InputDecoration(
    #   fillColor: context.colorSurface
    # )
    # This requires a regex.
    content = re.sub(r'const\s+(InputDecoration|BoxDecoration|Padding|EdgeInsets|BorderRadius|AlertDialog|SizedBox)\b', r'\1', content)
    
    if original != content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed {filepath}")

for root, _, files in os.walk('lib/ui'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
