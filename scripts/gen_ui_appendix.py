#!/usr/bin/env python3
"""从 lib/ 源码抽取视觉与文案参数，生成设计交接附录（机器生成部分）。

用法：python scripts/gen_ui_appendix.py > docs/_appendix_generated.md
"""
from __future__ import annotations

import os
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
SDK_ICONS = Path("C:/src/flutter/packages/flutter/lib/src/material/icons.dart")

COLOR_RE = re.compile(r"Color\(0x([0-9A-Fa-f]{8})\)")
ALPHA_RE = re.compile(r"([A-Za-z_][\w.]*)\.withValues\(alpha: ([0-9.]+)\)")
ICON_RE = re.compile(r"Icons\.([A-Za-z0-9_]+)")
STR_RE = re.compile(r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\"")
CJK_RE = re.compile(r"[\u4e00-\u9fff]")
MS_RE = re.compile(r"Duration\(milliseconds: (\d+)\)")
CURVE_RE = re.compile(r"Curves\.([A-Za-z0-9_.]+)")
FONT_RE = re.compile(r"fontSize: ([0-9.]+)")
EDGE_RE = re.compile(r"EdgeInsets\.(all|symmetric|only|fromLTRB)\(([^)]*)\)")
RADIUS_RE = re.compile(r"BorderRadius\.circular\(([0-9.]+)\)")


def dart_files() -> list[Path]:
    out = []
    for p in LIB.rglob("*.dart"):
        if p.name.endswith(".g.dart"):
            continue
        out.append(p)
    return sorted(out)


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def cell(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ").strip()


def load_icon_codepoints() -> dict[str, str]:
    if not SDK_ICONS.exists():
        return {}
    mapping: dict[str, str] = {}
    pat = re.compile(r"static const IconData (\w+) = IconData\(0x([0-9a-fA-F]+)")
    for line in SDK_ICONS.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = pat.search(line)
        if m:
            mapping[m.group(1)] = "0x" + m.group(2).lower()
    return mapping


def main() -> None:
    colors: dict[str, list[str]] = defaultdict(list)   # hex -> positions
    alphas: dict[tuple[str, str], list[str]] = defaultdict(list)
    icons: dict[str, list[str]] = defaultdict(list)
    texts: dict[str, list[tuple[int, str]]] = defaultdict(list)
    durations: Counter = Counter()
    curves: Counter = Counter()
    fonts: dict[str, list[str]] = defaultdict(list)
    edges: Counter = Counter()
    radii: Counter = Counter()

    for p in dart_files():
        r = rel(p)
        lines = p.read_text(encoding="utf-8", errors="ignore").splitlines()
        for i, line in enumerate(lines, 1):
            loc = f"{r}:{i}"
            for m in COLOR_RE.finditer(line):
                colors["#" + m.group(1).upper()].append(loc)
            for m in ALPHA_RE.finditer(line):
                alphas[(m.group(1), m.group(2))].append(loc)
            for m in ICON_RE.finditer(line):
                icons[m.group(1)].append(loc)
            for m in STR_RE.finditer(line):
                s = m.group(1) if m.group(1) is not None else m.group(2)
                if s and CJK_RE.search(s):
                    texts[r].append((i, s))
            for m in MS_RE.finditer(line):
                durations[m.group(1)] += 1
            for m in CURVE_RE.finditer(line):
                curves[m.group(1)] += 1
            for m in FONT_RE.finditer(line):
                fonts[m.group(1)].append(loc)
            for m in EDGE_RE.finditer(line):
                edges[f"{m.group(1)}({m.group(2)})"] += 1
            for m in RADIUS_RE.finditer(line):
                radii[m.group(1)] += 1

    codepoints = load_icon_codepoints()

    print("# 附录 A：机器抽取的视觉 / 文案 / 动效参数\n")
    print("> 本附录由 `scripts/gen_ui_appendix.py` 扫描 `lib/**/*.dart` 自动生成，"
          "行号可直接定位；重建命令：`python scripts/gen_ui_appendix.py > docs/_appendix_generated.md`。\n")

    # A1 颜色
    print("## A1 颜色\n")
    print("### A1.1 全库硬编码色值（不含主题 token）\n")
    print("| 色值 | 出现次数 | 位置（前 6 处） |")
    print("|---|---|---|")
    for hexv, locs in sorted(colors.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        print(f"| `{hexv}` | {len(locs)} | {cell('、'.join(locs[:6]))} |")

    print("\n### A1.2 透明度使用矩阵（`withValues(alpha:)`）\n")
    print("| 基色表达式 | alpha | 次数 | 位置（前 5 处） |")
    print("|---|---|---|---|")
    for (base, a), locs in sorted(alphas.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        print(f"| `{cell(base)}` | {a} | {len(locs)} | {cell('、'.join(locs[:5]))} |")

    # A4 图标
    print("\n## A4 图标清单\n")
    print(f"共 **{len(icons)}** 个不同图标（Material Rounded 家族为主），codepoint 取自 Flutter SDK 的 `icons.dart`。\n")
    print("| # | 图标名 | codepoint | 次数 | 位置（前 4 处） |")
    print("|---|---|---|---|---|")
    for idx, (name, locs) in enumerate(sorted(icons.items(), key=lambda kv: (-len(kv[1]), kv[0])), 1):
        cp = codepoints.get(name, "—")
        print(f"| {idx} | `Icons.{name}` | `{cp}` | {len(locs)} | {cell('、'.join(locs[:4]))} |")

    # A5 文案
    total = sum(len(v) for v in texts.values())
    uniq = len({s for v in texts.values() for _, s in v})
    print("\n## A5 文案清单（含中文的字符串字面量）\n")
    print(f"共 **{total}** 处中文文案，去重后 **{uniq}** 条。按文件分组，行号可定位。\n")
    for r in sorted(texts):
        seen = set()
        rows = []
        for line, s in texts[r]:
            if s in seen:
                continue
            seen.add(s)
            rows.append((line, s))
        print(f"### {r}（{len(rows)} 条）\n")
        print("| 行 | 文案 |")
        print("|---|---|")
        for line, s in rows:
            print(f"| {line} | {cell(s)} |")
        print()

    # A6 动效
    print("## A6 动画时长与曲线\n")
    print("| 时长（ms） | 次数 |")
    print("|---|---|")
    for ms, n in sorted(durations.items(), key=lambda kv: -kv[1]):
        print(f"| {ms} | {n} |")
    if curves:
        print("\n| 曲线 | 次数 |")
        print("|---|---|")
        for c, n in sorted(curves.items(), key=lambda kv: -kv[1]):
            print(f"| `Curves.{c}` | {n} |")

    # A7 字号
    print("\n## A7 就地字号覆盖（`fontSize:`）\n")
    print("| 字号 | 次数 | 位置（前 6 处） |")
    print("|---|---|---|")
    for size, locs in sorted(fonts.items(), key=lambda kv: -len(kv[1])):
        print(f"| {size} | {len(locs)} | {cell('、'.join(locs[:6]))} |")

    # A8 圆角与内边距
    print("\n## A8 圆角与内边距取值分布\n")
    print("### 圆角\n")
    print("| 半径 | 次数 |")
    print("|---|---|")
    for radius, n in sorted(radii.items(), key=lambda kv: -kv[1]):
        print(f"| {radius} | {n} |")
    print("\n### EdgeInsets（前 30 种）\n")
    print("| 写法 | 次数 |")
    print("|---|---|")
    for edge, n in edges.most_common(30):
        print(f"| `{cell(edge)}` | {n} |")


if __name__ == "__main__":
    main()
