#!/bin/sh

# 获取脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# 加载配置文件
CONFIG_FILE="$SCRIPT_DIR/config"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
else
    echo "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# === 初始化目录结构 ===
mkdir -p "$FILE_DIR" "$DOWNLOAD_DIR"
[ -n "$BAK_DIR" ] && mkdir -p "$BAK_DIR"
touch "$LOG_FILE"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] 开始更新域名列表" >> "$LOG_FILE"
echo "备份设置: ${BAK_DIR:-无} (保留${MAX_BACKUPS}份)" >> "$LOG_FILE"

# ============= 下载函数 =============
download_file() {
    local url="$1"
    local output_file="$2"
    local retries=3 delay=2

    echo "下载: $url" >> "$LOG_FILE"
    for i in $(seq 1 $retries); do
        if curl -fsSL "$url" -o "$output_file" && [ -s "$output_file" ]; then
            echo "下载成功: $(wc -l < "$output_file") 行" >> "$LOG_FILE"
            return 0
        fi
        echo "尝试 $i/$retries 失败，等待 ${delay}秒..." >> "$LOG_FILE"
        sleep $delay
    done

    echo "错误: 下载失败 $url" >> "$LOG_FILE"
    return 1
}

# ============= 备份函数（按时间归类） =============
backup_files() {
    [ -z "$BAK_DIR" ] && return 0
    [ "$MAX_BACKUPS" -eq 0 ] && return 0

    local timestamp=$(date +"%Y%m%d%H%M%S")
    local subdir="${BAK_DIR}/${timestamp}"

    mkdir -p "$subdir" || return 1

    local success=0

    for file in "$@"; do
        [ -f "$file" ] || continue
        cp -f "$file" "$subdir/" && success=1
    done

    if [ "$success" -eq 1 ]; then
        echo "备份成功: ${timestamp}" >> "$LOG_FILE"

        # 清理旧备份目录，仅保留最新的 $MAX_BACKUPS 个目录
        find "$BAK_DIR" -mindepth 1 -maxdepth 1 -type d | sort -r | awk -v max="$MAX_BACKUPS" 'NR > max' | \
        while read -r old_dir; do
            rm -rf "$old_dir"
            echo "已清理旧备份: ${old_dir#$BAK_DIR/}" >> "$LOG_FILE"
        done
    else
        echo "备份失败: $file → ${timestamp}" >> "$LOG_FILE"
    fi
}

# ============= 主流程 =============
for type in direct proxy reject; do
    if ! download_file "$REPO_URL/$type-list.txt" "$DOWNLOAD_DIR/$type-list.txt"; then
        exit 1
    fi
done

# 统一备份多个文件
backup_files "$FILE_DIRECT" "$FILE_PROXY" "$FILE_REJECT"

# 执行自定义脚本
QUERY_AND_RULES_CUSTOM="$SCRIPT_DIR/query_and_rules_custom.sh"
if [ -f "$QUERY_AND_RULES_CUSTOM" ]; then
    echo "检测到域名查询及规则自定义脚本，执行中: $QUERY_AND_RULES_CUSTOM" >> "$LOG_FILE"
    if bash "$QUERY_AND_RULES_CUSTOM" >> "$LOG_FILE" 2>&1; then
        # echo "自定义更新脚本执行完成" >> "$LOG_FILE"
        # echo "跳过默认更新流程" >> "$LOG_FILE"
        exit 0
    else
        echo "自定义更新脚本执行失败!" >> "$LOG_FILE"
        exit 1
    fi
fi

# 更新文件
cp -f "$DOWNLOAD_DIRECT" "$FILE_DIRECT"
cp -f "$DOWNLOAD_PROXY" "$FILE_PROXY"
cp -f "$DOWNLOAD_REJECT" "$FILE_REJECT"

echo "文件更新完成：" >> "$LOG_FILE"
ls -lh "$FILE_DIR" | awk '{print "  " $0}' >> "$LOG_FILE"

# 重启服务
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

echo "SmartDNS域名列表更新完成!"
[ -n "$BAK_DIR" ] && echo "备份已保存至: $BAK_DIR (保留${MAX_BACKUPS}份)"
echo "详细日志: $LOG_FILE"
