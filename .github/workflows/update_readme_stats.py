#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import re
import os
from datetime import datetime, timezone, timedelta

# 定义需要统计的文件路径
TARGET_FILES = {
    'DIRECT': 'domain-set/direct-list.txt',
    'PROXY': 'domain-set/proxy-list.txt',
    'REJECT': 'domain-set/reject-list.txt',
    'APPLE': 'domain-set/apple-cn.txt',
    'GOOGLE': 'domain-set/google-cn.txt',
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
    
    # 获取当前北京时间 (UTC+8)，修复 DeprecationWarning 警告
    bj_time = datetime.now(timezone.utc) + timedelta(hours=8)
    update_time = bj_time.strftime('%Y-%m-%d %H:%M:%S')

    # 2. 读取现有的 README.md 尝试抓取历史数字用于对比
    readme_path = 'README.md'
    old_stats = {}
    if os.path.exists(readme_path):
        with open(readme_path, 'r', encoding='utf-8') as f:
            content = f.read()
        for key in current_stats.keys():
            # 兼容带有或不带有 _CN 历史格式的提取
            match = re.search(rf'{key}(?:_CN)?\s*规则数：(\d+)', content)
            old_stats[key] = int(match.group(1)) if match else current_stats[key]
    else:
        old_stats = current_stats.copy()

    # 3. 计算差值函数
    def get_diff_str(key):
        diff = current_stats[key] - old_stats.get(key, current_stats[key])
        if diff > 0:
            return f'update +{diff}'
        elif diff < 0:
            return f'update {diff}'
        else:
            return 'update +0'

    # 4. 生成动态统计文本
    stats_text = f"""最后更新时间：{update_time}
DIRECT 规则数：{current_stats['DIRECT']}，{get_diff_str('DIRECT')}
PROXY  规则数：{current_stats['PROXY']}，{get_diff_str('PROXY')}
REJECT 规则数：{current_stats['REJECT']}，{get_diff_str('REJECT')}
APPLE  规则数：{current_stats['APPLE']}，{get_diff_str('APPLE')}
GOOGLE 规则数：{current_stats['GOOGLE']}，{get_diff_str('GOOGLE')}
PCDN   规则数：{current_stats['PCDN']}，{get_diff_str('PCDN')}
HTTPDNS规则数：{current_stats['HTTPDNS']}，{get_diff_str('HTTPDNS')}"""

    # 5. 拼装成绝对完整的 README.md（不用再怕标记丢失或吞掉了）
    full_readme_content = f"""# 项目简介

这是一个自动更新域名列表的项目，定期从 Loyalsoldier 的 [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) 仓库获取最新的域名分类列表，处理为 SmartDNS 可直接使用的格式。

## 规则统计

{stats_text}
## 主要功能

1. **自动定时更新**：每天 UTC 时间 3:00 (北京时间 11:00) 自动执行更新
2. **同步上游域名列表**：
   - 直连列表 (direct-list)：包含国内[直连域名](https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/direct-list.txt)、[苹果中国域名](https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/apple-cn.txt)、[谷歌中国域名](https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/google-cn.txt)
   - 代理列表 (proxy-list)：包含[代理域名列表](https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/proxy-list.txt)、[GFWList 域名列表](https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/gfw.txt)
   - 屏蔽列表 (reject-list)：包含[广告域名列表](https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/reject-list.txt)
3. **数据处理**：
   - 移除 `regexp:` 开头的行
   - 移除 `full:` 前缀
   - 去重排序
4. **域名分类处理**：
   - 将 apple-cn 和 google-cn 的域名独立出来
   - 从 direct-list 中排除 apple-cn 和 google-cn 的域名
   - 从 proxy-list 中排除 apple-cn 和 google-cn 的域名
   - 按优先级去重 (reject > proxy > direct)

   **去重顺序:**
   1. reject-list 保持不变 (最高优先级)
   2. 从 proxy-list 中移除所有在 reject-list 中的域名
   3. 从 direct-list 中移除所有在 reject-list 中的域名
   4. 从 direct-list 中移除所有在 proxy-list 中的域名 (已去重后的)
     
   **最终结果:**
   - reject-list: 完整列表
   - proxy-list: 不含 reject 中的域名
   - direct-list: 不含 reject 和 proxy-list 中的域名

## 使用说明

### 一、手动获取域名列表

1. 从项目的 Releases 页面下载 [smartdns-domain-lists.zip](https://github.com/nrjycyd/smartdns-domain-lists/releases) 压缩包
2. 解压后得到 `domain-set` 目录，包含三个分类文件：
   - `direct-list.txt` - 直连域名列表
   - `proxy-list.txt` - 代理域名列表
   - `reject-list.txt` - 屏蔽域名列表

### 二、自动获取域名列表

本项目提供 1 个自动化脚本：
- `fetch_domain_lists.sh`

该脚本为主脚本，可以自动从预设仓库获取最新域名列表（直连/代理/拒绝三类）。

添加脚本执行权限：
```bash
chmod +x ./fetch_domain_lists.sh
