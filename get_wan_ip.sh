#!/bin/sh
#
# WAN 口 IP 查询 CGI API
# 适用环境：ImmortalWrt / OpenWrt 23.x
#

# ==============================
# HTTP 响应头
# ==============================
echo "Content-Type: application/json"
echo "Cache-Control: no-store"
echo ""

# ==============================
# 获取毫秒级 Unix 时间戳（BusyBox 兼容）
# ==============================
get_unix_ms() {
  now_s="$(date +%s)"
  uptime_frac="$(cut -d. -f2 /proc/uptime | cut -c1-3)"
  echo "${now_s}${uptime_frac}"
}

QUERIED_AT="$(get_unix_ms)"

# ==============================
# 通用字段初始化
# ==============================
IFACE_USED=""

WAN_IPV4=""
WAN_IPV6=""

HAS_IPV4=false
HAS_IPV6=false

IFACE_UP=""
LINK_STATE="unknown"
ADDRESS_STATE="none"

OK=true
ERROR=""

# ==============================
# 工具函数：查询接口状态
# ==============================

# 校验 IPv4 地址格式
is_valid_ipv4() {
  echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
}

# 校验 IPv6 地址格式（简化版，排除带作用域标识的地址）
is_valid_ipv6() {
  # 匹配标准 IPv6 格式，排除包含 % 的链路本地地址
  echo "$1" | grep -Eq '^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$' && \
  ! echo "$1" | grep -q '%'
}

# 查询 IPv4 地址
query_iface_ipv4() {
  ubus call "network.interface.$1" status 2>/dev/null \
    | jsonfilter -e '@["ipv4-address"][0].address' 2>/dev/null
}

# 查询 IPv6 地址
query_iface_ipv6() {
  ubus call "network.interface.$1" status 2>/dev/null \
    | jsonfilter -e '@["ipv6-address"][0].address' 2>/dev/null
}

# 查询接口 up 状态
query_iface_up() {
  ubus call "network.interface.$1" status 2>/dev/null \
    | jsonfilter -e '@.up' 2>/dev/null
}

# ==============================
# 1. 优先尝试逻辑接口 wan
# ==============================
WAN_IPV4="$(query_iface_ipv4 wan)"
WAN_IPV6="$(query_iface_ipv6 wan)"
IFACE_UP="$(query_iface_up wan)"
IFACE_USED="wan"

# 校验 IPv4 格式，不符合则清空
if [ -n "$WAN_IPV4" ] && ! is_valid_ipv4 "$WAN_IPV4"; then
  WAN_IPV4=""
fi

# 校验 IPv6 格式，不符合则清空
if [ -n "$WAN_IPV6" ] && ! is_valid_ipv6 "$WAN_IPV6"; then
  WAN_IPV6=""
fi

# ==============================
# 2. 若 wan 无任何 IP，则回退到 pppoe-wan
# ==============================
if [ -z "$WAN_IPV4" ] && [ -z "$WAN_IPV6" ]; then
  WAN_IPV4="$(query_iface_ipv4 pppoe-wan)"
  WAN_IPV6="$(query_iface_ipv6 pppoe-wan)"
  IFACE_UP="$(query_iface_up pppoe-wan)"
  IFACE_USED="pppoe-wan"

  # 校验 IPv4 格式，不符合则清空
  if [ -n "$WAN_IPV4" ] && ! is_valid_ipv4 "$WAN_IPV4"; then
    WAN_IPV4=""
  fi

  # 校验 IPv6 格式，不符合则清空
  if [ -n "$WAN_IPV6" ] && ! is_valid_ipv6 "$WAN_IPV6"; then
    WAN_IPV6=""
  fi
fi

# ==============================
# 3. 系统层校验（决定 ok）
# ==============================
# IFACE_UP 必须是 true / false，否则认为系统失败
if [ "$IFACE_UP" != "true" ] && [ "$IFACE_UP" != "false" ]; then
  OK=false
  ERROR="ubus_failed"
fi

# ==============================
# 4. 事实层判定（仅在 ok=true 时）
# ==============================
if [ "$OK" = "true" ]; then
  # iface_up（系统事实）
  if [ "$IFACE_UP" = "true" ]; then
    IFACE_UP=true
    LINK_STATE="up"
  else
    IFACE_UP=false
    LINK_STATE="down"
  fi

  # has_ipv4 / has_ipv6（事实层）
  if [ -n "$WAN_IPV4" ]; then
    HAS_IPV4=true
  fi

  if [ -n "$WAN_IPV6" ]; then
    HAS_IPV6=true
  fi

  # address_state（业务语义层，严格推导）
  if [ "$HAS_IPV4" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
    ADDRESS_STATE="dual"
  elif [ "$HAS_IPV4" = "true" ]; then
    ADDRESS_STATE="ipv4"
  elif [ "$HAS_IPV6" = "true" ]; then
    ADDRESS_STATE="ipv6"
  else
    ADDRESS_STATE="none"
  fi
fi

# ==============================
# 5. 输出 JSON
# ==============================
if [ "$OK" = "true" ]; then
  cat <<EOF
{
  "ok": true,
  "interface": "$IFACE_USED",

  "link_state": "$LINK_STATE",
  "address_state": "$ADDRESS_STATE",

  "iface_up": $IFACE_UP,
  "has_ipv4": $HAS_IPV4,
  "has_ipv6": $HAS_IPV6,

  "wan_ipv4": $( [ "$HAS_IPV4" = "true" ] && echo "\"$WAN_IPV4\"" || echo "null" ),
  "wan_ipv6": $( [ "$HAS_IPV6" = "true" ] && echo "\"$WAN_IPV6\"" || echo "null" ),

  "queried_at": $QUERIED_AT
}
EOF
else
  cat <<EOF
{
  "ok": false,
  "error": "$ERROR",
  "queried_at": $QUERIED_AT
}
EOF
fi