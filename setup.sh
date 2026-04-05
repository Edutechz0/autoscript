#!/bin/bash

# ==========================================
# EDUFWESH PREMIUM AUTO-INSTALLER (MASTER)
# SSH, WS, Xray, SlowDNS, Hysteria 1 & 2
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

# Save domains for future use
mkdir -p /etc/xray /etc/slowdns /etc/hysteria
echo "$MY_DOMAIN" > /etc/xray/domain
echo "$MY_NSDOMAIN" > /etc/slowdns/nsdomain

echo -e "\n${GREEN}[+] Domains saved! Starting system setup...${NC}"

# 2. SYSTEM UPDATE & DEPENDENCIES
export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get upgrade -y
apt-get install -y wget curl nano unzip ufw stunnel4 dropbear iptables squid jq python3

# 3. FIREWALL SETUP (Adding Hysteria UDP Ports)
ufw disable
# TCP Ports (SSH, Xray, Squid)
for port in 22 109 143 443 777 2253 8080 3128 80 2052 2053 2082 2083 2086 2087 2095 2096 8443 7300; do
    ufw allow $port/tcp
done
# UDP Ports (SlowDNS, Hysteria 1, Hysteria 2)
for port in 53 3666 5666; do
    ufw allow $port/udp
done
ufw --force enable

# 4. SSH, DROPBEAR, STUNNEL & SQUID SETUP
sed -i 's/#Port 22/Port 22\nPort 2253/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart ssh

sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 143"/g' /etc/default/dropbear
systemctl restart dropbear

# Generate global Self-Signed Cert using your domain
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
END
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl restart stunnel4

# 5. PYTHON WEBSOCKET PROXY (Port 80)
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

# 6. SLOWDNS (DNSTT) SETUP
wget -q -O /etc/slowdns/dnstt-server "https://raw.githubusercontent.com/Arya-Blitar22/st-pusat/main/slowdns/dnstt-server"
chmod +x /etc/slowdns/dnstt-server
cd /etc/slowdns
./dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub > /dev/null 2>&1
cat > /etc/systemd/system/slowdns.service << END
[Unit]
Description=SlowDNS Server
[Service]
WorkingDirectory=/etc/slowdns
ExecStart=/etc/slowdns/dnstt-server -udp :53 -privkey-file server.key ${MY_NSDOMAIN} 127.0.0.1:22
Restart=always
[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload && systemctl enable --now slowdns

# 7. HYSTERIA 1 & 2 SETUP
echo -e "${GREEN}[+] Installing Hysteria 1 & 2...${NC}"
# Hysteria 1 (Listening on UDP 3666)
wget -q -O /usr/local/bin/hysteria1 "https://github.com/apernet/hysteria/releases/download/v1.3.5/hysteria-linux-amd64"
chmod +x /usr/local/bin/hysteria1
cat > /etc/hysteria/config_v1.json << END
{
  "listen": ":3666",
  "cert": "/etc/stunnel/stunnel.pem",
  "key": "/etc/stunnel/stunnel.pem",
  "obfs": "edufwesh"
}
END
cat > /etc/systemd/system/hysteria1.service << END
[Unit]
Description=Hysteria 1
[Service]
ExecStart=/usr/local/bin/hysteria1 server -c /etc/hysteria/config_v1.json
Restart=always
[Install]
WantedBy=multi-user.target
END

# Hysteria 2 (Listening on UDP 5666)
wget -q -O /usr/local/bin/hysteria2 "https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
chmod +x /usr/local/bin/hysteria2
cat > /etc/hysteria/config_v2.yaml << END
listen: :5666
tls:
  cert: /etc/stunnel/stunnel.pem
  key: /etc/stunnel/stunnel.pem
obfs:
  type: salamander
  salamander:
    password: edufwesh
END
cat > /etc/systemd/system/hysteria2.service << END
[Unit]
Description=Hysteria 2
[Service]
ExecStart=/usr/local/bin/hysteria2 server -c /etc/hysteria/config_v2.yaml
Restart=always
[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload
systemctl enable --now hysteria1
systemctl enable --now hysteria2

# 8. THE INTERACTIVE MENU
cat > /usr/bin/menu << 'END'
#!/bin/bash
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}             EDUFWESH PREMIUM SERVER                ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e "${YELLOW}  WA: +234 916 921 2134  |  TG: @EDUFWESH3          ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e " [1] Add SSH/WS User"
echo -e " [2] Add Xray User (VLess/VMess/Trojan)"
echo -e " [3] Add Hysteria User"
echo -e " [4] Check System Services"
echo -e " [5] Show SlowDNS Public Key"
echo -e " [6] Reboot Server"
echo -e " [0] Exit"
echo -e "${CYAN}====================================================${NC}"
read -p " Select an option [0-6]: " option

case $option in
    1) read -p "Username: " user; read -p "Password: " pass; useradd -s /bin/false -M $user; echo -e "$pass\n$pass" | passwd $user >/dev/null 2>&1; echo "SSH/WS User $user created!";;
    2) echo -e "${YELLOW}Xray account script pending integration.${NC}";;
    3) echo -e "${YELLOW}Hysteria uses global passwords in this version. Check configs!${NC}";;
    4) echo -e "${CYAN}--- Service Status ---${NC}"; systemctl is-active --quiet stunnel4 && echo -e "Stunnel: ${GREEN}Online${NC}" || echo -e "Stunnel: ${RED}Offline${NC}"; systemctl is-active --quiet hysteria2 && echo -e "Hysteria 2: ${GREEN}Online${NC}" || echo -e "Hysteria 2: ${RED}Offline${NC}"; systemctl is-active --quiet slowdns && echo -e "SlowDNS: ${GREEN}Online${NC}" || echo -e "SlowDNS: ${RED}Offline${NC}";;
    5) echo -e "${GREEN}Your SlowDNS PubKey for the client is:${NC}"; cat /etc/slowdns/server.pub;;
    6) reboot;;
    0) exit 0;;
    *) echo -e "${RED}Invalid option!${NC}";;
esac
END
chmod +x /usr/bin/menu

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}Domain Linked: ${MY_DOMAIN}${NC}"
echo -e "${GREEN}NS Domain Linked: ${MY_NSDOMAIN}${NC}"
echo -e "${GREEN}Type 'menu' to access the control panel.${NC}"
echo -e "${GREEN}======================================${NC}"
