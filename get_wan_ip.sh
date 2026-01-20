#!/bin/sh
#
# WAN 口 IP 查询 CGI API
# 适用环境：ImmortalWrt / OpenWrt 23.x
#
# 功能说明：
# - 查询当前 WAN 口的 IPv4 / IPv6 地址
# - 以 JSON 形式通过 CGI 输出
# - 适合作为局域网内的状态查询 API
#

# ==============================
# HTTP 响应头
# ==============================
# 声明返回 JSON，并禁止任何形式的缓存
echo "Content-Type: application/json"
echo "Cache-Control: no-store"
echo ""

# ==============================
# 通用字段初始化
# ==============================
# 获取毫秒级 Unix 时间戳（兼容 BusyBox）
get_unix_ms() {
  now_s="$(date +%s)"
  uptime_frac="$(cut -d. -f2 /proc/uptime | cut -c1-3)"
  echo "${now_s}${uptime_frac}"
}

QUERIED_AT="$(get_unix_ms)"

# 实际使用到的接口名
IFACE_USED=""

# WAN 口 IPv4 / IPv6 地址
WAN_IPV4=""
WAN_IPV6=""

# 错误类型（仅在失败时返回）
ERROR=""

# 本次查询是否成功
OK=false

# ==============================
# 工具函数：从指定逻辑接口中提取 IP
# ==============================

# 查询指定接口的 IPv4 地址
query_iface_ipv4() {
  ubus call "network.interface.$1" status 2>/dev/null \
    | jsonfilter -e '@["ipv4-address"][0].address' 2>/dev/null
}

# 查询指定接口的 IPv6 地址
query_iface_ipv6() {
  ubus call "network.interface.$1" status 2>/dev/null \
    | jsonfilter -e '@["ipv6-address"][0].address' 2>/dev/null
}

# ==============================
# 1. 优先尝试逻辑接口 wan
# ==============================
WAN_IPV4="$(query_iface_ipv4 wan)"
WAN_IPV6="$(query_iface_ipv6 wan)"
IFACE_USED="wan"

# ==============================
# 2. 如果 wan 无 IP，则回退到 pppoe-wan
# ==============================
if [ -z "$WAN_IPV4" ] && [ -z "$WAN_IPV6" ]; then
  WAN_IPV4="$(query_iface_ipv4 pppoe-wan)"
  WAN_IPV6="$(query_iface_ipv6 pppoe-wan)"
  IFACE_USED="pppoe-wan"
fi

# ==============================
# 3. 判断查询结果状态
# ==============================
# 只要 IPv4 或 IPv6 任意一个存在，即认为成功
if [ -n "$WAN_IPV4" ] || [ -n "$WAN_IPV6" ]; then
  OK=true
else
  OK=false

  # 根据实际使用的接口判断失败原因
  CHECK_IFACE="${IFACE_USED:-wan}"
  IFACE_UP="$(
    ubus call network.interface.$CHECK_IFACE status 2>/dev/null \
    | jsonfilter -e '@.up' 2>/dev/null
  )"

  if [ "$IFACE_UP" = "true" ]; then
    # 接口是 UP 的，但没有分配到 IP
    ERROR="ip_not_assigned"
  elif [ "$IFACE_UP" = "false" ]; then
    # 接口未启用或已断开
    ERROR="wan_down"
  else
    # ubus 调用失败或返回异常
    ERROR="ubus_failed"
  fi
fi

# ==============================
# 4. 输出 JSON 结果
# ==============================
if [ "$OK" = "true" ]; then
  cat <<EOF
{
  "ok": true,
  "interface": "$IFACE_USED",
  "wan_ipv4": ${WAN_IPV4:+\"$WAN_IPV4\"},
  "wan_ipv6": ${WAN_IPV6:+\"$WAN_IPV6\"},
  "queried_at": $QUERIED_AT
}
EOF
else
  cat <<EOF
{
  "ok": false,
  "interface": "$IFACE_USED",
  "wan_ipv4": null,
  "wan_ipv6": null,
  "error": "$ERROR",
  "queried_at": $QUERIED_AT
}
EOF
fi