# WAN 口 IP 查询 CGI API

适用于 ImmortalWrt / OpenWrt 23.x 的 WAN 口 IP 地址查询脚本，以 JSON 格式输出当前路由器的公网 IP 信息。

## 功能特性

- **双协议栈支持**：同时查询 IPv4 和 IPv6 地址
- **接口故障转移**：优先查询 `wan` 接口，失败时自动回退到 `pppoe-wan` 接口
- **实时数据**：禁用缓存，确保返回最新的 IP 状态
- **精确时间戳**：提供毫秒级查询时间记录
- **错误分类**：明确区分不同失败场景（接口未启用、IP 未分配、ubus 调用失败）

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

### 查询成功

```json
{
  "ok": true,
  "interface": "wan",
  "wan_ipv4": "203.0.113.42",
  "wan_ipv6": "2001:db8::1",
  "queried_at": 1705747200123
}
```

### 查询失败 - 接口未启用

```json
{
  "ok": false,
  "interface": "wan",
  "wan_ipv4": null,
  "wan_ipv6": null,
  "error": "wan_down",
  "queried_at": 1705747200456
}
```

### 查询失败 - IP 未分配

```json
{
  "ok": false,
  "interface": "pppoe-wan",
  "wan_ipv4": null,
  "wan_ipv6": null,
  "error": "ip_not_assigned",
  "queried_at": 1705747200789
}
```

## 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `ok` | boolean | 查询是否成功（只要 IPv4 或 IPv6 任意一个存在即为 true） |
| `interface` | string | 实际查询的逻辑接口名称（`wan` 或 `pppoe-wan`） |
| `wan_ipv4` | string \| null | WAN 口 IPv4 地址，不存在时为 null |
| `wan_ipv6` | string \| null | WAN 口 IPv6 地址，不存在时为 null |
| `error` | string | 仅在 `ok: false` 时返回，错误类型见下表 |
| `queried_at` | number | 毫秒级 Unix 时间戳 |

## 错误类型

| 错误代码 | 说明 |
|---------|------|
| `wan_down` | WAN 接口未启用或已断开 |
| `ip_not_assigned` | 接口已启用但未分配到 IP 地址 |
| `ubus_failed` | ubus 调用失败或返回异常 |

## 技术实现

- 使用 `ubus` 查询网络接口状态
- 使用 `jsonfilter` 解析 JSON 数据
- 兼容 BusyBox 环境的毫秒级时间戳获取
- 符合 CGI 规范的 HTTP 响应头设置
