#!/usr/bin/env bash
#
# 域名规则标准化处理脚本
#
# 支持多种常见规则格式：
#
#   - 纯域名
#       example.com
#
#   - AdGuard Home 格式
#       ||example.com^
#
#   - Surge / Quantumult X 格式
#       DOMAIN,example.com
#       DOMAIN-SUFFIX,example.com
#
#   - Hosts 格式
#       0.0.0.0 example.com
#       127.0.0.1 example.com
#       ::1 example.com
#
# 输入：
#   从标准输入读取规则文件
#
# 示例：
#   cat rules.txt | ./.github/scripts/normalize_domain_list.sh
#
# 输出：
#   标准化后的纯域名列表
#   - 小写
#   - 去除重复
#   - 去除无效规则
#

# 删除 Windows 换行符 CRLF
# 避免同一个域名因为隐藏的 \r 导致无法去重
tr -d '\r' | \
awk -F',' '

BEGIN {
    # 忽略大小写
    IGNORECASE = 1
}

# 跳过注释行
# 例如：
# # comment
/^[[:space:]]*#/ { next }

# 跳过空行
/^[[:space:]]*$/ { next }


{
    # 当前行内容
    line = $0

    # 去除行首和行尾空格
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)


    #
    # 处理 AdGuard Home 规则
    #
    # 示例：
    # ||example.com^
    #
    if (line ~ /^\|\|/) {

        # 删除开头 ||
        sub(/^\|\|/, "", line)

        # 删除结尾 ^
        sub(/\^$/, "", line)

        print line
        next
    }


    #
    # 处理 Surge / Quantumult X 规则
    #
    # 示例：
    # DOMAIN,example.com
    # DOMAIN-SUFFIX,example.com
    #
    if ($1 == "DOMAIN" || $1 == "DOMAIN-SUFFIX") {

        domain = $2

        # 去除域名两端空格
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", domain)

        print domain
        next
    }


    #
    # 处理 Hosts 格式
    #
    # 示例：
    # 0.0.0.0 example.com
    # 127.0.0.1 example.com
    # ::1 example.com
    #
    if (line ~ /^(0\.0\.0\.0|127\.0\.0\.1|::1)[[:space:]]+/) {

        # 按空格拆分
        split(line, a, /[[:space:]]+/)

        # 输出第二列域名
        print a[2]
        next
    }


    #
    # 处理纯域名格式
    #
    # 示例：
    # example.com
    #
    if (line ~ /^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/) {

        print line
        next
    }
}

' | \

#
# 二次清理
#
sed \
    # 删除域名末尾 .
    -e 's/\.$//' \
    \
    # 删除行首空格
    -e 's/^[[:space:]]*//' \
    \
    # 删除行尾空格
    -e 's/[[:space:]]*$//' | \


#
# 统一转换为小写
#
tr '[:upper:]' '[:lower:]' | \


#
# 只保留合法域名
#
# 防止正则规则、IP 地址等进入域名列表
#
grep -E '^[a-z0-9.-]+\.[a-z]{2,}$' | \


#
# 排序并去除重复
#
sort -u
