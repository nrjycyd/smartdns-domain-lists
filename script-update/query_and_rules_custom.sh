#!/bin/bash

# 获取脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_FILE="$SCRIPT_DIR/config"

# 加载配置文件
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
else
    echo "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 缓存文件路径
TMP_DOMAIN_LIST="/tmp/smartdns_failed_domains.txt"
TMP_NEW_RULES="/tmp/smartdns_new_rules.txt"


# 创建规则文件（若不存在）并添加注释头
if [ ! -f "$DOWNLOAD_CUSTOM" ]; then
    {
        echo "# 给域名自定义分流规则"
        echo "# direct 直连"
        echo "# proxy  代理"
        echo "# reject 拒绝"
    } > "$DOWNLOAD_CUSTOM"
fi

# 提取现有域名规则
existing_domains=$(awk -F',' '/^[^#]/ {print $1}' "$DOWNLOAD_CUSTOM")

# 提取额外已知列表（每行一个域名）
for f in "$DOWNLOAD_DIRECT" "$DOWNLOAD_PROXY" "$DOWNLOAD_REJECT"; do
    [ -f "$f" ] && existing_domains="$existing_domains"$'\n'"$(grep -v '^[[:space:]]*#' "$f")"
done

# 汇总排除域名（去重）
exclude_domains=$(echo "$existing_domains" | sort -u)

# 提取失败的域名
grep 'send query' "$LOG_SMARTDNS" | grep 'total server number 0' \
    | awk '{for(i=1;i<=NF;i++) if ($i ~ /send/) print $(i+2)}' \
    | sort -u > "$TMP_DOMAIN_LIST"

# 检查必要依赖
for cmd in dig curl geoiplookup; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "缺少 $cmd 命令，请先安装。"; exit 1; }
done

# 清空新规则和未识别日志
> "$TMP_NEW_RULES"
> "$LOG_UNCLASSIFIED"

# 国家归属判断函数
get_country() {
    local ip="$1"
    local country

    # 本地 geoiplookup
    geoip_output=$(geoiplookup "$ip")
    country=$(echo "$geoip_output" | grep -o 'Country: .*' | awk '{print $2}')

    # 若无效，用 ip-api.com
    if [[ -z "$country" || "$country" == "--" ]]; then
        country=$(curl -m 3 -s "http://ip-api.com/line/$ip?fields=countryCode" | head -n1)
    fi

    [[ -z "$country" || "$country" == "ZZ" ]] && country="UNKNOWN"
    echo "$country"
}

# 处理域名
while read -r domain; do
    [[ -z "$domain" ]] && continue
    echo "$exclude_domains" | grep -qx "$domain" && continue

    ip=$(dig +short "$domain" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    if [[ -z "$ip" ]]; then
        echo "[$domain] 无法解析 IP，跳过" >&2
        continue
    fi

    country=$(get_country "$ip")

    case "$country" in
        CN)
            echo "$domain,direct" >> "$TMP_NEW_RULES"
            echo "[$domain] 属于中国，加入 direct。"
            ;;
        UNKNOWN)
            echo "$domain,proxy" >> "$TMP_NEW_RULES"
            echo "$domain [$ip] 无法识别归属地，默认 proxy。" >> "$LOG_UNCLASSIFIED"
            ;;
        *)
            echo "$domain,proxy" >> "$TMP_NEW_RULES"
            echo "[$domain] 属于 $country，加入 proxy。"
            ;;
    esac
done < "$TMP_DOMAIN_LIST"

# 去重后追加（仅在有新增时）
if [ -s "$TMP_NEW_RULES" ]; then
    sort -u "$TMP_NEW_RULES" >> "$DOWNLOAD_CUSTOM"
    echo "已追加 $(wc -l < "$TMP_NEW_RULES") 条规则到 $DOWNLOAD_CUSTOM。"

    # 执行自定义规则更新脚本
    PROCESS_DOMAIN_LISTS="$SCRIPT_DIR/process_domain_lists.sh"
    if [ -x "$PROCESS_DOMAIN_LISTS" ]; then
        "$PROCESS_DOMAIN_LISTS"
    else
        echo "警告："$PROCESS_DOMAIN_LISTS" 不存在或不可执行，跳过执行。"
    fi
else
    echo "无新增规则，$DOWNLOAD_CUSTOM 保持不变。"
fi


# 清理
rm -f "$TMP_DOMAIN_LIST" "$TMP_NEW_RULES"
