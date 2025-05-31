# 自动更新 SmartDNS 格式域名列表

## 项目简介

这是一个自动更新域名列表的项目，定期从 Loyalsoldier 的 [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) 仓库获取最新的域名分类列表，处理为 SmartDNS 可直接使用的格式。

**数据处理**：

- 移除 `regexp:` 开头的行
- 移除 `full:` 前缀
- 去重排序

## 主要功能

1. **自动定时更新**：每天 UTC 时间 3:00 (北京时间 11:00) 自动执行更新
3. **域名分类处理**：
   - 直连列表 (direct-list)：包含国内[直连域名](https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/direct-list.txt)、[苹果中国域名](https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/apple-cn.txt)、[谷歌中国域名](https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/google-cn.txt)
   - 代理列表 (proxy-list)：需要[代理访问的域名](https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/proxy-list.txt)
   - 屏蔽列表 (reject-list)：需要屏蔽的[广告域名](https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/reject-list.txt)

## 使用说明

### 一、手动获取域名列表

1. 从项目的 Releases 页面下载 `smartdns-domain-lists.zip` 压缩包
2. 解压后得到 `domain-set` 目录，包含三个分类文件：
   - `direct-list.txt` - 直连域名列表
   - `proxy-list.txt` - 代理域名列表
   - `reject-list.txt` - 屏蔽域名列表

### 二、自动获取域名列表

本项目提供一个自动化脚本：[fetch_domain_lists.sh](https://github.com/nrjycyd/smartdns-domain-lists/blob/main/script-update/fetch_domain_lists.sh)

> 主脚本，需要手动使用 `sudo` 命令执行或添加到 cron 作业；
>
> 分配执行权限：
> `sudo chmod +x /usr/local/bin/fetch_domain_lists.sh`

可以自动从预设仓库获取最新域名列表（直连/代理/拒绝三类）

添加脚本执行权限：

```bash
chmod +x ./update_domain_lists.sh
```

运行脚本：

```bash
sudo ./update_domain_lists.sh
```

添加设置每日自动更新：

```bash
0 3 * * * ./update_domain_lists.sh
```

### 三、自定义本地域名分流规则（可选项）

本项目提供一个自动化脚本：
- [query_and_rules_custom.sh](https://github.com/nrjycyd/smartdns-domain-lists/blob/main/script-update/query_and_rules_custom.sh)
- [process_domain_lists.sh](https://github.com/nrjycyd/smartdns-domain-lists/blob/main/script-update/process_domain_lists.sh)

> 从脚本，无需单独手动执行或添加到 cron 作业，由主脚本调配执行；
>
> 分配执行权限：
> `sudo chmod +x /usr/local/bin/query_and_rules_custom.sh`   
> `sudo chmod +x /usr/local/bin/process_domain_lists.sh`

在 `domain-set` 目录创建 `custom-list.txt` 文件，编辑分流模板

```ini
# 给域名自定义分流规则
# direct 直连
# proxy  代理
# reject 拒绝
a123.com,direct
b123.com,proxy
c123.com,reject
```

脚本会自动整理本地三个域名分类文件 direct / proxy / reject ， `custom-list.txt` 文件指定的域名优先级最高，比如 `cdn.jsdelivr.net` 域名原本在 `proxy-list.txt`，设置 `cdn.jsdelivr.net,direct` 规则后，脚本会将域名添加到 `direct-list.txt` ，并同步删除在 `proxy-list.txt` 和 `reject-list.txt` 下的记录。

脚本获取权限、添加自动更新同上。

## 配置 SmartDNS

将下载的域名列表文件配置到 SmartDNS 的相应规则中，例如：

```ini
domain-set -name direct -file /etc/smartdns/domain-set/direct-list.txt
nameserver /domain-set:direct/direct
```

具体配置方法请参考 SmartDNS [官方文档](https://pymumu.github.io/smartdns/config/domain-set/)。
