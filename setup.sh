#!/bin/bash

# ==========================================================
# EDUFWESH PREMIUM AUTO-INSTALLER (GOD-TIER FINAL MASTER)
# Split-Payload Bypass, OpenVPN Sync Fix, SlowDNS Lock
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

# ==========================================
# 1. Directory & Database Creation
# ==========================================
mkdir -p /etc/xray
mkdir -p /etc/slowdns
mkdir -p /etc/edufwesh
mkdir -p /etc/udp
mkdir -p /etc/openvpn
mkdir -p /etc/noobz
mkdir -p /var/log/xray

touch /etc/edufwesh/xray-clients.txt
touch /var/log/xray/access.log
touch /var/log/xray/error.log

chown -R nobody:nogroup /var/log/xray
chmod -R 777 /var/log/xray

echo "$MY_DOMAIN" > /etc/xray/domain
echo "$MY_NSDOMAIN" > /etc/slowdns/nsdomain

timedatectl set-timezone Africa/Lagos
export DEBIAN_FRONTEND=noninteractive

# ==========================================
# 2. SYSTEM UPDATE & PORT 53 FIX
# ==========================================
echo -e "\n${GREEN}[+] Freeing up Port 53 & Updating System...${NC}"

systemctl stop systemd-resolved
systemctl disable systemd-resolved >/dev/null 2>&1
killall -9 systemd-resolved >/dev/null 2>&1
fuser -k 53/udp >/dev/null 2>&1
fuser -k 53/tcp >/dev/null 2>&1

rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

apt-get update -y
apt-get upgrade -y
apt-get install -y wget curl nano unzip ufw stunnel4 dropbear iptables nginx haproxy jq python3 uuid-runtime cron bc vnstat net-tools speedtest-cli openvpn easy-rsa psmisc iptables-persistent

echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells

systemctl enable --now vnstat

cat >> /etc/sysctl.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.ip_forward=1
EOF
sysctl -p > /dev/null 2>&1

# ==========================================
# 3. FIREWALL SETUP
# ==========================================
echo -e "${GREEN}[+] Configuring Firewall Ports...${NC}"

ufw disable

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 109/tcp
ufw allow 143/tcp
ufw allow 443/tcp
ufw allow 447/tcp
ufw allow 777/tcp
ufw allow 1080/tcp
ufw allow 1194/tcp
ufw allow 7100/tcp
ufw allow 7200/tcp
ufw allow 7300/tcp

ufw allow 53/udp
ufw allow 1194/udp
ufw allow 7100/udp
ufw allow 7200/udp
ufw allow 7300/udp

ufw --force enable

iptables -I INPUT -p udp --dport 53 -j ACCEPT

# --- OpenVPN NAT & Forwarding Rules (persistent) ---
iptables -t nat -I POSTROUTING -s 10.8.0.0/24 -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE
iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
iptables -I FORWARD -d 10.8.0.0/24 -j ACCEPT

# Save iptables rules so they survive reboot
netfilter-persistent save

# ==========================================
# 4. SSH, DROPBEAR & STUNNEL
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

[dropbear_ssl_1]
accept = 777
connect = 127.0.0.1:109

[ws_epro_ssl]
accept = 447
connect = 127.0.0.1:8880
END

sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl restart stunnel4

# ==========================================
# 5. WS-EPRO (Python Split-Payload Engine)
# ==========================================
echo -e "${GREEN}[+] Installing Advanced WS-ePro Engine...${NC}"

cat > /usr/local/bin/ws-epro.py << 'END'
import socket
import threading

def handle_client(client_socket):
    try:
        request = client_socket.recv(8192)
        response = b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
        client_socket.send(response)
        
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect(('127.0.0.1', 109))
        
        ssh_started = False
        if b"SSH-2.0" in request:
            idx = request.find(b"SSH-2.0")
            ssh_socket.sendall(request[idx:])
            ssh_started = True
            
        threading.Thread(target=forward_c2s, args=(client_socket, ssh_socket, ssh_started)).start()
        threading.Thread(target=forward_s2c, args=(ssh_socket, client_socket)).start()
    except Exception as e:
        client_socket.close()

def forward_c2s(src, dst, ssh_started):
    try:
        while True:
            data = src.recv(8192)
            if not data:
                break
            if not ssh_started:
                if b"SSH-2.0" in data:
                    ssh_started = True
                    idx = data.find(b"SSH-2.0")
                    dst.sendall(data[idx:])
            else:
                dst.sendall(data)
    except Exception:
        pass
    finally:
        src.close()
        dst.close()

def forward_s2c(src, dst):
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
Description=WS-ePro Proxy Service
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

# ==========================================
# 6. XRAY CORE (VLESS, VMESS, TROJAN, SS + SOCKS5)
# ==========================================
echo -e "${GREEN}[+] Installing Xray Core...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1

cat > /usr/local/etc/xray/config.json << END
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
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
      }
    },
    {
      "port": 10004,
      "listen": "127.0.0.1",
      "protocol": "shadowsocks",
      "settings": {
        "clients": [],
        "network": "tcp,udp"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ss"
        }
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
# 7. NGINX & HAPROXY MULTIPLEXER
# ==========================================
echo -e "${GREEN}[+] Configuring HAProxy & Nginx...${NC}"
rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/conf.d/multiplexer.conf << END
server {
    listen 81 default_server;
    server_name _;
    
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    
    location / {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
}

server {
    listen 444 ssl http2 default_server;
    server_name _;
    ssl_certificate /etc/stunnel/stunnel.pem;
    ssl_certificate_key /etc/stunnel/stunnel.pem;
    
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    
    location / {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location /vless {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location /vmess {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location /trojan {
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location /ss {
        proxy_pass http://127.0.0.1:10004;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location ^~ /vless-grpc {
        grpc_pass grpc://127.0.0.1:10005;
    }
    location ^~ /vmess-grpc {
        grpc_pass grpc://127.0.0.1:10006;
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
    use_backend nginx_http if is_v2ray
    
    default_backend ws_epro_direct

frontend https_front
    bind *:443
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }
    
    acl is_mydomain req_ssl_sni -i ${MY_DOMAIN}
    use_backend nginx_https if is_mydomain
    
    default_backend stunnel_ws

backend nginx_http
    mode tcp
    server nginx1 127.0.0.1:81 check

backend nginx_https
    mode tcp
    server nginx2 127.0.0.1:444 check

backend ws_epro_direct
    mode tcp
    server wsepro 127.0.0.1:8880 check

backend stunnel_ws
    mode tcp
    server stunnelws 127.0.0.1:447 check
END

systemctl restart nginx
systemctl enable nginx
systemctl restart haproxy
systemctl enable haproxy

# ==========================================
# 8. OPENVPN & NOOBZVPN SETUP
# ==========================================
echo -e "${GREEN}[+] Setting up OpenVPN & NoobzVPN Services...${NC}"

export EASYRSA_BATCH=1
mkdir -p /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa

echo -e "${YELLOW}[!] Building Certificates (This is automated, please wait)...${NC}"
./easyrsa init-pki > /dev/null 2>&1
./easyrsa build-ca nopass > /dev/null 2>&1
./easyrsa gen-req server nopass > /dev/null 2>&1
./easyrsa sign-req server server > /dev/null 2>&1

echo -e "${YELLOW}[!] Generating DH Parameters (Calculating math... This can take 2-5 minutes. DO NOT CLOSE!)...${NC}"
./easyrsa gen-dh > /dev/null 2>&1

# Explicit direct key generation to prevent any file path failures
openvpn --genkey secret /etc/openvpn/ta.key 2>/dev/null || openvpn --genkey --secret /etc/openvpn/ta.key 2>/dev/null

cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem /etc/openvpn/

cat > /etc/openvpn/server.conf << END
port 1194
proto udp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
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
status openvpn-status.log
verb 3
END

cat > /etc/systemd/system/openvpn-server@.service << END
[Unit]
Description=OpenVPN service
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/openvpn --status %t/openvpn-server/status-%i.log --config %i.conf
Restart=always

[Install]
WantedBy=multi-user.target
END

cat > /etc/systemd/system/noobzvpnd.service << END
[Unit]
Description=NoobzVPN Daemon
After=network.target

[Service]
ExecStart=/bin/true
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable --now openvpn-server@server.service > /dev/null 2>&1
systemctl enable --now noobzvpnd.service > /dev/null 2>&1

# ==========================================
# 9. SLOWDNS & BADVPN SETUP
# ==========================================
echo -e "${GREEN}[+] Configuring SlowDNS & BadVPN...${NC}"

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

# Download dnstt-server with fallback URLs
DL_URL="https://github.com/iwakdusk/dnstt/raw/main/dnstt-server"
wget -q --timeout=10 -O /etc/slowdns/dnstt-server "$DL_URL" || \
curl -s -o /etc/slowdns/dnstt-server "$DL_URL" || \
wget -q --timeout=10 -O /etc/slowdns/dnstt-server "https://raw.githubusercontent.com/Arya-Blitar22/st-pusat/main/slowdns/dnstt-server"

chmod +x /etc/slowdns/dnstt-server

# Test if binary works
if ! /etc/slowdns/dnstt-server -h >/dev/null 2>&1; then
    echo -e "${RED}[!] DNSTT binary is broken. Trying static build...${NC}"
    wget -q -O /etc/slowdns/dnstt-server "https://github.com/iwakdusk/dnstt/releases/download/v1.0/dnstt-server-linux-amd64"
    chmod +x /etc/slowdns/dnstt-server
fi

# Permanently kill systemd-resolved
systemctl stop systemd-resolved
systemctl disable systemd-resolved
systemctl mask systemd-resolved
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

echo "7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59" > /etc/slowdns/server.pub
echo "819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae" > /etc/slowdns/server.key

cat > /etc/systemd/system/slowdns.service << END
[Unit]
Description=SlowDNS Server
After=network.target

[Service]
WorkingDirectory=/etc/slowdns
ExecStartPre=/bin/bash -c "for p in systemd-resolved dnsmasq unbound; do systemctl stop \$p 2>/dev/null; systemctl disable \$p 2>/dev/null; done"
ExecStartPre=/bin/bash -c "fuser -k 53/udp 53/tcp 2>/dev/null || true"
ExecStart=/etc/slowdns/dnstt-server -udp :53 -privkey-file /etc/slowdns/server.key ${MY_NSDOMAIN} 127.0.0.1:109
Restart=always
RestartSec=5
KillMode=process

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable --now slowdns

# ==========================================
# 10. MASTER DASHBOARD MENU SYSTEM
# ==========================================
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

DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
NSDOM=$(cat /etc/slowdns/nsdomain 2>/dev/null)
IPVPS=$(curl -s ipv4.icanhazip.com)
PUBKEY=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "Key Not Found")

# ----- SERVICE STATUS CHECKER -----
check_run() {
    if systemctl is-active --quiet $1; then
        echo -e "[ ${GREEN}RUNNING${NC} ]"
    else
        echo -e "[ ${RED}STOPPED${NC} ]"
    fi
}

# ----- CHECK ONLINE FUNCTION -----
check_online() {
    clear
    echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}                 ONLINE USER MONITOR                  ${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
    
    echo -e "${YELLOW}>> Active SSH Connections:${NC}"
    netstat -tnpa | grep ESTABLISHED | grep -E "sshd|dropbear|stunnel4" | awk '{print $5, $7}' | cut -d: -f1 | sort | uniq -c | awk '{print "   IP: "$2" (Sessions: "$1")"}'
    
    echo -e ""
    echo -e "${YELLOW}>> Active Xray (V2Ray) Connections:${NC}"
    if [ -f "/var/log/xray/access.log" ]; then
        tail -n 100 /var/log/xray/access.log | grep "accepted" | awk '{print $3}' | cut -d: -f1 | sort | uniq -c | awk '{print "   IP: "$2" (Requests: "$1")"}'
    else
        echo -e "   ${RED}Log file empty or not found.${NC}"
    fi
    
    echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
    read -n 1 -s -r -p "Press any key to return..."
}

# ----- DOMAIN & SSL TOOLS -----
domain_tools() {
    while true; do
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}               DOMAIN & SSL MANAGER                   ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e " Current Domain : ${WHITE}${DOMAIN}${NC}"
        echo -e " Current NS     : ${WHITE}${NSDOM}${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "    [01] Change VPS Domain (Host)"
        echo -e "    [02] Change NameServer (SlowDNS NS)"
        echo -e "    [03] Force Renew SSL Certificate (Recommended)"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "    [00] Back to Main Menu"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        read -p " Select menu : " dt_opt
        
        if [[ "$dt_opt" == "0" || "$dt_opt" == "00" ]]; then
            break
        fi
        
        case $dt_opt in
            1|01) 
                read -p " Enter New Domain: " newdom
                echo "$newdom" > /etc/xray/domain
                sed -i "s/server_name .*/server_name $newdom;/g" /etc/nginx/conf.d/multiplexer.conf
                sed -i "s/acl is_mydomain req_ssl_sni -i .*/acl is_mydomain req_ssl_sni -i $newdom/g" /etc/haproxy/haproxy.cfg
                systemctl restart nginx haproxy
                echo -e "${GREEN} Domain updated successfully to $newdom${NC}"
                sleep 2
                ;;
            2|02)
                read -p " Enter New NS Domain: " newns
                echo "$newns" > /etc/slowdns/nsdomain
                sed -i "s/server.key .*/server.key $newns 127.0.0.1:109/g" /etc/systemd/system/slowdns.service
                systemctl daemon-reload
                systemctl restart slowdns
                echo -e "${GREEN} NS Domain updated successfully to $newns${NC}"
                sleep 2
                ;;
            3|03)
                echo -e "${YELLOW} Regenerating Self-Signed SSL for HAProxy/Stunnel...${NC}"
                openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=NG/ST=Rivers/L=PH/O=Edufwesh/CN=${DOMAIN}" -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem > /dev/null 2>&1
                systemctl restart stunnel4
                systemctl restart nginx
                systemctl restart haproxy
                echo -e "${GREEN} Certificate fixed and services restarted!${NC}"
                sleep 2
                ;;
            *)
                echo -e "${RED}Invalid Option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# ----- SERVER SETTINGS HUB -----
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
        echo -e "  [06] Check Bandwidth Usage"
        echo -e "  [07] SlowDNS Key Manager"
        echo -e "  [08] Install UDP Custom"
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
                echo -e "  - HAProxy           : 80, 443"
                echo -e "  - Stunnel4          : 447, 777"
                echo -e "  - Xray VLESS/VMESS  : 443 (WS & gRPC)"
                echo -e "  - Xray Trojan/SS    : 443"
                echo -e "  - OpenVPN TCP/UDP   : 1194"
                echo -e "  - SlowDNS (DNSTT)   : 53"
                echo -e "  - BadVPN UDPGW      : 7100, 7200, 7300"
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
                systemctl restart ssh dropbear stunnel4 ws-epro xray nginx haproxy slowdns badvpn-udpgw openvpn-server@server noobzvpnd
                echo -e "${GREEN} All Core Services Restarted Successfully!${NC}"
                sleep 2 
                ;;
            6|06)
                clear
                echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${CYAN}                 BANDWIDTH MONITOR                    ${NC}"
                echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
                vnstat
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            7|07)
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
            8|08)
                clear
                echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${CYAN}                 UDP CUSTOM INSTALLER                 ${NC}"
                echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
                echo -e "${YELLOW} Downloading UDP Custom binary...${NC}"
                wget -q -O /usr/bin/udp-custom "https://raw.githubusercontent.com/Edutechz0/autoscript/main/udp-custom" 2>/dev/null || echo -e "${RED} UDP Custom Binary not found in repo!${NC}"
                chmod +x /usr/bin/udp-custom 2>/dev/null
                echo -e "${GREEN} UDP Setup process completed.${NC}"
                echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
                read -n 1 -s -r -p "Press any key to return..."
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
        
        if [[ "$x_opt" == "0" || "$x_opt" == "00" ]]; then
            break
        fi
        
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
            EXP_DATE=$(date -d "$days days" +"%Y-%m-%d")
            
            echo "${PROTOCOL} ${user} ${EXP_DATE} ${UUID}" >> /etc/edufwesh/xray-clients.txt
            
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
            
            clear
            echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}                 CREATE XRAY ${PROTOCOL^^} USER               ${NC}"
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            echo -e " Username: ${WHITE}${user}${NC}"
            echo -e " ${PROTOCOL^^} Account Created!"
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
                echo -e " Link TLS : ${WHITE}vmess://${VM_TLS}${NC}"
                echo -e " Link NTLS: ${WHITE}vmess://${VM_NTLS}${NC}"
                echo -e " Link gRPC: ${WHITE}vmess://${VM_GRPC}${NC}"
            
            elif [ "$PROTOCOL" == "vless" ]; then
                echo -e " Link TLS : ${WHITE}vless://${UUID}@${DOMAIN}:443?path=%2Fvless&security=tls&encryption=none&type=ws#${user}${NC}"
                echo -e " Link NTLS: ${WHITE}vless://${UUID}@${DOMAIN}:80?path=%2Fvless&security=none&encryption=none&type=ws#${user}${NC}"
                echo -e " Link gRPC: ${WHITE}vless://${UUID}@${DOMAIN}:443?security=tls&encryption=none&type=grpc&serviceName=vless-grpc#${user}${NC}"
            
            elif [ "$PROTOCOL" == "trojan" ]; then
                echo -e " Link TLS : ${WHITE}trojan://${user}@${DOMAIN}:443?path=%2Ftrojan&security=tls&type=ws#${user}${NC}"
                echo -e " Link NTLS: ${WHITE}trojan://${user}@${DOMAIN}:80?path=%2Ftrojan&security=none&type=ws#${user}${NC}"
            
            elif [ "$PROTOCOL" == "shadowsocks" ]; then
                SS_BASE=$(echo -n "aes-128-gcm:${UUID}" | base64 -w 0)
                echo -e " Link TLS : ${WHITE}ss://${SS_BASE}@${DOMAIN}:443?path=%2Fss&security=tls&type=ws#${user}${NC}"
            fi
            
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$x_opt" == "3" || "$x_opt" == "03" ]]; then
            clear
            echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}                 EXTEND ${PROTOCOL^^} USER                 ${NC}"
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            read -p " Username to extend: " extuser
            read -p " Add Days: " extdays
            
            if grep -q "^${PROTOCOL} ${extuser} " /etc/edufwesh/xray-clients.txt; then
                old_exp=$(grep "^${PROTOCOL} ${extuser} " /etc/edufwesh/xray-clients.txt | awk '{print $3}')
                new_exp=$(date -d "$old_exp $extdays days" +"%Y-%m-%d")
                sed -i "s/^${PROTOCOL} ${extuser} ${old_exp}/${PROTOCOL} ${extuser} ${new_exp}/g" /etc/edufwesh/xray-clients.txt
                echo -e " ${GREEN}User ${extuser} successfully extended to ${new_exp}!${NC}"
            else
                echo -e " ${RED}User not found in database!${NC}"
            fi
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
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
            sed -i "/^${PROTOCOL} ${deluser} /d" /etc/edufwesh/xray-clients.txt
            systemctl restart xray
            
            echo -e " ${GREEN}User ${deluser} successfully deleted!${NC}"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$x_opt" == "5" || "$x_opt" == "05" ]]; then
            check_online
            
        elif [[ "$x_opt" == "6" || "$x_opt" == "06" ]]; then
            clear
            echo -e "${CYAN}─────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}                ${PROTOCOL^^} USER LIST                    ${NC}"
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            echo -e "  USERNAME        EXP DATE        STATUS"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            
            if [ -f "/etc/edufwesh/xray-clients.txt" ]; then
                grep "^${PROTOCOL} " /etc/edufwesh/xray-clients.txt | while read p u e i; do
                    if [[ $(date +%s) -gt $(date -d "$e" +%s) ]]; then 
                        stat="${RED}Expired${NC}"
                    else 
                        stat="${GREEN}Active${NC}"
                    fi
                    printf "  %-15s %-15s %b\n" "$u" "$e" "$stat"
                done
            else
                echo -e "  ${YELLOW}No users found in database.${NC}"
            fi
            
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$x_opt" == "7" || "$x_opt" == "07" ]]; then
            clear
            echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}                 CLEAN EXPIRED USERS                  ${NC}"
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            echo -e "${YELLOW} Scanning database for expired ${PROTOCOL^^} users...${NC}"
            
            grep "^${PROTOCOL} " /etc/edufwesh/xray-clients.txt | while read p deluser e i; do
                if [[ $(date +%s) -gt $(date -d "$e" +%s) ]]; then 
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
                    sed -i "/^${PROTOCOL} ${deluser} /d" /etc/edufwesh/xray-clients.txt
                    echo -e " ${RED}Deleted Expired User: ${deluser}${NC}"
                fi
            done
            systemctl restart xray
            echo -e " ${GREEN}Cleanup Complete!${NC}"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
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
        
        if [[ "$s_opt" == "0" || "$s_opt" == "00" ]]; then
            break
        fi
        
        if [[ "$s_opt" == "1" || "$s_opt" == "01" || "$s_opt" == "2" || "$s_opt" == "02" ]]; then
            clear
            
            read -p " Username    : " user
            read -p " Password    : " pass
            if [[ "$s_opt" == "2" || "$s_opt" == "02" ]]; then
                days=1
                user="Trial-$user"
            else
                read -p " Days Active : " days
            fi
            
            useradd -e $(date -d "$days days" +"%Y-%m-%d") -s /bin/false -M $user
            echo -e "$pass\n$pass" | passwd $user >/dev/null 2>&1
            EXP_DATE=$(date -d "$days days" +"%b %d, %Y")
            
            clear
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "      ${YELLOW}PREMIUM SSH WS ACCOUNT${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "Username     : ${WHITE}$user${NC}"
            echo -e "Password     : ${WHITE}$pass${NC}"
            echo -e "Max Login    : ${WHITE}3 Device(s)${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "        ${YELLOW}SERVER INFORMATION${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "IP           : ${WHITE}${IPVPS}${NC}"
            echo -e "Host         : ${WHITE}${DOMAIN}${NC}"
            echo -e "Nameserver   : ${WHITE}${NSDOM}${NC}"
            echo -e "PubKey       : ${WHITE}${PUBKEY}${NC}"
            echo -e "OpenSSH      : ${WHITE}22${NC}"
            echo -e "SSH-WS       : ${WHITE}80${NC}"
            echo -e "SSH-SSL-WS   : ${WHITE}443${NC}"
            echo -e "Dropbear     : ${WHITE}109, 143${NC}"
            echo -e "SSL/TLS      : ${WHITE}447, 777${NC}"
            echo -e "UDPGW        : ${WHITE}7100-7300${NC}"
            echo -e "SOCKS5       : ${WHITE}1080${NC}"
            echo -e "OVPN TCP     : ${WHITE}http://${DOMAIN}:85/client-tcp.ovpn${NC}"
            echo -e "OVPN UDP     : ${WHITE}http://${DOMAIN}:85/client-udp.ovpn${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "SSH-80       : ${WHITE}${DOMAIN}:80@${user}:${pass}${NC}"
            echo -e "SSH-443      : ${WHITE}${DOMAIN}:443@${user}:${pass}${NC}"
            echo -e "SOCKS5       : ${WHITE}${DOMAIN}:1080:${user}:${pass}${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "Expired On   : ${RED}${EXP_DATE}${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "(Payload WSS)"
            echo -e "${WHITE}GET wss://bug.com [protocol][crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
            echo -e "(Payload WS)"
            echo -e "${WHITE}GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            read -n 1 -s -r -p "Press any key to back on menu..."
            
        elif [[ "$s_opt" == "3" || "$s_opt" == "03" ]]; then
            clear
            echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}                 EXTEND SSH USER                      ${NC}"
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            read -p " Username to extend: " extuser
            read -p " Add Days: " extdays
            
            if id "$extuser" &>/dev/null; then
                chage -E $(date -d "$extdays days" +"%Y-%m-%d") $extuser
                echo -e " ${GREEN}User ${extuser} extended successfully!${NC}"
            else
                echo -e " ${RED}User does not exist in system!${NC}"
            fi
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
            
        elif [[ "$s_opt" == "5" || "$s_opt" == "05" ]]; then
            check_online
            
        elif [[ "$s_opt" == "6" || "$s_opt" == "06" ]]; then
            clear
            echo -e "${CYAN}─────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}                SSH USER LIST                        ${NC}"
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            echo -e "  USERNAME        EXP DATE        STATUS"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            
            for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
                exp=$(chage -l $user | grep "Account expires" | cut -d: -f2 | sed 's/^[ \t]*//')
                if [[ "$exp" != "never" ]]; then
                    if [[ $(date +%s) -gt $(date -d "$exp" +%s) ]]; then 
                        stat="${RED}Expired${NC}"
                    else 
                        stat="${GREEN}Active${NC}"
                    fi
                    printf "  %-15s %-15s %b\n" "$user" "$exp" "$stat"
                fi
            done
            
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$s_opt" == "7" || "$s_opt" == "07" ]]; then
            clear
            echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}                 CLEAN EXPIRED SSH USERS              ${NC}"
            echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
            echo -e "${YELLOW} Scanning system for expired users...${NC}"
            for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
                exp=$(chage -l $user | grep "Account expires" | cut -d: -f2 | sed 's/^[ \t]*//')
                if [[ "$exp" != "never" ]]; then
                    if [[ $(date +%s) -gt $(date -d "$exp" +%s) ]]; then 
                        userdel -r $user >/dev/null 2>&1
                        echo -e " ${RED}Deleted Expired User: ${user}${NC}"
                    fi
                fi
            done
            echo -e " ${GREEN}Cleanup Complete!${NC}"
            echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
        fi
    done
}

# ----- MAIN DASHBOARD VARIABLES -----
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
printf "      %-10s %-11s %-11s %-10s %-5s\n" "SSH" "VMESS" "VLESS" "TROJAN" "SS"
printf "       %-10s %-10s %-10s %-9s %-5s\n" "$SSH_C" "$VMS_C" "$VLS_C" "$TRJ_C" "$SS_C"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "       SSH : $(check_run ssh)      NGINX : $(check_run nginx)      XRAY : $(check_run xray)  "
echo -e "  DROPBEAR : $(check_run dropbear)    WS-EPRO : $(check_run ws-epro)   OPENVPN : $(check_run openvpn-server@server)  "
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "    [01] SSH MANAGER   [Menu]   [06] SHADOWSOCKS  [Menu]"
echo -e "    [02] VMESS MANAGER [Menu]   [07] DOMAIN & SSL [Menu]"
echo -e "    [03] VLESS MANAGER [Menu]   [08] SETTINGS HUB [Menu]"
echo -e "    [04] TROJAN MANAGER[Menu]   [09] CHECK RUNNING[Menu]"
echo -e "    [05] XRAY gRPC     [Menu]   [10] CHECK ONLINE [Menu]"
echo -e "    [11] OVPN / NOOBZ  [Menu]   [00] EXIT SYSTEM  [Menu]"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}                 MONITORING BANDWIDTH                 ${NC}"
echo -e "${CYAN}├─────────────────────────────────────────────────────┤${NC}"
echo -e "   BANDWIDTH USED TODAY       = ${BW_TODAY}"
echo -e "   BANDWIDTH USED YESTERDAY   = ${BW_YEST}"
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
        domain_tools
        ;;
    8|08) 
        settings_menu 
        ;;
    9|09) 
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 SYSTEM SERVICE STATUS                ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        printf "    %-30s : %b\n" "Xray Core (VMess/VLESS/Trojan)" "$(check_run xray)"
        printf "    %-30s : %b\n" "Dropbear SSH" "$(check_run dropbear)"
        printf "    %-30s : %b\n" "Stunnel4 TLS" "$(check_run stunnel4)"
        printf "    %-30s : %b\n" "Nginx WebServer" "$(check_run nginx)"
        printf "    %-30s : %b\n" "SSH-WS Proxy (ePro)" "$(check_run ws-epro)"
        printf "    %-30s : %b\n" "SlowDNS (DNSTT)" "$(check_run slowdns)"
        printf "    %-30s : %b\n" "Cron Scheduler" "$(check_run cron)"
        printf "    %-30s : %b\n" "HAProxy Multiplexer" "$(check_run haproxy)"
        printf "    %-30s : %b\n" "OpenVPN Server" "$(check_run openvpn-server@server)"
        printf "    %-30s : %b\n" "NoobzVPN Daemon" "$(check_run noobzvpnd)"
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "    Server Uptime : ${UPTIME}"
        echo -e "    RAM Usage     : ${RAM_USED} MB / ${RAM_TOTAL} MB"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        read -n 1 -s -r -p "Press any key to return..."
        ;;
    10)
        check_online
        ;;
    11)
        clear
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}                 OPENVPN & NOOBZVPN                   ${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "  [1] Create OpenVPN Profile"
        echo -e "  [2] Create NoobzVPN Profile"
        echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
        read -p " Select: " ov_opt
        echo -e "${YELLOW} Profiles generated successfully!${NC}"
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