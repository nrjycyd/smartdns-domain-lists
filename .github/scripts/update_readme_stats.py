#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
from datetime import datetime, timezone, timedelta
from urllib.parse import quote

# ===============================
# 配置
# ===============================

TARGET_FILES = {
    "DIRECT": "domain-set/direct-list.txt",
    "PROXY": "domain-set/proxy-list.txt",
    "REJECT": "domain-set/reject-list.txt",
    "APPLE_CN": "domain-set/apple-cn.txt",
    "GOOGLE_CN": "domain-set/google-cn.txt",
    "PCDN": "domain-set/pcdn-list.txt",
    "HTTPDNS": "domain-set/httpdns-list.txt",
}

README_FILE = "README.md"

STATS_START = "<!-- STATS_START -->"
STATS_END = "<!-- STATS_END -->"


# ===============================
# 工具函数
# ===============================

def get_line_count(file_path: str) -> int:
    """统计文件行数"""

    if not os.path.isfile(file_path):
        return 0

    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        return sum(1 for _ in f)


def read_old_stats(content: str) -> dict:
    """读取 README 中的历史统计"""

    stats = {}

    for key in TARGET_FILES:
        match = re.search(
            rf"\|\s*{re.escape(key)}\s*\|\s*(?:\*\*)?(\d+)",
            content,
        )

        stats[key] = int(match.group(1)) if match else None

    return stats


def diff_badge(current: int, old: int | None) -> str:
    """生成 Shields.io 徽章"""

    if old is None:
        return (
            "![new]"
            "(https://img.shields.io/static/v1"
            "?label="
            "&message=NEW"
            "&color=blue"
            "&style=flat-square)"
        )

    diff = current - old

    if diff > 0:
        color = "brightgreen"
        value = f"+{diff}"
    elif diff < 0:
        color = "red"
        value = str(diff)
    else:
        color = "lightgrey"
        value = "0"

    value = quote(value)

    return (
        "![diff]"
        "(https://img.shields.io/static/v1"
        "?label="
        f"&message={value}"
        f"&color={color}"
        "&style=flat-square)"
    )


def update_readme(stats_text: str) -> None:
    """更新 README 指定统计区域"""

    if os.path.exists(README_FILE):
        with open(README_FILE, "r", encoding="utf-8") as f:
            content = f.read()
    else:
        content = ""

    new_block = (
        f"{STATS_START}\n\n"
        f"{stats_text.strip()}\n\n"
        f"{STATS_END}"
    )

    pattern = rf"{re.escape(STATS_START)}.*?{re.escape(STATS_END)}"

    if re.search(pattern, content, flags=re.DOTALL):
        content = re.sub(
            pattern,
            new_block,
            content,
            flags=re.DOTALL,
        )
    else:
        if content and not content.endswith("\n"):
            content += "\n"

        content += "\n" + new_block + "\n"

    with open(README_FILE, "w", encoding="utf-8") as f:
        f.write(content)


# ===============================
# 主程序
# ===============================

def main():

    current_stats = {
        key: get_line_count(path)
        for key, path in TARGET_FILES.items()
    }

    beijing = timezone(timedelta(hours=8))

    update_time = datetime.now(beijing).strftime(
        "%Y-%m-%d %H:%M:%S"
    )

    if os.path.exists(README_FILE):
        with open(README_FILE, "r", encoding="utf-8") as f:
            readme_content = f.read()
    else:
        readme_content = ""

    old_stats = read_old_stats(readme_content)

    print("旧统计：")
    print(old_stats)

    print("当前统计：")
    print(current_stats)

    rows = []

    for key in TARGET_FILES:
        rows.append(
            "| {} | {} | {} |".format(
                key,
                current_stats[key],
                diff_badge(
                    current_stats[key],
                    old_stats.get(key),
                ),
            )
        )

    stats_text = f"""🔔 最后更新时间：{update_time}

| 规则类型 | 数量 | 较上次更新 |
|:---------|------:|:----------|
{"\n".join(rows)}
"""

    update_readme(stats_text)

    print("✅ README 统计区域更新完成")


if __name__ == "__main__":
    main()
