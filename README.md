# 🚀 Edufwesh Premium Auto-Installer (v4.7.9)

An enterprise-grade, fully automated VPN and Proxy infrastructure deployment script designed exclusively for Ubuntu 24.04 environments. Edufwesh orchestrates a high-performance multiplexed network stack, military-grade anti-abuse firewalls, and a dynamic user-management system featuring ultra-precise minute-level expirations.

## ✨ Core Architecture & Features

### 🛡️ Advanced Network & Protocol Stack
- **Multi-Protocol Core:** Xray (VLESS/VMESS/Trojan), Shadowsocks (SS-2022), OpenVPN (TCP/UDP), WireGuard, Hysteria2, and Dropbear SSH.
- **Port 443 Multiplexing:** Seamlessly routes HTTPS, WebSocket, gRPC, and HTTPUpgrade traffic through a unified HAProxy and Nginx frontend.
- **Enhanced WS-ePro Proxy:** Custom Python WebSocket tunneling supporting OHP and split payloads for maximum bypass capabilities.
- **CDN Bypass Ready:** Integrated payload generation for Cloudflare Worker and AWS CloudFront domain spoofing.
- **SlowDNS & UDP Custom:** Built-in DNSTT implementation and raw UDP tunneling (udp2raw/wstunnel) for restrictive networks.

### 🛑 Military-Grade Security & Anti-Abuse
- **Ultimate AutoKill Daemon:** An aggressive background worker that detects and terminates multi-login abusers instantly across all protocols.
- **DDoS-Deflate Engine:** Actively monitors layer-4 connections and automatically bans IP addresses exceeding the 500-connection limit.
- **Automated Traffic Filtering:** Native `iptables` and UFW rules strictly dropping outbound SPAM (Port 25), RPC exploits, and P2P/BitTorrent tracker strings.

### ⏱️ Next-Gen User Management
- **The Flash Engine:** Bypasses standard Linux limitations to offer precise, minute-level expiration trials for SSH and Xray accounts.
- **Neon Pro UI:** A lightweight, interactive terminal menu (featuring Ocean/Sunset themes) for seamless administration, real-time bandwidth monitoring, and user management.

### 🔄 Secure Private Synchronization
- Features a token-authenticated auto-update engine. The script pulls encrypted updates directly from a private GitHub repository at 3:00 AM daily, ensuring zero-downtime hot-swaps of core system files without exposing your source code.

---

## 🚀 Installation Guide

Ensure you are logged in as `root` on a freshly rebuilt Ubuntu 24.04 server before executing the setup script.

1. Download and execute the installer:
   wget -q -O setup.sh https://raw.githubusercontent.com/Edutechz0/update/main/setup.sh && chmod +x setup.sh && ./setup.sh

2. Hardware ID (HWID) Verification:
   During installation, the script will generate a unique HWID for your VPS. You must register this HWID in your central MongoDB database (via the Master Bot) before the installation will proceed.

3. Owner Authentication:
   If you are the infrastructure owner, enter your Master Password when prompted to unlock the GitHub push-update features in the menu.

---

## ⚙️ Administration
Simply type `menu` in your terminal to launch the Neon Pro dashboard. From here you can add users, manage CDN links, backup your database, and push updates to your client nodes.
