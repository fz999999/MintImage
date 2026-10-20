#!/usr/bin/env python3
"""把 gen_ui_appendix.py 的输出拼进 docs/UI-SPEC-APPENDIX.md 的标记区。

用法：
    python scripts/gen_ui_appendix.py > docs/_appendix_generated.md
    python scripts/splice_appendix.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "docs" / "UI-SPEC-APPENDIX.md"
FRAGMENT = ROOT / "docs" / "_appendix_generated.md"

START = "<!-- GENERATED:START -->"
END = "<!-- GENERATED:END -->"


def main() -> None:
    doc = TARGET.read_text(encoding="utf-8")
    frag_lines = FRAGMENT.read_text(encoding="utf-8").splitlines()
    # 片段自带的标题与前两行说明丢弃，避免和主文档标题重复
    while frag_lines and (frag_lines[0].startswith("# ") or not frag_lines[0].strip()):
        frag_lines.pop(0)
    while frag_lines and frag_lines[0].startswith(">"):
        frag_lines.pop(0)

    if START not in doc or END not in doc:
        raise SystemExit("标记缺失，请先确认 UI-SPEC-APPENDIX.md 里有 GENERATED:START / END")

    head, rest = doc.split(START, 1)
    _, tail = rest.split(END, 1)
    merged = f"{head}{START}\n\n" + "\n".join(frag_lines).strip() + f"\n\n{END}{tail}"
    TARGET.write_text(merged, encoding="utf-8")
    print(f"spliced: {TARGET.name}, fragment lines: {len(frag_lines)}")


if __name__ == "__main__":
    main()
