#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
from datetime import datetime, timezone, timedelta

# 配置部分
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
        # 匹配标签内已存在的数字
        match = re.search(rf"\|\s*{key}\s*\|\s*(\d+)", content)
        stats[key] = int(match.group(1)) if match else None
    return stats

def diff_text_elegant(current, old):
    """生成优雅的 Markdown 徽章格式"""
    if old is None:
        return "![new](https://img.shields.io/badge/status-new-blue?style=flat-square)"
    
    diff = current - old
    
    if diff > 0:
        color, val = "brightgreen", f"+{diff}"
    elif diff < 0:
        color, val = "red", str(diff)
    else:
        color, val = "gray", "0"
        
    return f"![diff](https://img.shields.io/badge/change-{val}-{color}?style=flat-square)"

def update_readme(stats_text):
    """仅在 和 之间更新数据"""
    if not os.path.exists(README_FILE):
        return

    with open(README_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    # 构建带标签的新数据块
    new_block = f"\n\n{stats_text.strip()}\n\n"

    # 正则：匹配标签及其内部的所有内容 (flags=re.DOTALL 确保 . 能匹配换行符)
    pattern = r".*?"

    if re.search(pattern, content, flags=re.DOTALL):
        # 替换标签之间的内容
        content = re.sub(pattern, new_block, content, flags=re.DOTALL)
    else:
        # 如果未找到标签，追加到文件末尾 (建议手动添加标签)
        content += "\n\n" + new_block

    with open(README_FILE, "w", encoding="utf-8") as f:
        f.write(content)

def main():
    """主程序"""
    current_stats = {key: get_line_count(path) for key, path in TARGET_FILES.items()}

    # UTC 转北京时间
    update_time = (datetime.now(timezone.utc) + timedelta(hours=8)).strftime("%Y-%m-%d %H:%M:%S")

    if os.path.exists(README_FILE):
        with open(README_FILE, "r", encoding="utf-8") as f:
            readme_content = f.read()
    else:
        readme_content = ""

    old_stats = read_old_stats(readme_content)

    # 循环生成表格行
    table_rows = []
    for key in TARGET_FILES:
        current = current_stats[key]
        old = old_stats.get(key)
        badge = diff_text_elegant(current, old)
        table_rows.append(f"| {key} | {current} | {badge} |")
    
    stats_rows_str = "\n".join(table_rows)

    # 组装符合你要求的格式
    stats_text = f"""🔔 最后更新时间：{update_time}

| 规则类型 | 数量 | 较上次更新 |
|:---|---:|---:|
{stats_rows_str}"""

    update_readme(stats_text)
    print("✅ README 统计区域更新完成")

if __name__ == "__main__":
    main()
