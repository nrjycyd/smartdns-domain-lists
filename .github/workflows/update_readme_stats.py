#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
from datetime import datetime, timedelta


# ===============================
# 需要统计的规则文件
# ===============================

TARGET_FILES = {
    'DIRECT': 'domain-set/direct-list.txt',
    'PROXY': 'domain-set/proxy-list.txt',
    'REJECT': 'domain-set/reject-list.txt',
    'APPLE': 'domain-set/apple-cn.txt',
    'GOOGLE': 'domain-set/google-cn.txt',
    'PCDN': 'domain-set/pcdn-list.txt',
    'HTTPDNS': 'domain-set/httpdns-list.txt'
}


README_FILE = "README.md"


# ===============================
# 获取文件行数
# ===============================

def get_line_count(file_path):

    if not os.path.exists(file_path):
        return 0

    with open(
        file_path,
        "r",
        encoding="utf-8",
        errors="ignore"
    ) as f:
        return sum(1 for _ in f)



# ===============================
# 读取 README 旧统计数据
# ===============================

def read_old_stats(content):

    old_stats = {}

    for key in TARGET_FILES.keys():

        match = re.search(
            rf'{key}\s*规则数：(\d+)',
            content
        )

        if match:
            old_stats[key] = int(match.group(1))
        else:
            old_stats[key] = None


    return old_stats



# ===============================
# 生成变化字符串
# ===============================

def diff_text(current, old):

    if old is None:
        return "new"

    diff = current - old

    if diff > 0:
        return f"update +{diff}"

    elif diff < 0:
        return f"update {diff}"

    else:
        return "update +0"



# ===============================
# 更新 README 指定区域
# ===============================

def update_readme(stats_text):

    if os.path.exists(README_FILE):

        with open(
            README_FILE,
            "r",
            encoding="utf-8"
        ) as f:
            content = f.read()

    else:
        content = ""


    new_block = f"""<!-- STATS_START -->

{stats_text.strip()}

<!-- STATS_END -->"""


    pattern = (
        r"<!-- STATS_START -->"
        r".*?"
        r"<!-- STATS_END -->"
    )


    if re.search(
        pattern,
        content,
        flags=re.DOTALL
    ):

        content = re.sub(
            pattern,
            new_block,
            content,
            flags=re.DOTALL
        )

    else:

        content += "\n\n" + new_block



    with open(
        README_FILE,
        "w",
        encoding="utf-8"
    ) as f:
        f.write(content)



# ===============================
# 主程序
# ===============================

def main():


    # 当前统计

    current_stats = {}

    for key,path in TARGET_FILES.items():

        current_stats[key] = get_line_count(path)



    # 北京时间

    bj_time = (
        datetime.utcnow()
        +
        timedelta(hours=8)
    )


    update_time = bj_time.strftime(
        "%Y-%m-%d %H:%M:%S"
    )



    # 读取 README

    if os.path.exists(README_FILE):

        with open(
            README_FILE,
            "r",
            encoding="utf-8"
        ) as f:
            readme_content = f.read()

    else:

        readme_content = ""



    old_stats = read_old_stats(
        readme_content
    )



    # 生成统计文本

    stats_text = f"""
最后更新时间：{update_time}

DIRECT规则数：{current_stats['DIRECT']}，{diff_text(current_stats['DIRECT'], old_stats['DIRECT'])}

PROXY规则数：{current_stats['PROXY']}，{diff_text(current_stats['PROXY'], old_stats['PROXY'])}

REJECT规则数：{current_stats['REJECT']}，{diff_text(current_stats['REJECT'], old_stats['REJECT'])}

APPLE规则数：{current_stats['APPLE']}，{diff_text(current_stats['APPLE'], old_stats['APPLE'])}

GOOGLE规则数：{current_stats['GOOGLE']}，{diff_text(current_stats['GOOGLE'], old_stats['GOOGLE'])}

PCDN规则数：{current_stats['PCDN']}，{diff_text(current_stats['PCDN'], old_stats['PCDN'])}

HTTPDNS规则数：{current_stats['HTTPDNS']}，{diff_text(current_stats['HTTPDNS'], old_stats['HTTPDNS'])}
"""


    update_readme(
        stats_text
    )


    print(
        "✅ README 统计区域更新完成"
    )



if __name__ == "__main__":

    main()
