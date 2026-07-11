#!/usr/bin/env bash
#
# 域名规则标准化处理脚本
#
# 支持：
#   example.com
#   ||example.com^
#   DOMAIN,example.com
#   DOMAIN-SUFFIX,example.com
#   0.0.0.0 example.com
#   127.0.0.1 example.com
#   ::1 example.com
#
# 输入：
#   stdin
#
# 输出：
#   标准化后的纯域名列表
#   - 小写
#   - 去重
#   - 过滤无效内容
#

tr -d '\r' |
awk -F',' '
BEGIN {
    IGNORECASE = 1
}

# 跳过注释
/^[[:space:]]*#/ {
    next
}

# 跳过空行
/^[[:space:]]*$/ {
    next
}


{
    line=$0

    # 去除首尾空格
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)


    # ==========================
    # AdGuard Home
    # ||example.com^
    # ==========================
    if (line ~ /^\|\|/) {

        sub(/^\|\|/, "", line)

        # 删除 ^ 后所有参数
        sub(/\^.*/, "", line)

        print line
        next
    }


    # ==========================
    # Surge / Quantumult X
    # DOMAIN,example.com
    # DOMAIN-SUFFIX,example.com
    # ==========================
    if ($1 == "DOMAIN" || $1 == "DOMAIN-SUFFIX") {

        domain=$2

        gsub(/^[[:space:]]+|[[:space:]]+$/, "", domain)

        print domain
        next
    }


    # ==========================
    # Hosts
    # ==========================
    if (line ~ /^(0\.0\.0\.0|127\.0\.0\.1|::1)[[:space:]]+/) {

        split(line,a,/[\t ]+/)

        print a[2]
        next
    }


    # ==========================
    # 纯域名
    # ==========================
    if (line ~ /^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/) {

        print line
        next
    }

}
' |
sed -e 's/\.$//' \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//' |
tr '[:upper:]' '[:lower:]' |
grep -E '^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$' |
grep -vE '^[0-9.]+$' |
sort -u
