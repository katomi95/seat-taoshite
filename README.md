# シート倒してもいいですか？

**遊べるURL：https://katomi95.github.io/seat-taoshite/**

(以下、元の説明)


電車の座席を「倒す・起こす・回す」だけで戦う、3〜5分の3Dアクション（Godot 4.7 / GL Compatibility / Web対応）。

## 操作
- A / D：通路を歩く　W / S：上の席・下の席を選ぶ
- E（左クリック）：近くの席の背もたれを倒す／起こす
- R（右クリック）：席を180度回す（STAGE 2 から）

## 構成
OPENING → STAGE 1（挟む）→ STAGE 2（回転解禁）→ STAGE 3（自由戦闘）→ BOSS「絶対に席を動かさない男」→ ENDING

## 開発メモ
- モデル・効果音・BGM はすべてコードで生成（外部素材なし）
- 文字化け防止：文言を変えたら `py -3.10 tools/make_font.py`
- 検証：`godot --headless --path . --fixed-fps 60 -- --autoplay --fast=4 [--stage=N] --maxt=300`
- 撮影：`-- --autoplay --stage=N --shots=shots --at=1,2,3`（窓あり）
- Web書き出し：`godot --headless --path . --export-release Web docs/index.html`
