#!/bin/bash

# ------------ 配置区域（可修改）------------
export LC_ALL=C  # 优化排序性能

FILE_DIR="/etc/smartdns/domain-set"
FILE_DIRECT="$FILE_DIR/direct-list.txt"
FILE_PROXY="$FILE_DIR/proxy-list.txt"
FILE_REJECT="$FILE_DIR/reject-list.txt"
FILE_CUSTOM="$FILE_DIR/custom-list.txt"
TMP_DIR="/tmp/smartdns_tmp"
# ------------------------------------------

# 创建临时目录并确保退出时清理
mkdir -p "$TMP_DIR"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# 检查 custom-list 文件是否存在，不存在则创建空文件
if [ ! -f "$FILE_CUSTOM" ]; then
    echo "提示: 未找到 $FILE_CUSTOM，已自动创建空文件"
    touch "$FILE_CUSTOM"
fi

# 使用更高效的文件哈希计算方式
calculate_hash() {
    sha256sum "$FILE_DIRECT" "$FILE_PROXY" "$FILE_REJECT" 2>/dev/null | sha256sum | cut -d' ' -f1
}

# 获取修改前的哈希
old_hash=$(calculate_hash)

# 使用关联数组存储自定义规则
declare -A custom_rules
while IFS=',' read -r domain action _ || [ -n "$domain" ]; do
    [[ "$domain" =~ ^#|^$ ]] && continue
    domain=$(echo "$domain" | xargs)
    action=$(echo "$action" | xargs)
    custom_rules["$domain"]=$action
done < <(sort -u "$FILE_CUSTOM")

# 处理各列表文件
process_list() {
    local list_file=$1
    local list_type=$2
    local tmp_file="$TMP_DIR/$(basename "$list_file").tmp"

    [ -f "$list_file" ] || touch "$list_file"

    grep -vFxf <(printf "%s\n" "${!custom_rules[@]}") "$list_file" > "$tmp_file"

    for domain in "${!custom_rules[@]}"; do
        [ "${custom_rules[$domain]}" = "$list_type" ] && echo "$domain"
    done >> "$tmp_file"

    sort -u --parallel=4 "$tmp_file" > "$list_file"
}

# 并行处理三个列表
process_list "$FILE_DIRECT" direct &
process_list "$FILE_PROXY"  proxy &
process_list "$FILE_REJECT" reject &
wait

# 检查是否需要重启
new_hash=$(calculate_hash)
end_time=$(date +%s)
elapsed=$((end_time - start_time))

echo "处理完成，耗时 ${elapsed} 秒"

if [ "$old_hash" != "$new_hash" ]; then
    echo "检测到变更，正在重启 SmartDNS..."
    systemctl restart smartdns
    echo "SmartDNS 已重启"
else
    echo "无变更，无需重启 SmartDNS"
fi
