#!/bin/bash

# =========================================================================================
# EDUFWESH PREMIUM AUTO-INSTALLER (FIXED & OPTIMIZED v4.4)
# =========================================================================================
# Core Features:
# - Neon Pro UI, Xray Sniffing, Anti-Abuse Optimization, DoH/DoT
# - XTLS-Reality, Cloudflare WARP, SS-2022, QUIC, mKCP
# - Hysteria2, AutoKill, Anti-Torrent, Ghost-Clean, Backups
# - Telegram Bot Auto-Installer (Free Trials & Admin Control)
# - Fixed: Xray JSON Corruption & AutoKill Log Read Bugs
# - Fixed: Menu UI Border Alignments & MAC Address HWID Generation
# - Removed: Sing-box & AmneziaWG for maximum stability
# =========================================================================================

# ---------------------------------------------------------
# COLOR DEFINITIONS FOR NEON TERMINAL UI
# ---------------------------------------------------------
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

N_CYAN='\e[38;5;51m'
N_PINK='\e[38;5;198m'
N_PURPLE='\e[38;5;135m'
N_YELLOW='\e[38;5;226m'
N_GREEN='\e[38;5;46m'

clear
echo -e "${N_PURPLE}████████████████████████████████████████████████████████████████████████████████████████${NC}"
echo -e "${N_PURPLE}█${NC} ${N_CYAN}                              EDUFWESH SCRIPT INSTALLER                             ${NC} ${N_PURPLE}█${NC}"
echo -e "${N_PURPLE}████████████████████████████████████████████████████████████████████████████████████████${NC}"
echo ""

# =========================================================================================
# PRE-FLIGHT CHECKS & OS VALIDATION
# =========================================================================================
if [ "${EUID}" -ne 0 ]; then
    echo -e "${RED}[!] CRITICAL ERROR: You must run this script as root.${NC}"
    echo -e "${YELLOW}Please switch to root user by typing 'sudo su' and run the script again.${NC}"
    exit 1
fi

if ! grep -q "Ubuntu" /etc/os-release && ! grep -q "Debian" /etc/os-release; then
    echo -e "${RED}[!] WARNING: This script is heavily optimized for Ubuntu & Debian.${NC}"
    echo -e "${YELLOW}Proceeding on other distributions may result in package manager failures.${NC}"
    sleep 3
fi

# =========================================================================================
# 0. HARDWARE ID & MONGODB LICENSE VERIFICATION (UPGRADED)
# =========================================================================================
mkdir -p /etc/edufwesh
mkdir -p /var/lock

touch /var/lock/edufwesh_db.lock
chmod 666 /var/lock/edufwesh_db.lock

if [ -f /etc/edufwesh/hwid.txt ]; then
    VPS_HWID=$(cat /etc/edufwesh/hwid.txt)
else
    # Grab the machine-id
    SYS_ID=$(cat /etc/machine-id 2>/dev/null)
    
    # Grab the unique MAC address of the server's main network interface
    MAC_ADDR=$(cat /sys/class/net/$(ip route show default | awk '/default/ {print $5}' | head -n 1)/address 2>/dev/null)
    
    # Combine them to create a truly unique fingerprint, even on cloned OS templates
    VPS_HWID=$(echo "${SYS_ID}${MAC_ADDR}" | md5sum | cut -c1-12 | tr 'a-z' 'A-Z')
    
    # Fallback to random if something fails
    if [ -z "$VPS_HWID" ]; then
        VPS_HWID=$(head -c 16 /dev/urandom | md5sum | cut -c1-12 | tr 'a-z' 'A-Z')
    fi
    echo "$VPS_HWID" > /etc/edufwesh/hwid.txt
fi

echo -e "${N_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${N_CYAN}                         ❖ EDUFWESH LICENSE AUTHENTICATION ❖                          ${NC}"
echo -e "${N_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${N_YELLOW}This server requires an active VPN License to proceed.${NC}"
echo -e " ${WHITE}1. Copy your unique VPS Hardware ID below.${NC}"
echo -e " ${WHITE}2. Go to our Telegram Bot and purchase a VPN AutoInstaller License.${NC}"
echo -e " ${WHITE}3. The bot will ask for an HWID. Paste this exact code:${NC}"
echo -e "${N_PINK}----------------------------------------------------------------------------------------${NC}"
echo -e " Your VPS HWID: ${N_GREEN}${VPS_HWID}${NC}"
echo -e "${N_PINK}----------------------------------------------------------------------------------------${NC}"

MONGO_URI="mongodb+srv://edufwesh3_db_user:ntNVgqjLkXZXiOkD@edufweshcluster.uqhzx67.mongodb.net/?appName=EdufweshCluster"
MONGO_DB="EdufweshDB"
MONGO_COL="hwids"

read -p " [?] Press [ENTER] only AFTER you have bound this HWID in the bot... " 

echo -e "${N_YELLOW}[*] Validating License securely with Central MongoDB Database...${NC}"

apt-get update -y >/dev/null 2>&1
apt-get install -y python3-pip >/dev/null 2>&1
python3 -m pip install pymongo --break-system-packages >/dev/null 2>&1 || python3 -m pip install pymongo >/dev/null 2>&1

cat > /tmp/check_db.py << EOF
import sys
import time
from pymongo import MongoClient

uri = "$MONGO_URI"
hwid = "$VPS_HWID"
db_name = "$MONGO_DB"
col_name = "$MONGO_COL"

try:
    client = MongoClient(uri, serverSelectionTimeoutMS=5000)
    db = client[db_name]
    col = db[col_name]
    
    doc = col.find_one({"hwid": hwid, "service": "VPN"})
    
    if not doc:
        print("INVALID")
    else:
        exp = doc.get("exp_timestamp")
        if exp == "LIFETIME":
            print("VALID")
        elif isinstance(exp, (int, float)) and exp > time.time():
            print("VALID")
        else:
            print("EXPIRED")
except Exception as e:
    print("ERROR")
EOF

VERIFY_STATUS=$(python3 /tmp/check_db.py)

if [[ "$VERIFY_STATUS" == "VALID" ]]; then
    echo -e "${N_GREEN}[+] License Validated Successfully! Hardware is authorized.${NC}"
    sleep 2
    clear
elif [[ "$VERIFY_STATUS" == "EXPIRED" ]]; then
    echo -e "${RED}[!] LICENSE AUTHORIZATION FAILED: Your License has EXPIRED!${NC}"
    echo -e "${RED}[!] Please return to the Telegram bot to renew your subscription.${NC}"
    exit 1
else
    echo -e "${RED}[!] LICENSE AUTHORIZATION FAILED: HWID Not Found or Invalid Service!${NC}"
    echo -e "${RED}[!] You must bind the HWID for the VPN service in the bot before continuing.${NC}"
    exit 1
fi

# =========================================================================================
# 0.5. QUICK RESTORE MANAGER (SMART AUTO-DETECT)
# =========================================================================================
echo -e " ${N_YELLOW}[!] Choose Installation Mode:${NC}"
echo -e "  [1] Fresh Install (New Server Setup)"
echo -e "  [2] Quick Restore (Restore Database Backup on existing VPS)"
echo -e "${N_PINK}----------------------------------------------------------------------------------------${NC}"
read -p " Select [1/2] (Default 1): " INSTALL_MODE

if [ "$INSTALL_MODE" == "2" ]; then
    echo -e "${N_YELLOW} Searching for backup file in /root/ directory...${NC}"
    
    bpath=$(ls -t /root/edufwesh-backup-*.tar.gz 2>/dev/null | head -n 1)
    
    if [ -f "$bpath" ]; then
        echo -e "${N_GREEN} Found backup file: $bpath${NC}"
        echo -e "${N_YELLOW} Restoring database and configurations...${NC}"
        
        tar -xzf "$bpath" -C /
        systemctl daemon-reload
        systemctl restart xray dropbear ssh stunnel4 nginx haproxy slowdns noobzvpnd hysteria-server@config openvpn-server@server-udp openvpn-server@server-tcp badvpn-udpgw 2>/dev/null
        
        echo -e "${N_GREEN} Restore completed successfully! All services restarted.${NC}"
        echo -e "${N_YELLOW} Exiting installer. Type 'menu' to open your dashboard.${NC}"
        exit 0
    else
        echo -e "${RED} [!] Backup File not found!${NC}"
        echo -e "${YELLOW} Proceeding with fresh install...${NC}"
        sleep 4
    fi
fi

# =========================================================================================
# GATHERING USER INPUT FOR INSTALLATION
# =========================================================================================
echo ""
echo -e "${N_CYAN} ❖ SERVER DOMAIN CONFIGURATION ❖ ${NC}"
read -p " [?] Enter your main Domain (e.g., vpn.server.com) : " MY_DOMAIN
read -p " [?] Enter your NS Domain (e.g., ns.server.com)    : " MY_NSDOMAIN
read -p " [?] Enter your CloudFront/CDN domain (optional)   : " MY_CDN
echo -e "${N_PINK}----------------------------------------------------------------------------------------${NC}"
echo -e "${N_CYAN} ❖ TELEGRAM BOT INTEGRATION ❖ ${NC}"
echo -e "${N_YELLOW}[Bot Setup] Get token from @BotFather. Get ID from @userinfobot${NC}"
read -p " [?] Enter Telegram Bot Token (Press Enter to skip bot) : " BOT_TOKEN

if [ -n "$BOT_TOKEN" ]; then
    read -p " [?] Enter your Admin Telegram ID (Numbers only)        : " ADMIN_ID
    read -p " [?] Enter Channel Username for Force Join (or SKIP)    : " FORCE_CHANNEL
    read -p " [?] Enter Group Username for Force Join (or SKIP)      : " FORCE_GROUP
fi

# =========================================================================================
# 1. DIRECTORY & DATABASE CREATION
# =========================================================================================
echo -e "${N_CYAN}[+] Creating System Directories and Log Files...${NC}"
mkdir -p /etc/xray
mkdir -p /etc/slowdns
mkdir -p /etc/edufwesh
mkdir -p /etc/udp
mkdir -p /etc/openvpn
mkdir -p /etc/noobz
mkdir -p /etc/hysteria
mkdir -p /var/log/xray
mkdir -p /etc/stunnel
mkdir -p /var/www/html/ovpn

touch /etc/edufwesh/xray-clients.txt
touch /etc/edufwesh/trial_users.txt
touch /etc/edufwesh/user_limits.txt

touch /var/log/xray/access.log
touch /var/log/xray/error.log

chown -R nobody:nogroup /var/log/xray
chmod -R 777 /var/log/xray

echo "$MY_DOMAIN" > /etc/xray/domain
echo "$MY_NSDOMAIN" > /etc/slowdns/nsdomain
if [ -n "$MY_CDN" ]; then
    echo "$MY_CDN" > /etc/edufwesh/cdn_domain
fi

timedatectl set-timezone Africa/Lagos
export DEBIAN_FRONTEND=noninteractive

# =========================================================================================
# 2. SYSTEM UPDATE & TCP TUNING & TOOLS
# =========================================================================================
echo -e "\n${N_CYAN}[+] Freeing up Port 53 & Updating System Packages...${NC}"

systemctl stop systemd-resolved
systemctl disable systemd-resolved >/dev/null 2>&1
killall -9 systemd-resolved >/dev/null 2>&1
fuser -k 53/udp >/dev/null 2>&1
fuser -k 53/tcp >/dev/null 2>&1

rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

echo -e "${N_YELLOW}[*] Downloading necessary packages...${NC}"
apt-get update -y
apt-get upgrade -y
apt-get install -y wget curl nano unzip ufw stunnel4 dropbear iptables nginx haproxy jq python3 python3-pip python3-venv uuid-runtime cron bc vnstat net-tools speedtest-cli openvpn easy-rsa psmisc iptables-persistent lsb-release gnupg tar qrencode fail2ban logrotate socat wireguard-tools

echo -e "${N_CYAN}[+] Checking and Installing XanMod Kernel for True BBRv3...${NC}"
ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
    echo -e "${N_YELLOW}[*] Valid architecture detected for XanMod (x86_64). Proceeding...${NC}"
    wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -yq linux-xanmod-x64v3
    echo -e "${N_GREEN}[+] XanMod installation sequence completed. True BBRv3 will be active on next reboot.${NC}"
else
    echo -e "${RED}[!] Architecture $ARCH is not x86_64. Skipping XanMod kernel installation to prevent system failure.${NC}"
fi

echo -e "${N_CYAN}[+] Installing Cloudflare WARP CLI for Netflix Bypass...${NC}"
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null

apt-get update -y
apt-get install -y cloudflare-warp

warp-cli --accept-tos registration new || true
warp-cli --accept-tos mode proxy || true
warp-cli --accept-tos proxy port 40000 || true
warp-cli --accept-tos connect || true

if ! command -v websocat &>/dev/null; then
    echo -e "${GREEN}[+] Installing websocat binary...${NC}"
    wget -q -O /usr/local/bin/websocat "https://github.com/vi/websocat/releases/download/v1.11.0/websocat.x86_64-unknown-linux-musl"
    chmod +x /usr/local/bin/websocat
fi

echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells

systemctl enable --now vnstat

echo -e "${N_CYAN}[+] Applying Advanced BBRv3 TCP Network Tweaks...${NC}"
cat >> /etc/sysctl.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.ip_forward=1
net.ipv4.tcp_window_scaling=1
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 16384 16777216
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_keepalive_time=1200
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_mtu_probing=1
EOF
sysctl -p > /dev/null 2>&1

# =========================================================================================
# 2.5 SECURITY: FAIL2BAN & LOGROTATE
# =========================================================================================
echo -e "${N_CYAN}[+] Configuring Fail2Ban & LogRotate...${NC}"
cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = 22,109,143
filter = sshd
logpath = /var/log/auth.log
maxretry = 4
bantime = 3600
EOF
systemctl restart fail2ban

cat > /etc/logrotate.d/xray << 'EOF'
/var/log/xray/*.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
    postrotate
        systemctl restart xray > /dev/null 2>&1 || true
    endscript
}
EOF

# =========================================================================================
# 3. FIREWALL SETUP & ANTI-ABUSE BLOCKER
# =========================================================================================
echo -e "${N_CYAN}[+] Configuring Firewall Ports & Anti-Torrent Rules...${NC}"

ufw disable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 109/tcp
ufw allow 143/tcp
ufw allow 443/tcp
ufw allow 447/tcp
ufw allow 777/tcp
ufw allow 1080/tcp
ufw allow 1194/tcp     # OpenVPN TCP
ufw allow 7100/tcp
ufw allow 7200/tcp
ufw allow 7300/tcp
ufw allow 8443/tcp     # XTLS Reality
ufw allow 10007/tcp    # SS-2022
ufw allow 8080/tcp     # NoobzVPN STD
ufw allow 9443/tcp     # NoobzVPN SSL

ufw allow 10007/udp    # SS-2022
ufw allow 10008/udp    # VMess mKCP
ufw allow 10009/udp    # VLESS QUIC
ufw allow 36936/udp    # Hysteria2
ufw allow 53/udp       # SlowDNS
ufw allow 1194/udp     # OpenVPN UDP
ufw allow 7100/udp     # BadVPN
ufw allow 7200/udp     # BadVPN
ufw allow 7300/udp     # BadVPN

ufw --force enable

iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -t nat -I POSTROUTING -s 10.8.0.0/24 -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE
iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
iptables -I FORWARD -d 10.8.0.0/24 -j ACCEPT

iptables -t nat -I POSTROUTING -s 10.9.0.0/24 -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE
iptables -I FORWARD -s 10.9.0.0/24 -j ACCEPT
iptables -I FORWARD -d 10.9.0.0/24 -j ACCEPT

iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP
iptables -A FORWARD -p tcp --dport 6881:6889 -j DROP
iptables -A FORWARD -p udp --dport 6881:6889 -j DROP

netfilter-persistent save

# =========================================================================================
# 4. SSH, DROPBEAR, STUNNEL & ACME.SH SSL
# =========================================================================================
echo -e "${N_CYAN}[+] Configuring SSH & Dropbear...${NC}"

sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart ssh

sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 143"/g' /etc/default/dropbear
systemctl restart dropbear

echo -e "${N_CYAN}[+] Integrating Real Let's Encrypt SSL via Acme.sh...${NC}"

systemctl stop nginx >/dev/null 2>&1
fuser -k 80/tcp >/dev/null 2>&1

mkdir -p /etc/stunnel
mkdir -p /root/.acme.sh

curl -s https://get.acme.sh | sh -s email=admin@${MY_DOMAIN}
source /root/.acme.sh/acme.sh.env

/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt

echo -e "${N_YELLOW}[*] Attempting to issue Let's Encrypt SSL for ${MY_DOMAIN}...${NC}"
if /root/.acme.sh/acme.sh --issue -d ${MY_DOMAIN} --standalone --keylength ec-256 --force; then
    echo -e "${N_GREEN}[+] SSL Issue successful! Installing certificate...${NC}"
    
    /root/.acme.sh/acme.sh --install-cert -d ${MY_DOMAIN} --ecc \
        --fullchain-file /etc/stunnel/stunnel.crt \
        --key-file /etc/stunnel/stunnel.key
        
    cat /etc/stunnel/stunnel.crt /etc/stunnel/stunnel.key > /etc/stunnel/stunnel.pem
    echo -e "${N_GREEN}[+] Valid Let's Encrypt SSL integrated successfully.${NC}"
else
    echo -e "${RED}[!] Let's Encrypt issue failed! This usually means your domain DNS is not fully propagated or port 80 is blocked.${NC}"
    echo -e "${N_YELLOW}[*] Falling back to self-signed SSL to ensure installation completes...${NC}"
    
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=NG/ST=Rivers/L=PH/O=Edufwesh/CN=${MY_DOMAIN}" \
        -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem > /dev/null 2>&1
fi

cat > /etc/stunnel/stunnel.conf << END
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear_ssl_1]
accept = 777
connect = 127.0.0.1:109

[ws_epro_ssl]
accept = 447
connect = 127.0.0.1:8880
END

sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl restart stunnel4
# =========================================================================================
# 5. WS-EPRO (UNIVERSAL DUAL-SUPPORT PERMISSIVE PAYLOAD ENGINE)
# =========================================================================================
echo -e "${N_CYAN}[+] Installing Universal Dual-Support WS-ePro Engine...${NC}"

cat > /usr/local/bin/ws-epro.py << 'END'
import socket
import threading

def handle_client(client_socket):
    try:
        request = client_socket.recv(8192)
        if not request:
            client_socket.close()
            return
            
        req_str = request.decode('utf-8', errors='ignore')
        is_payload = False
        
        if "HTTP/" in req_str or "websocket" in req_str.lower() or "GET " in req_str or "POST " in req_str:
            response = "HTTP/1.1 101 Switching Protocols\r\n"
            response += "Upgrade: websocket\r\n"
            response += "Connection: Upgrade\r\n\r\n"
            client_socket.send(response.encode())
            is_payload = True
            
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect(('127.0.0.1', 109))
        
        if not is_payload:
            ssh_socket.sendall(request)
            
        threading.Thread(target=forward, args=(client_socket, ssh_socket)).start()
        threading.Thread(target=forward, args=(ssh_socket, client_socket)).start()
    except Exception as e:
        client_socket.close()

def forward(src, dst):
    try:
        while True:
            data = src.recv(8192)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        src.close()
        dst.close()

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('0.0.0.0', 8880))
server.listen(100)

while True:
    client, addr = server.accept()
    threading.Thread(target=handle_client, args=(client,)).start()
END

chmod +x /usr/local/bin/ws-epro.py

cat > /etc/systemd/system/ws-epro.service << END
[Unit]
Description=Universal Dual-Support WS-ePro Proxy Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ws-epro.py
Restart=always

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable --now ws-epro

# =========================================================================================
# 6. XRAY CORE (VLESS, VMESS, TROJAN, SS + SOCKS5)
# =========================================================================================
echo -e "${N_CYAN}[+] Installing & Optimizing Xray Core with DoH/DoT...${NC}"

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1

REALITY_KEYS=$(/usr/local/bin/xray x25519)
PRI_KEY=$(echo "$REALITY_KEYS" | grep "Private key" | awk '{print $3}')
PUB_KEY=$(echo "$REALITY_KEYS" | grep "Public key" | awk '{print $3}')
echo "$PRI_KEY" > /etc/xray/reality_pri
echo "$PUB_KEY" > /etc/xray/reality_pub

SS2022_KEY=$(openssl rand -base64 16)
echo "$SS2022_KEY" > /etc/xray/ss2022_key

cat > /usr/local/etc/xray/config.json << END
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "dns": {
    "servers": [
      "https+local://1.1.1.1/dns-query", 
      "tcp+local://8.8.8.8"
    ]
  },
  "inbounds": [
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "port": 10003,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/trojan"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "port": 10004,
      "listen": "127.0.0.1",
      "protocol": "shadowsocks",
      "settings": {
        "clients": [],
        "method": "aes-128-gcm",
        "password": "dummy-password",
        "network": "tcp,udp"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ss"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "port": 10005,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "vless-grpc"
        }
      }
    },
    {
      "port": 10006,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "vmess-grpc"
        }
      }
    },
    {
      "port": 1080,
      "listen": "0.0.0.0",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      }
    },
    {
      "port": 8443,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.microsoft.com:443",
          "xver": 0,
          "serverNames": ["www.microsoft.com"],
          "privateKey": "${PRI_KEY}",
          "shortIds": [""]
        }
      }
    },
    {
      "port": 10007,
      "listen": "0.0.0.0",
      "protocol": "shadowsocks",
      "settings": {
        "clients": [],
        "method": "2022-blake3-aes-128-gcm",
        "password": "${SS2022_KEY}",
        "network": "tcp,udp"
      }
    },
    {
      "port": 10008,
      "listen": "0.0.0.0",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "kcp",
        "kcpSettings": {
          "uplinkCapacity": 100,
          "downlinkCapacity": 100,
          "congestion": true,
          "header": {
            "type": "wechat-video"
          },
          "seed": "edufwesh"
        }
      }
    },
    {
      "port": 10009,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "quic",
        "quicSettings": {
          "security": "none",
          "header": {
            "type": "wechat-video"
          }
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "socks",
      "tag": "warp-out",
      "settings": {
        "servers": [
          {
            "address": "127.0.0.1",
            "port": 40000
          }
        ]
      }
    },
    {
      "protocol": "dns",
      "tag": "dns-out"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "port": 53,
        "network": "udp,tcp",
        "outboundTag": "dns-out"
      },
      {
        "type": "field",
        "domain": [
          "geosite:netflix",
          "geosite:primevideo",
          "domain:dstv.com",
          "domain:showmax.com"
        ],
        "outboundTag": "warp-out"
      },
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }
}
END

systemctl restart xray
systemctl enable xray

# =========================================================================================
# 6.5 HYSTERIA2 (NEXT-GEN UDP PROTOCOL)
# =========================================================================================
echo -e "${N_CYAN}[+] Installing Hysteria2 Next-Gen UDP...${NC}"
bash <(curl -fsSL https://get.hy2.sh/) >/dev/null 2>&1

cat > /etc/hysteria/config.yaml << END
listen: :36936
tls:
  cert: /etc/stunnel/stunnel.pem
  key: /etc/stunnel/stunnel.pem
auth:
  type: password
  password: ${SS2022_KEY}
masquerade:
  type: proxy
  proxy:
    url: https://www.microsoft.com
    rewriteHost: true
END

systemctl enable --now hysteria-server@config >/dev/null 2>&1

# =========================================================================================
# 6.6 AUTOMATED GHOST CLEANER & AUTOKILL DAEMON (FIXED FILE DESCRIPTOR BUGS)
# =========================================================================================
echo -e "${N_CYAN}[+] Installing Automated Ghost Cleanup & AutoKill Engine...${NC}"

cat > /etc/cron.daily/edufwesh-cleaner << 'EOF'
#!/bin/bash
for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    exp=$(chage -l $user | grep "Account expires" | cut -d: -f2 | sed 's/^[ \t]*//')
    if [[ "$exp" != "never" ]]; then
        if [[ $(date +%s) -gt $(date -d "$exp" +%s) ]]; then 
            userdel -r $user >/dev/null 2>&1
        fi
    fi
done

(
flock -n 9 || exit 1
for PROTOCOL in vmess vless trojan shadowsocks; do
    grep "^${PROTOCOL} " /etc/edufwesh/xray-clients.txt | while read p deluser e i; do
        if [[ $(date +%s) -gt $(date -d "$e" +%s) ]]; then 
            if [ "$PROTOCOL" == "vmess" ]; then
                jq "del(.inbounds[1].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[5].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[9].settings.clients[] | select(.email == \"$deluser\"))" /usr/local/etc/xray/config.json > /tmp/xray.json
            elif [ "$PROTOCOL" == "vless" ]; then
                jq "del(.inbounds[0].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[4].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[7].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[10].settings.clients[] | select(.email == \"$deluser\"))" /usr/local/etc/xray/config.json > /tmp/xray.json
            elif [ "$PROTOCOL" == "trojan" ]; then
                jq "del(.inbounds[2].settings.clients[] | select(.email == \"$deluser\"))" /usr/local/etc/xray/config.json > /tmp/xray.json
            elif [ "$PROTOCOL" == "shadowsocks" ]; then
                jq "del(.inbounds[3].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[8].settings.clients[] | select(.email == \"$deluser\"))" /usr/local/etc/xray/config.json > /tmp/xray.json
            fi
            mv /tmp/xray.json /usr/local/etc/xray/config.json
            sed -i "/^${PROTOCOL} ${deluser} /d" /etc/edufwesh/xray-clients.txt
        fi
    done
done
systemctl restart xray
) 9>/var/lock/edufwesh_db.lock
EOF
chmod +x /etc/cron.daily/edufwesh-cleaner

cat > /usr/bin/autokill-daemon << 'EOF'
#!/bin/bash
LIMIT_FILE="/etc/edufwesh/user_limits.txt"
touch $LIMIT_FILE

while true; do
    for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
        LIMIT=$(grep "^${user}:" $LIMIT_FILE | cut -d: -f2)
        if [ -z "$LIMIT" ]; then LIMIT=3; fi
        if [[ "$user" == Trial-* || "$user" == tr_* ]]; then LIMIT=1; fi
        
        COUNT=$(netstat -tnpa | grep ESTABLISHED | grep -E "sshd|dropbear|stunnel4" | grep -w "$user" | wc -l)
        if [ "$COUNT" -gt "$LIMIT" ]; then 
            pkill -u "$user"
        fi
    done
    
    if [ -f "/var/log/xray/access.log" ]; then
        tail -n 500 /var/log/xray/access.log | grep "accepted" | grep "email:" > /tmp/xray_active.log
        
        USERS=$(awk -F"email: " '{print $2}' /tmp/xray_active.log | tr -d ']' | sort | uniq)
        for user in $USERS; do
            if [ -z "$user" ]; then continue; fi
            
            LIMIT=$(grep "^${user}:" $LIMIT_FILE | cut -d: -f2)
            if [ -z "$LIMIT" ]; then LIMIT=3; fi
            if [[ "$user" == Trial-* || "$user" == tr_* ]]; then LIMIT=1; fi
            
            IP_COUNT=$(grep "email: ${user}\]" /tmp/xray_active.log | awk '{print $3}' | cut -d: -f1 | sort | uniq | wc -l)
            
            if [ "$IP_COUNT" -gt "$LIMIT" ]; then
                BAD_IPS=$(grep "email: ${user}\]" /tmp/xray_active.log | awk '{print $3}' | cut -d: -f1 | sort | uniq)
                for ip in $BAD_IPS; do
                    if [[ "$ip" == "127.0.0.1" || "$ip" == "::1" ]]; then continue; fi
                    if ! iptables -C INPUT -s "$ip" -j DROP &>/dev/null; then
                        iptables -I INPUT -s "$ip" -j DROP
                        (sleep 300 && iptables -D INPUT -s "$ip" -j DROP) &
                    fi
                done
                # FIX: Truncate preserves inode file descriptor so Xray keeps logging!
                truncate -s 0 /var/log/xray/access.log
            fi
        done
    fi
    sleep 60
done
EOF
chmod +x /usr/bin/autokill-daemon

cat > /etc/systemd/system/autokill.service << EOF
[Unit]
Description=Edufwesh Advanced AutoKill Daemon
After=network.target

[Service]
ExecStart=/usr/bin/autokill-daemon
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

echo -e "${N_CYAN}[+] Installing Xray Geo-Routing Auto-Updater...${NC}"
mkdir -p /usr/local/share/xray

cat > /etc/cron.weekly/xray-geo-update << 'EOF'
#!/bin/bash
wget -qO /tmp/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
wget -qO /tmp/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat

if [ -f "/tmp/geoip.dat" ] && [ -f "/tmp/geosite.dat" ]; then
    mv /tmp/geoip.dat /usr/local/share/xray/geoip.dat
    mv /tmp/geosite.dat /usr/local/share/xray/geosite.dat
    systemctl restart xray
fi
EOF
chmod +x /etc/cron.weekly/xray-geo-update
/etc/cron.weekly/xray-geo-update &

# =========================================================================================
# 6.7 BOT ADMIN HELPER SCRIPT
# =========================================================================================
cat > /usr/local/bin/vpn-admin << 'EOF'
#!/bin/bash
CMD=$1
USER=$2
DAYS=$3

exec 9>/var/lock/edufwesh_db.lock
flock -n 9 || { echo "Database is locked by another process. Please try again in a few seconds."; exit 1; }

if [ "$CMD" == "list" ]; then
    echo "--- XRAY USERS ---"
    awk '{print $2, "| Exp:", $3}' /etc/edufwesh/xray-clients.txt 2>/dev/null
    echo "--- SSH USERS ---"
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd 2>/dev/null
    
elif [ "$CMD" == "delete" ]; then
    userdel -r "$USER" 2>/dev/null
    if [ -f /usr/local/etc/xray/config.json ]; then
        jq "del(.inbounds[].settings.clients[]? | select(.email == \"$USER\"))" /usr/local/etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /usr/local/etc/xray/config.json
    fi
    sed -i "/ $USER /d" /etc/edufwesh/xray-clients.txt 2>/dev/null
    sed -i "/^${USER}:/d" /etc/edufwesh/user_limits.txt 2>/dev/null
    systemctl restart xray
    echo "Successfully deleted $USER"
    
elif [ "$CMD" == "extend" ]; then
    chage -E $(date -d "$DAYS days" +"%Y-%m-%d") "$USER" 2>/dev/null
    old_exp=$(grep " $USER " /etc/edufwesh/xray-clients.txt | awk '{print $3}')
    if [ -n "$old_exp" ]; then
        new_exp=$(date -d "$old_exp $DAYS days" +"%Y-%m-%d")
        sed -i "s/ ${USER} ${old_exp}/ ${USER} ${new_exp}/g" /etc/edufwesh/xray-clients.txt
        systemctl restart xray
    fi
    echo "Successfully extended $USER by $DAYS days"
fi

flock -u 9
exec 9>&-
EOF
chmod +x /usr/local/bin/vpn-admin

# =========================================================================================
# 6.8 TELEGRAM BOT (FREE TRIAL & ADMIN API)
# =========================================================================================
if [ -n "$BOT_TOKEN" ] && [ -n "$ADMIN_ID" ]; then
    echo -e "${N_CYAN}[+] Installing Telegram Bot System...${NC}"
    
    python3 -m venv /opt/bot-env
    /opt/bot-env/bin/pip install python-telegram-bot==20.7 >/dev/null 2>&1

    cat > /usr/local/bin/edufwesh-bot.py << 'EOF'
import os
import subprocess
import uuid
import json
import time
import fcntl
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes
from telegram.error import BadRequest

BOT_TOKEN = "BOT_TOKEN_PLACEHOLDER"
ADMIN_ID = ADMIN_ID_PLACEHOLDER
FORCE_CHANNEL = "FORCE_CHANNEL_PLACEHOLDER"
FORCE_GROUP = "FORCE_GROUP_PLACEHOLDER"
TRIAL_DB = "/etc/edufwesh/trial_users.txt"
LIMITS_DB = "/etc/edufwesh/user_limits.txt"
LOCK_FILE = "/var/lock/edufwesh_db.lock"

def run_cmd_safely(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode('utf-8').strip()
    except subprocess.CalledProcessError as e:
        return e.output.decode('utf-8').strip()

def has_trial(user_id):
    if not os.path.exists(TRIAL_DB): return False
    with open(TRIAL_DB, 'r') as f:
        for line in f:
            parts = line.strip().split(':')
            if len(parts) >= 2 and parts[0] == str(user_id):
                if time.time() - float(parts[1]) < 15 * 86400:
                    return True
    return False

def mark_trial(user_id):
    with open(LOCK_FILE, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX)
            lines = []
            if os.path.exists(TRIAL_DB):
                with open(TRIAL_DB, 'r') as f:
                    lines = f.readlines()
            with open(TRIAL_DB, 'w') as f:
                for line in lines:
                    if not line.startswith(str(user_id) + ":"):
                        f.write(line)
                f.write(f"{user_id}:{time.time()}\n")
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

def safe_db_write(cmd_script):
    with open(LOCK_FILE, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX)
            return run_cmd_safely(cmd_script)
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

async def check_force_sub(user_id, context):
    if user_id == ADMIN_ID:
        return True
    
    for chat in [FORCE_CHANNEL, FORCE_GROUP]:
        if chat and chat.upper() != "SKIP":
            try:
                member = await context.bot.get_chat_member(chat_id=chat, user_id=user_id)
                if member.status in ['left', 'kicked', 'banned']:
                    return False
            except Exception:
                return False
    return True

async def send_msg(update: Update, text, **kwargs):
    if update.callback_query:
        await update.callback_query.message.reply_text(text, **kwargs)
    else:
        await update.message.reply_text(text, **kwargs)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    
    if not await check_force_sub(user_id, context):
        keyboard = []
        if FORCE_CHANNEL and FORCE_CHANNEL.upper() != "SKIP":
            clean_c = FORCE_CHANNEL.replace('@', '')
            keyboard.append([InlineKeyboardButton("📢 Join Official Channel", url=f"https://t.me/{clean_c}")])
        if FORCE_GROUP and FORCE_GROUP.upper() != "SKIP":
            clean_g = FORCE_GROUP.replace('@', '')
            keyboard.append([InlineKeyboardButton("💬 Join Official Group", url=f"https://t.me/{clean_g}")])
            
        keyboard.append([InlineKeyboardButton("✅ I Have Joined", callback_data="check_join")])
        await send_msg(update, f"❌ *Access Denied!*\n\nYou must join our official channel/group to use this bot. Join now, then click 'I Have Joined'.", parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(keyboard))
        return

    keyboard = [
        [InlineKeyboardButton("🎁 Free 3-Day SSH", callback_data="freessh")],
        [InlineKeyboardButton("🎁 Free 3-Day V2Ray", callback_data="freev2ray")]
    ]
    
    msg = (
        "🟢 *Welcome to Edufwesh VPN Bot!*\n\n"
        "Click a button below to get your free 3-Day Trial:"
    )
    if user_id == ADMIN_ID:
        msg += "\n\n🛠 *Admin Commands:*\n/users - List users\n/delete <user> - Delete user\n/extend <user> <days> - Extend user\n/stats - Server status"
    
    await send_msg(update, msg, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(keyboard))

async def freessh(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if not await check_force_sub(user_id, context):
        await start(update, context)
        return
        
    if has_trial(user_id):
        await send_msg(update, "❌ You have already claimed your free trial limit. Please try again after 15 days or contact an admin to purchase a premium account.")
        return
    
    user = f"tr_{user_id}"[:15]
    password = str(uuid.uuid4())[:8]
    
    bash_script = f"""
    useradd -e $(date -d "3 days" +"%Y-%m-%d") -s /bin/false -M {user}
    echo "{password}\n{password}" | passwd {user}
    sed -i "/^{user}:/d" {LIMITS_DB} 2>/dev/null
    echo "{user}:1" >> {LIMITS_DB}
    """
    safe_db_write(bash_script)
    mark_trial(user_id)
    
    domain = run_cmd_safely("cat /etc/xray/domain 2>/dev/null")
    nsdom = run_cmd_safely("cat /etc/slowdns/nsdomain 2>/dev/null")
    pubkey = run_cmd_safely("cat /etc/slowdns/server.pub 2>/dev/null")
    ipvps = run_cmd_safely("curl -s ipv4.icanhazip.com 2>/dev/null")
    exp_date = run_cmd_safely('date -d "3 days" +"%b %d, %Y"')
    
    qr_text = run_cmd_safely(f"qrencode -t UTF8 '{domain}:80@{user}:{password}'")
    
    msg = (
        f"Username     : {user}\n"
        f"Password     : {password}\n"
        f"Max Login    : 1 Device(s)\n"
        f"Expired On   : {exp_date}\n"
        f"Host         : {domain}\n"
        f"Nameserver   : {nsdom}\n"
        f"PubKey       : {pubkey}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"SSH-80       : {domain}:80@{user}:{password}\n"
        f"SSH-443      : {domain}:443@{user}:{password}\n"
        f"SOCKS5       : {domain}:1080:{user}:{password}\n"
        f"OVPN UDP     : http://{domain}:81/ovpn/client-udp.ovpn\n"
        f"OVPN TCP     : http://{domain}:81/ovpn/client-tcp.ovpn\n"
        f"Hysteria2    : hysteria2://{user}:{password}@{ipvps}:36936\n"
        f"► Terminal QR Code (SSH-WS):\n"
        f"{qr_text}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"(Payload WSS)\n"
        f"GET wss://bug.com [protocol][crlf]Host: {domain}[crlf]Upgrade: websocket[crlf][crlf]\n"
        f"(Payload WS)\n"
        f"GET / HTTP/1.1[crlf]Host: {domain}[crlf]Upgrade: websocket[crlf][crlf]\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    )
    
    final_msg = f"✅ *Free 3-Day SSH Trial Created*\n\n```text\n{msg}\n```"
    await send_msg(update, final_msg, parse_mode="Markdown")

async def freev2ray(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if not await check_force_sub(user_id, context):
        await start(update, context)
        return
        
    if has_trial(user_id):
        await send_msg(update, "❌ You have already claimed your free trial limit. Please try again after 15 days or contact an admin to purchase a premium account.")
        return
    
    user = f"tr_{user_id}"[:15]
    uid = str(uuid.uuid4())
    exp = run_cmd_safely('date -d "3 days" +"%Y-%m-%d"')
    
    bash_script = f"""
    echo "vmess {user} {exp} {uid}" >> /etc/edufwesh/xray-clients.txt
    jq ".inbounds[1].settings.clients += [{{\\"id\\": \\"{uid}\\", \\"alterId\\": 0, \\"email\\": \\"{user}\\"}}] | .inbounds[5].settings.clients += [{{\\"id\\": \\"{uid}\\", \\"alterId\\": 0, \\"email\\": \\"{user}\\"}}] | .inbounds[9].settings.clients += [{{\\"id\\": \\"{uid}\\", \\"alterId\\": 0, \\"email\\": \\"{user}\\"}}]" /usr/local/etc/xray/config.json > /tmp/xray.json && mv /tmp/xray.json /usr/local/etc/xray/config.json
    systemctl restart xray
    sed -i "/^{user}:/d" {LIMITS_DB} 2>/dev/null
    echo "{user}:1" >> {LIMITS_DB}
    """
    safe_db_write(bash_script)
    mark_trial(user_id)
    domain = run_cmd_safely("cat /etc/xray/domain")
    
    vm_json = {"v":"2","ps":user,"add":domain,"port":"443","id":uid,"aid":"0","net":"ws","path":"/vmess","type":"none","host":domain,"tls":"tls","sni":domain}
    b64 = run_cmd_safely(f"echo '{json.dumps(vm_json)}' | base64 -w 0")
    
    msg = (
        f"✅ *Free 3-Day V2Ray (VMess) Trial Created*\n\n"
        f"👤 User: `{user}`\n"
        f"🌐 Host: `{domain}`\n"
        f"🔒 AutoKill: Restricted to 1 Device connection.\n\n"
        f"📥 *Copy Config Link below:*\n\n"
        f"`vmess://{b64}`"
    )
    await send_msg(update, msg, parse_mode="Markdown")

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    if query.data == "check_join" or query.data == "start":
        await start(update, context)
    elif query.data == "freessh":
        await freessh(update, context)
    elif query.data == "freev2ray":
        await freev2ray(update, context)

async def users_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID: return
    res = run_cmd_safely("/usr/local/bin/vpn-admin list")
    await send_msg(update, f"👥 *Active Users:*\n{res}", parse_mode="Markdown")

async def delete_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID: return
    if not context.args:
        await send_msg(update, "Usage: /delete <username>")
        return
    res = run_cmd_safely(f"/usr/local/bin/vpn-admin delete {context.args[0]}")
    await send_msg(update, f"🗑 *Action:* {res}", parse_mode="Markdown")

async def extend_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID: return
    if len(context.args) < 2:
        await send_msg(update, "Usage: /extend <username> <days>")
        return
    res = run_cmd_safely(f"/usr/local/bin/vpn-admin extend {context.args[0]} {context.args[1]}")
    await send_msg(update, f"✅ *Action:* {res}", parse_mode="Markdown")

async def stats_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID: return
    uptime = run_cmd_safely("uptime -p")
    ram = run_cmd_safely("free -m | awk 'NR==2{print $3\"MB / \"$2\"MB\"}'")
    bw = run_cmd_safely("vnstat -d --oneline | awk -F\\; '{print \"Today: \"$4\" | Yesterday: \"$5}'")
    await send_msg(update, f"📊 *Server Stats*\n\n*Uptime:* {uptime}\n*RAM Used:* {ram}\n*Bandwidth:* {bw}", parse_mode="Markdown")

if __name__ == '__main__':
    app = Application.builder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CallbackQueryHandler(button_handler))
    app.add_handler(CommandHandler("users", users_cmd))
    app.add_handler(CommandHandler("delete", delete_cmd))
    app.add_handler(CommandHandler("extend", extend_cmd))
    app.add_handler(CommandHandler("stats", stats_cmd))
    app.run_polling()
EOF

    sed -i "s/BOT_TOKEN_PLACEHOLDER/${BOT_TOKEN}/g" /usr/local/bin/edufwesh-bot.py
    sed -i "s/ADMIN_ID_PLACEHOLDER/${ADMIN_ID}/g" /usr/local/bin/edufwesh-bot.py
    sed -i "s/FORCE_CHANNEL_PLACEHOLDER/${FORCE_CHANNEL}/g" /usr/local/bin/edufwesh-bot.py
    sed -i "s/FORCE_GROUP_PLACEHOLDER/${FORCE_GROUP}/g" /usr/local/bin/edufwesh-bot.py

    cat > /etc/systemd/system/edufwesh-bot.service << 'EOF'
[Unit]
Description=Edufwesh Telegram Management Bot
After=network.target

[Service]
Type=simple
ExecStart=/opt/bot-env/bin/python3 /usr/local/bin/edufwesh-bot.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now edufwesh-bot >/dev/null 2>&1
    
    cat > /usr/local/bin/bot-watchdog.sh << 'EOF'
#!/bin/bash
if ! systemctl is-active --quiet edufwesh-bot; then
    systemctl restart edufwesh-bot
fi
EOF
    chmod +x /usr/local/bin/bot-watchdog.sh
    (crontab -l 2>/dev/null | grep -v "bot-watchdog"; echo "*/5 * * * * /usr/local/bin/bot-watchdog.sh") | crontab -
else
    echo -e "${N_YELLOW}[!] Bot setup skipped. Token or ID not provided.${NC}"
fi

# =========================================================================================
# 7. NGINX & HAPROXY MULTIPLEXER (Real-IP Forwarding Fix)
# =========================================================================================
echo -e "${N_CYAN}[+] Configuring HAProxy & Nginx...${NC}"
rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/conf.d/multiplexer.conf << 'END'
upstream xray_vmess {
    server 127.0.0.1:10002;
}
upstream xray_vless {
    server 127.0.0.1:10001;
}
upstream xray_trojan {
    server 127.0.0.1:10003;
}
upstream xray_ss {
    server 127.0.0.1:10004;
}
upstream ws_epro {
    server 127.0.0.1:8880;
}

server {
    listen 81 default_server;
    server_name _;
    
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    
    location / {
        proxy_pass http://ws_epro;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /ovpn/ {
        alias /var/www/html/ovpn/;
        autoindex on;
    }
}

server {
    listen 444 ssl http2;
    server_name _;
    ssl_certificate /etc/stunnel/stunnel.pem;
    ssl_certificate_key /etc/stunnel/stunnel.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    location / {
        proxy_pass http://ws_epro;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /ovpn/ {
        alias /var/www/html/ovpn/;
        autoindex on;
    }
    
    location /vless {
        proxy_pass http://xray_vless;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    location /vmess {
        proxy_pass http://xray_vmess;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    location /trojan {
        proxy_pass http://xray_trojan;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    location /ss {
        proxy_pass http://xray_ss;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
END

cat > /etc/haproxy/haproxy.cfg << END
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    retries 3
    timeout connect 10000
    timeout client  3600s
    timeout server  3600s

frontend http_front
    bind *:80
    mode tcp
    
    tcp-request inspect-delay 5s
    acl is_v2ray req.payload(0,0) -m sub /vmess
    acl is_v2ray req.payload(0,0) -m sub /vless
    acl is_v2ray req.payload(0,0) -m sub /trojan
    acl is_v2ray req.payload(0,0) -m sub /ss
    acl is_http req.payload(0,0) -m sub GET
    
    use_backend nginx_http if is_v2ray
    use_backend nginx_http if is_http
    
    default_backend ws_epro_direct

frontend https_front
    bind *:443
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }
    use_backend nginx_https

backend ws_epro_direct
    mode tcp
    server wsepro 127.0.0.1:8880 check

backend nginx_https
    mode tcp
    server nginx2 127.0.0.1:444 check

backend nginx_http
    mode tcp
    server nginx1 127.0.0.1:81 check
END

systemctl restart nginx
systemctl enable nginx
systemctl restart haproxy
systemctl enable haproxy

# =========================================================================================
# 8. OPENVPN & NOOBZVPN SETUP (DUAL TCP & UDP CORE)
# =========================================================================================
echo -e "${N_CYAN}[+] Setting up Dual OpenVPN (TCP/UDP) & NoobzVPN Services...${NC}"

export EASYRSA_BATCH=1
mkdir -p /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa

echo -e "${N_YELLOW}[!] Building Certificates (This is automated, please wait)...${NC}"
./easyrsa --batch init-pki > /dev/null 2>&1
./easyrsa --batch build-ca nopass > /dev/null 2>&1
./easyrsa --batch gen-req server nopass > /dev/null 2>&1
./easyrsa --batch sign-req server server > /dev/null 2>&1

echo -e "${N_YELLOW}[!] Generating DH Parameters (Calculating math... This can take 2-5 minutes. DO NOT CLOSE!)...${NC}"
./easyrsa --batch gen-dh > /dev/null 2>&1

./easyrsa --batch build-client-full generic_client nopass > /dev/null 2>&1

if openvpn --genkey --secret /etc/openvpn/ta.key 2>/dev/null; then
    : 
elif openvpn --genkey secret /etc/openvpn/ta.key 2>/dev/null; then
    : 
else
    openssl rand -base64 2048 | tr -d '\n' > /etc/openvpn/ta.key
fi

cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem /etc/openvpn/

PAM_PLUGIN=$(find /usr/lib -name "openvpn-plugin-auth-pam.so" | head -n 1)
if [ -z "$PAM_PLUGIN" ]; then
    PAM_PLUGIN="/usr/lib/openvpn/openvpn-plugin-auth-pam.so"
fi

cat > /etc/openvpn/server-udp.conf << END
port 1194
proto udp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
plugin $PAM_PLUGIN login
verify-client-cert none
username-as-common-name
auth SHA512
tls-auth /etc/openvpn/ta.key 0
topology subnet
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 ipv4"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"
keepalive 10 120
cipher AES-256-GCM
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status-udp.log
verb 3
END

cat > /etc/openvpn/server-tcp.conf << END
port 1194
proto tcp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
plugin $PAM_PLUGIN login
verify-client-cert none
username-as-common-name
auth SHA512
tls-auth /etc/openvpn/ta.key 0
topology subnet
server 10.9.0.0 255.255.255.0
push "redirect-gateway def1 ipv4"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"
keepalive 10 120
cipher AES-256-GCM
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status-tcp.log
verb 3
END

cat > /var/www/html/ovpn/client-udp.ovpn << END
client
dev tun
proto udp
remote $MY_DOMAIN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
auth-user-pass
cipher AES-256-GCM
auth SHA512
verb 3
<ca>
$(cat /etc/openvpn/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/easy-rsa/pki/issued/generic_client.crt)
</cert>
<key>
$(cat /etc/openvpn/easy-rsa/pki/private/generic_client.key)
</key>
key-direction 1
<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
END

cat > /var/www/html/ovpn/client-tcp.ovpn << END
client
dev tun
proto tcp
remote $MY_DOMAIN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
auth-user-pass
cipher AES-256-GCM
auth SHA512
verb 3
<ca>
$(cat /etc/openvpn/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/easy-rsa/pki/issued/generic_client.crt)
</cert>
<key>
$(cat /etc/openvpn/easy-rsa/pki/private/generic_client.key)
</key>
key-direction 1
<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
END

cat > /etc/systemd/system/openvpn-server@.service << END
[Unit]
Description=OpenVPN service
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/openvpn --status /var/log/openvpn-status-%i.log --config /etc/openvpn/%i.conf
Restart=always

[Install]
WantedBy=multi-user.target
END

echo -e "${N_CYAN}[+] Installing NoobzVPN Daemon...${NC}"
wget -q -O /usr/bin/noobzvpnd "https://github.com/noobz-id/noobzvpnd/raw/master/noobzvpnd-x86_64"
chmod +x /usr/bin/noobzvpnd

cat > /etc/noobz/config.json << END
{
    "tcp_std": [8080],
    "tcp_ssl": [9443],
    "cert": "/etc/stunnel/stunnel.pem",
    "key": "/etc/stunnel/stunnel.pem"
}
END

cat > /etc/systemd/system/noobzvpnd.service << END
[Unit]
Description=NoobzVPN Daemon
After=network.target stunnel4.service

[Service]
ExecStart=/usr/bin/noobzvpnd --config /etc/noobz/config.json
Restart=always

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable --now openvpn-server@server-udp.service > /dev/null 2>&1
systemctl enable --now openvpn-server@server-tcp.service > /dev/null 2>&1
(sleep 5 && systemctl enable --now noobzvpnd.service > /dev/null 2>&1) &

# =========================================================================================
# 9. SLOWDNS & BADVPN SETUP
# =========================================================================================
echo -e "${N_CYAN}[+] Configuring SlowDNS & BadVPN...${NC}"

wget -q -O /usr/bin/badvpn-udpgw "https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw64"
chmod +x /usr/bin/badvpn-udpgw

cat > /etc/systemd/system/badvpn-udpgw.service << END
[Unit]
Description=BadVPN UDPGW
After=network.target

[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500
Restart=always

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable --now badvpn-udpgw

ARCH=$(uname -m)
echo -e "${N_CYAN}[+] Detected architecture: $ARCH${NC}"

if [[ "$ARCH" == "x86_64" ]]; then
    BIN_NAME="dnstt-server-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    BIN_NAME="dnstt-server-arm64"
else
    echo -e "${RED}[!] Unsupported architecture: $ARCH. SlowDNS will be skipped.${NC}"
    skip_slowdns=1
fi

if [ -z "$skip_slowdns" ]; then
    echo -e "${GREEN}[+] Downloading dnstt-server...${NC}"
    wget -q --timeout=15 -O /etc/slowdns/dnstt-server "https://raw.githubusercontent.com/Edutechz0/autoscript/main/$BIN_NAME"
    chmod +x /etc/slowdns/dnstt-server
    setcap 'cap_net_bind_service=+ep' /etc/slowdns/dnstt-server 2>/dev/null || true
fi

if [ -z "$skip_slowdns" ] && ( [ ! -s /etc/slowdns/dnstt-server ] || ! /etc/slowdns/dnstt-server -h >/dev/null 2>&1 ); then
    echo -e "${N_YELLOW}[!] Binary from GitHub failed. Trying fallback...${NC}"
    if [[ "$ARCH" == "x86_64" ]]; then
        wget -q -O /etc/slowdns/dnstt-server "https://dnstt.network/dnstt-server-linux-amd64"
    elif [[ "$ARCH" == "aarch64" ]]; then
        wget -q -O /etc/slowdns/dnstt-server "https://dnstt.network/dnstt-server-linux-arm64"
    fi
    chmod +x /etc/slowdns/dnstt-server
    setcap 'cap_net_bind_service=+ep' /etc/slowdns/dnstt-server 2>/dev/null || true
fi

if [ -z "$skip_slowdns" ] && [ -s /etc/slowdns/dnstt-server ] && /etc/slowdns/dnstt-server -h >/dev/null 2>&1; then
    echo -e "${GREEN}[+] dnstt-server binary is ready and working.${NC}"
else
    echo -e "${RED}[!] Failed to obtain a working dnstt-server binary. SlowDNS disabled.${NC}"
    skip_slowdns=1
fi

systemctl stop systemd-resolved
systemctl disable systemd-resolved
systemctl mask systemd-resolved
systemctl stop dnsmasq unbound named 2>/dev/null
systemctl disable dnsmasq unbound named 2>/dev/null
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

if [ -z "$skip_slowdns" ]; then
    echo "7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59" > /etc/slowdns/server.pub
    echo "819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae" > /etc/slowdns/server.key

    cat > /etc/systemd/system/slowdns.service << END
[Unit]
Description=SlowDNS Server
After=network.target
Before=systemd-resolved.service

[Service]
WorkingDirectory=/etc/slowdns
ExecStartPre=/bin/bash -c "systemctl stop systemd-resolved dnsmasq unbound named 2>/dev/null; systemctl disable systemd-resolved dnsmasq unbound named 2>/dev/null"
ExecStartPre=/bin/bash -c "fuser -k 53/udp 53/tcp 2>/dev/null; killall -9 systemd-resolved dnsmasq unbound named 2>/dev/null || true"
ExecStartPre=/bin/bash -c "while ss -lun | grep -q ':53 '; do sleep 1; done"
ExecStart=/etc/slowdns/dnstt-server -udp 0.0.0.0:53 -privkey-file /etc/slowdns/server.key ${MY_NSDOMAIN} 127.0.0.1:8880
Restart=on-failure
RestartSec=10
KillMode=process
LimitNOFILE=65536
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
END

    if [ ! -s /etc/slowdns/server.key ] || [ ! -s /etc/slowdns/server.pub ]; then
        cd /etc/slowdns
        rm -f server.pub server.key
        ./dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub
    fi

    systemctl daemon-reload
    systemctl enable --now slowdns
else
    cat > /etc/systemd/system/slowdns.service << END
[Unit]
Description=SlowDNS (disabled)
After=network.target
[Service]
ExecStart=/bin/true
Restart=no
[Install]
WantedBy=multi-user.target
END
    systemctl daemon-reload
    systemctl enable slowdns
fi

# =========================================================================================
# 9.5 AUTOMATED BACKUP ENGINE (CLEANED)
# =========================================================================================
echo -e "${N_CYAN}[+] Installing Automated Backup Engine...${NC}"
cat > /usr/local/bin/edufwesh-do-backup << 'EOF'
#!/bin/bash
BPATH="/root/edufwesh-backup-$(date +%F).tar.gz"
STAGE_DIR="/tmp/edufwesh_backup_stage"

rm -rf $STAGE_DIR

mkdir -p $STAGE_DIR/etc/xray
mkdir -p $STAGE_DIR/etc/edufwesh
mkdir -p $STAGE_DIR/etc/slowdns

exec 9>/var/lock/edufwesh_db.lock
flock -n 9 || { echo "Database busy, skipping backup iteration..."; exit 1; }

cp /etc/xray/domain $STAGE_DIR/etc/xray/domain 2>/dev/null
cp /etc/xray/config.json $STAGE_DIR/etc/xray/config.json 2>/dev/null
cp /etc/slowdns/nsdomain $STAGE_DIR/etc/slowdns/nsdomain 2>/dev/null
cp /etc/slowdns/server.pub $STAGE_DIR/etc/slowdns/server.pub 2>/dev/null
cp /etc/slowdns/server.key $STAGE_DIR/etc/slowdns/server.key 2>/dev/null

cp /etc/edufwesh/backup_platform $STAGE_DIR/etc/edufwesh/ 2>/dev/null
cp /etc/edufwesh/discord_webhook $STAGE_DIR/etc/edufwesh/ 2>/dev/null
cp /etc/edufwesh/tg_bot_token $STAGE_DIR/etc/edufwesh/ 2>/dev/null
cp /etc/edufwesh/tg_chat_id $STAGE_DIR/etc/edufwesh/ 2>/dev/null
cp /etc/edufwesh/auto_backup_mode $STAGE_DIR/etc/edufwesh/ 2>/dev/null
cp /etc/edufwesh/user_limits.txt $STAGE_DIR/etc/edufwesh/ 2>/dev/null
cp /etc/edufwesh/trial_users.txt $STAGE_DIR/etc/edufwesh/ 2>/dev/null

grep -vE -i "trial|tr_" /etc/edufwesh/xray-clients.txt > $STAGE_DIR/etc/edufwesh/xray-clients.txt 2>/dev/null
awk -F: '!/tr_/ && !/Trial-/ {print $0}' /etc/passwd > $STAGE_DIR/etc/passwd 2>/dev/null
awk -F: '!/tr_/ && !/Trial-/ {print $0}' /etc/shadow > $STAGE_DIR/etc/shadow 2>/dev/null

flock -u 9
exec 9>&-

cd $STAGE_DIR
tar -czf $BPATH ./* 2>/dev/null
cd /

PLATFORM=$(cat /etc/edufwesh/backup_platform 2>/dev/null)
if [ "$PLATFORM" == "discord" ]; then
    WEBHOOK=$(cat /etc/edufwesh/discord_webhook 2>/dev/null)
    if [ -n "$WEBHOOK" ]; then
        curl -s -F "file1=@$BPATH" "$WEBHOOK" > /dev/null
    fi
elif [ "$PLATFORM" == "telegram" ]; then
    BOT_TOKEN=$(cat /etc/edufwesh/tg_bot_token 2>/dev/null)
    CHAT_ID=$(cat /etc/edufwesh/tg_chat_id 2>/dev/null)
    if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
        curl -s -F document=@"$BPATH" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument?chat_id=${CHAT_ID}" > /dev/null
    fi
fi

rm -rf $STAGE_DIR
EOF
chmod +x /usr/local/bin/edufwesh-do-backup
# =========================================================================================
# 10. MASTER DASHBOARD MENU SYSTEM
# =========================================================================================
echo -e "${GREEN}[+] Compiling Master Menu System...${NC}"
cat > /usr/bin/menu << 'END'
#!/bin/bash

# Color Variables
NC='\e[0m'
CYAN='\e[1;36m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'
N_CYAN='\e[38;5;51m'
N_PINK='\e[38;5;198m'
N_PURPLE='\e[38;5;135m'
N_YELLOW='\e[38;5;226m'
N_GREEN='\e[38;5;46m'

LOCK_FILE="/var/lock/edufwesh_db.lock"

# Standardized 85-Character Borders for perfect UI alignment
B_THICK="█████████████████████████████████████████████████████████████████████████████████████"
B_THIN="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

acquire_lock() {
    exec 9>"$LOCK_FILE"
    flock -n 9 || { 
        echo -e "\n${RED}[!] Database is currently locked by the Telegram Bot or another Admin.${NC}"
        echo -e "${YELLOW}Please wait a few seconds and try again.${NC}"
        sleep 2
        exec 9>&-
        return 1
    }
    return 0
}

release_lock() {
    flock -u 9
    exec 9>&-
}

# ----- SERVICE STATUS CHECKER -----
check_run() {
    if systemctl is-active --quiet $1; then
        echo -e "[ ${N_GREEN}ON${NC} ]"
    else
        echo -e "[ ${RED}OFF${NC} ]"
    fi
}

# ----- CHECK ONLINE FUNCTION -----
check_online() {
    clear
    echo -e "${N_PURPLE}${B_THIN}${NC}"
    echo -e "${N_CYAN}                             ONLINE USER MONITOR                             ${NC}"
    echo -e "${N_PURPLE}${B_THIN}${NC}"
    echo -e "${N_YELLOW}>> Active SSH Connections:${NC}"
    netstat -tnpa | grep ESTABLISHED | grep -E "sshd|dropbear|stunnel4" | awk '{print $5, $7}' | cut -d: -f1 | sort | uniq -c | awk '{print "   IP: "$2" (Sessions: "$1")"}'
    
    echo -e ""
    echo -e "${N_YELLOW}>> Active Xray (V2Ray) Connections:${NC}"
    if [ -f "/var/log/xray/access.log" ]; then
        tail -n 100 /var/log/xray/access.log | grep "accepted" | awk '{print $3}' | cut -d: -f1 | sort | uniq -c | awk '{print "   IP: "$2" (Requests: "$1")"}'
    else
        echo -e "   ${RED}Log file empty or not found.${NC}"
    fi

    echo -e "${N_PINK}${B_THIN}${NC}"
    read -n 1 -s -r -p "Press any key to return..."
}

# ----- DOMAIN & SSL TOOLS -----
domain_tools() {
    while true; do
        clear
        DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
        NSDOM=$(cat /etc/slowdns/nsdomain 2>/dev/null)
        
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        echo -e "${N_CYAN}                             DOMAIN & SSL MANAGER                            ${NC}"
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        echo -e " Current Domain : ${WHITE}${DOMAIN}${NC}"
        echo -e " Current NS     : ${WHITE}${NSDOM}${NC}"
        echo -e "${N_PINK}${B_THIN}${NC}"
        echo -e "    [01] ${WHITE}Change VPS Domain (Host)${NC}"
        echo -e "    [02] ${WHITE}Change NameServer (SlowDNS NS)${NC}"
        echo -e "    [03] ${WHITE}Force Renew Let's Encrypt SSL Certificate${NC}"
        echo -e "    [04] ${WHITE}Regenerate All Xray Config Links (new domain)${NC}"
        echo -e "${N_PINK}${B_THIN}${NC}"
        echo -e "    [00] ${RED}Back to Main Menu${NC}"
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        read -p " Select menu : " dt_opt
        
        if [[ "$dt_opt" == "0" || "$dt_opt" == "00" ]]; then
            break
        fi
        
        case $dt_opt in
            1|01) 
                read -p " Enter New Domain: " newdom
                echo "$newdom" > /etc/xray/domain
                sed -i "s/server_name .*/server_name $newdom;/g" /etc/nginx/conf.d/multiplexer.conf
                sed -i "s/.*req_ssl_sni -i .*/    acl is_mydomain req_ssl_sni -i $newdom/g" /etc/haproxy/haproxy.cfg
                systemctl restart nginx haproxy
                echo -e "${N_GREEN} Domain updated successfully to $newdom${NC}"
                sleep 2
                ;;
            2|02)
                read -p " Enter New NS Domain: " newns
                echo "$newns" > /etc/slowdns/nsdomain
                sed -i "s/server.key .*/server.key $newns 127.0.0.1:8880/g" /etc/systemd/system/slowdns.service
                systemctl daemon-reload
                systemctl restart slowdns
                echo -e "${N_GREEN} NS Domain updated successfully to $newns${NC}"
                sleep 2
                ;;
            3|03)
                echo -e "${N_YELLOW} Regenerating Let's Encrypt SSL via Acme.sh...${NC}"
                systemctl stop nginx >/dev/null 2>&1
                /root/.acme.sh/acme.sh --renew -d ${DOMAIN} --force --standalone
                /root/.acme.sh/acme.sh --install-cert -d ${DOMAIN} --ecc \
                    --fullchain-file /etc/stunnel/stunnel.crt \
                    --key-file /etc/stunnel/stunnel.key
                cat /etc/stunnel/stunnel.crt /etc/stunnel/stunnel.key > /etc/stunnel/stunnel.pem
                systemctl restart stunnel4 nginx haproxy
                echo -e "${N_GREEN} Certificate renewed and services restarted!${NC}"
                sleep 2
                ;;
            4|04)
                echo -e "${N_YELLOW} Regenerating config links for all existing Xray users with new domain...${NC}"
                echo -e "${N_GREEN} Note: Users must re-copy their config links from the respective menus.${NC}"
                echo -e "${N_GREEN} All new account creations will use the new domain automatically.${NC}"
                sleep 3
                ;;
            *)
                echo -e "${RED}Invalid Option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# ----- BACKUP MANAGER -----
backup_manager() {
    while true; do
        clear
        PLATFORM=$(cat /etc/edufwesh/backup_platform 2>/dev/null || echo "Not Set")
        AUTO_MODE=$(cat /etc/edufwesh/auto_backup_mode 2>/dev/null || echo "None")
        
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        echo -e "${N_CYAN}                           BACKUP & PLATFORM SETTINGS                        ${NC}"
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        echo -e " Current Platform : ${WHITE}${PLATFORM}${NC}"
        echo -e " Auto Backup Mode : ${WHITE}${AUTO_MODE}${NC}"
        echo -e "${N_PINK}${B_THIN}${NC}"
        echo -e "  [01] ${WHITE}Manual Backup (Send to Platform)${NC}"
        echo -e "  [02] ${WHITE}Automatic Backup Settings${NC}"
        echo -e "  [03] ${WHITE}Platform Settings (Discord/Telegram)${NC}"
        echo -e "  [04] ${WHITE}Restore Backup from File${NC}"
        echo -e "${N_PINK}${B_THIN}${NC}"
        echo -e "  [00] ${RED}Back to Settings Hub${NC}"
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        
        read -p " Select: " b_opt

        case $b_opt in
            1|01)
                if [ "$PLATFORM" == "Not Set" ] || [ -z "$PLATFORM" ]; then
                    echo -e "${RED}Please setup your backup platform settings first! (Option 3)${NC}"
                else
                    echo -e "${N_YELLOW}Generating and sending manual backup...${NC}"
                    /usr/local/bin/edufwesh-do-backup
                    echo -e "${N_GREEN}Backup process sent securely!${NC}"
                fi
                sleep 2
                ;;
            2|02)
                clear
                echo -e "${N_CYAN} ❖ AUTOMATIC BACKUP SETTINGS ${NC}"
                echo -e "  [1] When a new user is added (Excludes Trial)"
                echo -e "  [2] 24hrs backup (Every day)"
                echo -e "  [3] Disable Auto Backup"
                echo -e "${N_PINK}${B_THIN}${NC}"
                
                read -p " Select: " ab_opt
                
                if [ "$ab_opt" == "1" ]; then
                    echo "new_user" > /etc/edufwesh/auto_backup_mode
                    rm -f /etc/cron.d/edufwesh_daily_backup
                    echo -e "${N_GREEN}Auto backup set to trigger on new user additions!${NC}"
                elif [ "$ab_opt" == "2" ]; then
                    echo "24h" > /etc/edufwesh/auto_backup_mode
                    echo "0 0 * * * root /usr/local/bin/edufwesh-do-backup" > /etc/cron.d/edufwesh_daily_backup
                    echo -e "${N_GREEN}Auto backup set to run every 24 hours!${NC}"
                elif [ "$ab_opt" == "3" ]; then
                    echo "none" > /etc/edufwesh/auto_backup_mode
                    rm -f /etc/cron.d/edufwesh_daily_backup
                    echo -e "${N_GREEN}Auto backup disabled!${NC}"
                fi
                sleep 2
                ;;
            3|03)
                while true; do
                    clear
                    echo -e "${N_CYAN} ❖ PLATFORM SETTINGS ${NC}"
                    echo -e "  [1] Platform to receive backup file"
                    echo -e "  [2] Change Platform webhook or Telegram Bot ID/Token"
                    echo -e "${N_PINK}${B_THIN}${NC}"
                    echo -e "  [0] Back"
                    echo -e "${N_PURPLE}${B_THIN}${NC}"
                    
                    read -p " Select: " plat_opt
                    
                    if [ "$plat_opt" == "1" ]; then
                        echo -e "\n  [1] Discord\n  [2] Telegram"
                        read -p " Select Platform: " plat_sel
                        
                        if [ "$plat_sel" == "1" ]; then
                            echo "discord" > /etc/edufwesh/backup_platform
                            read -p " Enter Discord Webhook URL: " d_web
                            echo "$d_web" > /etc/edufwesh/discord_webhook
                            echo -e "${N_GREEN}Discord Platform Configured & Saved!${NC}"
                        elif [ "$plat_sel" == "2" ]; then
                            echo "telegram" > /etc/edufwesh/backup_platform
                            read -p " Enter Telegram Bot Token: " tg_token
                            read -p " Enter Telegram Chat/User ID: " tg_id
                            echo "$tg_token" > /etc/edufwesh/tg_bot_token
                            echo "$tg_id" > /etc/edufwesh/tg_chat_id
                            echo -e "${N_GREEN}Telegram Platform Configured & Saved!${NC}"
                        fi
                        sleep 2
                        
                    elif [ "$plat_opt" == "2" ]; then
                        CUR_PLAT=$(cat /etc/edufwesh/backup_platform 2>/dev/null)
                        
                        if [ "$CUR_PLAT" == "discord" ]; then
                            read -p " Enter NEW Discord Webhook URL: " d_web
                            echo "$d_web" > /etc/edufwesh/discord_webhook
                            echo -e "${N_GREEN}Webhook Updated!${NC}"
                        elif [ "$CUR_PLAT" == "telegram" ]; then
                            read -p " Enter NEW Telegram Bot Token: " tg_token
                            read -p " Enter NEW Telegram Chat/User ID: " tg_id
                            echo "$tg_token" > /etc/edufwesh/tg_bot_token
                            echo "$tg_id" > /etc/edufwesh/tg_chat_id
                            echo -e "${N_GREEN}Telegram Info Updated!${NC}"
                        else
                            echo -e "\n${RED}Platform not set yet. Select Option 1 first.${NC}"
                        fi
                        sleep 2
                        
                    elif [ "$plat_opt" == "0" ]; then
                        break
                    fi
                done
                ;;
            4|04)
                clear
                echo -e "${N_CYAN} ❖ RESTORE DATABASE ${NC}"
                read -p " Enter full path to backup file: " bpath
                
                if [ -f "$bpath" ]; then
                    tar -xzf "$bpath" -C /
                    systemctl restart xray dropbear ssh slowdns
                    echo -e "${N_GREEN} Restore completed! System Settings & Accounts Recovered!${NC}"
                else
                    echo -e "${RED} File not found!${NC}"
                fi
                sleep 2
                ;;
            0|00)
                break
                ;;
        esac
    done
}

# ----- SERVER SETTINGS HUB -----
settings_menu() {
    while true; do
        clear
        DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
        IPVPS=$(curl -s ipv4.icanhazip.com)
        
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        echo -e "${N_CYAN}                             SERVER SETTINGS HUB                             ${NC}"
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        echo -e "  [01] ${WHITE}Speedtest VPS${NC}              [05] ${WHITE}Restart All Services${NC}"
        echo -e "  [02] ${WHITE}Info Ports${NC}                 [06] ${WHITE}Check Bandwidth Usage${NC}"
        echo -e "  [03] ${WHITE}Set Auto Reboot${NC}            [07] ${WHITE}SlowDNS Key Manager${NC}"
        echo -e "  [04] ${WHITE}Server Health Check${NC}        [08] ${WHITE}Install UDP Custom${NC}"
        echo -e "  [09] ${WHITE}Test Xray Connectivity${NC}     [10] ${WHITE}Show Payload Examples${NC}"
        echo -e "  [11] ${WHITE}External TLS Handshake${NC}     [12] ${WHITE}Toggle Auto-Kill Daemon${NC}"
        echo -e "  [13] ${WHITE}Backup, Restore & Platform Settings${NC}"
        echo -e "  [14] ${WHITE}Telegram Bot Status${NC}        [15] ${WHITE}Force Update GeoIP DAT${NC}"
        echo -e "${N_PINK}${B_THIN}${NC}"
        echo -e "  [00] ${RED}Back to Main Dashboard${NC}"
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        
        read -p " Select option : " set_opt

        case $set_opt in
            1|01) 
                clear
                echo -e "${N_CYAN} ❖ SPEEDTEST RESULTS ${NC}"
                speedtest-cli
                echo -e "${N_PINK}${B_THIN}${NC}"
                read -n 1 -s -r -p "Press any key to return..." 
                ;;
            2|02) 
                clear
                echo -e "${N_CYAN} ❖ SYSTEM PORTS & INFO ${NC}"
                echo -e " ${N_YELLOW}>> Service & Port List${NC}"
                echo -e "  - OpenSSH           : 22"
                echo -e "  - Dropbear          : 109, 143"
                echo -e "  - WS-ePro Proxy     : 80, 8880"
                echo -e "  - HAProxy           : 80, 443"
                echo -e "  - Stunnel4          : 447, 777"
                echo -e "  - Xray WS & gRPC    : 443"
                echo -e "  - XTLS-Reality      : 8443 (TCP)"
                echo -e "  - Shadowsocks-2022  : 10007 (TCP/UDP)"
                echo -e "  - VMess mKCP        : 10008 (UDP)"
                echo -e "  - VLESS QUIC        : 10009 (UDP)"
                echo -e "  - Hysteria2         : 36936 (UDP)"
                echo -e "  - OpenVPN TCP/UDP   : 1194"
                echo -e "  - NoobzVPN          : 8080 (STD), 9443 (SSL)"
                echo -e "  - SlowDNS (DNSTT)   : 53"
                echo -e "  - BadVPN UDPGW      : 7100, 7200, 7300"
                echo -e "${N_PINK}${B_THIN}${NC}"
                echo -e " ${N_YELLOW}>> Server Status${NC}"
                echo -e "  - IP Address        : ${WHITE}${IPVPS}${NC}"
                echo -e "  - Domain            : ${WHITE}${DOMAIN}${NC}"
                read -n 1 -s -r -p "Press any key to return..." 
                ;;
            3|03)
                clear
                read -p " Reboot every how many hours? (e.g., 12): " hr
                echo "0 */$hr * * * root /sbin/reboot" > /etc/cron.d/auto_reboot
                echo -e "${N_GREEN} Auto-reboot set to every $hr hours.${NC}"
                sleep 2 
                ;;
            4|04)
                clear
                echo -e "${N_CYAN} ❖ SERVER HEALTH CHECK ${NC}"
                uptime
                echo ""
                free -h
                echo ""
                df -h | grep '^/dev/'
                echo -e "${N_PINK}${B_THIN}${NC}"
                read -n 1 -s -r -p "Press any key to return..." 
                ;;
            5|05)
                clear
                systemctl restart ssh dropbear stunnel4 ws-epro xray nginx haproxy slowdns badvpn-udpgw openvpn-server@server-udp openvpn-server@server-tcp noobzvpnd hysteria-server@config
                if systemctl is-active --quiet edufwesh-bot; then 
                    systemctl restart edufwesh-bot
                fi
                echo -e "${N_GREEN} All Core Services Restarted Successfully!${NC}"
                sleep 2 
                ;;
            6|06)
                clear
                echo -e "${N_CYAN} ❖ BANDWIDTH MONITOR ${NC}"
                vnstat
                echo -e "${N_PINK}${B_THIN}${NC}"
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            7|07)
                clear
                echo -e "${N_CYAN} ❖ SLOWDNS KEY MANAGER ${NC}"
                echo -e "  [1] Switch to Global Key (Edufwesh Default)"
                echo -e "  [2] Generate Fresh Random Key"
                echo -e "${N_PINK}${B_THIN}${NC}"
                read -p " Select : " dns_opt
                
                if [ "$dns_opt" == "1" ]; then
                    echo "7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59" > /etc/slowdns/server.pub
                    echo "819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae" > /etc/slowdns/server.key
                    systemctl restart slowdns
                    echo -e "${N_GREEN} Switched to Global Key successfully!${NC}"
                elif [ "$dns_opt" == "2" ]; then
                    cd /etc/slowdns
                    rm -f server.pub server.key
                    ./dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub
                    systemctl restart slowdns
                    echo -e "${N_GREEN} New Keys Generated successfully!${NC}"
                fi
                sleep 2 
                ;;
            8|08)
                clear
                echo -e "${N_CYAN} ❖ UDP CUSTOM INSTALLER ${NC}"
                echo -e "${N_YELLOW} Downloading UDP Custom binary...${NC}"
                wget -q -O /usr/bin/udp-custom "https://raw.githubusercontent.com/Edutechz0/autoscript/main/udp-custom" 2>/dev/null || echo -e "${RED} UDP Custom Binary not found in repo!${NC}"
                chmod +x /usr/bin/udp-custom 2>/dev/null
                echo -e "${N_GREEN} UDP Setup process completed.${NC}"
                echo -e "${N_PINK}${B_THIN}${NC}"
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            9|09)
                clear
                echo -e "${N_CYAN} ❖ XRAY CONNECTIVITY TEST ${NC}"
                DOMAIN=$(cat /etc/xray/domain)
                
                echo -e " Testing WebSocket paths on port 443 (TLS) via HAProxy/Nginx:"
                echo ""
                for path in vmess vless trojan ss; do
                    echo -n " $path: "
                    curl -sk --http1.1 --max-time 5 -i "https://${DOMAIN}/${path}" \
                        --header "Host: ${DOMAIN}" \
                        --header "Upgrade: websocket" \
                        --header "Connection: Upgrade" \
                        --header "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
                        --header "Sec-WebSocket-Version: 13" 2>/dev/null | head -n1 | cut -d' ' -f2
                done
                
                echo -e "\n${N_YELLOW}Testing Xray directly on localhost (bypassing proxy):${NC}"
                declare -A port_map=( ["vless"]=10001 ["vmess"]=10002 ["trojan"]=10003 ["ss"]=10004 )
                for path in vmess vless trojan ss; do
                    port=${port_map[$path]}
                    echo -n " $path (localhost:$port): "
                    curl -s --http1.1 --max-time 2 -i "http://127.0.0.1:${port}/${path}" \
                        --header "Host: ${DOMAIN}" \
                        --header "Upgrade: websocket" \
                        --header "Connection: Upgrade" \
                        --header "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
                        --header "Sec-WebSocket-Version: 13" 2>/dev/null | head -n1 | cut -d' ' -f2
                done
                
                echo -e "\n${N_PINK}${B_THIN}${NC}"
                echo -e " If direct test returns '101' but external returns '400', the issue is with HAProxy/Nginx."
                echo -e " If both return '400', check Xray error log: tail -f /var/log/xray/error.log"
                echo -e " If direct returns '101' and you have accounts, ensure your domain DNS resolves to this server."
                echo -e ""
                echo -e "${N_YELLOW}Xray local ports status:${NC}"
                for port in 10001 10002 10003 10004 10005 10006; do
                    if ss -tln | grep -q ":$port "; then
                        echo -e "   Port $port: ${N_GREEN}listening${NC}"
                    else
                        echo -e "   Port $port: ${RED}not listening${NC}"
                    fi
                done
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            10)
                clear
                echo -e "${N_CYAN} ❖ PAYLOAD EXAMPLES FOR TUNNEL APPS ${NC}"
                DOMAIN=$(cat /etc/xray/domain)
                CDN=$(cat /etc/edufwesh/cdn_domain 2>/dev/null)
                
                echo -e "${N_YELLOW}► HTTP Injector / Napsternet (VMESS/VLESS/Trojan)${NC}"
                echo -e "  Method: WebSocket"
                echo -e "  Host: ${DOMAIN}"
                echo -e "  Port: 443"
                echo -e "  SNI: ${DOMAIN} (or your CDN domain for bypass)"
                echo -e "  Path: /vmess   (or /vless, /trojan, /ss)"
                echo -e "  TLS: Enable"
                if [ -n "$CDN" ]; then
                    echo -e "  CloudFront/CDN bypass: Use address = ${CDN}, SNI = ${CDN}, Host = ${DOMAIN}"
                fi
                
                echo -e ""
                echo -e "${N_YELLOW}► SSH over WebSocket (using WS-ePro)${NC}"
                echo -e "  Host: ${DOMAIN}"
                echo -e "  Port: 443"
                echo -e "  SNI: ${DOMAIN}"
                echo -e "  Path: / (root)"
                echo -e "  TLS: Enable"
                echo -e "  Username/Password: as created in SSH menu"
                
                echo -e ""
                echo -e "${N_YELLOW}► SlowDNS (DNS tunnel)${NC}"
                echo -e "  DNS Server: ${NSDOM}"
                echo -e "  Public Key: $(cat /etc/slowdns/server.pub 2>/dev/null | head -c 30)..."
                echo -e "${N_PINK}${B_THIN}${NC}"
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            11)
                clear
                echo -e "${N_CYAN} ❖ EXTERNAL TLS HANDSHAKE TEST ${NC}"
                DOMAIN=$(cat /etc/xray/domain)
                echo -e " Testing TLS handshake to ${DOMAIN}:443 ..."
                echo -e ""
                echo -e "${N_YELLOW}Running openssl s_client...${NC}"
                echo -e " (Look for 'CONNECTED' and 'SSL handshake has read')"
                echo -e ""
                timeout 10 openssl s_client -connect ${DOMAIN}:443 -servername ${DOMAIN} -tlsextdebug -brief 2>&1 | head -30
                echo -e "${N_PINK}${B_THIN}${NC}"
                echo -e " If you see 'CONNECTED' and 'SSL handshake has read' then TLS is working."
                echo -e " If you see 'handshake failure' or 'timeout', check:"
                echo -e "   1. Domain DNS resolution: dig ${DOMAIN}"
                echo -e "   2. Firewall: ufw status"
                echo -e "   3. Nginx error logs: tail -f /var/log/nginx/error.log"
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            12)
                clear
                echo -e "${N_CYAN} ❖ MULTI-LOGIN AUTOKILL MANAGER ${NC}"
                if systemctl is-active --quiet autokill; then
                    echo -e "${N_YELLOW} AutoKill is currently: ${N_GREEN}RUNNING${NC}"
                    read -p " Do you want to stop it? (y/n): " act
                    if [[ "$act" == "y" ]]; then 
                        systemctl stop autokill
                        echo -e "${N_GREEN} AutoKill stopped!${NC}"
                    fi
                else
                    echo -e "${N_YELLOW} AutoKill is currently: ${RED}STOPPED${NC}"
                    read -p " Do you want to start it? (y/n): " act
                    if [[ "$act" == "y" ]]; then 
                        systemctl start autokill
                        echo -e "${N_GREEN} AutoKill started!${NC}"
                    fi
                fi
                sleep 2
                ;;
            13)
                backup_manager
                ;;
            14)
                clear
                echo -e "${N_CYAN} ❖ TELEGRAM BOT STATUS ${NC}"
                if systemctl is-active --quiet edufwesh-bot; then
                    echo -e "${N_GREEN} Bot is ACTIVE and RUNNING!${NC}"
                    echo -e "${N_YELLOW} Users can send /start to your bot to claim free trials.${NC}"
                else
                    echo -e "${RED} Bot is currently OFFLINE or NOT INSTALLED.${NC}"
                    echo -e " You must provide your Bot Token and Admin ID during installation."
                fi
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            15)
                clear
                echo -e "${N_YELLOW} Force Updating GeoIP and GeoSite Data...${NC}"
                /etc/cron.weekly/xray-geo-update
                echo -e "${N_GREEN} Streaming Bypass Rules Updated!${NC}"
                sleep 2
                ;;
            0|00) 
                break 
                ;;
        esac
    done
}

# ----- XRAY MANAGER FUNCTION -----
xray_menu() {
    PROTOCOL=$1
    while true; do
        DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
        CDN=$(cat /etc/edufwesh/cdn_domain 2>/dev/null)
        IPVPS=$(curl -s ipv4.icanhazip.com)
        clear
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        echo -e "${N_CYAN}                          XRAY ${PROTOCOL^^} MANAGER                             ${NC}"
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        echo -e "    [01] ${WHITE}Create ${PROTOCOL^^} Account${NC}"
        echo -e "    [02] ${WHITE}Create Trial Account${NC}"
        echo -e "    [03] ${WHITE}Extend ${PROTOCOL^^} Account${NC}"
        echo -e "    [04] ${WHITE}Delete ${PROTOCOL^^} Account${NC}"
        echo -e "    [05] ${WHITE}Check User Login${NC}"
        echo -e "    [06] ${WHITE}List ${PROTOCOL^^} Members${NC}"
        echo -e "    [07] ${WHITE}Clean Expired Users (Manual)${NC}"
        echo -e "${N_PINK}${B_THIN}${NC}"
        echo -e "    [00] ${RED}Back to Main Menu${NC}"
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        
        read -p " Select : " x_opt
        
        if [[ "$x_opt" == "0" || "$x_opt" == "00" ]]; then
            break
        fi
        
        if [[ "$x_opt" == "1" || "$x_opt" == "01" || "$x_opt" == "2" || "$x_opt" == "02" ]]; then
            clear
            echo -e "${N_CYAN} ❖ CREATE PREMIUM XRAY ${PROTOCOL^^} USER ❖ ${NC}"
            echo -e "${N_PINK}${B_THIN}${NC}"
            read -p " Username: " user
            
            if [[ "$x_opt" == "2" || "$x_opt" == "02" ]]; then
                days=1
                user="Trial-$user"
                limit=1
            else
                read -p " Days Active: " days
                read -p " Max Connections (Multi-login limit): " limit
                if [ -z "$limit" ]; then limit=3; fi
            fi
            
            acquire_lock || continue
            
            sed -i "/^${user}:/d" /etc/edufwesh/user_limits.txt 2>/dev/null
            echo "${user}:${limit}" >> /etc/edufwesh/user_limits.txt
            
            UUID=$(uuidgen)
            EXP_DATE=$(date -d "$days days" +"%Y-%m-%d")
            
            echo "${PROTOCOL} ${user} ${EXP_DATE} ${UUID}" >> /etc/edufwesh/xray-clients.txt
            
            if [ "$PROTOCOL" == "vmess" ]; then
                jq ".inbounds[1].settings.clients += [{\"id\": \"${UUID}\", \"alterId\": 0, \"email\": \"${user}\"}] | .inbounds[5].settings.clients += [{\"id\": \"${UUID}\", \"alterId\": 0, \"email\": \"${user}\"}] | .inbounds[9].settings.clients += [{\"id\": \"${UUID}\", \"alterId\": 0, \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
            elif [ "$PROTOCOL" == "vless" ]; then
                jq ".inbounds[0].settings.clients += [{\"id\": \"${UUID}\", \"email\": \"${user}\"}] | .inbounds[4].settings.clients += [{\"id\": \"${UUID}\", \"email\": \"${user}\"}] | .inbounds[7].settings.clients += [{\"id\": \"${UUID}\", \"flow\": \"xtls-rprx-vision\", \"email\": \"${user}\"}] | .inbounds[10].settings.clients += [{\"id\": \"${UUID}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
            elif [ "$PROTOCOL" == "trojan" ]; then
                jq ".inbounds[2].settings.clients += [{\"password\": \"${user}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
            elif [ "$PROTOCOL" == "shadowsocks" ]; then
                SS2022_PASS=$(echo -n "$UUID" | md5sum | head -c 16 | base64)
                jq ".inbounds[3].settings.clients += [{\"password\": \"${UUID}\", \"method\": \"aes-128-gcm\", \"email\": \"${user}\"}] | .inbounds[8].settings.clients += [{\"password\": \"${SS2022_PASS}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
            fi
            
            mv /tmp/xray.json /usr/local/etc/xray/config.json
            systemctl restart xray
            
            release_lock
            
            if [[ "$x_opt" == "1" || "$x_opt" == "01" ]]; then
                AUTO_MODE=$(cat /etc/edufwesh/auto_backup_mode 2>/dev/null)
                if [ "$AUTO_MODE" == "new_user" ]; then
                    /usr/local/bin/edufwesh-do-backup &
                fi
            fi
            
            clear
            echo -e "${N_PURPLE}${B_THIN}${NC}"
            echo -e "${N_CYAN}                     XRAY ${PROTOCOL^^} ACCOUNT CREATED                     ${NC}"
            echo -e "${N_PURPLE}${B_THIN}${NC}"
            echo -e "Remarks        : ${WHITE}${user}${NC}"
            echo -e "Domain         : ${WHITE}${DOMAIN}${NC}"
            if [ -n "$CDN" ]; then
                echo -e "Wildcard       : ${WHITE}(${CDN}).${DOMAIN}${NC}"
            fi
            echo -e "Port TLS       : ${WHITE}443${NC}"
            echo -e "Port none TLS  : ${WHITE}80${NC}"
            echo -e "Port gRPC      : ${WHITE}443${NC}"
            
            if [ "$PROTOCOL" == "vmess" ]; then
                echo -e "id             : ${WHITE}${UUID}${NC}"
                echo -e "alterId        : ${WHITE}0${NC}"
                echo -e "Security       : ${WHITE}auto${NC}"
                echo -e "Network        : ${WHITE}ws, grpc, mKCP${NC}"
                echo -e "Path           : ${WHITE}/vmess${NC}"
                echo -e "ServiceName    : ${WHITE}vmess-grpc${NC}"
            elif [ "$PROTOCOL" == "vless" ]; then
                echo -e "id             : ${WHITE}${UUID}${NC}"
                echo -e "encryption     : ${WHITE}none${NC}"
                echo -e "Network        : ${WHITE}ws, grpc, tcp (Reality), quic${NC}"
                echo -e "Path           : ${WHITE}/vless (WS), vless-grpc (gRPC)${NC}"
            elif [ "$PROTOCOL" == "trojan" ]; then
                echo -e "Password       : ${WHITE}${user}${NC}"
                echo -e "Network        : ${WHITE}ws${NC}"
                echo -e "Path           : ${WHITE}/trojan${NC}"
            elif [ "$PROTOCOL" == "shadowsocks" ]; then
                echo -e "Password       : ${WHITE}${UUID}${NC}"
                echo -e "Method         : ${WHITE}aes-128-gcm, 2022-blake3-aes-128-gcm${NC}"
                echo -e "Network        : ${WHITE}ws, tcp/udp${NC}"
                echo -e "Path           : ${WHITE}/ss${NC}"
            fi
            echo -e "${N_PINK}${B_THIN}${NC}"
            echo -e "Max Login      : ${WHITE}${limit} Device(s)${NC}"
            echo -e "Expired On     : ${RED}${EXP_DATE}${NC}"
            echo -e "${N_PURPLE}${B_THIN}${NC}"
            
            if [ "$PROTOCOL" == "vmess" ]; then
                VM_TLS=$(cat <<EOF | base64 -w 0
{"v":"2","ps":"${user}","add":"${DOMAIN}","port":"443","id":"${UUID}","aid":"0","net":"ws","path":"/vmess","type":"none","host":"${DOMAIN}","tls":"tls","sni":"${DOMAIN}"}
EOF
)
                VM_NTLS=$(cat <<EOF | base64 -w 0
{"v":"2","ps":"${user}","add":"${DOMAIN}","port":"80","id":"${UUID}","aid":"0","net":"ws","path":"/vmess","type":"none","host":"${DOMAIN}","tls":"none"}
EOF
)
                VM_GRPC=$(cat <<EOF | base64 -w 0
{"v":"2","ps":"${user}","add":"${DOMAIN}","port":"443","id":"${UUID}","aid":"0","net":"grpc","path":"vmess-grpc","type":"none","host":"${DOMAIN}","tls":"tls","sni":"${DOMAIN}"}
EOF
)
                VM_KCP=$(cat <<EOF | base64 -w 0
{"v":"2","ps":"${user} (mKCP)","add":"${IPVPS}","port":"10008","id":"${UUID}","aid":"0","net":"kcp","type":"wechat-video","tls":"none"}
EOF
)
                echo -e "Link TLS       : ${WHITE}vmess://${VM_TLS}${NC}"
                echo -e "Link none TLS  : ${WHITE}vmess://${VM_NTLS}${NC}"
                echo -e "Link gRPC      : ${WHITE}vmess://${VM_GRPC}${NC}"
                echo -e "Link UDP mKCP  : ${WHITE}vmess://${VM_KCP}${NC}"
                if [ -n "$CDN" ]; then
                    VM_CDN=$(cat <<EOF | base64 -w 0
{"v":"2","ps":"${user} (CDN)","add":"${CDN}","port":"443","id":"${UUID}","aid":"0","net":"ws","path":"/vmess","type":"none","host":"${DOMAIN}","tls":"tls","sni":"${CDN}"}
EOF
)
                    echo -e "Link CloudFront: ${WHITE}vmess://${VM_CDN}${NC}"
                fi
                echo -e "\n${N_YELLOW}► Terminal QR Code (TLS):${NC}"
                qrencode -t ANSIUTF8 "vmess://${VM_TLS}"
                
            elif [ "$PROTOCOL" == "vless" ]; then
                REALITY_PUB=$(cat /etc/xray/reality_pub 2>/dev/null)
                VL_TLS="vless://${UUID}@${DOMAIN}:443?path=%2Fvless&security=tls&encryption=none&type=ws&host=${DOMAIN}&sni=${DOMAIN}#${user}"
                echo -e "Link TLS       : ${WHITE}${VL_TLS}${NC}"
                echo -e "Link none TLS  : ${WHITE}vless://${UUID}@${DOMAIN}:80?path=%2Fvless&security=none&encryption=none&type=ws&host=${DOMAIN}#${user}${NC}"
                echo -e "Link gRPC      : ${WHITE}vless://${UUID}@${DOMAIN}:443?security=tls&encryption=none&type=grpc&serviceName=vless-grpc&host=${DOMAIN}&sni=${DOMAIN}#${user}${NC}"
                echo -e "Link REALITY   : ${WHITE}vless://${UUID}@${IPVPS}:8443?security=reality&encryption=none&pbk=${REALITY_PUB}&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.microsoft.com#${user}-Reality${NC}"
                echo -e "Link UDP QUIC  : ${WHITE}vless://${UUID}@${IPVPS}:10009?security=none&encryption=none&headerType=wechat-video&quicSecurity=none&type=quic#${user}-QUIC${NC}"
                if [ -n "$CDN" ]; then
                    echo -e "Link CloudFront: ${WHITE}vless://${UUID}@${CDN}:443?path=%2Fvless&security=tls&encryption=none&type=ws&sni=${CDN}&host=${DOMAIN}#${user}${NC}"
                fi
                echo -e "\n${N_YELLOW}► Terminal QR Code (TLS):${NC}"
                qrencode -t ANSIUTF8 "${VL_TLS}"
                
            elif [ "$PROTOCOL" == "trojan" ]; then
                TR_TLS="trojan://${user}@${DOMAIN}:443?path=%2Ftrojan&security=tls&type=ws&host=${DOMAIN}&sni=${DOMAIN}#${user}"
                echo -e "Link TLS       : ${WHITE}${TR_TLS}${NC}"
                echo -e "Link none TLS  : ${WHITE}trojan://${user}@${DOMAIN}:80?path=%2Ftrojan&security=none&type=ws&host=${DOMAIN}#${user}${NC}"
                if [ -n "$CDN" ]; then
                    echo -e "Link CloudFront: ${WHITE}trojan://${user}@${CDN}:443?path=%2Ftrojan&security=tls&type=ws&sni=${CDN}&host=${DOMAIN}#${user}${NC}"
                fi
                echo -e "\n${N_YELLOW}► Terminal QR Code (TLS):${NC}"
                qrencode -t ANSIUTF8 "${TR_TLS}"
                
            elif [ "$PROTOCOL" == "shadowsocks" ]; then
                SS_BASE=$(echo -n "aes-128-gcm:${UUID}" | base64 -w 0)
                SS2022_KEY=$(cat /etc/xray/ss2022_key 2>/dev/null)
                SS2022_PASS=$(echo -n "$UUID" | md5sum | head -c 16 | base64)
                SS2022_BASE=$(echo -n "2022-blake3-aes-128-gcm:${SS2022_KEY}:${SS2022_PASS}" | base64 -w 0)
                echo -e "Link TLS       : ${WHITE}ss://${SS_BASE}@${DOMAIN}:443?path=%2Fss&security=tls&type=ws&host=${DOMAIN}&sni=${DOMAIN}#${user}${NC}"
                echo -e "Link SS-2022   : ${WHITE}ss://${SS2022_BASE}@${IPVPS}:10007#${user}-SS2022${NC}"
                if [ -n "$CDN" ]; then
                    echo -e "Link CloudFront: ${WHITE}ss://${SS_BASE}@${CDN}:443?path=%2Fss&security=tls&type=ws&sni=${CDN}&host=${DOMAIN}#${user}${NC}"
                fi
                echo -e "\n${N_YELLOW}► Terminal QR Code (TLS):${NC}"
                qrencode -t ANSIUTF8 "ss://${SS_BASE}@${DOMAIN}:443?path=%2Fss&security=tls&type=ws&host=${DOMAIN}&sni=${DOMAIN}#${user}"
            fi
            
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$x_opt" == "3" || "$x_opt" == "03" ]]; then
            clear
            echo -e "${N_CYAN} ❖ EXTEND ${PROTOCOL^^} USER ${NC}"
            read -p " Username to extend: " extuser
            read -p " Add Days: " extdays
            
            acquire_lock || continue
            
            if grep -q "^${PROTOCOL} ${extuser} " /etc/edufwesh/xray-clients.txt; then
                old_exp=$(grep "^${PROTOCOL} ${extuser} " /etc/edufwesh/xray-clients.txt | awk '{print $3}')
                new_exp=$(date -d "$old_exp $extdays days" +"%Y-%m-%d")
                sed -i "s/^${PROTOCOL} ${extuser} ${old_exp}/${PROTOCOL} ${extuser} ${new_exp}/g" /etc/edufwesh/xray-clients.txt
                echo -e " ${N_GREEN}User ${extuser} successfully extended to ${new_exp}!${NC}"
            else
                echo -e " ${RED}User not found in database!${NC}"
            fi
            release_lock
            
            echo -e "${N_PINK}${B_THIN}${NC}"
            read -n 1 -s -r -p "Press any key to return..."

        elif [[ "$x_opt" == "4" || "$x_opt" == "04" ]]; then
            clear
            echo -e "${N_CYAN} ❖ DELETE XRAY ${PROTOCOL^^} USER ${NC}"
            read -p " Username to delete: " deluser
            
            acquire_lock || continue
            
            if [ "$PROTOCOL" == "vmess" ]; then
                jq "del(.inbounds[1].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[5].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[9].settings.clients[] | select(.email == \"$deluser\"))" /usr/local/etc/xray/config.json > /tmp/xray.json
            elif [ "$PROTOCOL" == "vless" ]; then
                jq "del(.inbounds[0].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[4].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[7].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[10].settings.clients[] | select(.email == \"$deluser\"))" /usr/local/etc/xray/config.json > /tmp/xray.json
            elif [ "$PROTOCOL" == "trojan" ]; then
                jq "del(.inbounds[2].settings.clients[] | select(.email == \"$deluser\"))" /usr/local/etc/xray/config.json > /tmp/xray.json
            elif [ "$PROTOCOL" == "shadowsocks" ]; then
                jq "del(.inbounds[3].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[8].settings.clients[] | select(.email == \"$deluser\"))" /usr/local/etc/xray/config.json > /tmp/xray.json
            fi
            
            mv /tmp/xray.json /usr/local/etc/xray/config.json
            sed -i "/^${PROTOCOL} ${deluser} /d" /etc/edufwesh/xray-clients.txt
            sed -i "/^${deluser}:/d" /etc/edufwesh/user_limits.txt 2>/dev/null
            systemctl restart xray
            
            release_lock
            
            echo -e " ${N_GREEN}User ${deluser} successfully deleted!${NC}"
            echo -e "${N_PINK}${B_THIN}${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$x_opt" == "5" || "$x_opt" == "05" ]]; then
            check_online
            
        elif [[ "$x_opt" == "6" || "$x_opt" == "06" ]]; then
            clear
            echo -e "${N_CYAN} ❖ ${PROTOCOL^^} USER LIST ${NC}"
            echo -e "${N_PINK}${B_THIN}${NC}"
            echo -e "  USERNAME        EXP DATE        STATUS"
            echo -e "${N_PINK}${B_THIN}${NC}"
            
            if [ -f "/etc/edufwesh/xray-clients.txt" ]; then
                grep "^${PROTOCOL} " /etc/edufwesh/xray-clients.txt | while read p u e i; do
                    if [[ $(date +%s) -gt $(date -d "$e" +%s) ]]; then 
                        stat="${RED}Expired${NC}"
                    else 
                        stat="${N_GREEN}Active${NC}"
                    fi
                    printf "  %-15s %-15s %b\n" "$u" "$e" "$stat"
                done
            else
                echo -e "  ${N_YELLOW}No users found in database.${NC}"
            fi
            
            echo -e "${N_PURPLE}${B_THIN}${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$x_opt" == "7" || "$x_opt" == "07" ]]; then
            clear
            echo -e "${N_CYAN} ❖ CLEAN EXPIRED USERS ${NC}"
            echo -e "${N_YELLOW} Scanning database for expired ${PROTOCOL^^} users...${NC}"
            
            acquire_lock || continue
            
            grep "^${PROTOCOL} " /etc/edufwesh/xray-clients.txt | while read p deluser e i; do
                if [[ $(date +%s) -gt $(date -d "$e" +%s) ]]; then 
                    if [ "$PROTOCOL" == "vmess" ]; then
                        jq "del(.inbounds[1].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[5].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[9].settings.clients[] | select(.email == \"$deluser\"))" /usr/local/etc/xray/config.json > /tmp/xray.json
                    elif [ "$PROTOCOL" == "vless" ]; then
                        jq "del(.inbounds[0].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[4].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[7].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[10].settings.clients[] | select(.email == \"$deluser\"))" /usr/local/etc/xray/config.json > /tmp/xray.json
                    elif [ "$PROTOCOL" == "trojan" ]; then
                        jq "del(.inbounds[2].settings.clients[] | select(.email == \"$deluser\"))" /usr/local/etc/xray/config.json > /tmp/xray.json
                    elif [ "$PROTOCOL" == "shadowsocks" ]; then
                        jq "del(.inbounds[3].settings.clients[] | select(.email == \"$deluser\")) | del(.inbounds[8].settings.clients[] | select(.email == \"$deluser\"))" /usr/local/etc/xray/config.json > /tmp/xray.json
                    fi
                    mv /tmp/xray.json /usr/local/etc/xray/config.json
                    sed -i "/^${PROTOCOL} ${deluser} /d" /etc/edufwesh/xray-clients.txt
                    sed -i "/^${deluser}:/d" /etc/edufwesh/user_limits.txt 2>/dev/null
                    echo -e " ${RED}Deleted Expired User: ${deluser}${NC}"
                fi
            done
            
            systemctl restart xray
            release_lock
            
            echo -e " ${N_GREEN}Cleanup Complete!${NC}"
            echo -e "${N_PINK}${B_THIN}${NC}"
            read -n 1 -s -r -p "Press any key to return..."
        fi
    done
}

# ----- SSH MENU FUNCTION -----
ssh_menu() {
    while true; do
        clear
        DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
        NSDOM=$(cat /etc/slowdns/nsdomain 2>/dev/null)
        PUBKEY=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "Key Not Found")
        IPVPS=$(curl -s ipv4.icanhazip.com)
        
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        echo -e "${N_CYAN}                                SSH/WS MANAGER                               ${NC}"
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        echo -e "    [01] ${WHITE}Create SSH Account${NC}"
        echo -e "    [02] ${WHITE}Create Trial Account${NC}"
        echo -e "    [03] ${WHITE}Extend SSH Account${NC}"
        echo -e "    [04] ${WHITE}Delete SSH Account${NC}"
        echo -e "    [05] ${WHITE}Check User Login${NC}"
        echo -e "    [06] ${WHITE}List SSH Members${NC}"
        echo -e "    [07] ${WHITE}Clean Expired Users${NC}"
        echo -e "${N_PINK}${B_THIN}${NC}"
        echo -e "    [00] ${RED}Back to Main Menu${NC}"
        echo -e "${N_PURPLE}${B_THIN}${NC}"
        
        read -p " Select : " s_opt
        
        if [[ "$s_opt" == "0" || "$s_opt" == "00" ]]; then
            break
        fi
        
        if [[ "$s_opt" == "1" || "$s_opt" == "01" || "$s_opt" == "2" || "$s_opt" == "02" ]]; then
            clear
            
            echo -e "${N_CYAN} ❖ CREATE PREMIUM SSH USER ❖ ${NC}"
            echo -e "${N_PINK}${B_THIN}${NC}"
            
            read -p " Username    : " user
            read -p " Password    : " pass
            
            if [[ "$s_opt" == "2" || "$s_opt" == "02" ]]; then
                days=1
                user="Trial-$user"
                limit=1
            else
                read -p " Days Active : " days
                read -p " Max Connections (Multi-login limit): " limit
                if [ -z "$limit" ]; then limit=3; fi
            fi
            
            acquire_lock || continue
            
            sed -i "/^${user}:/d" /etc/edufwesh/user_limits.txt 2>/dev/null
            echo "${user}:${limit}" >> /etc/edufwesh/user_limits.txt
            
            useradd -e $(date -d "$days days" +"%Y-%m-%d") -s /bin/false -M $user
            echo -e "$pass\n$pass" | passwd $user >/dev/null 2>&1
            EXP_DATE=$(date -d "$days days" +"%b %d, %Y")
            
            release_lock
            
            if [[ "$s_opt" == "1" || "$s_opt" == "01" ]]; then
                AUTO_MODE=$(cat /etc/edufwesh/auto_backup_mode 2>/dev/null)
                if [ "$AUTO_MODE" == "new_user" ]; then
                    /usr/local/bin/edufwesh-do-backup &
                fi
            fi
            
            clear
            echo -e "${N_PURPLE}${B_THIN}${NC}"
            echo -e "                           ${N_YELLOW}PREMIUM SSH WS ACCOUNT${NC}                        "
            echo -e "${N_PURPLE}${B_THIN}${NC}"
            echo -e "Username     : ${WHITE}$user${NC}"
            echo -e "Password     : ${WHITE}$pass${NC}"
            echo -e "Max Login    : ${WHITE}${limit} Device(s)${NC}"
            echo -e "Expired On   : ${RED}${EXP_DATE}${NC}"
            echo -e "Host         : ${WHITE}${DOMAIN}${NC}"
            echo -e "Nameserver   : ${WHITE}${NSDOM}${NC}"
            echo -e "PubKey       : ${WHITE}${PUBKEY}${NC}"
            echo -e "${N_PINK}${B_THIN}${NC}"
            echo -e "SSH-80       : ${WHITE}${DOMAIN}:80@${user}:${pass}${NC}"
            echo -e "SSH-443      : ${WHITE}${DOMAIN}:443@${user}:${pass}${NC}"
            echo -e "SOCKS5       : ${WHITE}${DOMAIN}:1080:${user}:${pass}${NC}"
            echo -e "OVPN UDP     : ${WHITE}http://${DOMAIN}:81/ovpn/client-udp.ovpn${NC}"
            echo -e "OVPN TCP     : ${WHITE}http://${DOMAIN}:81/ovpn/client-tcp.ovpn${NC}"
            echo -e "Hysteria2    : ${WHITE}hysteria2://${user}:${pass}@${IPVPS}:36936${NC}"
            echo -e "\n${N_YELLOW}► Terminal QR Code (SSH-WS):${NC}"
            qrencode -t ANSIUTF8 "${DOMAIN}:80@${user}:${pass}"
            echo -e "${N_PINK}${B_THIN}${NC}"
            echo -e "(Payload WSS)"
            echo -e "${WHITE}GET wss://bug.com [protocol][crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
            echo -e "(Payload WS)"
            echo -e "${WHITE}GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
            echo -e "${N_PURPLE}${B_THIN}${NC}"
            read -n 1 -s -r -p "Press any key to back on menu..."
            
        elif [[ "$s_opt" == "3" || "$s_opt" == "03" ]]; then
            clear
            echo -e "${N_CYAN} ❖ EXTEND SSH USER ${NC}"
            read -p " Username to extend: " extuser
            read -p " Add Days: " extdays
            
            acquire_lock || continue
            
            if id "$extuser" &>/dev/null; then
                chage -E $(date -d "$extdays days" +"%Y-%m-%d") $extuser
                echo -e " ${N_GREEN}User ${extuser} extended successfully!${NC}"
            else
                echo -e " ${RED}User does not exist in system!${NC}"
            fi
            
            release_lock
            echo -e "${N_PINK}${B_THIN}${NC}"
            read -n 1 -s -r -p "Press any key to return..."

        elif [[ "$s_opt" == "4" || "$s_opt" == "04" ]]; then
            clear
            echo -e "${N_CYAN} ❖ DELETE SSH USER ${NC}"
            read -p " Username to delete: " deluser
            
            acquire_lock || continue
            
            userdel -r $deluser >/dev/null 2>&1
            sed -i "/^${deluser}:/d" /etc/edufwesh/user_limits.txt 2>/dev/null
            echo -e " ${N_GREEN}User ${deluser} successfully deleted!${NC}"
            
            release_lock
            echo -e "${N_PINK}${B_THIN}${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$s_opt" == "5" || "$s_opt" == "05" ]]; then
            check_online
            
        elif [[ "$s_opt" == "6" || "$s_opt" == "06" ]]; then
            clear
            echo -e "${N_CYAN} ❖ SSH USER LIST ${NC}"
            echo -e "${N_PINK}${B_THIN}${NC}"
            echo -e "  USERNAME        EXP DATE        STATUS"
            echo -e "${N_PINK}${B_THIN}${NC}"
            
            for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
                exp=$(chage -l $user | grep "Account expires" | cut -d: -f2 | sed 's/^[ \t]*//')
                if [[ "$exp" != "never" ]]; then
                    if [[ $(date +%s) -gt $(date -d "$exp" +%s) ]]; then 
                        stat="${RED}Expired${NC}"
                    else 
                        stat="${N_GREEN}Active${NC}"
                    fi
                    printf "  %-15s %-15s %b\n" "$user" "$exp" "$stat"
                fi
            done
            
            echo -e "${N_PURPLE}${B_THIN}${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$s_opt" == "7" || "$s_opt" == "07" ]]; then
            clear
            echo -e "${N_CYAN} ❖ CLEAN EXPIRED SSH USERS ${NC}"
            echo -e "${N_YELLOW} Scanning system for expired users...${NC}"
            
            acquire_lock || continue
            
            for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
                exp=$(chage -l $user | grep "Account expires" | cut -d: -f2 | sed 's/^[ \t]*//')
                if [[ "$exp" != "never" ]]; then
                    if [[ $(date +%s) -gt $(date -d "$exp" +%s) ]]; then 
                        userdel -r $user >/dev/null 2>&1
                        sed -i "/^${user}:/d" /etc/edufwesh/user_limits.txt 2>/dev/null
                        echo -e " ${RED}Deleted Expired User: ${user}${NC}"
                    fi
                fi
            done
            
            release_lock
            
            echo -e " ${N_GREEN}Cleanup Complete!${NC}"
            echo -e "${N_PINK}${B_THIN}${NC}"
            read -n 1 -s -r -p "Press any key to return..."
        fi
    done
}

# =========================================================================================
# 11. MASTER DASHBOARD MENU SYSTEM (RENDER ENGINE)
# =========================================================================================
while true; do
    DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
    NSDOM=$(cat /etc/slowdns/nsdomain 2>/dev/null)
    IPVPS=$(curl -s ipv4.icanhazip.com)
    OS_INFO=$(cat /etc/os-release | grep -w PRETTY_NAME | cut -d= -f2 | tr -d '"')
    UPTIME=$(uptime -p | cut -d " " -f 2-)
    DATETIME=$(date "+%d-%m-%Y | %H:%M:%S")
    RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
    RAM_USED=$(free -m | awk 'NR==2{print $3}')
    IFACE=$(ip route | grep default | awk '{print $5}')
    BW_TODAY=$(vnstat -i $IFACE -d --oneline | awk -F\; '{print $4}' | sed 's/ //g' 2>/dev/null || echo "0 MiB")
    BW_YEST=$(vnstat -i $IFACE -d --oneline | awk -F\; '{print $5}' | sed 's/ //g' 2>/dev/null || echo "0 MiB")
    BW_MONTH=$(vnstat -i $IFACE -m --oneline | awk -F\; '{print $11}' | sed 's/ //g' 2>/dev/null || echo "0 MiB")
    
    SSH_C=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)
    VLS_C=$(jq '.inbounds[0].settings.clients | length' /usr/local/etc/xray/config.json 2>/dev/null || echo "0")
    VMS_C=$(jq '.inbounds[1].settings.clients | length' /usr/local/etc/xray/config.json 2>/dev/null || echo "0")
    TRJ_C=$(jq '.inbounds[2].settings.clients | length' /usr/local/etc/xray/config.json 2>/dev/null || echo "0")
    SS_C=$(jq '.inbounds[3].settings.clients | length' /usr/local/etc/xray/config.json 2>/dev/null || echo "0")

    clear
    echo -e "${N_PURPLE}${B_THICK}${NC}"
    echo -e "${N_PURPLE}█${NC} ${N_CYAN}                           𝗘𝗱𝘂𝗳𝘄𝗲𝘀𝗵 𝗩𝗣𝗡 𝗠𝗔𝗡𝗔𝗚𝗘𝗥 v4.4                         ${NC} ${N_PURPLE}█${NC}"
    echo -e "${N_PURPLE}█${NC} ${N_PINK}                   Telegram: @EDUFWESH3 | WA: +2349169212134                 ${NC} ${N_PURPLE}█${NC}"
    echo -e "${N_PURPLE}${B_THICK}${NC}"
    echo -e ""
    echo -e "${N_CYAN} ❖ SYSTEM INFORMATION ${NC}"
    echo -e "${N_PINK}${B_THIN}${NC}"
    printf "  ${WHITE}%-15s${NC} : %-20s ${WHITE}%-10s${NC} : %-20s\n" "OS" "${OS_INFO:0:20}" "Uptime" "$UPTIME"
    printf "  ${WHITE}%-15s${NC} : %-20s ${WHITE}%-10s${NC} : %-20s\n" "Domain" "${DOMAIN:0:20}" "IP VPS" "$IPVPS"
    printf "  ${WHITE}%-15s${NC} : %-20s ${WHITE}%-10s${NC} : %-20s\n" "NS Domain" "${NSDOM:0:20}" "RAM Usage" "${RAM_USED}MB / ${RAM_TOTAL}MB"
    echo -e ""
    echo -e "${N_CYAN} ❖ BANDWIDTH USAGE ${NC}"
    echo -e "${N_PINK}${B_THIN}${NC}"
    printf "  ${WHITE}%-15s${NC} : %-15s ${WHITE}%-15s${NC} : %-15s\n" "Today Usage" "$BW_TODAY" "Yesterday Usage" "$BW_YEST"
    printf "  ${WHITE}%-15s${NC} : %-15s\n" "Monthly Usage" "$BW_MONTH"
    echo -e ""
    echo -e "${N_CYAN} ❖ PROTOCOL ACCOUNTS ${NC}"
    echo -e "${N_PINK}${B_THIN}${NC}"
    printf "  ${N_GREEN}%-10s %-10s %-10s %-10s %-10s${NC}\n" "SSH" "VMESS" "VLESS" "TROJAN" "SS"
    printf "  ${WHITE}%-10s %-10s %-10s %-10s %-10s${NC}\n" "$SSH_C" "$VMS_C" "$VLS_C" "$TRJ_C" "$SS_C"
    echo -e ""
    echo -e "${N_CYAN} ❖ SERVICES STATUS ${NC}"
    echo -e "${N_PINK}${B_THIN}${NC}"
    printf "  ${WHITE}%-10s${NC}: %-15b ${WHITE}%-10s${NC}: %-15b ${WHITE}%-10s${NC}: %-15b\n" "SSH" "$(check_run ssh)" "NGINX" "$(check_run nginx)" "XRAY" "$(check_run xray)"
    printf "  ${WHITE}%-10s${NC}: %-15b ${WHITE}%-10s${NC}: %-15b ${WHITE}%-10s${NC}: %-15b\n" "DROPBEAR" "$(check_run dropbear)" "WS-EPRO" "$(check_run ws-epro)" "OVPN UDP" "$(check_run openvpn-server@server-udp)"
    printf "  ${WHITE}%-10s${NC}: %-15b ${WHITE}%-10s${NC}: %-15b ${WHITE}%-10s${NC}: %-15b\n" "STUNNEL4" "$(check_run stunnel4)" "SLOWDNS" "$(check_run slowdns)" "OVPN TCP" "$(check_run openvpn-server@server-tcp)"
    printf "  ${WHITE}%-10s${NC}: %-15b ${WHITE}%-10s${NC}: %-15b ${WHITE}%-10s${NC}: %-15b\n" "HAPROXY" "$(check_run haproxy)" "NOOBZVPN" "$(check_run noobzvpnd)" "AUTOKILL" "$(check_run autokill)"
    echo -e ""
    echo -e "${N_PURPLE}${B_THICK}${NC}"
    echo -e "${N_CYAN} ✦ PROTOCOL MANAGERS                            ✦ SYSTEM & TOOLS ${NC}"
    echo -e "${N_PINK}${B_THIN}${NC}"
    echo -e "  [01] ${WHITE}SSH Manager${NC}                              [08] ${WHITE}Domain & SSL Manager${NC}"
    echo -e "  [02] ${WHITE}VMess Manager${NC}                            [09] ${WHITE}Server Settings Hub${NC}"
    echo -e "  [03] ${WHITE}VLess Manager${NC}                            [10] ${WHITE}Check Online Users${NC}"
    echo -e "  [04] ${WHITE}Trojan Manager${NC}                           [11] ${WHITE}OpenVPN & NoobzVPN${NC}"
    echo -e "  [05] ${WHITE}Xray gRPC Manager${NC}                        [12] ${WHITE}Check Services Detail${NC}"
    echo -e "  [06] ${WHITE}Shadowsocks Manager${NC}                      [13] ${WHITE}Change SSH Banner${NC}"
    echo -e ""
    echo -e "                                           [00] ${RED}Exit System${NC}"
    echo -e "${N_PURPLE}${B_THICK}${NC}"
    
    read -p " Select menu : " opt

    case $opt in
        1|01) ssh_menu ;;
        2|02) xray_menu "vmess" ;;
        3|03) xray_menu "vless" ;;
        4|04) xray_menu "trojan" ;;
        6|06) xray_menu "shadowsocks" ;;
        5|05) 
            clear
            echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}XRAY gRPC MANAGER${NC}                    ${N_PURPLE}│${NC}"
            echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
            echo -e "    [01] Create VLESS gRPC\n    [02] Create VMESS gRPC\n    [00] Back to Main Menu"
            read -p " Select : " g_opt
            
            if [[ "$g_opt" == "1" || "$g_opt" == "01" || "$g_opt" == "2" || "$g_opt" == "02" ]]; then
                acquire_lock || continue
                read -p " Username: " user
                read -p " Max Login: " limit
                if [ -z "$limit" ]; then limit=3; fi
                
                sed -i "/^${user}:/d" /etc/edufwesh/user_limits.txt 2>/dev/null
                echo "${user}:${limit}" >> /etc/edufwesh/user_limits.txt
                
                UUID=$(uuidgen)
                if [[ "$g_opt" == "1" || "$g_opt" == "01" ]]; then
                    jq ".inbounds[4].settings.clients += [{\"id\": \"${UUID}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
                    mv /tmp/xray.json /usr/local/etc/xray/config.json
                    systemctl restart xray
                    echo -e " ${N_GREEN}VLESS gRPC Created! ID: ${UUID}${NC}"
                else
                    jq ".inbounds[5].settings.clients += [{\"id\": \"${UUID}\", \"alterId\": 0, \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
                    mv /tmp/xray.json /usr/local/etc/xray/config.json
                    systemctl restart xray
                    echo -e " ${N_GREEN}VMESS gRPC Created! ID: ${UUID}${NC}"
                fi
                
                release_lock
                read -n 1 -s -r -p "Press any key..."
            fi 
            ;;
        13)
            clear
            echo -e "${N_CYAN} ❖ CHANGE SSH BANNER ❖ ${NC}"
            echo -e "${N_YELLOW} Opening /etc/issue.net in nano editor...${NC}"
            echo -e "${N_YELLOW} (Press Ctrl+X, then Y, then Enter to save and exit)${NC}"
            sleep 3
            touch /etc/issue.net
            nano /etc/issue.net
            
            if grep -q "^[#]*Banner" /etc/ssh/sshd_config; then
                sed -i 's/^[#]*Banner.*/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config
            else
                echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
            fi
            
            if grep -q "^DROPBEAR_BANNER=" /etc/default/dropbear; then
                sed -i 's|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER="/etc/issue.net"|g' /etc/default/dropbear
            else
                echo 'DROPBEAR_BANNER="/etc/issue.net"' >> /etc/default/dropbear
            fi
            
            systemctl restart ssh dropbear
            echo -e "\n ${N_GREEN}Banner successfully updated and applied!${NC}"
            echo -e "${N_PINK}${B_THIN}${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            ;;
        8|08) domain_tools ;;
        9|09) settings_menu ;;
        10) check_online ;;
        11)
            clear
            echo -e "${N_CYAN} ❖ OPENVPN & NOOBZVPN ${NC}\n  [1] Show OpenVPN UDP Profile\n  [2] Show OpenVPN TCP Profile\n  [3] Show NoobzVPN Profile Info"
            read -p " Select: " ov_opt
            
            if [ "$ov_opt" == "1" ]; then 
                clear
                cat /var/www/html/ovpn/client-udp.ovpn
                read -n 1 -s -r -p "Press any key to return..."
            elif [ "$ov_opt" == "2" ]; then 
                clear
                cat /var/www/html/ovpn/client-tcp.ovpn
                read -n 1 -s -r -p "Press any key to return..."
            elif [ "$ov_opt" == "3" ]; then 
                clear
                echo -e " Host: ${DOMAIN}\n Port STD: 8080\n Port SSL: 9443"
                read -n 1 -s -r -p "Press any key to return..."
            fi 
            ;;
        12)
            clear
            echo -e "${N_PURPLE}┌──────────────────────────────────────────────────────────────────────────┐${NC}"
            echo -e "${N_PURPLE}│${NC}                         ${N_CYAN}DETAILED SERVICE STATUS${NC}                          ${N_PURPLE}│${NC}"
            echo -e "${N_PURPLE}└──────────────────────────────────────────────────────────────────────────┘${NC}"
            printf "    %-30s : %b\n" "Xray Core (VMess/VLESS/Trojan)" "$(check_run xray)"
            printf "    %-30s : %b\n" "Dropbear SSH" "$(check_run dropbear)"
            printf "    %-30s : %b\n" "Stunnel4 TLS" "$(check_run stunnel4)"
            printf "    %-30s : %b\n" "Nginx WebServer" "$(check_run nginx)"
            printf "    %-30s : %b\n" "SSH-WS Proxy (ePro)" "$(check_run ws-epro)"
            printf "    %-30s : %b\n" "SlowDNS (DNSTT)" "$(check_run slowdns)"
            printf "    %-30s : %b\n" "Cron Scheduler" "$(check_run cron)"
            printf "    %-30s : %b\n" "HAProxy Multiplexer" "$(check_run haproxy)"
            printf "    %-30s : %b\n" "OpenVPN UDP Server" "$(check_run openvpn-server@server-udp)"
            printf "    %-30s : %b\n" "OpenVPN TCP Server" "$(check_run openvpn-server@server-tcp)"
            printf "    %-30s : %b\n" "NoobzVPN Daemon" "$(check_run noobzvpnd)"
            printf "    %-30s : %b\n" "Fail2Ban" "$(check_run fail2ban)"
            printf "    %-30s : %b\n" "AutoKill Daemon" "$(check_run autokill)"
            printf "    %-30s : %b\n" "Telegram Bot" "$(check_run edufwesh-bot)"
            read -n 1 -s -r -p "Press any key to return..." 
            ;;
        0|00) 
            clear
            exit 0 
            ;;
    esac
done
END
chmod +x /usr/bin/menu

# =========================================================================================
# FINAL VERIFICATION & COMPILATION SEQUENCE
# =========================================================================================
systemctl restart noobzvpnd >/dev/null 2>&1

echo -e "\n${N_YELLOW}[+] Verifying critical services...${NC}"
sleep 3

if systemctl is-active --quiet openvpn-server@server-udp; then 
    echo -e " ${N_GREEN}✔ OpenVPN (UDP) is running${NC}"
fi

if systemctl is-active --quiet openvpn-server@server-tcp; then 
    echo -e " ${N_GREEN}✔ OpenVPN (TCP) is running${NC}"
fi

if systemctl is-active --quiet noobzvpnd; then 
    echo -e " ${N_GREEN}✔ NoobzVPN is running${NC}"
fi

if systemctl is-active --quiet slowdns; then 
    echo -e " ${N_GREEN}✔ SlowDNS (DNSTT) is running${NC}"
fi

if systemctl is-active --quiet xray; then 
    echo -e " ${N_GREEN}✔ Xray core is running${NC}"
fi

if systemctl is-active --quiet edufwesh-bot; then 
    echo -e " ${N_GREEN}✔ Telegram Bot is running successfully!${NC}"
fi

sleep 2
clear

echo -e "${N_PURPLE}=====================================================================================${NC}"
echo -e "${N_CYAN}                             ❖ INSTALLATION SUCCESSFUL ❖                             ${NC}"
echo -e "${N_PURPLE}=====================================================================================${NC}"
echo -e "${WHITE} Your Edufwesh VPN Manager has been installed with the following:${NC}"
echo -e ""
echo -e " ${N_YELLOW}>> Protocols & Ports Configured:${NC}"
echo -e "  - OpenSSH           : 22"
echo -e "  - Dropbear          : 109, 143"
echo -e "  - WS-ePro Proxy     : 80, 8880"
echo -e "  - HAProxy           : 80, 443"
echo -e "  - Stunnel4          : 447, 777"
echo -e "  - Xray WS & gRPC    : 443"
echo -e "  - XTLS-Reality      : 8443 (TCP)"
echo -e "  - Shadowsocks-2022  : 10007 (TCP/UDP)"
echo -e "  - VMess mKCP        : 10008 (UDP)"
echo -e "  - VLESS QUIC        : 10009 (UDP)"
echo -e "  - Hysteria2         : 36936 (UDP)"
echo -e "  - OpenVPN TCP/UDP   : 1194"
echo -e "  - NoobzVPN          : 8080 (STD), 9443 (SSL)"
echo -e "  - SlowDNS (DNSTT)   : 53"
echo -e "  - BadVPN UDPGW      : 7100, 7200, 7300"
echo -e "${N_PURPLE}=====================================================================================${NC}"
echo -e "${N_GREEN} To access your control panel at any time, simply type: menu${NC}"
echo -e "${N_PURPLE}=====================================================================================${NC}"
echo ""

read -p " [?] It is highly recommended to reboot the server now. Reboot? (y/n): " REBOOT_ANS
if [[ "$REBOOT_ANS" =~ ^[Yy]$ ]]; then
    echo -e "${N_YELLOW} Rebooting system in 3 seconds...${NC}"
    sleep 3
    reboot
else
    echo -e "${N_GREEN} Reboot skipped. You can reboot later by typing 'reboot'.${NC}"
fi
