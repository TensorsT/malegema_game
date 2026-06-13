# 跨网络联机部署指南（Noray 中继服务器）

本项目的“在线房间”使用 [Noray](https://github.com/foxssake/noray) 做 NAT 打洞 / 中继。
两位玩家即使在**不同网络**、**没有公网 IP**、**不做端口映射**，也能用“房间码”联机：

- 房主点击 **创建在线房间** → 得到一个房间码（OID）。
- 好友点击 **加入在线房间** → 粘贴房间码即可。

原理：双方都主动连接到一台有公网 IP 的 Noray 服务器，由它协调打洞；
打洞失败时自动改走中继转发。**所以你需要一台带公网 IP 的服务器来跑 Noray。**

---

## 一、免费方案：Oracle Cloud Always Free（推荐）

Oracle 云提供“永久免费”的小型云主机（含公网 IPv4），适合跑 Noray。

1. 注册 Oracle Cloud 账号，创建一台 **Always Free** 的 VM 实例（Ubuntu 即可）。
2. 在实例的「VCN 安全列表 / Security List」放行入站端口：
   - TCP `8890`（Noray 控制端口）
   - UDP `8890`（打洞 / 中继）
   - UDP `8809`（远端地址注册端口）
3. SSH 登录后安装 Docker：
   ```bash
   sudo apt update && sudo apt install -y docker.io
   sudo systemctl enable --now docker
   ```
4. 同时放行系统防火墙（如启用了 ufw / firewalld）对应端口。
5. 运行 Noray（二选一）：

   **方式 A：docker compose（推荐）**
   ```bash
   # 把项目里的 docker-compose.noray.yml 上传到服务器，或直接在服务器创建同名文件
   sudo docker compose -f docker-compose.noray.yml up -d
   ```

   **方式 B：docker run**
   ```bash
   sudo docker run -d --name noray --restart unless-stopped \
     -p 8890:8890/tcp \
     -p 8890:8890/udp \
     -p 8809:8809/udp \
     ghcr.io/foxssake/noray:latest
   ```

6. 记下这台机器的**公网 IP**（或给它绑定一个域名）。

7. 快速自检（在服务器上）：
   ```bash
   sudo docker ps | grep noray          # 容器应在运行
   sudo ss -ulnp | grep -E '8890|8809'  # UDP 端口应已监听
   ```

> 也可用任意其他 VPS（搬瓦工、腾讯云轻量、Hetzner 等），步骤相同，
> 关键是有公网 IP 且放行上面三个端口。

---

## 二、在游戏里填写服务器地址

1. 进入「联机对战」大厅 → 点 **联机服务器设置**。
2. 服务器填你的 Noray 公网 IP 或域名，端口默认 `8890`。
3. 保存。该配置会写入 `user://pvp_net.cfg`，下次自动记住。

之后即可使用 **创建在线房间 / 加入在线房间**。

---

## 三、不想自建服务器？

- **局域网联机**：同一 Wi-Fi / 路由器下，用「局域网 · 创建 / 加入房间」即可，无需任何服务器。
- 若以后上线 Steam，可改用 Steam 的中继（SteamMultiplayerPeer），无需自建服务器。

---

## 四、常见问题

- **一直停在“正在连接联机服务器”**：检查服务器地址/端口、云安全组与系统防火墙是否放行 8890(TCP+UDP)、8809(UDP)。
- **能创建房间但对方连不上**：通常是某一方网络对 UDP 限制严格；Noray 会自动回退中继，确认 UDP 8890 已放行。
- **房间码**：就是房主创建房间后显示的那串字符，原样复制给好友即可。

---

## 五、部署后联机自测清单

按顺序做，可快速确认整条链路是否通：

1. **服务器**
   - [ ] `docker ps` 中 `noray` 状态为 `Up`
   - [ ] 云安全组已放行 `8890/tcp`、`8890/udp`、`8809/udp`
   - [ ] 若启用了 ufw：`sudo ufw allow 8890/tcp && sudo ufw allow 8890/udp && sudo ufw allow 8809/udp`

2. **游戏内配置**
   - [ ] 联机大厅 → **联机服务器设置** → 填公网 IP/域名，端口 `8890` → 保存
   - [ ] 状态栏应显示「已保存联机服务器：xxx:8890」

3. **单机冒烟（可选）**
   - [ ] 点 **创建在线房间**，等待面板应出现「房间码：xxxx」
   - [ ] 若一直停在「正在连接联机服务器」，回到第 1 步查端口与地址

4. **跨网络实测（需要两台机器、两个网络）**
   - [ ] 房主：创建在线房间 → 复制房间码
   - [ ] 好友：加入在线房间 → 粘贴房间码 → 连接
   - [ ] 双方进入对战棋盘，能正常选牌/消除

5. **仍失败时**
   - 先在同一局域网用「局域网 · 创建/加入」确认对战逻辑正常
   - 再查 Noray 日志：`sudo docker logs noray --tail 50`
