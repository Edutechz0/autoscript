# 🚀 Edufwesh Premium VPN Auto-Installer (v4.0 GOD-TIER)

![Version](https://img.shields.io/badge/Version-4.0%20God--Tier-blueviolet?style=for-the-badge)
![OS](https://img.shields.io/badge/OS-Ubuntu%2020.04%20%7C%2022.04-orange?style=for-the-badge&logo=ubuntu)
![Bash](https://img.shields.io/badge/Language-Bash%20Script-green?style=for-the-badge&logo=gnu-bash)
![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)

The ultimate, all-in-one automated installation script for deploying secure, high-speed, and obfuscated VPN tunneling protocols on your Linux VPS. Built for server administrators, tunneling enthusiasts, and VPN sellers looking for maximum automation and security.

---

## ✨ Core Features

### 🛡️ Next-Gen Protocols & Tunneling
* **Xray Core Options:** VLESS, VMess, Trojan, and Shadowsocks-2022.
* **Advanced Transports:** XTLS-Reality, gRPC, WebSocket (WS), QUIC, and mKCP.
* **UDP Mastery:** Hysteria2 (Next-Gen UDP), UDP Custom, and BadVPN-UDPGW (7100, 7200, 7300).
* **SSH & Legacy Proxies:** Dropbear SSH, OpenSSH, Stunnel4, and WS-ePro (Split-Payload Engine).
* **DNS Tunneling:** SlowDNS (DNSTT) fully integrated and optimized.
* **Traditional VPNs:** OpenVPN (TCP/UDP) & NoobzVPN auto-profile generation.

### ⚙️ System Enhancements
* **True TCP BBRv3:** Congestion control powered by the custom XanMod Linux Kernel.
* **HAProxy & Nginx Multiplexing:** Run multiple protocols seamlessly over Port 443 with Real-IP forwarding.
* **Auto-SSL:** Real Let's Encrypt SSL certificates issued via `Acme.sh` (Standalone mode).
* **Cloudflare WARP Integration:** Outbound geo-routing to bypass streaming restrictions (Netflix, Prime, etc.).
* **Geo-Routing Auto-Updater:** Weekly crons to fetch the latest `geoip.dat` and `geosite.dat`.

### 🤖 Native Telegram Bot Automation
Manage your server directly from Telegram without ever logging into SSH!
* **Free Trial System:** Users can claim 3-Day SSH or V2Ray trials automatically.
* **Force-Join (Must Sub):** Mandates users to join your official Channel/Group before accessing the bot.
* **Admin Controls:** View active users, delete accounts, extend expiries, and check server stats via chat.

### 🔒 Security & Anti-Abuse
* **Smart AutoKill Daemon:** Instantly detects and drops multi-login abusers based on custom device limits.
* **Ghost Cleaner:** Automatically scans and deletes expired users from the database.
* **Anti-Torrent Firewall:** IPTables string-matching to block P2P/BitTorrent traffic and protect your VPS.
* **Automated Backups:** Daily or event-triggered database backups sent securely to your Discord Webhook or Telegram Chat.

---

## 💻 Requirements

To ensure a flawless installation, your server must meet the following requirements:

| Requirement | Details |
| --- | --- |
| **Operating System** | Ubuntu 20.04 LTS or Ubuntu 22.04 LTS (Highly Recommended) |
| **User Privileges** | `root` access required |
| **Domain** | An active domain or subdomain pointing to your VPS IP |
| **Fresh OS** | Do not run on a server with pre-existing web servers (Apache/Nginx) |

---

## 🛠️ Installation Guide

**1. Log in to your Ubuntu VPS as root.**

**2. Run this single command to download and start the installation:**
```bash
apt update && apt install -y wget && wget -q [https://raw.githubusercontent.com/Edutechz0/autoscript/main/setup.sh](https://raw.githubusercontent.com/Edutechz0/autoscript/main/setup.sh) && chmod +x setup.sh && ./setup.sh
```

**3. Follow the on-screen interactive prompts.** You will be asked for:
* Your Hardware ID (HWID) License key.
* Your Domain Name and NameServer (NS) Domain.
* Your Telegram Bot Token & Admin ID.

**4. Reboot the server when prompted.**

---

## 📊 The Master Dashboard

Once the installation is complete and the server has rebooted, type `menu` in your terminal to access the interactive dashboard.

```text
======================================================================
                  𝗘𝗱𝘂𝗳𝘄𝗲𝘀𝗵 𝗩𝗣𝗡 𝗠𝗔𝗡𝗔𝗚𝗘𝗥 v4.0                 
======================================================================
 ✦ PROTOCOL MANAGERS               ✦ SYSTEM & TOOLS 
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [01] SSH Manager                 [07] Domain & SSL Manager
  [02] VMess Manager               [08] Server Settings Hub
  [03] VLess Manager               [09] Check Online Users
  [04] Trojan Manager              [10] OpenVPN & NoobzVPN
  [05] Xray gRPC Manager           [11] Check Services Detail
  [06] Shadowsocks Manager         [00] Exit System
======================================================================
```

---

## ⚠️ Important Notes
* **Licensing System:** This script includes an HWID verification layer connecting to the Edufwesh Koyeb API. To use this exact script out-of-the-box, an active license bound to your machine ID is required.
* **DNS Propagation:** Ensure your domain name is fully propagated to your VPS IP address *before* running the script, otherwise, the Let's Encrypt SSL issuance will fail.

---

## 📞 Contact & Support

For business inquiries, license purchases, or custom script modifications:

* **Telegram:** [@EDUFWESH3](https://t.me/EDUFWESH3)
* **WhatsApp:** +2349169212134

---
*Built with ❤️ for the Tunneling Community.*
