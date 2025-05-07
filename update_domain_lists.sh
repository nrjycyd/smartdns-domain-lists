#!/bin/sh

# =============================================
# SmartDNS 域名列表自动更新脚本（优化版）
# 功能：下载直连/代理/拒绝列表，更新配置并重启服务
# 作者：nrjycyd（原始脚本） + 优化注释
# =============================================

# ------------ 配置区域（可修改）------------
FILE_DIR="/etc/smartdns/domain-set"
BAK_DIR="/var/backups/smartdns/domain-set-bak"  # 备份目录，留空则不备份
MAX_BACKUPS=3                  # 备份保留份数（0表示不限制）
REPO_URL="https://raw.githubusercontent.com/nrjycyd/smartdns-domain-lists/main/domain-set"

# 临时文件路径
TMP_DIRECT="/tmp/direct-list.tmp"
TMP_PROXY="/tmp/proxy-list.tmp"
TMP_REJECT="/tmp/reject-list.tmp"

# 最终存放路径
FILE_DIRECT="$FILE_DIR/direct-list.txt"
FILE_PROXY="$FILE_DIR/proxy-list.txt"
FILE_REJECT="$FILE_DIR/reject-list.txt"

# 日志文件路径
LOG_FILE="/var/log/smartdns_update.log"
# ------------------------------------------

# 初始化目录结构
mkdir -p "$FILE_DIR" 2>/dev/null
[ -n "$BAK_DIR" ] && mkdir -p "$BAK_DIR" 2>/dev/null
touch "$LOG_FILE" 2>/dev/null

# 记录开始时间
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 开始更新域名列表" >> "$LOG_FILE"
echo "备份设置: ${BAK_DIR:-无} (保留${MAX_BACKUPS}份)" >> "$LOG_FILE"

# ============= 下载函数 =============
download_file() {
    local url="$1"
    local tmp_file="$2"
    local retries=3 delay=2
    
    echo "下载: $url" >> "$LOG_FILE"
    
    for i in $(seq 1 $retries); do
        if curl -fsSL "$url" -o "$tmp_file" && [ -s "$tmp_file" ] && grep -q "." "$tmp_file"; then
            echo "下载成功: $(wc -l < "$tmp_file") 行" >> "$LOG_FILE"
            return 0
        fi
        echo "尝试 $i/$retries 失败，等待 ${delay}秒..." >> "$LOG_FILE"
        sleep $delay
    done
    
    echo "错误: 下载失败 $url" >> "$LOG_FILE"
    return 1
}

# ============= 备份函数（修复版） =============
backup_file() {
    [ -z "$BAK_DIR" ] && return 0
    [ "$MAX_BACKUPS" -eq 0 ] && return 0

    local file="$1"
    [ -f "$file" ] || return 0

    local filename=$(basename "$file")
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local backup_file="${BAK_DIR}/${filename}.bak-${timestamp}"

    # 创建新备份
    if cp -f "$file" "$backup_file"; then
        echo "备份成功: $(basename "$backup_file")" >> "$LOG_FILE"

        # 清理旧备份（兼容sh的实现）
        ls -t "${BAK_DIR}/${filename}.bak-"* 2>/dev/null | \
        awk -v max="$MAX_BACKUPS" 'NR>max {print $0}' | \
        while read -r old; do
            rm -f "$old"
            echo "已清理旧备份: $(basename "$old")" >> "$LOG_FILE"
        done
    else
        echo "备份失败: $file → $backup_file" >> "$LOG_FILE"
    fi
}

# ============= 主下载流程 =============
for type in direct proxy reject; do
    if ! download_file "$REPO_URL/$type-list.txt" "/tmp/$type-list.tmp"; then
        exit 1
    fi
done

# ============= 执行备份 =============
if [ -n "$BAK_DIR" ]; then
    backup_file "$FILE_DIRECT"
    backup_file "$FILE_PROXY"
    backup_file "$FILE_REJECT"
fi

# ============= 文件处理 =============
mv -f "$TMP_DIRECT" "$FILE_DIRECT"
mv -f "$TMP_PROXY" "$FILE_PROXY"
mv -f "$TMP_REJECT" "$FILE_REJECT"

echo "文件更新完成：" >> "$LOG_FILE"
ls -lh "$FILE_DIR" | awk '{print "  " $0}' >> "$LOG_FILE"

# ============= 服务管理 =============
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

# 完成记录
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 更新完成" >> "$LOG_FILE"
echo "-------------------------------------" >> "$LOG_FILE"

# 控制台输出
echo "SmartDNS域名列表更新完成!"
[ -n "$BAK_DIR" ] && echo "备份已保存至: $BAK_DIR (保留${MAX_BACKUPS}份)"
echo "详细日志: $LOG_FILE"
