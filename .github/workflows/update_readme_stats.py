#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
from datetime import datetime, timedelta


TARGET_FILES = {
    "DIRECT": "domain-set/direct-list.txt",
    "PROXY": "domain-set/proxy-list.txt",
    "REJECT": "domain-set/reject-list.txt",
    "APPLE_CN": "domain-set/apple-cn.txt",
    "GOOGLE_CN": "domain-set/google-cn.txt",
    "PCDN": "domain-set/pcdn-list.txt",
    "HTTPDNS": "domain-set/httpdns-list.txt"
}

README_FILE = "README.md"


def get_line_count(file_path):
    """统计文件行数"""
    if not os.path.exists(file_path):
        return 0

    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        return sum(1 for _ in f)


def read_old_stats(content):
    """读取 README 历史统计"""
    stats = {}

    for key in TARGET_FILES:
        match = re.search(
            rf"{key}\s*规则数：(\d+)",
            content
        )
        stats[key] = int(match.group(1)) if match else None

    return stats


def diff_text(current, old):
    """生成变化描述"""
    if old is None:
        return "new"

    diff = current - old

    if diff > 0:
        return f"update +{diff}"
    if diff < 0:
        return f"update {diff}"

    return "update +0"


def update_readme(stats_text):
    """替换 README 统计区域"""

    if os.path.exists(README_FILE):
        with open(README_FILE, "r", encoding="utf-8") as f:
            content = f.read()
    else:
        content = ""

    new_block = (
        "<!-- STATS_START -->\n\n"
        f"{stats_text.strip()}\n\n"
        "<!-- STATS_END -->"
    )

    pattern = (
        r"<!-- STATS_START -->.*?<!-- STATS_END -->"
    )

    if re.search(pattern, content, re.DOTALL):
        content = re.sub(
            pattern,
            new_block,
            content,
            flags=re.DOTALL
        )
    else:
        content += "\n\n" + new_block

    with open(README_FILE, "w", encoding="utf-8") as f:
        f.write(content)


def main():
    """主程序"""

    current_stats = {
        key: get_line_count(path)
        for key, path in TARGET_FILES.items()
    }

    bj_time = datetime.utcnow() + timedelta(hours=8)

    update_time = bj_time.strftime(
        "%Y-%m-%d %H:%M:%S"
    )

    if os.path.exists(README_FILE):
        with open(README_FILE, "r", encoding="utf-8") as f:
            readme_content = f.read()
    else:
        readme_content = ""

    old_stats = read_old_stats(readme_content)

    stats_text = f"""🔔 最后更新时间：{update_time}

| 规则类型 | 数量 | 变化 |
|:---|---:|---:|
| DIRECT | {current_stats['DIRECT']} | {diff_text(current_stats['DIRECT'], old_stats['DIRECT'])} |
| PROXY | {current_stats['PROXY']} | {diff_text(current_stats['PROXY'], old_stats['PROXY'])} |
| REJECT | {current_stats['REJECT']} | {diff_text(current_stats['REJECT'], old_stats['REJECT'])} |
| APPLE_CN_CN | {current_stats['APPLE_CN_CN']} | {diff_text(current_stats['APPLE_CN_CN'], old_stats['APPLE_CN_CN'])} |
| GOOGLE_CN_CN | {current_stats['GOOGLE_CN_CN']} | {diff_text(current_stats['GOOGLE_CN_CN'], old_stats['GOOGLE_CN_CN'])} |
| PCDN | {current_stats['PCDN']} | {diff_text(current_stats['PCDN'], old_stats['PCDN'])} |
| HTTPDNS | {current_stats['HTTPDNS']} | {diff_text(current_stats['HTTPDNS'], old_stats['HTTPDNS'])} |
"""

    update_readme(stats_text)

    print("✅ README 统计区域更新完成")


if __name__ == "__main__":
    main()
