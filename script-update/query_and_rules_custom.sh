#!/bin/bash

# 获取脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_FILE="$SCRIPT_DIR/config"

# === 函数：安装依赖 ===
install_dependencies() {
    echo "[INFO] 检查并安装必要依赖..." | tee -a "$LOG_FILE"
    sudo apt-get update
    sudo apt-get install -y geoip-bin libmaxminddb0 libmaxminddb-dev mmdb-bin curl dnsutils
}

# === 函数：自动更新 GeoIP 数据库 ===
update_geoip_db() {
    echo "[INFO] 检查并更新 GeoIP 数据库..." >> "$LOG_FILE"

    HASH_DIR="$SCRIPT_DIR/.hash"
    HASH_FILE="$HASH_DIR/GeoLite2-Country.mmdb.md5"
    sudo mkdir -p "$(dirname "$GEOIP_DB")"
    mkdir -p "$HASH_DIR"

    TMP_DB="/tmp/GeoLite2-Country.mmdb"
    if wget -q --timeout=10 -O "$TMP_DB" "$GEOIP_URL"; then
        new_md5=$(md5sum "$TMP_DB" | awk '{print $1}')
        old_md5=""
        [ -f "$HASH_FILE" ] && old_md5=$(cat "$HASH_FILE")

        if [ "$new_md5" != "$old_md5" ]; then
            sudo mv "$TMP_DB" "$GEOIP_DB"
            echo "$new_md5" > "$HASH_FILE"
            echo "[INFO] GeoIP 数据库已更新: $GEOIP_DB" >> "$LOG_FILE"
        else
            rm -f "$TMP_DB"
            echo "[INFO] GeoIP 数据库无更新" >> "$LOG_FILE"
        fi
    else
        echo "[WARN] 下载 GeoIP 数据库失败: $GEOIP_URL" >> "$LOG_FILE"
        rm -f "$TMP_DB"
    fi
}

# 加载配置文件
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
else
    echo "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 安装依赖
install_dependencies

# 你可以根据需求调用 GeoIP 更新函数，比如：
# update_geoip_db

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

# 检查必要命令依赖
for cmd in dig curl geoiplookup mmdblookup; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "缺少 $cmd 命令，请先安装。"; exit 1; }
done

# 清空新规则和未识别日志
> "$TMP_NEW_RULES"
> "$LOG_UNCLASSIFIED"

# 增强版国家查询函数
get_country() {
    local ip="$1"
    local country
    local method

    # 本地 GeoIP 查询
    if [[ -f "$GEOIP_DB" && -x $(command -v mmdblookup) ]]; then
        country=$(mmdblookup --file "$GEOIP_DB" --ip "$ip" country iso_code 2>/dev/null | \
                  grep -oE '"[A-Z]{2}"' | tr -d '"' | head -n1)

        if [[ -n "$country" && "$country" != "null" ]]; then
            echo "$country:mmdblookup"
            return 0
        else
            echo "DEBUG: mmdblookup查询失败，返回值为: '$country'" >&2
        fi
    else
        echo "DEBUG: 缺少mmdblookup或数据库文件" >&2
    fi

    # API 查询
    sleep $API_DELAY
    country=$(curl -m 5 -s "http://ip-api.com/line/$ip?fields=countryCode" | head -n1)
    method="ip-api.com"

    if [[ "$country" == *"rate limited"* ]]; then
        sleep 5
        country=$(curl -m 5 -s "http://ip-api.com/line/$ip?fields=countryCode" | head -n1)
    fi

    [[ -z "$country" || "$country" == "ZZ" ]] && country="UNKNOWN"
    echo "$country:$method"
}

# 处理域名（带调试信息）
while read -r domain || [[ -n "$domain" ]]; do
    [[ -z "$domain" ]] && continue
    [[ -n "$exclude_domains" ]] && grep -qxF "$domain" <<< "$exclude_domains" && continue

    # DNS解析
    ip=$(dig +short "$domain" @"$PUBLIC_DNS" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)
    [[ -z "$ip" ]] && echo "[DNS失败] $domain" >&2 && continue

    # 获取国家信息
    result=$(get_country "$ip")
    country="${result%%:*}"
    method="${result#*:}"

    # 确定处理动作
    case "$country" in
        CN) action="direct" ;;
        *)  action="proxy"
            [[ "$country" == "UNKNOWN" ]] && echo "$domain [$ip] 无法识别归属地" >> "$LOG_UNCLASSIFIED"
            ;;
    esac

    # 输出处理结果
    printf "[%-10s] %-40s → %-15s → %-5s → 标记为 %s\n" \
           "$method" "$domain" "$ip" "$country" "$action" >&2
    echo "$domain,$action" >> "$TMP_NEW_RULES"
done < "$TMP_DOMAIN_LIST"

# # 去重后追加（仅在有新增时）
# if [ -s "$TMP_NEW_RULES" ]; then
#     sort -u "$TMP_NEW_RULES" >> "$DOWNLOAD_CUSTOM"
#     echo "已追加 $(wc -l < "$TMP_NEW_RULES") 条规则到 $DOWNLOAD_CUSTOM。"

#     # 执行域名整理脚本
#     PROCESS_DOMAIN_LISTS="$SCRIPT_DIR/process_domain_lists.sh"
#     if [ -x "$PROCESS_DOMAIN_LISTS" ]; then
#         "$PROCESS_DOMAIN_LISTS"
#     else
#         echo "警告："$PROCESS_DOMAIN_LISTS" 不存在或不可执行，跳过执行。"
#     fi
# else
#     echo "无新增规则，$DOWNLOAD_CUSTOM 保持不变。"
# fi

# 准备哈希缓存目录
HASH_DIR="$SCRIPT_DIR/.hash"
mkdir -p "$HASH_DIR"

NEED_PROCESS=0

# 检查三个主列表是否有变化
for VAR_NAME in DOWNLOAD_DIRECT DOWNLOAD_PROXY DOWNLOAD_REJECT; do
    FILE_PATH="${!VAR_NAME}"
    FILE_NAME=$(basename "$FILE_PATH")
    HASH_FILE="$HASH_DIR/${FILE_NAME}.md5"

    NEW_HASH=$(md5sum "$FILE_PATH" 2>/dev/null | awk '{print $1}')
    OLD_HASH=""
    [ -f "$HASH_FILE" ] && OLD_HASH=$(<"$HASH_FILE")

    if [ "$NEW_HASH" != "$OLD_HASH" ]; then
        echo "$FILE_NAME 发生变化"
        echo "$NEW_HASH" > "$HASH_FILE"
        NEED_PROCESS=1
    fi
done

# 检查 TMP_NEW_RULES 是否要追加进 DOWNLOAD_CUSTOM
if [ -s "$TMP_NEW_RULES" ]; then
    TMP_SORTED=$(mktemp)
    sort -u "$TMP_NEW_RULES" > "$TMP_SORTED"

    TMP_MERGED=$(mktemp)
    cat "$DOWNLOAD_CUSTOM" "$TMP_SORTED" | sort -u > "$TMP_MERGED"

    NEW_CUSTOM_HASH=$(md5sum "$TMP_MERGED" | awk '{print $1}')
    OLD_CUSTOM_HASH=$(md5sum "$DOWNLOAD_CUSTOM" | awk '{print $1}')

    if [ "$NEW_CUSTOM_HASH" != "$OLD_CUSTOM_HASH" ]; then
        cat "$TMP_SORTED" >> "$DOWNLOAD_CUSTOM"
        echo "已追加 $(wc -l < "$TMP_SORTED") 条规则到 $DOWNLOAD_CUSTOM。"
        echo "$NEW_CUSTOM_HASH" > "$HASH_DIR/$(basename "$DOWNLOAD_CUSTOM").md5"
        NEED_PROCESS=1
    else
        echo "$DOWNLOAD_CUSTOM 内容未变，未追加规则。"
    fi

    rm -f "$TMP_SORTED" "$TMP_MERGED"
else
    echo "无新增规则，$DOWNLOAD_CUSTOM 保持不变。"
fi

# 如果任何变动，执行整理脚本
PROCESS_DOMAIN_LISTS="$SCRIPT_DIR/process_domain_lists.sh"
if [ "$NEED_PROCESS" -eq 1 ]; then
    if [ -x "$PROCESS_DOMAIN_LISTS" ]; then
        echo "文件变化，执行域名整理脚本..."
        "$PROCESS_DOMAIN_LISTS"
    else
        echo "警告：$PROCESS_DOMAIN_LISTS 不存在或不可执行，跳过执行。"
    fi
else
    echo "所有文件未变化，跳过域名整理。"
    echo "-------------------------------------"
fi

# 清理
rm -f "$TMP_DOMAIN_LIST" "$TMP_NEW_RULES"
