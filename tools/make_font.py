"""使用文字だけに絞ったフォントを作る（Web 書き出しを軽くするため）。
    py -3.10 tools/make_font.py
scripts/*.gd を走査するので、文言を変えたら必ず再実行すること。
"""
import glob
import os
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

ROOT = os.path.join(os.path.dirname(__file__), "..")
chars = set(chr(c) for c in range(0x20, 0x7F))
chars |= set("　、。「」『』（）［］？！：…ー―～・●○★×▼♥")
chars |= set(chr(c) for c in range(0x3041, 0x30FF))
chars |= set(chr(c) for c in range(0xFF01, 0xFF5F))
for p in glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True):
    with open(p, encoding="utf-8") as f:
        for ch in f.read():
            if ord(ch) > 0x7F:
                chars.add(ch)

font = TTFont(r"C:\Windows\Fonts\NotoSansJP-VF.ttf")
font = instancer.instantiateVariableFont(font, {"wght": 700})
opts = subset.Options()
opts.layout_features = ["*"]
sub = subset.Subsetter(opts)
sub.populate(text="".join(sorted(chars)))
sub.subset(font)
path = os.path.join(ROOT, "fonts", "NotoSansJP-Bold-subset.ttf")
font.save(path)
print(len(chars), "chars ->", os.path.getsize(path), "bytes")
