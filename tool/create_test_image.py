# tool/create_test_image.py
# OCR読み取りテスト用の学校プリント画像を生成する。
# 関連: lib/src/services/ocr_service.dart, lib/src/services/extraction_service.dart

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

FONT = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
OUT = Path(__file__).resolve().parent.parent / "assets" / "test_print.png"
W, H = 600, 800
BG = (255, 250, 240)
LINE = (50, 50, 50)
RED = (180, 40, 40)
BLUE = (30, 80, 160)


def make_image() -> Path:
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    f16 = ImageFont.truetype(FONT, 16)
    f20 = ImageFont.truetype(FONT, 20)
    f24 = ImageFont.truetype(FONT, 24)
    f30 = ImageFont.truetype(FONT, 30)

    HEADER = '\u5712\u3060\u3088\u308a'
    SUB = '\u4fdd\u8b77\u8005\u69d8'
    DATE = '2026\u5e747\u67083\u65e5\uff08\u91d1\uff09'
    MOTO = '\u25a0 \u660e\u65e5\u306e\u6301\u3061\u7269'
    TEISHUTSU = '\u25a0 \u63d0\u51fa\u7269'
    SHIRASE = '\u25a0 \u304a\u77e5\u3089\u305b'

    ITEMS = [
        '\u30fb\u4f53\u64cd\u7740\uff08\u8d64\u767d\u5e3d\u3082\u5fd8\u308c\u305a\u306b\uff09',
        '\u30fb\u6c34\u7b52\uff08\u4e2d\u8eab\u306f\u304a\u8336\u304b\u6c34\uff09',
        '\u30fb\u30bf\u30aa\u30eb\uff08\u6c57\u3075\u304d\u7528\uff09',
        '\u30fb\u7d75\u306e\u5177\u30bb\u30c3\u30c8',
        '\u30fb\u81ea\u7531\u5e33',
        '\u30fb\u6b6f\u78e8\u304d\u30bb\u30c3\u30c8',
    ]
    ITEMS2 = [
        '\u30fb\u5065\u5eb7\u30ab\u30fc\u30c9\uff08\u637a\u5370\u5fc5\u9808\uff09',
        '\u30fb\u8aad\u66f8\u611f\u60f3\u6587\uff08\u539f\u7a3f\u7528\u7d193\u679a\u4ee5\u4e0a\uff09',
        '\u30fbPTA\u5f79\u54e1\u30a2\u30f3\u30b1\u30fc\u30c8',
        '\u30fb\u96c6\u91d1\u888b\uff087,500\u5186\uff09',
    ]
    NOTICES = [
        '\u6765\u9031\u6708\u66dc\u65e5\uff087/7\uff09\u306f\u6821\u5916\u5b66\u7fd2\u306e\u305f\u3081\u3001\u304a\u5f01\u5f53\u304c\u5fc5\u8981\u3067\u3059\u3002',
        '\u767b\u6821\u6642\u9593\u306f\u3044\u3064\u3082\u901a\u308a8:00\u3067\u3059\u3002',
    ]

    y = 30
    d.text((W // 2, y), HEADER, fill=LINE, font=f30, anchor='mt')
    y += 50
    d.text((W // 2, y), SUB, fill=LINE, font=f20, anchor='mt')
    y += 10
    d.line((40, y, W - 40, y), fill=LINE, width=2)
    y += 20
    d.text((W - 50, y), DATE, fill=LINE, font=f16, anchor='rt')
    y += 40

    d.text((40, y), MOTO, fill=RED, font=f24)
    y += 40
    for item in ITEMS:
        d.text((60, y), item, fill=LINE, font=f20)
        y += 32

    y += 20
    d.text((40, y), TEISHUTSU, fill=BLUE, font=f24)
    y += 40
    for item in ITEMS2:
        d.text((60, y), item, fill=LINE, font=f20)
        y += 32

    y += 20
    d.text((40, y), SHIRASE, fill=RED, font=f24)
    y += 40
    for n in NOTICES:
        d.text((60, y), n, fill=LINE, font=f16)
        y += 28

    y = H - 60
    d.line((40, y, W - 40, y), fill=LINE, width=1)
    FOOTER = '\u2588\u2588\u5e02\u7acb\u2588\u2588\u5c0f\u5b66\u6821'
    d.text((W // 2, y + 15), FOOTER, fill=(150, 150, 150), font=f16, anchor='mt')
    APP = '\u3042\u3057\u305f\u3082\u3064\u3082\u306e'
    d.text((W // 2, y + 40), APP, fill=(150, 150, 150), font=f16, anchor='mt')

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, 'PNG')
    print('Created:', OUT, img.size)
    return OUT


if __name__ == '__main__':
    make_image()
