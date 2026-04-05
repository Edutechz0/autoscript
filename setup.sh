#!/bin/bash

# ==========================================================
# EDUFWESH PREMIUM AUTO-INSTALLER (GOD-TIER V10 - EXPANDED)
# gRPC, Shadowsocks, OpenVPN, WS-ePro, UDP Custom, Domain Tools
# ==========================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

clear
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│       WELCOME TO EDUFWESH SCRIPT INSTALLER          │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
echo ""

read -p " [?] Enter your main Domain (e.g., vpn.server.com) : " MY_DOMAIN
read -p " [?] Enter your NS Domain (e.g., ns.server.com)    : " MY_NSDOMAIN

# Directory creation
mkdir -p /etc/xray
mkdir -p /etc/slowdns
mkdir -p /etc/edufwesh
mkdir -p /etc/udp

# Save domains
echo "$MY_DOMAIN" > /etc/xray/domain
echo "$MY_NSDOMAIN" > /etc/slowdns/nsdomain

# Set Timezone to West Africa Time
timedatectl set-timezone Africa/Lagos
export DEBIAN_FRONTEND=noninteractive

# ==========================================
# 1. SYSTEM UPDATE & PORT 53 FIX
# ==========================================
echo -e "\n${GREEN}[+] Freeing up Port 53 & Updating System...${NC}"

# Disable systemd-resolved to free Port 53 for SlowDNS
systemctl stop systemd-resolved
systemctl disable systemd-resolved >/dev/null 2>&1
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Update and Install Packages
apt-get update -y
apt-get upgrade -y
apt-get install -y wget curl nano unzip ufw stunnel4 dropbear iptables nginx jq python3 uuid-runtime cron bc vnstat net-tools speedtest-cli openvpn

# Shell Fixes for SSH Tunneling
echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells

# Initialize vnstat bandwidth monitoring
systemctl enable --now vnstat

# Enable BBR Optimization
cat >> /etc/sysctl.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p > /dev/null 2>&1

# ==========================================
# 2. FIREWALL SETUP
# ==========================================
echo -e "${GREEN}[+] Configuring Firewall Ports...${NC}"
ufw disable

# TCP Ports
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 109/tcp
ufw allow 143/tcp
ufw allow 443/tcp
ufw allow 777/tcp
ufw allow 1194/tcp
ufw allow 7300/tcp

# UDP Ports
ufw allow 53/udp
ufw allow 1194/udp
ufw allow 7100/udp
ufw allow 7200/udp
ufw allow 7300/udp

ufw --force enable

# ==========================================
# 3. SSH, DROPBEAR & STUNNEL
# ==========================================
echo -e "${GREEN}[+] Configuring SSH & Dropbear...${NC}"

# OpenSSH
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart ssh

# Dropbear
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 143"/g' /etc/default/dropbear
systemctl restart dropbear

# Stunnel4
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=NG/ST=Rivers/L=PH/O=Edufwesh/CN=${MY_DOMAIN}" \
    -keyout /etc/stunnel/stunnel.pem \
    -out /etc/stunnel/stunnel.pem > /dev/null 2>&1

cat > /etc/stunnel/stunnel.conf << END
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear_ssl]
accept = 777
connect = 127.0.0.1:109
END

sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl restart stunnel4

# ==========================================
# 4. WS-EPRO (WebSocket eProxy)
# ==========================================
echo -e "${GREEN}[+] Installing WS-ePro...${NC}"

# Attempt to fetch ws-epro from main repo, fallback to Tarap if missing
wget -q -O /usr/bin/ws-epro "https://raw.githubusercontent.com/Edutechz0/autoscript/main/ws-epro" 2>/dev/null || wget -q -O /usr/bin/ws-epro "https://raw.githubusercontent.com/Tarap-Kuhing/tarap/main/ssh/ws-epro"
chmod +x /usr/bin/ws-epro

cat > /etc/systemd/system/ws-epro.service << END
[Unit]
Description=WS-ePro Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ws-epro -listen :8880 -ssh 127.0.0.1:109
Restart=always

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable --now ws-epro

# ==========================================
# 5. XRAY CORE (VLESS, VMESS, TROJAN, SS + gRPC)
# ==========================================
echo -e "${GREEN}[+] Installing Xray Core...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1

cat > /usr/local/etc/xray/config.json << END
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/edufwesh-vless" } }
    },
    {
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/edufwesh-vmess" } }
    },
    {
      "port": 10003,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": { "clients": [] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/edufwesh-trojan" } }
    },
    {
      "port": 10004,
      "listen": "127.0.0.1",
      "protocol": "shadowsocks",
      "settings": { "clients": [], "network": "tcp,udp" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/edufwesh-ss" } }
    },
    {
      "port": 10005,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vless-grpc" } }
    },
    {
      "port": 10006,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vmess-grpc" } }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
END

systemctl restart xray
systemctl enable xray

# ==========================================
# 6. NGINX MULTIPLEXER (WS & gRPC Routing)
# ==========================================
echo -e "${GREEN}[+] Configuring Nginx Multiplexer...${NC}"
rm /etc/nginx/sites-enabled/default

cat > /etc/nginx/conf.d/multiplexer.conf << END
server {
    listen 80;
    server_name $MY_DOMAIN;
    
    location / { 
        proxy_pass http://127.0.0.1:8880; 
        proxy_http_version 1.1; 
        proxy_set_header Upgrade \$http_upgrade; 
        proxy_set_header Connection "upgrade"; 
        proxy_set_header Host \$host; 
    }
}

server {
    listen 443 ssl http2;
    server_name $MY_DOMAIN;
    
    ssl_certificate /etc/stunnel/stunnel.pem;
    ssl_certificate_key /etc/stunnel/stunnel.pem;
    
    # WS Routing
    location / { 
        proxy_pass http://127.0.0.1:8880; 
        proxy_http_version 1.1; 
        proxy_set_header Upgrade \$http_upgrade; 
        proxy_set_header Connection "upgrade"; 
        proxy_set_header Host \$host; 
    }
    location /edufwesh-vless { 
        proxy_pass http://127.0.0.1:10001; 
        proxy_http_version 1.1; 
        proxy_set_header Upgrade \$http_upgrade; 
        proxy_set_header Connection "upgrade"; 
        proxy_set_header Host \$host; 
    }
    location /edufwesh-vmess { 
        proxy_pass http://127.0.0.1:10002; 
        proxy_http_version 1.1; 
        proxy_set_header Upgrade \$http_upgrade; 
        proxy_set_header Connection "upgrade"; 
        proxy_set_header Host \$host; 
    }
    location /edufwesh-trojan { 
        proxy_pass http://127.0.0.1:10003; 
        proxy_http_version 1.1; 
        proxy_set_header Upgrade \$http_upgrade; 
        proxy_set_header Connection "upgrade"; 
        proxy_set_header Host \$host; 
    }
    location /edufwesh-ss { 
        proxy_pass http://127.0.0.1:10004; 
        proxy_http_version 1.1; 
        proxy_set_header Upgrade \$http_upgrade; 
        proxy_set_header Connection "upgrade"; 
        proxy_set_header Host \$host; 
    }
    
    # gRPC Routing
    location ^~ /vless-grpc { 
        grpc_pass grpc://127.0.0.1:10005; 
    }
    location ^~ /vmess-grpc { 
        grpc_pass grpc://127.0.0.1:10006; 
    }
}
END

systemctl restart nginx
systemctl enable nginx

# ==========================================
# 7. SLOWDNS & BADVPN SETUP
# ==========================================
echo -e "${GREEN}[+] Configuring SlowDNS & BadVPN...${NC}"

# BadVPN UDPGW
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

# SlowDNS
wget -q -O /etc/slowdns/dnstt-server "https://raw.githubusercontent.com/Arya-Blitar22/st-pusat/main/slowdns/dnstt-server"
chmod +x /etc/slowdns/dnstt-server

echo "7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59" > /etc/slowdns/server.pub
echo "819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae" > /etc/slowdns/server.key

cat > /etc/systemd/system/slowdns.service << END
[Unit]
Description=SlowDNS Server
After=network.target

[Service]
WorkingDirectory=/etc/slowdns
ExecStart=/etc/slowdns/dnstt-server -udp :53 -privkey-file server.key ${MY_NSDOMAIN} 127.0.0.1:109
Restart=always

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable --now slowdns

# ==========================================
# 8. MASTER DASHBOARD MENU COMPILATION
# ==========================================
echo -e "${GREEN}[+] Compiling God-Tier Dashboard...${NC}"

cat > /usr/bin/menu << 'END'
#!/bin/bash
NC='\e[0m'
CYAN='\e[1;36m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'

DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
NSDOM=$(cat /etc/slowdns/nsdomain 2>/dev/null)
IPVPS=$(curl -s ipv4.icanhazip.com)

# ----- DOMAIN & SSL TOOLS -----
domain_tools() {
    clear
    echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}                 DOMAIN & SSL MANAGER                 ${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
    echo -e "  [1] Change Main Domain"
    echo -e "  [2] Change Name Server (NS) Domain"
    echo -e "  [3] Fix/Regenerate SSL Certificate"
    echo -e "  [0] Back to Settings"
    echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
    read -p " Select : " dt_opt
    case $dt_opt in
        1) 
            read -p " Enter New Domain: " newdom
            echo "$newdom" > /etc/xray/domain
            sed -i "s/server_name .*/server_name $newdom;/g" /etc/nginx/conf.d/multiplexer.conf
            systemctl restart nginx
            echo -e "${GREEN} Domain updated successfully to $newdom${NC}"
            ;;
        2)
            read -p " Enter New NS Domain: " newns
            echo "$newns" > /etc/slowdns/nsdomain
            sed -i "s/server.key .*/server.key $newns 127.0.0.1:109/g" /etc/systemd/system/slowdns.service
            systemctl daemon-reload
            systemctl restart slowdns
            echo -e "${GREEN} NS Domain updated successfully to $newns${NC}"
            ;;
        3)
            echo -e "${YELLOW} Regenerating Self-Signed SSL for Nginx/Stunnel...${NC}"
            openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=NG/ST=Rivers/L=PH/O=Edufwesh/CN=${DOMAIN}" -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem > /dev/null 2>&1
            systemctl restart stunnel4
            systemctl restart nginx
            echo -e "${GREEN} Certificate fixed and services restarted!${NC}"
            ;;
    esac
}

# ----- SETTINGS MENU -----
settings_menu() {
    while true; do
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 SERVER SETTINGS HUB                  ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "  [01] Speedtest VPS"
        echo -e "  [02] Info Ports"
        echo -e "  [03] Domain & SSL Tools"
        echo -e "  [04] Install UDP Custom"
        echo -e "  [05] SlowDNS Key Manager"
        echo -e "  [06] Server Health Check"
        echo -e "  [00] Back to Main Dashboard"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        read -p " Select option : " set_opt

        case $set_opt in
            1|01) 
                clear
                echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${CYAN}                 SPEEDTEST RESULTS                    ${NC}"
                echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
                speedtest-cli
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
                ;;
            2|02) 
                clear
                echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${CYAN}                 SYSTEM PORTS & INFO                  ${NC}"
                echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
                echo -e " ${YELLOW}>> Service & Port List${NC}"
                echo -e "  - OpenSSH           : 22"
                echo -e "  - Dropbear          : 109, 143"
                echo -e "  - WS-ePro Proxy     : 80, 8880"
                echo -e "  - Stunnel4          : 777"
                echo -e "  - Xray VLESS/VMESS  : 443 (WS & gRPC)"
                echo -e "  - Xray Trojan/SS    : 443"
                echo -e "  - OpenVPN TCP/UDP   : 1194"
                echo -e "  - SlowDNS (DNSTT)   : 53"
                echo -e "  - BadVPN UDPGW      : 7300"
                echo -e "  - UDP Custom        : 7100, 7200"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
                echo -e " ${YELLOW}>> Server Status${NC}"
                echo -e "  - IP Address        : ${IPVPS}"
                echo -e "  - Domain            : ${DOMAIN}"
                echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
                ;;
            3|03) 
                domain_tools 
                ;;
            4|04) 
                clear
                echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${CYAN}                 UDP CUSTOM INSTALLER                 ${NC}"
                echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
                echo -e "${YELLOW} Downloading UDP Custom binary...${NC}"
                wget -q -O /usr/bin/udp-custom "https://raw.githubusercontent.com/Edutechz0/autoscript/main/udp-custom" 2>/dev/null || echo -e "${RED} UDP Custom Binary not found in repo! Ensure it's uploaded.${NC}"
                chmod +x /usr/bin/udp-custom 2>/dev/null
                echo -e "${GREEN} UDP Setup process completed.${NC}"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
                ;;
            5|05) 
                clear
                echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${CYAN}                 SLOWDNS KEY MANAGER                  ${NC}"
                echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
                echo -e "  [1] Switch to Global Key (Edufwesh Default)"
                echo -e "  [2] Generate Fresh Random Key"
                echo -e "  [3] Input Custom Key Pair"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
                read -p " Select : " dns_opt
                if [ "$dns_opt" == "1" ]; then
                    echo "7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59" > /etc/slowdns/server.pub
                    echo "819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae" > /etc/slowdns/server.key
                    systemctl restart slowdns
                    echo -e "${GREEN} Switched to Global Key successfully!${NC}"
                elif [ "$dns_opt" == "2" ]; then
                    cd /etc/slowdns
                    rm -f server.pub server.key
                    ./dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub
                    systemctl restart slowdns
                    echo -e "${GREEN} New Keys Generated successfully!${NC}"
                elif [ "$dns_opt" == "3" ]; then
                    read -p " Paste Public Key: " in_pub
                    read -p " Paste Private Key: " in_priv
                    echo "$in_pub" > /etc/slowdns/server.pub
                    echo "$in_priv" > /etc/slowdns/server.key
                    systemctl restart slowdns
                    echo -e "${GREEN} Custom Keys Saved successfully!${NC}"
                fi
                ;;
            6|06) 
                clear
                echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${CYAN}                 SERVER HEALTH CHECK                  ${NC}"
                echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
                uptime
                echo ""
                free -h
                echo ""
                df -h | grep '^/dev/'
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
                ;;
            0|00) break ;;
            *) echo -e "${RED}Invalid Option${NC}" ;;
        esac
        echo -e ""; read -n 1 -s -r -p "Press any key to return..."
    done
}

# ----- MAIN DASHBOARD VARIABLES -----
OS_INFO=$(cat /etc/os-release | grep -w PRETTY_NAME | cut -d= -f2 | tr -d '"')
UPTIME=$(uptime -p | cut -d " " -f 2-)
DATETIME=$(date "+%d-%m-%Y | %H:%M:%S")
RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
RAM_USED=$(free -m | awk 'NR==2{print $3}')
RAM_FREE=$(free -m | awk 'NR==2{print $4}')

check_status() { systemctl is-active --quiet $1 && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"; }
STS_SSH=$(check_status ssh)
STS_NGX=$(check_status nginx)
STS_XRY=$(check_status xray)
STS_DPB=$(check_status dropbear)
STS_WSP=$(check_status ws-epro)
STS_DNS=$(check_status slowdns)

IFACE=$(ip route | grep default | awk '{print $5}')
BW_TODAY=$(vnstat -i $IFACE -d --oneline | awk -F\; '{print $4}' | sed 's/ //g' 2>/dev/null || echo "0 MiB")
BW_MONTH=$(vnstat -i $IFACE -m --oneline | awk -F\; '{print $11}' | sed 's/ //g' 2>/dev/null || echo "0 MiB")

SSH_C=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)
VLS_C=$(jq '.inbounds[0].settings.clients | length' /usr/local/etc/xray/config.json 2>/dev/null || echo "0")
VMS_C=$(jq '.inbounds[1].settings.clients | length' /usr/local/etc/xray/config.json 2>/dev/null || echo "0")
TRJ_C=$(jq '.inbounds[2].settings.clients | length' /usr/local/etc/xray/config.json 2>/dev/null || echo "0")
SS_C=$(jq '.inbounds[3].settings.clients | length' /usr/local/etc/xray/config.json 2>/dev/null || echo "0")

# ----- MAIN DASHBOARD LOOP -----
while true; do
clear
echo -e "${CYAN} * Documentation:  https://help.ubuntu.com${NC}"
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}                 LICENSE INFORMATION                  ${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
echo -e "   Client     : EDUFWESH"
echo -e "   Expiry Date: 31-12-2029"
echo -e "   Days Left  : Unlimited"
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}                   VPS INFORMATION                    ${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
echo -e "   Server Uptime      = ${UPTIME}"
echo -e "   Current Time       = ${DATETIME}"
echo -e "   Operating System   = ${OS_INFO}"
echo -e "   Current Domain     = ${DOMAIN}"
echo -e "   NS Domain          = ${NSDOM}"
echo -e "   Total Ram          = ${RAM_TOTAL} MB"
echo -e "   Total Used Ram     = ${RAM_USED} MB"
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}            @THETECHSAVAGETELEGRAM VPN MANAGER        ${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
echo -e "    Use Core          : Xray-Core 2024"
echo -e "    IP-VPS            : ${IPVPS}"
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "      SSH     VMESS     VLESS    TROJAN    SS"
echo -e "       ${SSH_C}        ${VMS_C}         ${VLS_C}        ${TRJ_C}        ${SS_C}"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "       SSH : ${STS_SSH}      NGINX : ${STS_NGX}      XRAY : ${STS_XRY}  "
echo -e "           DROPBEAR : ${STS_DPB}      WS-EPRO : ${STS_WSP}  "
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "    [01] SSH       [Menu]      [06] SHADOWSOCKS"
echo -e "    [02] VMESS     [Menu]      [07] OPENVPN / NOOBZ"
echo -e "    [03] VLESS     [Menu]      [08] SETTING"
echo -e "    [04] TROJAN    [Menu]      [09] DELETE USERS"
echo -e "    [05] XRAY gRPC [Menu]      [00] EXIT SYSTEM"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}                 MONITORING BANDWIDTH                 ${NC}"
echo -e "${CYAN}├─────────────────────────────────────────────────────┤${NC}"
echo -e "   BANDWIDTH USED TODAY       = ${BW_TODAY}"
echo -e "   TOTAL BANDWIDTH THIS MONTH = ${BW_MONTH}"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
read -p " Select menu : " opt

case $opt in
    1|01)
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 CREATE SSH/WS USER                   ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        read -p " Username    : " user
        read -p " Password    : " pass
        read -p " Days Active : " days
        useradd -e $(date -d "$days days" +"%Y-%m-%d") -s /bin/false -M $user
        echo -e "$pass\n$pass" | passwd $user >/dev/null 2>&1
        EXP_DATE=$(date -d "$days days" +"%b %d, %Y")
        
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}                 PREMIUM SSH WS ACCOUNT               ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e " Username      : ${WHITE}$user${NC}"
        echo -e " Password      : ${WHITE}$pass${NC}"
        echo -e " Expired On    : ${RED}${EXP_DATE}${NC}"
        echo -e " Domain        : ${WHITE}${DOMAIN}${NC}"
        echo -e " Port WSS      : 443"
        echo -e " Port WS       : 80"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        ;;
    2|02)
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 CREATE XRAY VMESS USER               ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        read -p " Username: " user
        UUID=$(uuidgen)
        jq ".inbounds[1].settings.clients += [{\"id\": \"${UUID}\", \"alterId\": 0, \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
        mv /tmp/xray.json /usr/local/etc/xray/config.json
        systemctl restart xray
        echo -e "${GREEN} VMess Account Created!${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        echo -e " ID: ${WHITE}${UUID}${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        ;;
    3|03)
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 CREATE XRAY VLESS USER               ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        read -p " Username: " user
        UUID=$(uuidgen)
        jq ".inbounds[0].settings.clients += [{\"id\": \"${UUID}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
        mv /tmp/xray.json /usr/local/etc/xray/config.json
        systemctl restart xray
        echo -e "${GREEN} VLess Account Created!${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        echo -e " ID: ${WHITE}${UUID}${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        ;;
    4|04)
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 CREATE XRAY TROJAN USER              ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        read -p " Username: " user
        UUID=$(uuidgen)
        jq ".inbounds[2].settings.clients += [{\"password\": \"${user}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
        mv /tmp/xray.json /usr/local/etc/xray/config.json
        systemctl restart xray
        echo -e "${GREEN} Trojan Account Created!${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        echo -e " Password: ${WHITE}${user}${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        ;;
    5|05)
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 CREATE XRAY gRPC USER                ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "  [1] VLess gRPC"
        echo -e "  [2] VMess gRPC"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        read -p " Select Protocol: " grpc_opt
        read -p " Username: " user
        UUID=$(uuidgen)
        
        if [ "$grpc_opt" == "1" ]; then
            jq ".inbounds[4].settings.clients += [{\"id\": \"${UUID}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
            mv /tmp/xray.json /usr/local/etc/xray/config.json
        elif [ "$grpc_opt" == "2" ]; then
            jq ".inbounds[5].settings.clients += [{\"id\": \"${UUID}\", \"alterId\": 0, \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
            mv /tmp/xray.json /usr/local/etc/xray/config.json
        fi
        
        systemctl restart xray
        echo -e "${GREEN} gRPC Account Created!${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        echo -e " ID: ${WHITE}${UUID}${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        ;;
    6|06)
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 CREATE SHADOWSOCKS USER              ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        read -p " Username: " user
        UUID=$(uuidgen)
        jq ".inbounds[3].settings.clients += [{\"password\": \"${UUID}\", \"method\": \"aes-128-gcm\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
        mv /tmp/xray.json /usr/local/etc/xray/config.json
        systemctl restart xray
        echo -e "${GREEN} Shadowsocks Account Created!${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        echo -e " Password: ${WHITE}${UUID}${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        ;;
    7|07) 
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 OPENVPN & NOOBZVPN                   ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "${YELLOW} OpenVPN and NoobzVPN auto-installers are pending ${NC}"
        echo -e "${YELLOW} final binary integration in your GitHub repo.    ${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        ;;
    8|08) settings_menu ;;
    9|09) 
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 DELETE SYSTEM USER                   ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        read -p " Enter Username to delete: " deluser
        userdel -r $deluser >/dev/null 2>&1
        echo -e "${GREEN} User $deluser deleted successfully!${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        ;;
    0|00) clear; exit 0 ;;
    *) echo -e "\n${RED}Invalid Option!${NC}" ;;
esac
echo -e ""
read -n 1 -s -r -p "Press any key to return..."
done
END
chmod +x /usr/bin/menu

echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}Type 'menu' to access the expanded Dashboard.${NC}"
echo -e "${GREEN}======================================${NC}"
