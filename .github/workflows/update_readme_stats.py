#!/usr/bin/env python3
"""update_readme_stats.py - 统计各域名列表文件数量，更新 README.md 中的域名统计表格。

在仓库根目录执行。
"""

import os
import re
from datetime import datetime, timezone

DOMAIN_DIR = "domain-set"
README = "README.md"
MARKER_START = "<!-- DOMAIN-STATS-START -->"
MARKER_END = "<!-- DOMAIN-STATS-END -->"

FILES = [
    "direct-list.txt",
    "proxy-list.txt",
    "reject-list.txt",
    "apple-cn.txt",
    "google-cn.txt",
    "pcdn-list.txt",
    "httpdns-list.txt",
]


def count_domains() -> dict[str, int]:
    """统计各文件的域名数量."""
    counts = {}
    for fname in FILES:
        path = os.path.join(DOMAIN_DIR, fname)
        try:
            with open(path, encoding="utf-8") as f:
                # wc -l 等价：统计行数
                counts[fname] = sum(1 for _ in f)
        except FileNotFoundError:
            counts[fname] = 0
    return counts


def extract_old_counts(readme_path: str) -> dict[str, int]:
    """从 README 现有标记区内提取昨日的域名数量."""
    old = {}
    try:
        with open(readme_path, encoding="utf-8") as f:
            content = f.read()
    except FileNotFoundError:
        return old

    # 取标记区之间的内容
    m = re.search(
        re.escape(MARKER_START) + r"\n(.*?)\n" + re.escape(MARKER_END),
        content,
        re.DOTALL,
    )
    if not m:
        return old

    block = m.group(1)
    # 匹配表格行: | filename | 12345 | ... |
    pattern = re.compile(r"\|\s*(\S+\.txt)\s*\|\s*([\d,]+)\s*\|")
    for match in pattern.finditer(block):
        fname = match.group(1)
        count_str = match.group(2).replace(",", "")
        try:
            old[fname] = int(count_str)
        except ValueError:
            pass
    return old


def fmt_delta(delta: int) -> str:
    """格式化变化量，带符号."""
    if delta > 0:
        return f"+{delta}"
    elif delta < 0:
        return str(delta)
    else:
        return "0"


def generate_stats_md(counts: dict[str, int], old_counts: dict[str, int]) -> str:
    """生成统计块内容."""
    now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    lines = [
        f"> 每日自动更新，更新时间：{now_utc}",
        "",
        "| 文件 | 域名数量 | 变化 |",
        "|------|---------|------|",
    ]

    for fname in FILES:
        count = counts.get(fname, 0)
        old = old_counts.get(fname, 0)
        delta = count - old
        lines.append(f"| {fname} | {count:,} | {fmt_delta(delta)} |")

    return "\n".join(lines)


def update_readme(readme_path: str, stats_md: str) -> None:
    """将统计块注入 README 标记之间."""
    with open(readme_path, encoding="utf-8") as f:
        content = f.read()

    replacement = f"{MARKER_START}\n{stats_md}\n{MARKER_END}"
    pattern = re.escape(MARKER_START) + r".*?" + re.escape(MARKER_END)
    new_content = re.sub(pattern, replacement, content, count=1, flags=re.DOTALL)

    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(new_content)


def main() -> None:
    counts = count_domains()
    old_counts = extract_old_counts(README)

    # 打印统计日志
    print("=== 各文件域名数量统计 ===")
    total = 0
    for fname in FILES:
        c = counts.get(fname, 0)
        print(f"{fname:25s} {c:>8,} 条")
        if fname not in ("pcdn-list.txt", "httpdns-list.txt"):
            total += c
    print(f"\n前5个文件总域名数: {total:,} (不含 pcdn 和 httpdns)")

    print("\n=== 相对昨日变化 ===")
    for fname in FILES:
        c = counts.get(fname, 0)
        old = old_counts.get(fname, 0)
        print(f"{fname:25s} {fmt_delta(c - old):>6}")

    # 生成统计块并写入 README
    stats_md = generate_stats_md(counts, old_counts)
    update_readme(README, stats_md)

    print(f"\nREADME.md 已更新域名统计数据")
    print("=" * 50)


if __name__ == "__main__":
    main()
