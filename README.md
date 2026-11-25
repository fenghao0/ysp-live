# ysp-live｜央视频直播网关

ysp-live 是一款面向电视直播的轻量级直播网关，整合多线路直播资源，为电视、手机及 IPTV 播放客户端提供统一的直播订阅入口。

## 功能特点

- **央视频道与卫视频道**：覆盖央视、各大卫视等多个直播频道。
- **多线路保障**：支持 JCE 与 BK 双线路，线路异常时自动切换，提升频道可用性。
- **高码率播放**：支持高码率设备协议，兼顾清晰度与播放体验。
- **按需拉流**：根据播放需求获取直播流，减少不必要的上游连接。
- **TS 缓存**：提供直播数据缓存，改善播放连续性。
- **快速换台**：优化频道刷新与切换流程，减少等待时间。
- **并发控制**：对高码率线路进行并发管理，合理利用上游资源。
- **统一 M3U 订阅**：通过一个订阅地址获取全频道列表，兼容常见直播播放器。
- **运行状态与诊断**：提供健康状态、频道状态及运行诊断信息，便于了解服务情况。
- **Docker 运行**：支持 Docker 环境及 host 网络模式，适用于 OpenWrt 和常见 Linux 设备。

## 一键部署

在终端（SSH）中运行以下命令，即可通过 Docker 一键安装或更新到 GitHub 最新版本：

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/tmxk2020/ysp-live/main/install.sh)"
```

## 访问入口

| 功能 | 地址 |
|---|---|
| 全频道 M3U 订阅 | `http://设备IP:8767/all.m3u` |
| 健康检查 | `http://设备IP:8767/health` |
| 运行诊断 | `http://设备IP:8767/diag` |

将地址中的“设备IP”替换为运行 ysp-live 的设备局域网 IP。

## 更多内容请关注

- **大亨分享**：[项目主页 / 社区](https://tmxk.pp.ua)
- **Telegram 频道**：[TMXKの分享](https://t.me/tmxktg)
- **项目源码**：[GitHub - tmxk2020/ysp-live](https://github.com/tmxk2020/ysp-live)

## 感谢

- **Gary's Club**：[Telegram 群组](https://t.me/+rgxyQeDLtjcxM2U1)
