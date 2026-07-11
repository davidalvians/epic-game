import sys
import re

path = r'C:\Users\ASUS\project-epic-app\epic_app\lib\features\home\home_tab.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("return ':';", "return '${m.toString().padLeft(2, \"0\")}:${s.toString().padLeft(2, \"0\")}';")
text = text.replace("String title = 'Lanjutkan ';", "String title = 'Lanjutkan ${draft.kategori.capitalizeFirst}';")
text = re.sub(r"'Level.*?Sisa waktu.*?',", "'Level ${draft.level} • Sisa waktu: ${_formatSisa(draft.remainingSeconds)}',", text)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
