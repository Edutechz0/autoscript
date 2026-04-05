#!/bin/bash

# ==========================================================
# EDUFWESH PREMIUM AUTO-INSTALLER (PRO V7 - MASTER FINAL)
# Nginx Multiplexer, Spacious UI, Global SlowDNS Key
# ==========================================================

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

clear
echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}       WELCOME TO EDUFWESH SCRIPT INSTALLER         ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo ""

read -p " [?] Enter your main Domain (e.g., vpn.server.com) : " MY_DOMAIN
read -p " [?] Enter your NS Domain (e.g., ns.server.com)    : " MY_NSDOMAIN

mkdir -p /etc/xray /etc/slowdns /etc/edufwesh
echo "$MY_DOMAIN" > /etc/xray/domain
echo "$MY_NSDOMAIN" > /etc/slowdns/nsdomain

timedatectl set-timezone Africa/Lagos
touch /root/reboot_log.txt

# 1. SYSTEM UPDATE & DEPENDENCIES
export DEBIAN_FRONTEND=noninteractive
echo -e "\n${GREEN}[+] Updating System & Installing Pro Dependencies...${NC}"
apt-get update -y && apt-get upgrade -y
apt-get install -y wget curl nano unzip ufw stunnel4 dropbear iptables nginx jq python3 uuid-runtime cron bc vnstat net-tools speedtest-cli

# 2. FIX SSH AUTHENTICATION FOR TUNNELING
echo -e "${GREEN}[+] Applying Shell Fixes for SSH Auth...${NC}"
echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells

systemctl enable --now vnstat
vnstat -u -i $(ip route | grep default | awk '{print $5}') > /dev/null 2>&1

cat >> /etc/sysctl.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p > /dev/null 2>&1

# 3. FIREWALL SETUP
echo -e "${GREEN}[+] Configuring Firewall Ports...${NC}"
ufw disable
for port in 22 80 443 777 7300; do ufw allow $port/tcp; done
ufw allow 53/udp
ufw --force enable

# 4. SSH & DROPBEAR SETUP
echo -e "${GREEN}[+] Configuring Core Tunnels...${NC}"
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart ssh

sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 143"/g' /etc/default/dropbear
systemctl restart dropbear

# 5. SSL & STUNNEL
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
accept = 777
connect = 127.0.0.1:109
END
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl restart stunnel4

# 6. PYTHON WEBSOCKET PROXY
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
server.bind(('127.0.0.1', 8880))
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

# 7. XRAY CORE
echo -e "${GREEN}[+] Installing Xray Core...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
cat > /usr/local/etc/xray/config.json << END
{
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
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
END
systemctl restart xray && systemctl enable xray

# 8. NGINX MULTIPLEXER
echo -e "${GREEN}[+] Configuring Nginx Multiplexer...${NC}"
rm /etc/nginx/sites-enabled/default
cat > /etc/nginx/conf.d/multiplexer.conf << END
server {
    listen 80;
    server_name $MY_DOMAIN;
    location / {
        proxy_redirect off;
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
    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    location /edufwesh-vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    location /edufwesh-vmess {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    location /edufwesh-trojan {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
END
systemctl restart nginx && systemctl enable nginx

# 9. SLOWDNS (DNSTT) SETUP WITH GLOBAL KEY
echo -e "${GREEN}[+] Configuring SlowDNS...${NC}"
wget -q -O /etc/slowdns/dnstt-server "https://raw.githubusercontent.com/Arya-Blitar22/st-pusat/main/slowdns/dnstt-server"
chmod +x /etc/slowdns/dnstt-server

# Injecting Global Key as Default
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
systemctl daemon-reload && systemctl enable --now slowdns

# 10. THE MASTER UI DASHBOARD & SETTINGS MENU
echo -e "${GREEN}[+] Compiling Premium Dashboard & Settings Hub...${NC}"
cat > /usr/bin/menu << 'END'
#!/bin/bash
NC='\e[0m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'

DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
NSDOM=$(cat /etc/slowdns/nsdomain 2>/dev/null)
IPVPS=$(curl -s ipv4.icanhazip.com)
PUBKEY=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "Key Not Found")

# ----- SETTINGS MENU FUNCTION -----
settings_menu() {
    while true; do
        clear
        echo -e "${CYAN}====================================================${NC}"
        echo -e "${YELLOW}                 SERVER SETTINGS HUB                ${NC}"
        echo -e "${CYAN}====================================================${NC}"
        echo -e " [01] Speedtest VPS"
        echo -e " [02] Info Ports"
        echo -e " [03] Set Auto Reboot (Hours Interval)"
        echo -e " [04] Set Auto Reboot (Specific WAT Time)"
        echo -e " [05] View Server Reboot Log"
        echo -e " [06] Restart All Services"
        echo -e " [07] Change Login Banner"
        echo -e " [08] Check Bandwidth Usage"
        echo -e " [09] Server Health Check"
        echo -e " [10] SlowDNS Key Manager"
        echo -e ""
        echo -e " [00] Back to Main Dashboard"
        echo -e "${CYAN}====================================================${NC}"
        read -p " Select option : " set_opt

        case $set_opt in
            1|01) clear; echo -e "${YELLOW}Running Speedtest...${NC}"; speedtest-cli ;;
            2|02) clear; echo -e "${YELLOW}Active Listening Ports:${NC}"; netstat -tulpn | grep LISTEN ;;
            3|03) 
                read -p " Reboot every how many hours? (e.g., 12): " hr
                echo "0 */$hr * * * root /sbin/reboot" > /etc/cron.d/auto_reboot
                echo -e "${GREEN}Auto-reboot set to every $hr hours.${NC}"
                ;;
            4|04) 
                read -p " Enter hour for daily reboot (0-23 WAT): " hr
                echo "0 $hr * * * root /sbin/reboot" > /etc/cron.d/auto_reboot
                echo -e "${GREEN}Auto-reboot set for $hr:00 WAT daily.${NC}"
                ;;
            5|05) clear; echo -e "${YELLOW}Recent Reboots:${NC}"; last reboot | head -n 10 ;;
            6|06) 
                echo -e "${YELLOW}Restarting all core services...${NC}"
                systemctl restart ssh dropbear stunnel4 ws-proxy xray nginx slowdns
                echo -e "${GREEN}Services Restarted!${NC}"
                ;;
            7|07) 
                nano /etc/issue.net
                echo -e "${GREEN}Banner Updated!${NC}"
                ;;
            8|08) clear; vnstat ;;
            9|09) 
                clear; echo -e "${CYAN}--- Server Health ---${NC}"
                uptime
                free -h
                df -h | grep '^/dev/'
                ;;
            10) 
                clear
                echo -e "${YELLOW}--- SlowDNS Key Manager ---${NC}"
                echo -e " [1] Switch to Global Key (Edufwesh Default)"
                echo -e " [2] Generate Fresh Random Key"
                echo -e " [3] Input Custom Key Pair"
                echo -e "${CYAN}====================================================${NC}"
                read -p " Select : " dns_opt
                
                GLOBAL_PUB="7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59"
                GLOBAL_PRIV="819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae"

                if [ "$dns_opt" == "1" ]; then
                    echo "$GLOBAL_PUB" > /etc/slowdns/server.pub
                    echo "$GLOBAL_PRIV" > /etc/slowdns/server.key
                    systemctl restart slowdns
                    echo -e "${GREEN}Switched to Global Key & Service Restarted!${NC}"
                elif [ "$dns_opt" == "2" ]; then
                    cd /etc/slowdns
                    rm -f server.pub server.key
                    ./dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub
                    systemctl restart slowdns
                    echo -e "${GREEN}New Random Keys Generated & Service Restarted!${NC}"
                elif [ "$dns_opt" == "3" ]; then
                    echo -e "${RED}Warning: You must have BOTH the Private and Public key.${NC}"
                    read -p " Paste Public Key: " in_pub
                    read -p " Paste Private Key: " in_priv
                    echo "$in_pub" > /etc/slowdns/server.pub
                    echo "$in_priv" > /etc/slowdns/server.key
                    systemctl restart slowdns
                    echo -e "${GREEN}Custom Keys Saved & Service Restarted!${NC}"
                else
                    echo -e "${RED}Invalid Option${NC}"
                fi
                ;;
            0|00) break ;;
            *) echo -e "${RED}Invalid Option${NC}" ;;
        esac
        echo -e ""
        read -n 1 -s -r -p "Press any key to return to settings..."
    done
}

# ----- MAIN MENU DASHBOARD -----
OS_INFO=$(cat /etc/os-release | grep -w PRETTY_NAME | cut -d= -f2 | tr -d '"')
UPTIME=$(uptime -p | cut -d " " -f 2-)
DATETIME=$(date "+%d-%m-%Y | %H:%M:%S")
RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
RAM_USED=$(free -m | awk 'NR==2{print $3}')
RAM_FREE=$(free -m | awk 'NR==2{print $4}')
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

check_status() { systemctl is-active --quiet $1 && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"; }
STS_SSH=$(check_status ssh); STS_NGX=$(check_status nginx); STS_XRY=$(check_status xray)
STS_DPB=$(check_status dropbear); STS_WSP=$(check_status ws-proxy); STS_DNS=$(check_status slowdns)

IFACE=$(ip route | grep default | awk '{print $5}')
BW_TODAY=$(vnstat -i $IFACE -d --oneline | awk -F\; '{print $4}' | sed 's/ //g')
BW_MONTH=$(vnstat -i $IFACE -m --oneline | awk -F\; '{print $11}' | sed 's/ //g')

SSH_C=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)
VLS_C=$(grep -c "id" /usr/local/etc/xray/config.json)

while true; do
clear
echo -e "${BLUE}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${NC}             ${CYAN}EDUFWESH MASTER CONTROL PANEL${NC}                  ${BLUE}│${NC}"
echo -e "${BLUE}├────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC} ${YELLOW}WA: +234 916 921 2134${NC}   |   ${YELLOW}TG: @EDUFWESH3${NC}               ${BLUE}│${NC}"
echo -e "${BLUE}├────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC} Client       : ${WHITE}Edufwesh${NC}                                   ${BLUE}│${NC}"
echo -e "${BLUE}│${NC} OS           : ${WHITE}${OS_INFO}${NC}"
echo -e "${BLUE}│${NC} Server IP    : ${WHITE}${IPVPS}${NC}                                  ${BLUE}│${NC}"
echo -e "${BLUE}│${NC} Domain       : ${WHITE}${DOMAIN}${NC}"
echo -e "${BLUE}│${NC} Uptime       : ${WHITE}${UPTIME}${NC}"
echo -e "${BLUE}│${NC} System Time  : ${WHITE}${DATETIME}${NC}"
echo -e "${BLUE}│${NC} RAM Usage    : ${WHITE}${RAM_USED} MB / ${RAM_TOTAL} MB (Free: ${RAM_FREE} MB)${NC}"
echo -e "${BLUE}│${NC} CPU Load     : ${WHITE}${CPU_USAGE} %${NC}"
echo -e "${BLUE}├────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC} ${GREEN}SERVICES:${NC} SSH [${STS_SSH}] | NGINX [${STS_NGX}] | XRAY [${STS_XRY}] | DNS [${STS_DNS}] ${BLUE}│${NC}"
echo -e "${BLUE}├────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC} ${GREEN}[01]${NC} Add SSH/WS User        ${GREEN}[04]${NC} Server Settings          ${BLUE}│${NC}"
echo -e "${BLUE}│${NC} ${GREEN}[02]${NC} Add Xray VLess         ${GREEN}[05]${NC} Delete Users             ${BLUE}│${NC}"
echo -e "${BLUE}│${NC} ${GREEN}[03]${NC} Add Xray VMess         ${GREEN}[00]${NC} Exit Dashboard           ${BLUE}│${NC}"
echo -e "${BLUE}├────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC} ${YELLOW}BANDWIDTH MONITORING:${NC}                                      ${BLUE}│${NC}"
echo -e "${BLUE}│${NC} Data Used Today: ${WHITE}${BW_TODAY}${NC} | Data This Month: ${WHITE}${BW_MONTH}${NC}      ${BLUE}│${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────┘${NC}"
read -p " Select menu : " opt

case $opt in
    1|01)
        clear
        echo -e "${CYAN}--- Create SSH/WS User ---${NC}"
        echo -e ""
        read -p " Username    : " user
        read -p " Password    : " pass
        read -p " Days Active : " days
        useradd -e $(date -d "$days days" +"%Y-%m-%d") -s /bin/false -M $user
        echo -e "$pass\n$pass" | passwd $user >/dev/null 2>&1
        EXP_DATE=$(date -d "$days days" +"%b %d, %Y")
        
        clear
        echo -e "${BLUE}========================================================${NC}"
        echo -e "${YELLOW}                 PREMIUM SSH WS ACCOUNT                 ${NC}"
        echo -e "${BLUE}========================================================${NC}"
        echo -e ""
        echo -e "${GREEN}Username      :${NC} ${WHITE}$user${NC}"
        echo -e "${GREEN}Password      :${NC} ${WHITE}$pass${NC}"
        echo -e "${GREEN}Max Login     :${NC} ${WHITE}2 Device(s)${NC}"
        echo -e ""
        echo -e "${BLUE}========================================================${NC}"
        echo -e "${YELLOW}                   SERVER INFORMATION                   ${NC}"
        echo -e "${BLUE}========================================================${NC}"
        echo -e ""
        echo -e "${GREEN}IP            :${NC} ${WHITE}${IPVPS}${NC}"
        echo -e "${GREEN}Host          :${NC} ${WHITE}${DOMAIN}${NC}"
        echo -e "${GREEN}Nameserver    :${NC} ${WHITE}${NSDOM}${NC}"
        echo -e "${GREEN}PubKey        :${NC} ${WHITE}${PUBKEY}${NC}"
        echo -e "${GREEN}OpenSSH       :${NC} ${WHITE}22, 2253${NC}"
        echo -e "${GREEN}SSH-WS        :${NC} ${WHITE}80, 8080${NC}"
        echo -e "${GREEN}SSH-SSL-WS    :${NC} ${WHITE}443, 8443${NC}"
        echo -e "${GREEN}Dropbear      :${NC} ${WHITE}109, 143${NC}"
        echo -e "${GREEN}Stunnel4      :${NC} ${WHITE}777${NC}"
        echo -e "${GREEN}UDPGW         :${NC} ${WHITE}7300${NC}"
        echo -e ""
        echo -e "${BLUE}========================================================${NC}"
        echo -e ""
        echo -e "${GREEN}SSH-80        :${NC} ${WHITE}${DOMAIN}:80@${user}:${pass}${NC}"
        echo -e "${GREEN}SSH-443       :${NC} ${WHITE}${DOMAIN}:443@${user}:${pass}${NC}"
        echo -e ""
        echo -e "${BLUE}========================================================${NC}"
        echo -e "${GREEN}Expired On    :${NC} ${RED}${EXP_DATE}${NC}"
        echo -e "${BLUE}========================================================${NC}"
        echo -e ""
        echo -e "${GREEN}(Payload WSS)${NC}"
        echo -e "${WHITE}GET wss://bug.com [protocol][crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
        echo -e ""
        echo -e "${GREEN}(Payload WS)${NC}"
        echo -e "${WHITE}GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
        echo -e ""
        echo -e "${BLUE}========================================================${NC}"
        ;;
    2|02)
        echo -e "\n${CYAN}--- Create VLess User ---${NC}"
        read -p " Username: " user
        UUID=$(uuidgen)
        jq ".inbounds[0].settings.clients += [{\"id\": \"${UUID}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
        mv /tmp/xray.json /usr/local/etc/xray/config.json
        systemctl restart xray
        echo -e "\n${GREEN}VLess Account Created!${NC}"
        echo -e "Link: ${CYAN}vless://${UUID}@${DOMAIN}:443?path=%2Fedufwesh-vless&security=tls&encryption=none&type=ws#${user}${NC}"
        ;;
    3|03)
        echo -e "\n${CYAN}--- Create VMess User ---${NC}"
        read -p " Username: " user
        UUID=$(uuidgen)
        jq ".inbounds[1].settings.clients += [{\"id\": \"${UUID}\", \"alterId\": 0, \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
        mv /tmp/xray.json /usr/local/etc/xray/config.json
        systemctl restart xray
        echo -e "\n${GREEN}VMess Account Created!${NC}"
        cat <<EOF
{
  "v": "2", "ps": "${user}", "add": "${DOMAIN}", "port": "443", "id": "${UUID}",
  "aid": "0", "net": "ws", "path": "/edufwesh-vmess", "type": "none",
  "host": "${DOMAIN}", "tls": "tls"
}
EOF
        ;;
    4|04) settings_menu ;;
    5|05)
        read -p " Enter SSH Username to delete: " deluser
        userdel -r $deluser >/dev/null 2>&1
        echo -e "${GREEN}User $deluser deleted!${NC}"
        ;;
    0|00) clear; exit 0 ;;
    *) echo -e "\n${RED}Invalid Option!${NC}" ;;
esac
echo -e ""
read -n 1 -s -r -p "Press any key to return to menu..."
done
END
chmod +x /usr/bin/menu

echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}Type 'menu' to access the Pro Dashboard.${NC}"
echo -e "${GREEN}======================================${NC}"
