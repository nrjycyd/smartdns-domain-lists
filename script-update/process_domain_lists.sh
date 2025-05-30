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

export LC_ALL=C

TMP_DIR="/tmp/smartdns_tmp"
mkdir -p "$TMP_DIR"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

declare -A custom_rules
while IFS=',' read -r domain action _ || [ -n "$domain" ]; do
    [[ "$domain" =~ ^#|^$ ]] && continue
    domain=$(echo "$domain" | xargs)
    action=$(echo "$action" | xargs)
    custom_rules["$domain"]=$action
done < <(sort -u "$DOWNLOAD_CUSTOM")

process_list() {
    local list_file=$1
    local list_type=$2
    local tmp_file="$TMP_DIR/$(basename "$list_file").tmp"

    [ -f "$list_file" ] || touch "$list_file"

    grep -vFxf <(printf "%s\n" "${!custom_rules[@]}") "$list_file" > "$tmp_file"

    for domain in "${!custom_rules[@]}"; do
        [ "${custom_rules[$domain]}" = "$list_type" ] && echo "$domain"
    done >> "$tmp_file"

    sort -u "$tmp_file" > "$list_file"
}

process_list "$FILE_DIRECT" direct &
process_list "$FILE_PROXY" proxy &
process_list "$FILE_REJECT" reject &
wait

if systemctl is-active --quiet smartdns; then
    echo "正在重启SmartDNS服务..." >> "$LOG_FILE"
    if systemctl restart smartdns; then
        echo "服务重启成功" >> "$LOG_FILE"
    else
        echo "服务重启失败!" >> "$LOG_FILE"
        exit 1
    fi
else
    echo "SmartDNS未运行，请手动启动" >> "$LOG_FILE"
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] 更新完成" >> "$LOG_FILE"
echo "-------------------------------------" >> "$LOG_FILE"

[ -n "$BAK_DIR" ] && echo "备份已保存至: $BAK_DIR (保留${MAX_BACKUPS}份)"
echo "详细日志: $LOG_FILE"
