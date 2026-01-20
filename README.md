# WAN 口 IP 查询 CGI API

适用于 ImmortalWrt / OpenWrt 23.x 的 WAN 口 IP 地址查询脚本，以 JSON 格式输出当前路由器的公网 IP 信息。

## 快速安装

在 OpenWrt 路由器中执行以下命令即可下载或更新脚本：

```bash
wget -O /www/cgi-bin/get_wan_ip.sh https://raw.githubusercontent.com/huangxm168/get-wan-ip/refs/heads/main/get_wan_ip.sh && chmod +x /www/cgi-bin/get_wan_ip.sh
```

该命令会：
- 下载最新版本的脚本到 `/www/cgi-bin/get_wan_ip.sh`
- 自动覆盖旧版本（如果存在）
- 赋予脚本执行权限

## 功能特性

- **双协议栈支持**：同时查询 IPv4 和 IPv6 地址
- **接口故障转移**：优先查询 `wan` 接口，失败时自动回退到 `pppoe-wan` 接口
- **实时数据**：禁用缓存，确保返回最新的 IP 状态
- **精确时间戳**：提供毫秒级查询时间记录
- **多层状态信息**：提供链路状态、地址状态、接口状态等多维度事实层字段
- **语义化状态**：通过 `address_state` 字段清晰表达地址配置情况（双栈 / 仅 IPv4 / 仅 IPv6 / 无地址）

## 系统要求

- ImmortalWrt 或 OpenWrt 23.x 及以上版本
- 依赖工具：`ubus`、`jsonfilter`（通常已预装）

## 使用方法

### 通过浏览器访问

```
http://你的路由器IP/cgi-bin/get_wan_ip.sh
```

### 通过命令行调用

```bash
curl http://192.168.1.1/cgi-bin/get_wan_ip.sh
```

## 返回示例

### 双栈地址正常

```json
{
  "ok": true,
  "interface": "wan",

  "link_state": "up",
  "address_state": "dual",

  "iface_up": true,
  "has_ipv4": true,
  "has_ipv6": true,

  "wan_ipv4": "203.0.113.42",
  "wan_ipv6": "2001:db8::1",

  "queried_at": 1705747200123
}
```

### 仅 IPv4 地址

```json
{
  "ok": true,
  "interface": "pppoe-wan",

  "link_state": "up",
  "address_state": "ipv4",

  "iface_up": true,
  "has_ipv4": true,
  "has_ipv6": false,

  "wan_ipv4": "203.0.113.42",
  "wan_ipv6": null,

  "queried_at": 1705747200456
}
```

### 接口启用但无地址

```json
{
  "ok": true,
  "interface": "wan",

  "link_state": "up",
  "address_state": "none",

  "iface_up": true,
  "has_ipv4": false,
  "has_ipv6": false,

  "wan_ipv4": null,
  "wan_ipv6": null,

  "queried_at": 1705747200789
}
```

### 接口未启用

```json
{
  "ok": true,
  "interface": "wan",

  "link_state": "down",
  "address_state": "none",

  "iface_up": false,
  "has_ipv4": false,
  "has_ipv6": false,

  "wan_ipv4": null,
  "wan_ipv6": null,

  "queried_at": 1705747201012
}
```

### 系统调用失败

```json
{
  "ok": false,
  "error": "ubus_failed",
  "queried_at": 1705747201345
}
```

## 字段说明

### 所有响应共有字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `ok` | boolean | 系统层查询是否成功（仅在 ubus 调用正常时为 true） |
| `queried_at` | number | 毫秒级 Unix 时间戳 |

### 成功响应（`ok: true`）字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `interface` | string | 实际查询的逻辑接口名称（`wan` 或 `pppoe-wan`） |
| `link_state` | string | 链路状态：`up`（已启用）或 `down`（未启用） |
| `address_state` | string | 地址状态：`dual`（双栈）、`ipv4`（仅 IPv4）、`ipv6`（仅 IPv6）、`none`（无地址） |
| `iface_up` | boolean | 接口是否启用（事实层） |
| `has_ipv4` | boolean | 是否存在 IPv4 地址 |
| `has_ipv6` | boolean | 是否存在 IPv6 地址 |
| `wan_ipv4` | string \| null | WAN 口 IPv4 地址，不存在时为 null |
| `wan_ipv6` | string \| null | WAN 口 IPv6 地址，不存在时为 null |

### 失败响应（`ok: false`）字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `error` | string | 错误类型，当前仅有 `ubus_failed`（ubus 调用失败或返回异常） |

## 技术实现

- 使用 `ubus` 查询网络接口状态
- 使用 `jsonfilter` 解析 JSON 数据
- IP 地址格式校验（排除非标准格式和链路本地地址）
- 兼容 BusyBox 环境的毫秒级时间戳获取
- 符合 CGI 规范的 HTTP 响应头设置
