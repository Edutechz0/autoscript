#!/bin/bash

# ==========================================
# EDUFWESH PREMIUM AUTO-INSTALLER (ULTIMATE)
# BBR, Auto-Kill, Auto-Maintenance, Xray/Hysteria
# ==========================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}       WELCOME TO EDUFWESH SCRIPT INSTALLER         ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo ""

# 1. DOMAIN & NS PROMPTS
read -p " [?] Enter your main Domain (e.g., vpn.server.com) : " MY_DOMAIN
read -p " [?] Enter your NS Domain (e.g., ns.server.com)    : " MY_NSDOMAIN

mkdir -p /etc/xray /etc/slowdns /etc/hysteria /etc/edufwesh
echo "$MY_DOMAIN" > /etc/xray/domain
echo "$MY_NSDOMAIN" > /etc/slowdns/nsdomain

# 2. TCP BBR OPTIMIZATION (Speed Boost)
echo -e "\n${GREEN}[+] Enabling TCP BBR Optimization...${NC}"
cat >> /etc/sysctl.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p > /dev/null 2>&1

# 3. SYSTEM UPDATE & DEPENDENCIES
export DEBIAN_FRONTEND=noninteractive
echo -e "${GREEN}[+] Updating System & Installing Dependencies...${NC}"
apt-get update -y && apt-get upgrade -y
apt-get install -y wget curl nano unzip ufw stunnel4 dropbear iptables squid jq python3 uuid-runtime cron bc

# 4. FIREWALL SETUP
echo -e "${GREEN}[+] Configuring Firewall Ports...${NC}"
ufw disable
# TCP Ports (Including Cloudflare WS/WSS Ports)
for port in 22 80 109 143 443 777 2052 2053 2082 2083 2086 2087 2095 2096 3128 7300 8080 8443; do
    ufw allow $port/tcp
done
# UDP Ports (SlowDNS, Hysteria)
for port in 53 3666 5666; do
    ufw allow $port/udp
done
ufw --force enable

# 5. SSH, DROPBEAR, STUNNEL & SQUID SETUP
echo -e "${GREEN}[+] Configuring Core Tunnels (SSH/Dropbear/Stunnel)...${NC}"
sed -i 's/#Port 22/Port 22\nPort 2253/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart ssh

sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 143"/g' /etc/default/dropbear
systemctl restart dropbear

openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=NG/ST=Rivers/L=Port Harcourt/O=Edufwesh/CN=${MY_DOMAIN}" \
    -keyout /etc/stunnel/stunnel.pem \
    -out /etc/stunnel/stunnel.pem > /dev/null 2>&1

cat > /etc/stunnel/stunnel.conf << END
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear_ssl]
accept = 443
connect = 127.0.0.1:109

[websocket_ssl]
accept = 2053
connect = 127.0.0.1:80
END
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl restart stunnel4

# 6. PYTHON WEBSOCKET PROXY (Port 80)
cat > /usr/local/bin/ws-proxy.py << 'END'
import socket, threading
def handle_client(client_socket):
    try:
        request = client_socket.recv(1024).decode('utf-8', errors='ignore')
        if "Upgrade: websocket" in request:
            client_socket.send(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n").encode())
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect(('127.0.0.1', 109))
        threading.Thread(target=forward, args=(client_socket, ssh_socket)).start()
        threading.Thread(target=forward, args=(ssh_socket, client_socket)).start()
    except: client_socket.close()
def forward(s, d):
    try:
        while True:
            data = s.recv(4096)
            if not data: break
            d.sendall(data)
    except: pass
    finally: s.close(); d.close()
server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('0.0.0.0', 80))
server.listen(100)
while True:
    client, addr = server.accept()
    threading.Thread(target=handle_client, args=(client,)).start()
END
chmod +x /usr/local/bin/ws-proxy.py
cat > /etc/systemd/system/ws-proxy.service << END
[Unit]
Description=Python WS Proxy
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws-proxy.py
Restart=always
[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload && systemctl enable --now ws-proxy

# 7. SLOWDNS (DNSTT) SETUP
echo -e "${GREEN}[+] Configuring SlowDNS...${NC}"
wget -q -O /etc/slowdns/dnstt-server "https://raw.githubusercontent.com/Arya-Blitar22/st-pusat/main/slowdns/dnstt-server"
chmod +x /etc/slowdns/dnstt-server
cd /etc/slowdns
./dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub > /dev/null 2>&1
cat > /etc/systemd/system/slowdns.service << END
[Unit]
Description=SlowDNS Server
[Service]
WorkingDirectory=/etc/slowdns
ExecStart=/etc/slowdns/dnstt-server -udp :53 -privkey-file server.key ${MY_NSDOMAIN} 127.0.0.1:109
Restart=always
[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload && systemctl enable --now slowdns

# 8. XRAY CORE (VLESS/VMESS)
echo -e "${GREEN}[+] Installing Xray Core...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
cat > /usr/local/etc/xray/config.json << END
{
  "inbounds": [
    {
      "port": 8443,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/edufwesh" } }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
END
systemctl restart xray && systemctl enable xray

# 9. AUTO-MAINTENANCE (Cron Jobs)
echo -e "${GREEN}[+] Setting up Auto-Maintenance & Optimization...${NC}"
cat > /etc/cron.d/edufwesh_maintenance << END
# Reboot daily at 4:00 AM
0 4 * * * root /sbin/reboot
# Clear RAM Cache daily at 12:00 AM
0 0 * * * root /usr/bin/sync && echo 3 > /proc/sys/vm/drop_caches
# Auto-delete expired SSH accounts daily at 1:00 AM
0 1 * * * root /usr/local/bin/user-expire
END

cat > /usr/local/bin/user-expire << 'END'
#!/bin/bash
today=$(date +%s)
for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    exp=$(chage -l $user | grep "Account expires" | awk -F": " '{print $2}')
    if [[ "$exp" != "never" ]]; then
        exp_sec=$(date -d "$exp" +%s)
        if [[ $today -gt $exp_sec ]]; then
            userdel -r $user > /dev/null 2>&1
        fi
    fi
done
END
chmod +x /usr/local/bin/user-expire

# 10. MULTI-LOGIN PREVENTER (Auto-Kill for SSH/WS)
echo -e "${GREEN}[+] Installing Auto-Kill Service...${NC}"
cat > /usr/local/bin/autokill << 'END'
#!/bin/bash
MAX_LOGINS=2
while true; do
    for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
        login_count=$(ps -u $user | grep sshd | wc -l)
        if [ $login_count -gt $MAX_LOGINS ]; then
            pkill -u $user
        fi
    done
    sleep 30
done
END
chmod +x /usr/local/bin/autokill
cat > /etc/systemd/system/autokill.service << END
[Unit]
Description=Edufwesh Auto-Kill MultiLogin
[Service]
ExecStart=/usr/local/bin/autokill
Restart=always
[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload && systemctl enable --now autokill

# 11. THE MASTER MENU
echo -e "${GREEN}[+] Compiling Master Dashboard...${NC}"
cat > /usr/bin/menu << 'END'
#!/bin/bash
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
DOMAIN=$(cat /etc/xray/domain)

clear
echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}           EDUFWESH MASTER CONTROL PANEL            ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e "${YELLOW}  WA: +234 916 921 2134  |  TG: @EDUFWESH3          ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e " [1] Add SSH / WS User"
echo -e " [2] Add Xray VLess User (WS)"
echo -e " [3] Check System Status & Traffic"
echo -e " [4] Show SlowDNS Public Key"
echo -e " [5] Clear Server RAM Cache"
echo -e " [6] Reboot Server"
echo -e " [0] Exit"
echo -e "${CYAN}====================================================${NC}"
read -p " Select an option [0-6]: " option

case $option in
    1)
        read -p " Username: " user
        read -p " Password: " pass
        read -p " Days Active: " days
        useradd -e $(date -d "$days days" +"%Y-%m-%d") -s /bin/false -M $user
        echo -e "$pass\n$pass" | passwd $user >/dev/null 2>&1
        echo -e "\n${GREEN}Account Created!${NC}"
        echo -e "Host: $DOMAIN"
        echo -e "Port (SSH): 22, 2253"
        echo -e "Port (WS): 80"
        echo -e "Port (WSS/SSL): 443, 2053"
        echo -e "User: $user | Pass: $pass | Exp: $(date -d "$days days" +"%Y-%m-%d")"
        ;;
    2)
        read -p " Username: " user
        UUID=$(uuidgen)
        # Add to JSON via JQ
        jq ".inbounds[0].settings.clients += [{\"id\": \"${UUID}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
        mv /tmp/xray.json /usr/local/etc/xray/config.json
        systemctl restart xray
        echo -e "\n${GREEN}Xray VLess Account Created!${NC}"
        echo -e "Copy Link:"
        echo -e "${CYAN}vless://${UUID}@${DOMAIN}:8443?path=%2Fedufwesh&security=none&encryption=none&type=ws#${user}${NC}"
        ;;
    3)
        echo -e "\n${CYAN}--- Service Status ---${NC}"
        systemctl is-active --quiet stunnel4 && echo -e "Stunnel: ${GREEN}Online${NC}" || echo -e "Stunnel: ${RED}Offline${NC}"
        systemctl is-active --quiet ws-proxy && echo -e "WS Proxy: ${GREEN}Online${NC}" || echo -e "WS Proxy: ${RED}Offline${NC}"
        systemctl is-active --quiet slowdns && echo -e "SlowDNS: ${GREEN}Online${NC}" || echo -e "SlowDNS: ${RED}Offline${NC}"
        systemctl is-active --quiet xray && echo -e "Xray Core: ${GREEN}Online${NC}" || echo -e "Xray Core: ${RED}Offline${NC}"
        systemctl is-active --quiet autokill && echo -e "Auto-Kill: ${GREEN}Active${NC}" || echo -e "Auto-Kill: ${RED}Offline${NC}"
        ;;
    4)
        echo -e "\n${GREEN}Your SlowDNS Client PubKey is:${NC}"
        cat /etc/slowdns/server.pub
        ;;
    5)
        sync && echo 3 > /proc/sys/vm/drop_caches
        echo -e "${GREEN}RAM Cache Cleared!${NC}"
        ;;
    6)
        reboot
        ;;
    0)
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option!${NC}"
        ;;
esac
END
chmod +x /usr/bin/menu

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}TCP BBR Optimized, Auto-Maintenance Active.${NC}"
echo -e "${GREEN}Type 'menu' to manage your accounts.${NC}"
echo -e "${GREEN}======================================${NC}"
