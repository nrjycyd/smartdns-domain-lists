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
#   *.example.com
#   *example.com
#   -.example.com
#
# 输出：
#   SmartDNS 标准格式
#
#   example.com     -> domain
#   *.example.com   -> sub
#   -.example.com   -> full
#   *example.com    -> suffix
#

tr -d '\r' |
awk -F',' '
BEGIN {
    IGNORECASE = 1
}

# 跳过注释
/^[[:space:]]*#/ { next }

# 跳过空行
/^[[:space:]]*$/ { next }

{
    line = $0

    # 去除首尾空格
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)

    # ==========================
    # 已经是 SmartDNS 格式
    # ==========================
    if (line ~ /^(\*\.|\*|-\.).+/) {
        print line
        next
    }

    # ==========================
    # AdGuard Home
    # ||example.com^
    # ==========================
    if (line ~ /^\|\|/) {
        sub(/^\|\|/, "", line)
        sub(/\^.*/, "", line)
        print line
        next
    }

    # ==========================
    # Surge / Quantumult X
    # ==========================
    if (toupper($1) == "DOMAIN") {
    domain = $2
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", domain)

    # SmartDNS full
    print "-." domain
    next
}

if (toupper($1) == "DOMAIN-SUFFIX") {
    domain = $2
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", domain)

    # SmartDNS domain
    print domain
    next
}

    # ==========================
    # Hosts
    # ==========================
    if (line ~ /^(0\.0\.0\.0|127\.0\.0\.1|::1)[[:space:]]+/) {
        split(line, a, /[[:space:]]+/)
        print a[2]
        next
    }

    # ==========================
    # 普通域名
    # ==========================
    if (line ~ /^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/) {
        print line
        next
    }
}
' |
sed \
    -e 's/\.$//' \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//' |
tr '[:upper:]' '[:lower:]' |
grep -E '^(\*\.|\*|-\.|)?[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$' |
grep -vE '^(\*\.|\*|-\.|)?[0-9.]+$' |
sort -u
