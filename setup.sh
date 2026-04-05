#!/bin/bash

# ==========================================================
# EDUFWESH PREMIUM AUTO-INSTALLER (GOD-TIER V11 - FULL EXPANDED)
# Uncompressed UI, Full Submenus, Payload Generators
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

mkdir -p /etc/xray
mkdir -p /etc/slowdns
mkdir -p /etc/edufwesh
mkdir -p /etc/udp
mkdir -p /etc/openvpn
mkdir -p /etc/noobz

echo "$MY_DOMAIN" > /etc/xray/domain
echo "$MY_NSDOMAIN" > /etc/slowdns/nsdomain

timedatectl set-timezone Africa/Lagos
export DEBIAN_FRONTEND=noninteractive

# ==========================================
# 1. SYSTEM UPDATE & PORT 53 FIX
# ==========================================
echo -e "\n${GREEN}[+] Freeing up Port 53 & Updating System...${NC}"
systemctl stop systemd-resolved
systemctl disable systemd-resolved >/dev/null 2>&1
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

apt-get update -y
apt-get upgrade -y
apt-get install -y wget curl nano unzip ufw stunnel4 dropbear iptables nginx jq python3 uuid-runtime cron bc vnstat net-tools speedtest-cli openvpn

echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells
systemctl enable --now vnstat

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
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 109/tcp
ufw allow 143/tcp
ufw allow 443/tcp
ufw allow 777/tcp
ufw allow 1194/tcp
ufw allow 7300/tcp
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
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart ssh

sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 143"/g' /etc/default/dropbear
systemctl restart dropbear

openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=NG/ST=Rivers/L=PH/O=Edufwesh/CN=${MY_DOMAIN}" -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem > /dev/null 2>&1

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
# 4. WS-EPRO (Python eProxy Engine)
# ==========================================
echo -e "${GREEN}[+] Installing WS-ePro Engine...${NC}"
cat > /usr/local/bin/ws-epro.py << 'END'
import socket, threading
def handle_client(client_socket):
    try:
        request = client_socket.recv(1024).decode('utf-8', errors='ignore')
        if "Upgrade: websocket" in request or "HTTP" in request:
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
server.bind(('127.0.0.1', 8880))
server.listen(100)
while True:
    client, addr = server.accept()
    threading.Thread(target=handle_client, args=(client,)).start()
END

chmod +x /usr/local/bin/ws-epro.py

cat > /etc/systemd/system/ws-epro.service << END
[Unit]
Description=WS-ePro Proxy Service
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws-epro.py
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
  "log": { "loglevel": "warning" },
  "inbounds": [
    { "port": 10001, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } } },
    { "port": 10002, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } } },
    { "port": 10003, "listen": "127.0.0.1", "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } } },
    { "port": 10004, "listen": "127.0.0.1", "protocol": "shadowsocks", "settings": { "clients": [], "network": "tcp,udp" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/ss" } } },
    { "port": 10005, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vless-grpc" } } },
    { "port": 10006, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vmess-grpc" } } }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
END

systemctl restart xray
systemctl enable xray

# ==========================================
# 6. NGINX MULTIPLEXER (WS & gRPC)
# ==========================================
echo -e "${GREEN}[+] Configuring Nginx Multiplexer...${NC}"
rm /etc/nginx/sites-enabled/default

cat > /etc/nginx/conf.d/multiplexer.conf << END
server {
    listen 80;
    server_name $MY_DOMAIN;
    location / { proxy_pass http://127.0.0.1:8880; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
}
server {
    listen 443 ssl http2;
    server_name $MY_DOMAIN;
    ssl_certificate /etc/stunnel/stunnel.pem;
    ssl_certificate_key /etc/stunnel/stunnel.pem;
    
    location / { proxy_pass http://127.0.0.1:8880; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /vless { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /vmess { proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /trojan { proxy_pass http://127.0.0.1:10003; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /ss { proxy_pass http://127.0.0.1:10004; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    
    location ^~ /vless-grpc { grpc_pass grpc://127.0.0.1:10005; }
    location ^~ /vmess-grpc { grpc_pass grpc://127.0.0.1:10006; }
}
END

systemctl restart nginx
systemctl enable nginx

# ==========================================
# 7. SLOWDNS & BADVPN SETUP
# ==========================================
echo -e "${GREEN}[+] Configuring SlowDNS & BadVPN...${NC}"

wget -q -O /usr/bin/badvpn-udpgw "https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw64"
chmod +x /usr/bin/badvpn-udpgw

cat > /etc/systemd/system/badvpn-udpgw.service << END
[Unit]
Description=BadVPN UDPGW
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500
Restart=always
[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable --now badvpn-udpgw

wget -q -O /etc/slowdns/dnstt-server "https://raw.githubusercontent.com/Arya-Blitar22/st-pusat/main/slowdns/dnstt-server"
chmod +x /etc/slowdns/dnstt-server

echo "7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59" > /etc/slowdns/server.pub
echo "819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae" > /etc/slowdns/server.key

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

# ----- XRAY MANAGER FUNCTION -----
xray_menu() {
    PROTOCOL=$1
    while true; do
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 XRAY ${PROTOCOL^^} MANAGER                  ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "    [01] Create ${PROTOCOL^^} Account"
        echo -e "    [02] Create Trial Account"
        echo -e "    [03] Extend ${PROTOCOL^^} Account"
        echo -e "    [04] Delete ${PROTOCOL^^} Account"
        echo -e "    [05] Check User Login"
        echo -e "    [06] List ${PROTOCOL^^} Members"
        echo -e "    [07] Clean Expired Users (Manual)"
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "    [00] Back to Main Menu"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        read -p " Select : " x_opt
        
        if [[ "$x_opt" == "0" || "$x_opt" == "00" ]]; then break; fi
        
        if [[ "$x_opt" == "1" || "$x_opt" == "01" || "$x_opt" == "2" || "$x_opt" == "02" ]]; then
            clear
            echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}                 CREATE XRAY ${PROTOCOL^^} USER               ${NC}"
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            
            read -p " Username: " user
            if [[ "$x_opt" == "2" || "$x_opt" == "02" ]]; then
                days=1
                user="Trial-$user"
            else
                read -p " Days Active: " days
            fi
            
            UUID=$(uuidgen)
            EXP_DATE=$(date -d "$days days" +"%b %d, %Y")
            
            if [ "$PROTOCOL" == "vmess" ]; then
                jq ".inbounds[1].settings.clients += [{\"id\": \"${UUID}\", \"alterId\": 0, \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
                jq ".inbounds[5].settings.clients += [{\"id\": \"${UUID}\", \"alterId\": 0, \"email\": \"${user}\"}]" /tmp/xray.json > /tmp/xray2.json
            elif [ "$PROTOCOL" == "vless" ]; then
                jq ".inbounds[0].settings.clients += [{\"id\": \"${UUID}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
                jq ".inbounds[4].settings.clients += [{\"id\": \"${UUID}\", \"email\": \"${user}\"}]" /tmp/xray.json > /tmp/xray2.json
            elif [ "$PROTOCOL" == "trojan" ]; then
                jq ".inbounds[2].settings.clients += [{\"password\": \"${user}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray2.json
            elif [ "$PROTOCOL" == "shadowsocks" ]; then
                jq ".inbounds[3].settings.clients += [{\"password\": \"${UUID}\", \"method\": \"aes-128-gcm\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray2.json
            fi
            
            mv /tmp/xray2.json /usr/local/etc/xray/config.json
            systemctl restart xray
            
            echo -e " ${GREEN}${PROTOCOL^^} Account Created!${NC}"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            
            if [ "$PROTOCOL" == "trojan" ]; then 
                echo -e " Password: ${WHITE}${user}${NC}"
            else 
                echo -e " ID: ${WHITE}${UUID}${NC}"
            fi
            
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            
            if [ "$PROTOCOL" == "vmess" ]; then
                VM_TLS=$(cat <<EOF | base64 -w 0
{"v":"2","ps":"${user}","add":"${DOMAIN}","port":"443","id":"${UUID}","aid":"0","net":"ws","path":"/vmess","type":"none","host":"${DOMAIN}","tls":"tls"}
EOF
)
                VM_NTLS=$(cat <<EOF | base64 -w 0
{"v":"2","ps":"${user}","add":"${DOMAIN}","port":"80","id":"${UUID}","aid":"0","net":"ws","path":"/vmess","type":"none","host":"${DOMAIN}","tls":"none"}
EOF
)
                VM_GRPC=$(cat <<EOF | base64 -w 0
{"v":"2","ps":"${user}","add":"${DOMAIN}","port":"443","id":"${UUID}","aid":"0","net":"grpc","path":"vmess-grpc","type":"none","host":"${DOMAIN}","tls":"tls"}
EOF
)
                echo -e " ${GREEN}LINK TLS (Cloudflare/Standard) :${NC}"
                echo -e " ${WHITE}vmess://${VM_TLS}${NC}"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
                echo -e " ${GREEN}LINK NO-TLS (Port 80) :${NC}"
                echo -e " ${WHITE}vmess://${VM_NTLS}${NC}"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
                echo -e " ${GREEN}LINK gRPC (Cloudflare gRPC) :${NC}"
                echo -e " ${WHITE}vmess://${VM_GRPC}${NC}"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            
            elif [ "$PROTOCOL" == "vless" ]; then
                echo -e " ${GREEN}LINK TLS (Cloudflare/Standard) :${NC}"
                echo -e " ${WHITE}vless://${UUID}@${DOMAIN}:443?path=%2Fvless&security=tls&encryption=none&type=ws#${user}${NC}"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
                echo -e " ${GREEN}LINK NO-TLS (Port 80) :${NC}"
                echo -e " ${WHITE}vless://${UUID}@${DOMAIN}:80?path=%2Fvless&security=none&encryption=none&type=ws#${user}${NC}"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
                echo -e " ${GREEN}LINK gRPC (Cloudflare gRPC) :${NC}"
                echo -e " ${WHITE}vless://${UUID}@${DOMAIN}:443?security=tls&encryption=none&type=grpc&serviceName=vless-grpc#${user}${NC}"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            
            elif [ "$PROTOCOL" == "trojan" ]; then
                echo -e " ${GREEN}LINK TROJAN TLS :${NC}"
                echo -e " ${WHITE}trojan://${user}@${DOMAIN}:443?path=%2Ftrojan&security=tls&type=ws#${user}${NC}"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            
            elif [ "$PROTOCOL" == "shadowsocks" ]; then
                SS_BASE=$(echo -n "aes-128-gcm:${UUID}" | base64 -w 0)
                echo -e " ${GREEN}LINK SHADOWSOCKS TLS :${NC}"
                echo -e " ${WHITE}ss://${SS_BASE}@${DOMAIN}:443?path=%2Fss&security=tls&type=ws#${user}${NC}"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            fi
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$x_opt" == "4" || "$x_opt" == "04" ]]; then
            clear
            echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}                 DELETE XRAY ${PROTOCOL^^} USER               ${NC}"
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            read -p " Username to delete: " deluser
            
            if [ "$PROTOCOL" == "vmess" ]; then
                jq 'del(.inbounds[1].settings.clients[] | select(.email == "'$deluser'"))' /usr/local/etc/xray/config.json > /tmp/xray.json
                jq 'del(.inbounds[5].settings.clients[] | select(.email == "'$deluser'"))' /tmp/xray.json > /tmp/xray2.json
            elif [ "$PROTOCOL" == "vless" ]; then
                jq 'del(.inbounds[0].settings.clients[] | select(.email == "'$deluser'"))' /usr/local/etc/xray/config.json > /tmp/xray.json
                jq 'del(.inbounds[4].settings.clients[] | select(.email == "'$deluser'"))' /tmp/xray.json > /tmp/xray2.json
            elif [ "$PROTOCOL" == "trojan" ]; then
                jq 'del(.inbounds[2].settings.clients[] | select(.email == "'$deluser'"))' /usr/local/etc/xray/config.json > /tmp/xray2.json
            elif [ "$PROTOCOL" == "shadowsocks" ]; then
                jq 'del(.inbounds[3].settings.clients[] | select(.email == "'$deluser'"))' /usr/local/etc/xray/config.json > /tmp/xray2.json
            fi
            
            mv /tmp/xray2.json /usr/local/etc/xray/config.json
            systemctl restart xray
            echo -e " ${GREEN}User ${deluser} successfully deleted!${NC}"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$x_opt" == "6" || "$x_opt" == "06" ]]; then
            clear
            echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}                 LIST XRAY ${PROTOCOL^^} USERS              ${NC}"
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            grep -E '"email":' /usr/local/etc/xray/config.json | awk -F '"' '{print $4}' | sort | uniq
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
        else
            echo -e "${YELLOW}Feature pending integration!${NC}"
            sleep 1
        fi
    done
}

# ----- SSH MENU FUNCTION -----
ssh_menu() {
    while true; do
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 SSH/WS MANAGER                       ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "    [01] Create SSH Account"
        echo -e "    [02] Create Trial Account"
        echo -e "    [03] Extend SSH Account"
        echo -e "    [04] Delete SSH Account"
        echo -e "    [05] Check User Login"
        echo -e "    [06] List SSH Members"
        echo -e "    [07] Clean Expired Users"
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "    [00] Back to Main Menu"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        read -p " Select : " s_opt
        
        if [[ "$s_opt" == "0" || "$s_opt" == "00" ]]; then break; fi
        
        if [[ "$s_opt" == "1" || "$s_opt" == "01" ]]; then
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
            echo -e " Port UDPGW    : 7300"
            echo -e " Port SlowDNS  : 53"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            echo -e " ${GREEN}LINK WS / WSS (Port 80/443) :${NC}"
            echo -e " ${WHITE}GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$s_opt" == "4" || "$s_opt" == "04" ]]; then
            clear
            echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}                 DELETE SSH USER                      ${NC}"
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            read -p " Username to delete: " deluser
            userdel -r $deluser >/dev/null 2>&1
            echo -e " ${GREEN}User ${deluser} successfully deleted!${NC}"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
        else
            echo -e "${YELLOW}Feature pending integration!${NC}"
            sleep 1
        fi
    done
}

# ----- SETTINGS MENU FUNCTION -----
settings_menu() {
    while true; do
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 SERVER SETTINGS HUB                  ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "  [01] Speedtest VPS"
        echo -e "  [02] Info Ports"
        echo -e "  [03] Set Auto Reboot"
        echo -e "  [04] Server Health Check"
        echo -e "  [05] Restart All Services"
        echo -e "  [06] Change Domain / SSL Tools"
        echo -e "  [07] Check Bandwidth Usage"
        echo -e "  [08] SlowDNS Key Manager"
        echo -e "  [09] Install UDP Custom"
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
                read -n 1 -s -r -p "Press any key to return..."
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
                echo -e "  - SlowDNS (DNSTT)   : 53"
                echo -e "  - BadVPN UDPGW      : 7300"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
                echo -e " ${YELLOW}>> Server Status${NC}"
                echo -e "  - IP Address        : ${IPVPS}"
                echo -e "  - Domain            : ${DOMAIN}"
                echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            3|03)
                clear
                read -p " Reboot every how many hours? (e.g., 12): " hr
                echo "0 */$hr * * * root /sbin/reboot" > /etc/cron.d/auto_reboot
                echo -e "${GREEN} Auto-reboot set to every $hr hours.${NC}"
                sleep 2
                ;;
            4|04)
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
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            5|05)
                clear
                systemctl restart ssh dropbear stunnel4 ws-epro xray nginx slowdns badvpn-udpgw
                echo -e "${GREEN} All Core Services Restarted Successfully!${NC}"
                sleep 2
                ;;
            6|06)
                clear
                echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${CYAN}                 DOMAIN & SSL MANAGER                 ${NC}"
                echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
                read -p " Enter New Domain: " newdom
                echo "$newdom" > /etc/xray/domain
                sed -i "s/server_name .*/server_name $newdom;/g" /etc/nginx/conf.d/multiplexer.conf
                systemctl restart nginx
                echo -e "${GREEN} Domain updated successfully to $newdom${NC}"
                sleep 2
                ;;
            8|08)
                clear
                echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${CYAN}                 SLOWDNS KEY MANAGER                  ${NC}"
                echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
                echo -e "  [1] Switch to Global Key (Edufwesh Default)"
                echo -e "  [2] Generate Fresh Random Key"
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
                fi
                sleep 2
                ;;
            0|00) break ;;
        esac
    done
}

# ----- MAIN DASHBOARD VARIABLES -----
OS_INFO=$(cat /etc/os-release | grep -w PRETTY_NAME | cut -d= -f2 | tr -d '"')
UPTIME=$(uptime -p | cut -d " " -f 2-)
DATETIME=$(date "+%d-%m-%Y | %H:%M:%S")
RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
RAM_USED=$(free -m | awk 'NR==2{print $3}')

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
echo -e "${CYAN}               𝗘𝗱𝘂𝗳𝘄𝗲𝘀𝗵 𝗩𝗣𝗡 𝗠𝗔𝗡𝗔𝗚𝗘𝗥                   ${NC}"
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
echo -e "    [01] SSH MANAGER   [Menu]  [06] SHADOWSOCKS  [Menu]"
echo -e "    [02] VMESS MANAGER [Menu]  [07] OPENVPN / NOOBZVPN"
echo -e "    [03] VLESS MANAGER [Menu]  [08] SERVER SETTINGS"
echo -e "    [04] TROJAN MANAGER[Menu]  [09] CHECK RUNNING"
echo -e "    [05] XRAY gRPC     [Menu]  [00] EXIT SYSTEM"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}                 MONITORING BANDWIDTH                 ${NC}"
echo -e "${CYAN}├─────────────────────────────────────────────────────┤${NC}"
echo -e "   BANDWIDTH USED TODAY       = ${BW_TODAY}"
echo -e "   TOTAL BANDWIDTH THIS MONTH = ${BW_MONTH}"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
read -p " Select menu : " opt

case $opt in
    1|01) ssh_menu ;;
    2|02) xray_menu "vmess" ;;
    3|03) xray_menu "vless" ;;
    4|04) xray_menu "trojan" ;;
    6|06) xray_menu "shadowsocks" ;;
    5|05) 
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 XRAY gRPC MANAGER                    ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "    [01] Create VLESS gRPC"
        echo -e "    [02] Create VMESS gRPC"
        echo -e "    [00] Back to Main Menu"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        read -p " Select : " g_opt
        if [[ "$g_opt" == "1" || "$g_opt" == "01" ]]; then
            read -p " Username: " user
            UUID=$(uuidgen)
            jq ".inbounds[4].settings.clients += [{\"id\": \"${UUID}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
            mv /tmp/xray.json /usr/local/etc/xray/config.json
            systemctl restart xray
            echo -e " ${GREEN}VLESS gRPC Account Created!${NC}"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            echo -e " ID: ${WHITE}${UUID}${NC}"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
        elif [[ "$g_opt" == "2" || "$g_opt" == "02" ]]; then
            read -p " Username: " user
            UUID=$(uuidgen)
            jq ".inbounds[5].settings.clients += [{\"id\": \"${UUID}\", \"alterId\": 0, \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
            mv /tmp/xray.json /usr/local/etc/xray/config.json
            systemctl restart xray
            echo -e " ${GREEN}VMESS gRPC Account Created!${NC}"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            echo -e " ID: ${WHITE}${UUID}${NC}"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
        fi
        ;;
    7|07) 
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 OPENVPN & NOOBZVPN                   ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e " OpenVPN and NoobzVPN auto-installers are pending"
        echo -e " final binary integration in your GitHub repo."
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        read -n 1 -s -r -p "Press any key to return..."
        ;;
    8|08) settings_menu ;;
    9|09) 
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 SYSTEM STATUS CHECK                  ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        systemctl --type=service --state=running | grep -E "xray|nginx|stunnel4|ws-epro|dropbear|ssh|slowdns|badvpn|openvpn"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        read -n 1 -s -r -p "Press any key to return..."
        ;;
    0|00) clear; exit 0 ;;
    *) echo -e "\n${RED}Invalid Option!${NC}"; sleep 1 ;;
esac
done
END

chmod +x /usr/bin/menu

echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}Type 'menu' to access the expanded Dashboard.${NC}"
echo -e "${GREEN}======================================${NC}"
