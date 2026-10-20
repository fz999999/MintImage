"""检查最新几张生成图是不是真的透明背景。"""

import os
import sqlite3
import struct
import zlib

DATA = r"E:\code\10.20MintImage-main\MintImage-main\build\windows\x64\runner\Release\data"


def png_info(path: str) -> str:
    with open(path, "rb") as handle:
        head = handle.read(33)
    width, height = struct.unpack(">II", head[16:24])
    bit_depth = head[24]
    color_type = head[25]
    names = {0: "灰度", 2: "RGB（无 alpha）", 3: "调色板", 4: "灰度+alpha", 6: "RGBA（有 alpha）"}
    return f"{width}x{height} bit={bit_depth} colorType={color_type} {names.get(color_type, color_type)}"


def alpha_stats(path: str) -> str:
    """只解 IDAT，判断 alpha 通道是否真的有透明像素（抽样前 200 行）。"""
    with open(path, "rb") as handle:
        data = handle.read()
    if data[25] != 6:
        return "无 alpha 通道"

    offset = 8
    idat = b""
    width = height = 0
    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        kind = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : offset + 8 + length]
        if kind == b"IHDR":
            width, height = struct.unpack(">II", payload[:8])
        elif kind == b"IDAT":
            idat += payload
        elif kind == b"IEND":
            break
        offset += 12 + length

    try:
        raw = zlib.decompress(idat)
    except Exception as error:  # noqa: BLE001
        return f"解压失败: {error}"

    stride = width * 4 + 1
    rows = min(height, 200)
    transparent = 0
    total = 0
    for y in range(rows):
        row = raw[y * stride + 1 : (y + 1) * stride]
        for x in range(0, len(row), 4):
            total += 1
            if row[x + 3] < 250:
                transparent += 1
    return f"抽样 {rows} 行，透明像素 {transparent}/{total}"


def main() -> None:
    connection = sqlite3.connect(os.path.join(DATA, "mint_image.sqlite"))
    query = (
        "select status, duration_ms, created_at, result_image_path "
        "from image_records_table order by created_at desc limit 3"
    )
    for status, duration, created, path in connection.execute(query):
        if not path or not os.path.exists(path):
            print(f"{status} {duration}ms -> 文件缺失")
            continue
        print(f"{status} {duration}ms")
        print(f"  {os.path.basename(path)}")
        print(f"  {png_info(path)}")
        print(f"  {alpha_stats(path)}")


if __name__ == "__main__":
    main()
