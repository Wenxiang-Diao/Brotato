from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


SOURCE = Path("vertical_slice/art/p4_phase3_preview/icon_preview_board_v1.png")
OUTPUT = SOURCE.with_name("icon_preview_review_v1.jpg")

LABELS = [
    "01 弹壳手枪",
    "02 磁暴硬币",
    "03 冻流水晶",
    "04 裂纹板砖",
    "05 标记",
    "06 感电",
    "07 冻结",
    "08 灼烧",
    "09 雷链",
    "10 破碎",
    "11 热冲击",
    "12 星辉回路",
    "13 生命",
    "14 经验",
    "15 重抽",
    "16 暂停/设置",
    "17 重心偏移",
    "18 防线空洞",
    "19 急促脉冲",
    "20 星屑漏损",
    "21 冻结迟钝",
    "22 裂隙回声",
]

GROUPS = {
    0: "武器与基础状态",
    6: "基础状态、反应与技能",
    12: "通用 UI 与负面状态",
    18: "负面状态",
}


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    board = Image.new("RGB", (1440, 1240), (7, 12, 22))
    draw = ImageDraw.Draw(board)

    regular = r"C:\Windows\Fonts\msyh.ttc"
    bold = r"C:\Windows\Fonts\msyhbd.ttc"
    title_font = ImageFont.truetype(bold, 38)
    group_font = ImageFont.truetype(bold, 22)
    label_font = ImageFont.truetype(regular, 18)
    small_font = ImageFont.truetype(regular, 15)

    draw.text(
        (56, 36),
        "星链回响 · P4 阶段 3 图标预览 v1",
        font=title_font,
        fill=(244, 247, 252),
    )
    draw.text(
        (56, 88),
        "统一深色粗轮廓 · 晶体切面 · 轻量能量色 · 透明背景源文件",
        font=small_font,
        fill=(151, 166, 190),
    )

    cell_size = 256
    card_width = 204
    card_height = 222
    start_x = 54
    start_y = 142
    gap_x = 24
    row_gap = 54

    for index, label in enumerate(LABELS):
        row = index // 6
        column = index % 6
        x = start_x + column * (card_width + gap_x)
        y = start_y + row * (card_height + row_gap)

        if index in GROUPS:
            draw.text(
                (x, y - 32),
                GROUPS[index],
                font=group_font,
                fill=(102, 227, 240),
            )

        draw.rounded_rectangle(
            (x, y, x + card_width, y + card_height),
            radius=12,
            fill=(16, 27, 45),
            outline=(47, 68, 96),
            width=2,
        )

        crop = source.crop(
            (
                column * cell_size,
                row * cell_size,
                (column + 1) * cell_size,
                (row + 1) * cell_size,
            )
        )
        crop.thumbnail((168, 168), Image.Resampling.LANCZOS)
        icon_x = x + (card_width - crop.width) // 2
        icon_y = y + 12 + (168 - crop.height) // 2
        board.paste(crop, (icon_x, icon_y), crop)

        bounds = draw.textbbox((0, 0), label, font=label_font)
        text_x = x + (card_width - (bounds[2] - bounds[0])) // 2
        draw.text(
            (text_x, y + 188),
            label,
            font=label_font,
            fill=(232, 238, 247),
        )

    board.save(OUTPUT, quality=92, subsampling=0, optimize=True)
    print(OUTPUT.resolve())


if __name__ == "__main__":
    main()
