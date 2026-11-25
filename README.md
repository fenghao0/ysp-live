# ysp-live｜央视频直播网关（20261125-TMXK）

基于你提供的 20261124 原始代码升级，保留 Python + Node.js 引擎架构、TS 缓存、按需拉流、后台刷新与 Docker host 网络模式。

## 本次修复重点

- CCTV6 改为优先走 bkliveinfo（BK）线路，避免因未命中高码率设备频道映射而只走不稳定的 JCE 路径。
- 所有卫视频道默认优先 BK；其余频道保留原有线路策略。
- JCE 出现限流、超时、HTTP 错误等普通异常时，不再只识别 `DeadHostError`，而是自动尝试 BK。
- BK 不可用时自动尝试 JCE，保留双线路互相兜底，避免某条线路短时异常就直接黑屏。
- 保留原代码的按需拉流、缓存、并发刷新和高码率设备协议逻辑；不虚构 CCTV6 的高码率 live_id。

## 一键安装 / 更新

在 OpenWrt 或 Linux 终端执行（沿用本仓库原有 `install.sh`，不替换安装脚本）：

```bash
sh -c "$(wget -O- https://raw.githubusercontent.com/tmxk2020/ysp-live/main/install.sh)"
```

## 手动部署

```bash
docker compose up -d --build
```

默认使用 host 网络，监听 `8767` 端口。原有数据目录 `./data` 保留。

## 订阅与诊断

- 全频道订阅：`http://设备IP:8767/all.m3u`
- 健康检查：`http://设备IP:8767/health`
- 实时诊断：`http://设备IP:8767/diag`

## 频道首帧测试

容器构建后，可先单独测试 CCTV6 和几个卫视频道：

```bash
docker exec ysp-live python3 /app/check_v20261125_startup.py --base-url http://127.0.0.1:8767 cctv6 bjws jsws dfws hnws
```

测试全部频道：

```bash
docker exec ysp-live python3 /app/check_v20261125_startup.py --base-url http://127.0.0.1:8767
```

测试脚本使用 FFmpeg 尝试解码首帧。只有实际解码出首帧才算通过；HTTP 返回 200 或拿到 m3u8 不代表一定能播放。

## TMXK 项目与反馈

- 项目仓库：[tmxk2020/ysp-live](https://github.com/tmxk2020/ysp-live)
- 社区：[大亨分享](https://tmxk.pp.ua)
- Telegram 频道：[TMXKの分享](https://t.me/tmxktg)
- 反馈交流：[联系我们](https://tmxk.pp.ua/d/10-lian-xi-wo-men)

## 说明

本次静态检查覆盖 Python 语法、频道映射一致性和双线路故障切换逻辑。实际频道是否可播放仍需在部署网络环境中执行首帧测试；不同线路可能受地区、运营商和上游限流影响。
