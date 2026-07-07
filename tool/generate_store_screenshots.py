"""Generate Google Play Store screenshot PNGs for あした持つもの.

The images are deterministic marketing screenshots based on the current app UI
and store listing plan. They are intentionally generated from code so copy,
colors, and layout can be reviewed and regenerated before release.
"""

from __future__ import annotations

from pathlib import Path
from textwrap import wrap

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "store" / "screenshots"
FONT_PATH = ROOT / "assets" / "fonts" / "NotoSansJP.ttf"

W, H = 1080, 1920
BG = "#F7F8F4"
INK = "#17201C"
MUTED = "#5C6B63"
PRIMARY = "#00796B"
PRIMARY_DARK = "#005B50"
PRIMARY_SOFT = "#DCEFE9"
YELLOW = "#F4C95D"
SURFACE = "#FFFFFF"
SURFACE_ALT = "#F1F5F2"
LINE = "#D7DFDA"
ERROR = "#B3261E"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_PATH), size=size)


F_TITLE = font(64)
F_SUB = font(34)
F_APPBAR = font(34)
F_H2 = font(34)
F_BODY = font(27)
F_SMALL = font(23)
F_TINY = font(19)


def text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], value: str, fill=INK, fnt=F_BODY):
    draw.text(xy, value, fill=fill, font=fnt)


def rounded(draw: ImageDraw.ImageDraw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def wrapped_text(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    value: str,
    max_chars: int,
    fill=INK,
    fnt=F_BODY,
    line_gap: int = 8,
):
    lines: list[str] = []
    for part in value.split("\n"):
        lines.extend(wrap(part, max_chars) or [""])
    for line in lines:
        text(draw, (x, y), line, fill=fill, fnt=fnt)
        y += fnt.size + line_gap
    return y


def base(title: str, subtitle: str) -> tuple[Image.Image, ImageDraw.ImageDraw, tuple[int, int, int, int]]:
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)

    rounded(draw, (0, 0, W, 290), 0, PRIMARY)
    text(draw, (80, 70), title, fill="#FFFFFF", fnt=F_TITLE)
    wrapped_text(draw, 82, 155, subtitle, 24, fill="#EAF7F2", fnt=F_SUB, line_gap=6)

    frame = (110, 300, 970, 1820)
    rounded(draw, frame, 64, "#10251F")
    screen = (138, 342, 942, 1782)
    rounded(draw, screen, 44, SURFACE)
    rounded(draw, (455, 318, 625, 335), 9, "#2C443B")
    return img, draw, screen


def appbar(draw: ImageDraw.ImageDraw, screen, title_value: str, right: str = ""):
    x1, y1, x2, _ = screen
    rounded(draw, (x1, y1, x2, y1 + 100), 42, PRIMARY)
    draw.rectangle((x1, y1 + 52, x2, y1 + 100), fill=PRIMARY)
    text(draw, (x1 + 34, y1 + 30), title_value, fill="#FFFFFF", fnt=F_APPBAR)
    if right:
        text(draw, (x2 - 155, y1 + 32), right, fill="#FFFFFF", fnt=F_BODY)


def chip(draw, x, y, label, active=False, w=None):
    w = w or 32 + len(label) * 25
    rounded(draw, (x, y, x + w, y + 54), 27, PRIMARY_SOFT if active else SURFACE_ALT, outline=LINE)
    text(draw, (x + 20, y + 13), label, fill=PRIMARY_DARK if active else MUTED, fnt=F_SMALL)
    return x + w + 12


def card(draw, x, y, w, h, title_value, meta="", accent=PRIMARY, items=None):
    rounded(draw, (x, y, x + w, y + h), 18, SURFACE, outline=LINE)
    rounded(draw, (x, y, x + 10, y + h), 8, accent)
    text(draw, (x + 30, y + 22), title_value, fill=INK, fnt=F_BODY)
    if meta:
        text(draw, (x + 30, y + 60), meta, fill=MUTED, fnt=F_SMALL)
    if items:
        yy = y + 96
        for item in items:
            draw.ellipse((x + 34, yy + 6, x + 54, yy + 26), outline=PRIMARY, width=3)
            text(draw, (x + 68, yy), item, fill=INK, fnt=F_SMALL)
            yy += 34


def home():
    img, draw, s = base("明日の忘れ物を減らす", "園・学校の連絡をTodoに変換")
    appbar(draw, s, "あした持つもの", "設定  人物")
    x1, y1, x2, _ = s
    y = y1 + 130
    rounded(draw, (x1 + 28, y, x2 - 28, y + 72), 20, SURFACE_ALT, outline=LINE)
    text(draw, (x1 + 58, y + 20), "検索…", fill=MUTED, fnt=F_BODY)
    y += 92
    nx = chip(draw, x1 + 28, y, "すべて", active=True, w=116)
    nx = chip(draw, nx, y, "長女", w=98)
    chip(draw, nx, y, "次男", w=98)
    y += 96
    text(draw, (x1 + 30, y), "今日やること", fill=PRIMARY_DARK, fnt=F_H2)
    y += 50
    card(draw, x1 + 28, y, 748, 170, "持ち物：水筒・体操着・帽子", "今日 / 長女 / 持ち物", items=["水筒", "体操着", "帽子"])
    y += 205
    text(draw, (x1 + 30, y), "明日の持ち物・提出", fill=PRIMARY_DARK, fnt=F_H2)
    y += 50
    card(draw, x1 + 28, y, 748, 128, "申込書を提出", "明日 / 次男 / 提出", accent=YELLOW, items=["申込書"])
    y += 166
    text(draw, (x1 + 30, y), "期限未設定・要確認", fill=PRIMARY_DARK, fnt=F_H2)
    y += 50
    card(draw, x1 + 28, y, 748, 128, "期限確認：集金袋 500円", "月末まで / 要確認", accent=ERROR, items=["集金袋"])
    fab(draw, x2 - 240, s[3] - 118, "＋ 追加")
    return img


def add_todo():
    img, draw, s = base("入力は撮るか貼るだけ", "OCRと貼り付けから候補を作成")
    appbar(draw, s, "追加")
    x1, y1, x2, _ = s
    y = y1 + 135
    text(draw, (x1 + 34, y), "画像・スクショから登録", fill=INK, fnt=F_H2)
    y += 60
    button(draw, x1 + 34, y, 350, "写真を撮る", outline=True)
    button(draw, x1 + 414, y, 350, "画像を選ぶ", outline=True)
    y += 125
    text(draw, (x1 + 34, y), "OCRテキストを貼り付けて抽出", fill=INK, fnt=F_H2)
    y += 62
    rounded(draw, (x1 + 34, y, x2 - 34, y + 300), 18, SURFACE, outline=LINE)
    wrapped_text(
        draw,
        x1 + 60,
        y + 28,
        "7月10日までに水着、帽子、タオルを持参してください。\n集金袋に500円を入れて提出してください。\n申込書は7月12日までに提出してください。",
        23,
        fill=MUTED,
        fnt=F_BODY,
    )
    y += 330
    button(draw, x1 + 34, y, 730, "貼り付け文からTodo候補を作る", outline=True)
    y += 135
    line(draw, x1 + 34, x2 - 34, y)
    y += 48
    button(draw, x1 + 34, y, 730, "手動で入力する", outline=True)
    return img


def review():
    img, draw, s = base("複数の用事も一度で整理", "持ち物・集金・提出を分けて確認")
    appbar(draw, s, "3件の候補を確認")
    x1, y1, x2, _ = s
    y = y1 + 132
    wrapped_text(draw, x1 + 34, y, "必要な候補だけ選んで登録。あとから詳細画面で修正できます。", 24, fill=MUTED, fnt=F_SMALL)
    y += 92
    rounded(draw, (x1 + 34, y, x2 - 34, y + 70), 18, SURFACE_ALT, outline=LINE)
    text(draw, (x1 + 58, y + 18), "対象：長女", fill=INK, fnt=F_BODY)
    y += 100
    candidate(draw, x1 + 34, y, "持ち物：水着・帽子・タオル", "持ち物 / 2026/7/10 / 水着・帽子・タオル", PRIMARY)
    y += 150
    candidate(draw, x1 + 34, y, "集金 500円", "集金 / 500円 / 集金袋", YELLOW)
    y += 150
    candidate(draw, x1 + 34, y, "申込書を提出", "提出 / 2026/7/12 / 申込書", PRIMARY_DARK)
    button(draw, x1 + 34, s[3] - 108, 730, "3件を登録", outline=False)
    return img


def detail():
    img, draw, s = base("登録後も見やすく確認", "チェック項目・期限・メモを一画面に")
    appbar(draw, s, "Todo詳細", "✎  🗑")
    x1, y1, x2, _ = s
    y = y1 + 135
    rounded(draw, (x1 + 34, y, x2 - 34, y + 260), 20, SURFACE, outline=LINE)
    text(draw, (x1 + 62, y + 28), "持ち物：水筒・体操着・帽子", fill=INK, fnt=F_H2)
    text(draw, (x1 + 62, y + 88), "種類：持ち物", fill=MUTED, fnt=F_BODY)
    text(draw, (x1 + 62, y + 128), "期限：今日", fill=MUTED, fnt=F_BODY)
    text(draw, (x1 + 62, y + 168), "対象：長女", fill=MUTED, fnt=F_BODY)
    button(draw, x1 + 62, y + 205, 270, "完了にする", outline=False)
    y += 295
    rounded(draw, (x1 + 34, y, x2 - 34, y + 235), 20, SURFACE, outline=LINE)
    text(draw, (x1 + 62, y + 26), "チェック項目", fill=INK, fnt=F_H2)
    checklist(draw, x1 + 68, y + 88, ["水筒", "体操着", "帽子"])
    y += 270
    rounded(draw, (x1 + 34, y, x2 - 34, y + 210), 20, SURFACE, outline=LINE)
    text(draw, (x1 + 62, y + 26), "メモ・OCR全文", fill=INK, fnt=F_H2)
    wrapped_text(draw, x1 + 62, y + 82, "明日の体育で使います。名前の確認もお願いします。", 23, fill=MUTED, fnt=F_BODY)
    return img


def settings():
    img, draw, s = base("気に入ったら買い切りで応援", "広告なしで朝の確認に集中")
    appbar(draw, s, "設定")
    x1, y1, x2, _ = s
    y = y1 + 130
    text(draw, (x1 + 34, y), "通知時刻", fill=PRIMARY_DARK, fnt=F_H2)
    y += 54
    tile(draw, x1 + 34, y, "前日（夜）", "前日の20:00に通知", "夜")
    y += 86
    tile(draw, x1 + 34, y, "当日（朝）", "当日の07:00に通知", "朝")
    y += 110
    text(draw, (x1 + 34, y), "サポーター", fill=PRIMARY_DARK, fnt=F_H2)
    y += 52
    rounded(draw, (x1 + 34, y, x2 - 34, y + 430), 24, SURFACE_ALT, outline=LINE)
    draw.ellipse((x1 + 66, y + 34, x1 + 126, y + 94), fill=PRIMARY_SOFT)
    text(draw, (x1 + 82, y + 46), "♡", fill=PRIMARY, fnt=F_BODY)
    text(draw, (x1 + 146, y + 34), "買い切りサポーター", fill=INK, fnt=F_H2)
    text(draw, (x1 + 146, y + 82), "広告を消して、朝の支度確認に集中できます。", fill=MUTED, fnt=F_SMALL)
    benefit(draw, x1 + 70, y + 146, "広告なしでホーム画面を広く使える")
    benefit(draw, x1 + 70, y + 196, "ログイン不要・端末内保存の方針はそのまま")
    benefit(draw, x1 + 70, y + 246, "今後の改善を買い切りで応援")
    button(draw, x1 + 70, y + 310, 660, "広告を消して応援する", outline=False)
    text(draw, (x1 + 70, y + 382), "買い切り ¥190", fill=MUTED, fnt=F_SMALL)
    text(draw, (x2 - 210, y + 382), "購入を復元", fill=PRIMARY, fnt=F_SMALL)
    return img


def button(draw, x, y, w, label, outline=False):
    fill = SURFACE if outline else PRIMARY
    fg = PRIMARY if outline else "#FFFFFF"
    rounded(draw, (x, y, x + w, y + 68), 34, fill, outline=PRIMARY, width=2)
    tw = draw.textlength(label, font=F_BODY)
    text(draw, (int(x + (w - tw) / 2), y + 16), label, fill=fg, fnt=F_BODY)


def fab(draw, x, y, label):
    rounded(draw, (x, y, x + 184, y + 70), 35, PRIMARY)
    text(draw, (x + 34, y + 18), label, fill="#FFFFFF", fnt=F_BODY)


def line(draw, x1, x2, y):
    draw.line((x1, y, x2, y), fill=LINE, width=2)


def candidate(draw, x, y, title_value, meta, accent):
    rounded(draw, (x, y, x + 730, y + 120), 20, SURFACE_ALT, outline=LINE)
    draw.ellipse((x + 28, y + 42, x + 58, y + 72), outline=PRIMARY, width=4)
    rounded(draw, (x + 80, y + 22, x + 90, y + 98), 5, accent)
    text(draw, (x + 110, y + 26), title_value, fill=INK, fnt=F_BODY)
    text(draw, (x + 110, y + 66), meta, fill=MUTED, fnt=F_SMALL)


def checklist(draw, x, y, items):
    for item in items:
        draw.ellipse((x, y + 6, x + 28, y + 34), outline=PRIMARY, width=4)
        text(draw, (x + 48, y), item, fill=INK, fnt=F_BODY)
        y += 52


def tile(draw, x, y, title_value, subtitle, icon):
    rounded(draw, (x, y, x + 730, y + 72), 16, SURFACE, outline=LINE)
    text(draw, (x + 26, y + 16), icon, fill=PRIMARY, fnt=F_BODY)
    text(draw, (x + 82, y + 10), title_value, fill=INK, fnt=F_SMALL)
    text(draw, (x + 82, y + 39), subtitle, fill=MUTED, fnt=F_TINY)


def benefit(draw, x, y, label):
    draw.ellipse((x, y + 8, x + 26, y + 34), fill=PRIMARY_SOFT, outline=PRIMARY)
    text(draw, (x + 42, y), label, fill=INK, fnt=F_SMALL)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    screenshots = [
        ("01-home.png", home()),
        ("02-add-todo.png", add_todo()),
        ("03-review-candidates.png", review()),
        ("04-todo-detail.png", detail()),
        ("05-settings-supporter.png", settings()),
    ]
    for filename, image in screenshots:
        image.save(OUT_DIR / filename, optimize=True)
        print(OUT_DIR / filename)


if __name__ == "__main__":
    main()
