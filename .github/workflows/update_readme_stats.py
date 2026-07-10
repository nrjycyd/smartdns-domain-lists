#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import re
import os
from datetime import datetime, timedelta

# 定义需要统计的文件路径及其在 README 中的标识
TARGET_FILES = {
    'DIRECT': 'domain-set/direct-list.txt',
    'PROXY': 'domain-set/proxy-list.txt',
    'REJECT': 'domain-set/reject-list.txt',
    'APPLE_CN': 'domain-set/apple-cn.txt',
    'GOOGLE_CN': 'domain-set/google-cn.txt',
    'PCDN': 'domain-set/pcdn-list.txt',
    'HTTPDNS': 'domain-set/httpdns-list.txt'
}

def get_line_count(file_path):
    """安全获取文件行数"""
    if not os.path.exists(file_path):
        return 0
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        return sum(1 for _ in f)

def main():
    # 1. 统计当前最新的域名数量
    current_stats = {key: get_line_count(path) for key, path in TARGET_FILES.items()}
    
    # 获取当前北京时间 (UTC+8)
    # GitHub Actions 默认是 UTC 时间，手动加 8 小时转换为北京时间
    bj_time = datetime.utcnow() + timedelta(hours=8)
    update_time = bj_time.strftime('%Y-%m-%d %H:%M:%S')

    # 2. 读取现有的 README.md 尝试抓取历史数据
    readme_path = 'README.md'
    try:
        with open(readme_path, 'r', encoding='utf-8') as f:
            readme_content = f.read()
    except FileNotFoundError:
        readme_content = '\n'

    # 正则匹配形如 'DIRECT规则数：12345' 的历史数字
    old_stats = {}
    for key in current_stats.keys():
        match = re.search(rf'{key}\s*规则数：(\d+)', readme_content)
        old_stats[key] = int(match.group(1)) if match else current_stats[key]

    # 3. 计算差值函数
    def get_diff_str(key):
        diff = current_stats[key] - old_stats[key]
        if diff > 0:
            return f'update +{diff}'
        elif diff < 0:
            return f'update {diff}'
        else:
            return 'update +0'

    # 4. 拼装为你要求的文本格式
    stats_text = f'''
最后更新时间：{update_time}
DIRECT规则数：{current_stats['DIRECT']}，{get_diff_str('DIRECT')}
PROXY 规则数：{current_stats['PROXY']}，{get_diff_str('PROXY')}
REJECT规则数：{current_stats['REJECT']}，{get_diff_str('REJECT')}
APPLE_CN 规则数：{current_stats['APPLE_CN']}，{get_diff_str('APPLE_CN')}
GOOGLE_CN规则数：{current_stats['GOOGLE_CN']}，{get_diff_str('GOOGLE_CN')}
PCDN  规则数：{current_stats['PCDN']}，{get_diff_str('PCDN')}
HTTPDNS规则数：{current_stats['HTTPDNS']}，{get_diff_str('HTTPDNS')}
'''

    # 5. 替换回 README.md
    pattern = r'.*?'
    replacement = f'\\n{stats_text.strip()}\\n'
    new_readme = re.sub(pattern, replacement, readme_content, flags=re.DOTALL)

    with open(readme_path, 'w', encoding='utf-8') as f:
        f.write(new_readme)
    
    print("✅ README 统计数据与对比已成功分离并更新！")

if __name__ == '__main__':
    main()
