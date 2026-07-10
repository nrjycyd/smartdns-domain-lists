#!/bin/bash
# update_readme_stats.sh - 统计各域名列表文件数量，更新 README.md 中的域名统计表格
# 在仓库根目录执行

set -euo pipefail

DOMAIN_DIR="domain-set"
README="README.md"
STATS_FILE="/tmp/stats.md"

# ---- 1. 统计各文件域名数 ----
D_COUNT=$(wc -l < "${DOMAIN_DIR}/direct-list.txt")
P_COUNT=$(wc -l < "${DOMAIN_DIR}/proxy-list.txt")
R_COUNT=$(wc -l < "${DOMAIN_DIR}/reject-list.txt")
A_COUNT=$(wc -l < "${DOMAIN_DIR}/apple-cn.txt")
G_COUNT=$(wc -l < "${DOMAIN_DIR}/google-cn.txt")
PC_COUNT=$(wc -l < "${DOMAIN_DIR}/pcdn-list.txt")
H_COUNT=$(wc -l < "${DOMAIN_DIR}/httpdns-list.txt")

echo "=== 各文件域名数量统计 ==="
echo "direct-list.txt:  ${D_COUNT} 条"
echo "proxy-list.txt:   ${P_COUNT} 条"
echo "reject-list.txt:  ${R_COUNT} 条"
echo "apple-cn.txt:     ${A_COUNT} 条"
echo "google-cn.txt:    ${G_COUNT} 条"
echo "pcdn-list.txt:    ${PC_COUNT} 条"
echo "httpdns-list.txt: ${H_COUNT} 条"
echo ""

TOTAL=$((D_COUNT + P_COUNT + R_COUNT + A_COUNT + G_COUNT))
echo "前5个文件总域名数: ${TOTAL} (不含 pcdn 和 httpdns)"

# ---- 2. 从现有 README 提取昨日数据 ----
extract_count() {
    # 从 README 表格中提取指定文件的旧域名数
    awk -F'|' -v file="$1" 'index($0, file) { gsub(/,/,"",$3); gsub(/ /,"",$3); print $3; exit }' "${README}"
}

OLD_D=$(extract_count "direct-list.txt")
OLD_P=$(extract_count "proxy-list.txt")
OLD_R=$(extract_count "reject-list.txt")
OLD_A=$(extract_count "apple-cn.txt")
OLD_G=$(extract_count "google-cn.txt")
OLD_PC=$(extract_count "pcdn-list.txt")
OLD_H=$(extract_count "httpdns-list.txt")

# 默认值 (首次运行无历史数据)
OLD_D=${OLD_D:-0}; OLD_P=${OLD_P:-0}; OLD_R=${OLD_R:-0}
OLD_A=${OLD_A:-0}; OLD_G=${OLD_G:-0}; OLD_PC=${OLD_PC:-0}; OLD_H=${OLD_H:-0}

# ---- 3. 计算变化量 ----
D_DELTA=$((D_COUNT - OLD_D))
P_DELTA=$((P_COUNT - OLD_P))
R_DELTA=$((R_COUNT - OLD_R))
A_DELTA=$((A_COUNT - OLD_A))
G_DELTA=$((G_COUNT - OLD_G))
PC_DELTA=$((PC_COUNT - OLD_PC))
H_DELTA=$((H_COUNT - OLD_H))

fmt_delta() {
    local d=$1
    if [ "$d" -gt 0 ]; then echo "+${d}"; elif [ "$d" -lt 0 ]; then echo "${d}"; else echo "0"; fi
}

echo ""
echo "=== 相对昨日变化 ==="
echo "direct-list.txt:  $(fmt_delta $D_DELTA)"
echo "proxy-list.txt:   $(fmt_delta $P_DELTA)"
echo "reject-list.txt:  $(fmt_delta $R_DELTA)"
echo "apple-cn.txt:     $(fmt_delta $A_DELTA)"
echo "google-cn.txt:    $(fmt_delta $G_DELTA)"
echo "pcdn-list.txt:    $(fmt_delta $PC_DELTA)"
echo "httpdns-list.txt: $(fmt_delta $H_DELTA)"

# ---- 4. 生成表格并注入 README ----
cat > "${STATS_FILE}" << STATS_EOF
| 文件 | 域名数量 | 变化 |
|------|---------|------|
| direct-list.txt | ${D_COUNT} | $(fmt_delta $D_DELTA) |
| proxy-list.txt | ${P_COUNT} | $(fmt_delta $P_DELTA) |
| reject-list.txt | ${R_COUNT} | $(fmt_delta $R_DELTA) |
| apple-cn.txt | ${A_COUNT} | $(fmt_delta $A_DELTA) |
| google-cn.txt | ${G_COUNT} | $(fmt_delta $G_DELTA) |
| pcdn-list.txt | ${PC_COUNT} | $(fmt_delta $PC_DELTA) |
| httpdns-list.txt | ${H_COUNT} | $(fmt_delta $H_DELTA) |
STATS_EOF

awk '/<!-- DOMAIN-STATS-START -->/ { print; while (getline < "'"${STATS_FILE}"'") print; in_block=1; next }
     /<!-- DOMAIN-STATS-END -->/   { in_block=0 }
     !in_block' "${README}" > "${README}.tmp" && mv "${README}.tmp" "${README}"

rm -f "${STATS_FILE}"
echo ""
echo "README.md 已更新域名统计数据"
echo "=========================================="
