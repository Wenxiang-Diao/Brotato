import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


SOURCE = Path("vertical_slice/art/p4_phase3_preview/icon_preview_board_v1.png")
OUTPUT_DIR = Path("vertical_slice/art/p4_phase3_icons_preview")
OVERVIEW = OUTPUT_DIR / "icon_overview_v1.png"
MANIFEST = OUTPUT_DIR / "manifest.json"

ICONS = [
    ("01_shell_pistol", "01 弹壳手枪", "武器"),
    ("02_magnetic_coin", "02 磁暴硬币", "武器"),
    ("03_frost_crystal", "03 冻流水晶", "武器"),
    ("04_cracked_brick", "04 裂纹板砖", "武器"),
    ("05_mark", "05 标记", "基础状态"),
    ("06_shock", "06 感电", "基础状态"),
    ("07_freeze", "07 冻结", "基础状态"),
    ("08_burn", "08 灼烧", "基础状态"),
    ("09_lightning_chain", "09 雷链", "元素反应"),
    ("10_shatter", "10 破碎", "元素反应"),
    ("11_thermal_shock", "11 热冲击", "元素反应"),
    ("12_stellar_circuit", "12 星辉回路", "主动技能"),
    ("13_health", "13 生命", "通用 UI"),
    ("14_experience", "14 经验", "通用 UI"),
    ("15_reroll", "15 重抽", "通用 UI"),
    ("16_pause_settings", "16 暂停/设置", "通用 UI"),
    ("17_shifted_balance", "17 重心偏移", "负面状态"),
    ("18_hollow_defense", "18 防线空洞", "负面状态"),
    ("19_rushed_pulse", "19 急促脉冲", "负面状态"),
    ("20_stardust_leak", "20 星屑漏损", "负面状态"),
    ("21_freeze_dullness", "21 冻结迟钝", "负面状态"),
    ("22_rift_echo", "22 裂隙回声", "负面状态"),
]

CELL_SIZE = 256
ICON_PADDING = 18


def find_column_splits(alpha: Image.Image, row: int) -> list[int]:
    y_start = row * CELL_SIZE
    y_end = (row + 1) * CELL_SIZE
    splits = [0]

    for nominal in range(CELL_SIZE, alpha.width, CELL_SIZE):
        search_start = nominal - 64
        search_end = nominal + 64
        empty_columns = []
        for x in range(search_start, search_end + 1):
            visible = alpha.crop((x, y_start, x + 1, y_end)).getbbox()
            empty_columns.append(visible is None)

        runs = []
        run_start = None
        for offset, is_empty in enumerate(empty_columns):
            if is_empty and run_start is None:
                run_start = offset
            if not is_empty and run_start is not None:
                runs.append((run_start, offset - 1))
                run_start = None
        if run_start is not None:
            runs.append((run_start, len(empty_columns) - 1))

        if not runs:
            splits.append(nominal)
            continue

        best = max(
            runs,
            key=lambda run: (
                run[1] - run[0],
                -abs((search_start + (run[0] + run[1]) // 2) - nominal),
            ),
        )
        splits.append(search_start + (best[0] + best[1]) // 2)

    splits.append(alpha.width)
    return splits


def split_icons() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != (1536, 1024):
        raise ValueError(f"Unexpected source size: {source.size}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    source_alpha = source.getchannel("A")
    row_splits = {
        row: find_column_splits(source_alpha, row)
        for row in range(source.height // CELL_SIZE)
    }

    for index, (filename, _, _) in enumerate(ICONS):
        row = index // 6
        column = index % 6
        splits = row_splits[row]
        cell = source.crop(
            (
                splits[column],
                row * CELL_SIZE,
                splits[column + 1],
                (row + 1) * CELL_SIZE,
            )
        )

        alpha = cell.getchannel("A")
        bounds = alpha.getbbox()
        if bounds is None:
            raise ValueError(f"No visible pixels found for {filename}")

        icon = cell.crop(bounds)
        target_size = CELL_SIZE - ICON_PADDING * 2
        icon.thumbnail((target_size, target_size), Image.Resampling.LANCZOS)

        canvas = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
        x = (CELL_SIZE - icon.width) // 2
        y = (CELL_SIZE - icon.height) // 2
        canvas.alpha_composite(icon, (x, y))
        canvas.save(OUTPUT_DIR / f"{filename}.png", optimize=True)


def create_overview() -> None:
    width = 1440
    height = 1240
    board = Image.new("RGB", (width, height), (7, 12, 22))
    draw = ImageDraw.Draw(board)

    regular = r"C:\Windows\Fonts\msyh.ttc"
    bold = r"C:\Windows\Fonts\msyhbd.ttc"
    title_font = ImageFont.truetype(bold, 38)
    group_font = ImageFont.truetype(bold, 22)
    label_font = ImageFont.truetype(regular, 18)
    small_font = ImageFont.truetype(regular, 15)

    draw.text(
        (56, 36),
        "星链回响 · 独立图标总览 v1",
        font=title_font,
        fill=(244, 247, 252),
    )
    draw.text(
        (56, 88),
        "以下内容由 22 个独立 256×256 透明 PNG 重新拼装",
        font=small_font,
        fill=(151, 166, 190),
    )

    group_starts = {
        0: "武器与基础状态",
        6: "基础状态、反应与技能",
        12: "通用 UI 与负面状态",
        18: "负面状态",
    }
    card_width = 204
    card_height = 222
    start_x = 54
    start_y = 142
    gap_x = 24
    row_gap = 54

    for index, (filename, label, _) in enumerate(ICONS):
        row = index // 6
        column = index % 6
        x = start_x + column * (card_width + gap_x)
        y = start_y + row * (card_height + row_gap)

        if index in group_starts:
            draw.text(
                (x, y - 32),
                group_starts[index],
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

        icon = Image.open(OUTPUT_DIR / f"{filename}.png").convert("RGBA")
        icon.thumbnail((168, 168), Image.Resampling.LANCZOS)
        icon_x = x + (card_width - icon.width) // 2
        icon_y = y + 12 + (168 - icon.height) // 2
        board.paste(icon, (icon_x, icon_y), icon)

        bounds = draw.textbbox((0, 0), label, font=label_font)
        text_x = x + (card_width - (bounds[2] - bounds[0])) // 2
        draw.text(
            (text_x, y + 188),
            label,
            font=label_font,
            fill=(232, 238, 247),
        )

    board.save(OVERVIEW, optimize=True)


def create_manifest() -> None:
    entries = []
    for filename, label, category in ICONS:
        entries.append(
            {
                "id": filename,
                "label": label,
                "category": category,
                "file": f"{filename}.png",
                "size": [CELL_SIZE, CELL_SIZE],
                "status": "preview_pending_approval",
            }
        )
    MANIFEST.write_text(
        json.dumps(entries, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    split_icons()
    create_overview()
    create_manifest()
    print(f"Created {len(ICONS)} icons in {OUTPUT_DIR.resolve()}")
    print(OVERVIEW.resolve())


if __name__ == "__main__":
    main()
