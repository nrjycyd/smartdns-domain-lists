# Normalize domain lists from different rule formats
normalize_domain_list() {
    tr -d '\r' | \
    awk -F',' '
    # 跳过注释和空行
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }

    {
        line = $0

        # 去除首尾空白
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)

        # AdGuard: ||example.com^
        if (line ~ /^\|\|/) {
            sub(/^\|\|/, "", line)
            sub(/\^$/, "", line)
            print line
            next
        }

        # Surge / Quantumult X
        if ($1 == "DOMAIN" || $1 == "DOMAIN-SUFFIX") {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
            print $2
            next
        }

        # Hosts
        if (line ~ /^(0\.0\.0\.0|127\.0\.0\.1|::1)[[:space:]]+/) {
            split(line, a, /[[:space:]]+/)
            print a[2]
            next
        }

        # 已经是纯域名
        if (line ~ /^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/) {
            print line
            next
        }
    }
    ' | \
    sed -e 's/\.$//' \
        -e 's/^[[:space:]]*//' \
        -e 's/[[:space:]]*$//' | \
    tr '[:upper:]' '[:lower:]' | \
    grep -E '^[a-z0-9.-]+\.[a-z]{2,}$' | \
    sort -u
}
