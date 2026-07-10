#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
from pathlib import Path
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

README_FILE = Path("README.md")


# ===============================
# 获取文件行数
# ===============================
def get_line_count(file_path: str) -> int:
    path = Path(file_path)
    if not path.exists():
        return 0
    
    with path.open("r", encoding="utf-8", errors="ignore") as f:
        # 使用生成器表达式，针对大体积规则列表依然能保持低内存占用
        return sum(1 for _ in f)


# ===============================
# 读取 README 旧统计数据
# ===============================
def read_old_stats(content: str) -> dict:
    old_stats = {}
    for key in TARGET_FILES.keys():
        match = re.search(rf'{key}\s*规则数：(\d+)', content)
        old_stats[key] = int(match.group(1)) if match else None
    return old_stats


# ===============================
# 生成变化字符串
# ===============================
def diff_text(current: int, old: int) -> str:
    if old is None:
        return "new"
    
    diff = current - old
    # 合并了 >0 和 ==0 的情况，因为 +0 同样适用 f"+{diff}"
    return f"update +{diff}" if diff >= 0 else f"update {diff}"


# ===============================
# 主程序
# ===============================
def main():
    # 1. 统一读取 README 内容（避免多次读取）
    readme_content = README_FILE.read_text(encoding="utf-8") if README_FILE.exists() else ""
    
    # 2. 获取旧数据和当前最新数据
    old_stats = read_old_stats(readme_content)
    current_stats = {key: get_line_count(path) for key, path in TARGET_FILES.items()}
    
    # 3. 动态生成统计文本 (以后增删规则，只需修改顶部的 TARGET_FILES)
    bj_time = (datetime.utcnow() + timedelta(hours=8)).strftime("%Y-%m-%d %H:%M:%S")
    stats_lines = [f"最后更新时间：{bj_time}"]
    
    for key in TARGET_FILES.keys():
        diff = diff_text(current_stats[key], old_stats[key])
        stats_lines.append(f"{key}规则数：{current_stats[key]}，{diff}")
    
    # 使用双换行符拼接所有文本
    stats_text = "\n\n".join(stats_lines)
    
    new_block = f"\n\n{stats_text}\n\n"
    pattern = r".*?"
    
    # 4. 替换并写入 README
    if re.search(pattern, readme_content, flags=re.DOTALL):
        new_content = re.sub(pattern, new_block, readme_content, flags=re.DOTALL)
    else:
        # 如果原来没有该区块，则直接追加到末尾
        new_content = f"{readme_content.strip()}\n\n{new_block}"
        
    README_FILE.write_text(new_content, encoding="utf-8")
    print("✅ README 统计区域更新完成")


if __name__ == "__main__":
    main()
