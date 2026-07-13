import os
import re

replacements = {
    r'\bAppColors\.background\b': 'context.colorBackground',
    r'\bAppColors\.surface\b': 'context.colorSurface',
    r'\bAppColors\.surfaceVariant\b': 'context.colorSurfaceVariant',
    r'\bAppColors\.cardBackground\b': 'context.colorCardBackground',
    r'\bAppColors\.textPrimary\b': 'context.colorTextPrimary',
    r'\bAppColors\.textSecondary\b': 'context.colorTextSecondary',
    r'\bAppColors\.textTertiary\b': 'context.colorTextTertiary',
    r'\bAppColors\.divider\b': 'context.colorDivider',
    r'\bAppColors\.border\b': 'context.colorBorder',
}

def process_file(filepath):
    if 'app_colors.dart' in filepath or 'app_theme.dart' in filepath:
        return
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    for k, v in replacements.items():
        content = re.sub(k, v, content)
    
    # Very basic const removal for things that became dynamic
    content = re.sub(r'const\s+(Icon|Text|BoxDecoration|BorderSide|TextStyle|GoogleFonts)', r'\1', content)
    
    if original != content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Updated {filepath}")

for root, _, files in os.walk('lib/ui'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
