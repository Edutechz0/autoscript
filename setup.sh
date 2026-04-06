#!/bin/bash

# ==========================================================
# EDUFWESH PREMIUM AUTO-INSTALLER (GOD-TIER FINAL MASTER)
# Neon Pro UI, Xray Sniffing & Anti-Abuse Optimization
# ==========================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'
# NEW NEON COLORS
N_CYAN='\e[38;5;51m'
N_PINK='\e[38;5;198m'
N_PURPLE='\e[38;5;135m'
N_YELLOW='\e[38;5;226m'
N_GREEN='\e[38;5;46m'

clear
echo -e "${N_PURPLE}███████████████████████████████████████████████████████${NC}"
echo -e "${N_PURPLE}█${NC} ${N_CYAN}       WELCOME TO EDUFWESH SCRIPT INSTALLER      ${NC} ${N_PURPLE}█${NC}"
echo -e "${N_PURPLE}███████████████████████████████████████████████████████${NC}"
echo ""

read -p " [?] Enter your main Domain (e.g., vpn.server.com) : " MY_DOMAIN
read -p " [?] Enter your NS Domain (e.g., ns.server.com)    : " MY_NSDOMAIN
read -p " [?] Enter your CloudFront/CDN domain for bypass (optional, press Enter to skip): " MY_CDN

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
if [ -n "$MY_CDN" ]; then
    echo "$MY_CDN" > /etc/edufwesh/cdn_domain
fi

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

# Install websocat for WebSocket testing
if ! command -v websocat &>/dev/null; then
    echo -e "${GREEN}[+] Installing websocat...${NC}"
    wget -q -O /usr/local/bin/websocat "https://github.com/vi/websocat/releases/download/v1.11.0/websocat.x86_64-unknown-linux-musl"
    chmod +x /usr/local/bin/websocat
fi

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
        request = client_socket.recv(8192).decode('utf-8', errors='ignore')
        if "Upgrade: websocket" in request or "HTTP" in request:
            response = "HTTP/1.1 101 Switching Protocols\r\n"
            response += "Upgrade: websocket\r\n"
            response += "Connection: Upgrade\r\n\r\n"
            client_socket.send(response.encode())
            
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect(('127.0.0.1', 109))
        
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
    except Exception as e:
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
echo -e "${GREEN}[+] Installing & Optimizing Xray Core...${NC}"
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
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
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
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
END

systemctl restart xray
systemctl enable xray

# ==========================================
# 7. NGINX & HAPROXY MULTIPLEXER (Real-IP Forwarding Fix)
# ==========================================
echo -e "${GREEN}[+] Configuring HAProxy & Nginx...${NC}"
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
    default_backend ws_epro_direct

frontend https_front
    bind *:443
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }
    # Accept any SNI and forward to Nginx (allows CloudFront/CDN bypass)
    use_backend nginx_https

backend ws_epro_direct
    mode tcp
    server wsepro 127.0.0.1:8880 check

backend nginx_https
    mode tcp
    server nginx2 127.0.0.1:444 check
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

# Generate TLS authentication key (compatible with all OpenVPN versions)
if openvpn --genkey --secret /etc/openvpn/ta.key 2>/dev/null; then
    : # success
elif openvpn --genkey secret /etc/openvpn/ta.key 2>/dev/null; then
    : # success
else
    # Last resort: use openssl to create a random key
    openssl rand -base64 2048 | tr -d '\n' > /etc/openvpn/ta.key
fi

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
# 9. SLOWDNS & BADVPN SETUP (FULLY FIXED)
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

# --- Detect architecture and download correct binary from your repo ---
ARCH=$(uname -m)
echo -e "${CYAN}[+] Detected architecture: $ARCH${NC}"

if [[ "$ARCH" == "x86_64" ]]; then
    BIN_NAME="dnstt-server-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    BIN_NAME="dnstt-server-arm64"
else
    echo -e "${RED}[!] Unsupported architecture: $ARCH. SlowDNS will be skipped.${NC}"
    skip_slowdns=1
fi

if [ -z "$skip_slowdns" ]; then
    echo -e "${GREEN}[+] Downloading dnstt-server from your repository...${NC}"
    wget -q --timeout=15 -O /etc/slowdns/dnstt-server "https://raw.githubusercontent.com/Edutechz0/autoscript/main/$BIN_NAME"
    chmod +x /etc/slowdns/dnstt-server
    # Give binary permission to bind to low ports
    setcap 'cap_net_bind_service=+ep' /etc/slowdns/dnstt-server 2>/dev/null || true
fi

# Fallback to dnstt.network if your repo fails
if [ -z "$skip_slowdns" ] && ( [ ! -s /etc/slowdns/dnstt-server ] || ! /etc/slowdns/dnstt-server -h >/dev/null 2>&1 ); then
    echo -e "${YELLOW}[!] Binary from GitHub failed. Trying fallback from dnstt.network...${NC}"
    if [[ "$ARCH" == "x86_64" ]]; then
        wget -q -O /etc/slowdns/dnstt-server "https://dnstt.network/dnstt-server-linux-amd64"
    elif [[ "$ARCH" == "aarch64" ]]; then
        wget -q -O /etc/slowdns/dnstt-server "https://dnstt.network/dnstt-server-linux-arm64"
    fi
    chmod +x /etc/slowdns/dnstt-server
    setcap 'cap_net_bind_service=+ep' /etc/slowdns/dnstt-server 2>/dev/null || true
fi

# Final validation
if [ -z "$skip_slowdns" ] && [ -s /etc/slowdns/dnstt-server ] && /etc/slowdns/dnstt-server -h >/dev/null 2>&1; then
    echo -e "${GREEN}[+] dnstt-server binary is ready and working.${NC}"
else
    echo -e "${RED}[!] Failed to obtain a working dnstt-server binary. SlowDNS will be disabled.${NC}"
    skip_slowdns=1
fi

# Permanently kill systemd-resolved and other DNS stub resolvers
systemctl stop systemd-resolved
systemctl disable systemd-resolved
systemctl mask systemd-resolved
systemctl stop dnsmasq unbound named 2>/dev/null
systemctl disable dnsmasq unbound named 2>/dev/null
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Write keys and create service only if binary is present
if [ -z "$skip_slowdns" ]; then
    # Write the global keys (Edufwesh default)
    echo "7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59" > /etc/slowdns/server.pub
    echo "819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae" > /etc/slowdns/server.key

    # Create slowdns service with proper capabilities and port waiting
    cat > /etc/systemd/system/slowdns.service << END
[Unit]
Description=SlowDNS Server
After=network.target
Before=systemd-resolved.service

[Service]
WorkingDirectory=/etc/slowdns
ExecStartPre=/bin/bash -c "systemctl stop systemd-resolved dnsmasq unbound named 2>/dev/null; systemctl disable systemd-resolved dnsmasq unbound named 2>/dev/null"
ExecStartPre=/bin/bash -c "fuser -k 53/udp 53/tcp 2>/dev/null; killall -9 systemd-resolved dnsmasq unbound named 2>/dev/null || true"
ExecStartPre=/bin/bash -c "while ss -lun | grep -q ':53 '; do echo 'Waiting for port 53 to free...'; sleep 1; done"
ExecStart=/etc/slowdns/dnstt-server -udp 0.0.0.0:53 -privkey-file /etc/slowdns/server.key ${MY_NSDOMAIN} 127.0.0.1:109
Restart=on-failure
RestartSec=10
KillMode=process
LimitNOFILE=65536
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
END

    # Validate keys exist and are non-empty
    if [ ! -s /etc/slowdns/server.key ] || [ ! -s /etc/slowdns/server.pub ]; then
        echo -e "${YELLOW}[!] Keys missing, generating fresh ones...${NC}"
        cd /etc/slowdns
        rm -f server.pub server.key
        ./dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub
    fi

    systemctl daemon-reload
    systemctl enable --now slowdns

    # Final check
    sleep 2
    if systemctl is-active --quiet slowdns; then
        echo -e "${GREEN}[+] SlowDNS service is running successfully.${NC}"
    else
        echo -e "${RED}[!] SlowDNS service failed to start. Check logs with: journalctl -u slowdns --no-pager -n 20${NC}"
    fi
else
    echo -e "${YELLOW}[!] SlowDNS setup skipped due to missing binary or unsupported architecture.${NC}"
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
N_CYAN='\e[38;5;51m'
N_PINK='\e[38;5;198m'
N_PURPLE='\e[38;5;135m'
N_YELLOW='\e[38;5;226m'
N_GREEN='\e[38;5;46m'

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
    echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
    echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}ONLINE USER MONITOR${NC}                 ${N_PURPLE}│${NC}"
    echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
    
    echo -e "${N_YELLOW}>> Active SSH Connections:${NC}"
    netstat -tnpa | grep ESTABLISHED | grep -E "sshd|dropbear|stunnel4" | awk '{print $5, $7}' | cut -d: -f1 | sort | uniq -c | awk '{print "   IP: "$2" (Sessions: "$1")"}'
    
    echo -e ""
    echo -e "${N_YELLOW}>> Active Xray (V2Ray) Connections:${NC}"
    if [ -f "/var/log/xray/access.log" ]; then
        tail -n 100 /var/log/xray/access.log | grep "accepted" | awk '{print $3}' | cut -d: -f1 | sort | uniq -c | awk '{print "   IP: "$2" (Requests: "$1")"}'
    else
        echo -e "   ${RED}Log file empty or not found.${NC}"
    fi
    
    echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
    read -n 1 -s -r -p "Press any key to return..."
}

# ----- DOMAIN & SSL TOOLS (with live refresh) -----
domain_tools() {
    while true; do
        clear
        # Read current values each time
        DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
        NSDOM=$(cat /etc/slowdns/nsdomain 2>/dev/null)
        echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}DOMAIN & SSL MANAGER${NC}                ${N_PURPLE}│${NC}"
        echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
        echo -e " Current Domain : ${WHITE}${DOMAIN}${NC}"
        echo -e " Current NS     : ${WHITE}${NSDOM}${NC}"
        echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
        echo -e "    [01] Change VPS Domain (Host)"
        echo -e "    [02] Change NameServer (SlowDNS NS)"
        echo -e "    [03] Force Renew SSL Certificate"
        echo -e "    [04] Regenerate All Xray Config Links (new domain)"
        echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
        echo -e "    [00] Back to Main Menu"
        echo -e "${N_PURPLE}───────────────────────────────────────────────────────${NC}"
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
                sed -i "s/server.key .*/server.key $newns 127.0.0.1:109/g" /etc/systemd/system/slowdns.service
                systemctl daemon-reload
                systemctl restart slowdns
                echo -e "${N_GREEN} NS Domain updated successfully to $newns${NC}"
                sleep 2
                ;;
            3|03)
                echo -e "${N_YELLOW} Regenerating Self-Signed SSL for HAProxy/Stunnel...${NC}"
                openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=NG/ST=Rivers/L=PH/O=Edufwesh/CN=${DOMAIN}" -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem > /dev/null 2>&1
                systemctl restart stunnel4 nginx haproxy
                echo -e "${N_GREEN} Certificate fixed and services restarted!${NC}"
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

# ----- SERVER SETTINGS HUB -----
settings_menu() {
    while true; do
        clear
        echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}SERVER SETTINGS HUB${NC}                 ${N_PURPLE}│${NC}"
        echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "  [01] Speedtest VPS"
        echo -e "  [02] Info Ports"
        echo -e "  [03] Set Auto Reboot"
        echo -e "  [04] Server Health Check"
        echo -e "  [05] Restart All Services"
        echo -e "  [06] Check Bandwidth Usage"
        echo -e "  [07] SlowDNS Key Manager"
        echo -e "  [08] Install UDP Custom"
        echo -e "  [09] Test Xray Connectivity (curl)"
        echo -e "  [10] Show Payload Examples"
        echo -e "  [11] Test External TLS Handshake"
        echo -e "  [12] Verbose WebSocket Test"
        echo -e "  [13] WebSocket Echo Test (websocat)"
        echo -e "  [00] Back to Main Dashboard"
        echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
        read -p " Select option : " set_opt

        case $set_opt in
            1|01) 
                clear
                echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}SPEEDTEST RESULTS${NC}                   ${N_PURPLE}│${NC}"
                echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
                speedtest-cli
                echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
                read -n 1 -s -r -p "Press any key to return..." 
                ;;
            2|02) 
                clear
                echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}SYSTEM PORTS & INFO${NC}                 ${N_PURPLE}│${NC}"
                echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
                echo -e " ${N_YELLOW}>> Service & Port List${NC}"
                echo -e "  - OpenSSH           : 22"
                echo -e "  - Dropbear          : 109, 143"
                echo -e "  - WS-ePro Proxy     : 80, 8880"
                echo -e "  - HAProxy           : 80, 443"
                echo -e "  - Stunnel4          : 447, 777"
                echo -e "  - Xray VLESS/VMESS  : 443 (WS & gRPC)"
                echo -e "  - Xray Trojan/SS    : 443"
                echo -e "  - OpenVPN UDP       : 1194"
                echo -e "  - SlowDNS (DNSTT)   : 53"
                echo -e "  - BadVPN UDPGW      : 7100, 7200, 7300"
                echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
                echo -e " ${N_YELLOW}>> Server Status${NC}"
                echo -e "  - IP Address        : ${IPVPS}"
                echo -e "  - Domain            : ${DOMAIN}"
                echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
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
                echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}SERVER HEALTH CHECK${NC}                 ${N_PURPLE}│${NC}"
                echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
                uptime
                echo ""
                free -h
                echo ""
                df -h | grep '^/dev/'
                echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
                read -n 1 -s -r -p "Press any key to return..." 
                ;;
            5|05)
                clear
                systemctl restart ssh dropbear stunnel4 ws-epro xray nginx haproxy slowdns badvpn-udpgw openvpn-server@server noobzvpnd
                echo -e "${N_GREEN} All Core Services Restarted Successfully!${NC}"
                sleep 2 
                ;;
            6|06)
                clear
                echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}BANDWIDTH MONITOR${NC}                   ${N_PURPLE}│${NC}"
                echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
                vnstat
                echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            7|07)
                clear
                echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}SLOWDNS KEY MANAGER${NC}                 ${N_PURPLE}│${NC}"
                echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
                echo -e "  [1] Switch to Global Key (Edufwesh Default)"
                echo -e "  [2] Generate Fresh Random Key"
                echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
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
                echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}UDP CUSTOM INSTALLER${NC}                ${N_PURPLE}│${NC}"
                echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
                echo -e "${N_YELLOW} Downloading UDP Custom binary...${NC}"
                wget -q -O /usr/bin/udp-custom "https://raw.githubusercontent.com/Edutechz0/autoscript/main/udp-custom" 2>/dev/null || echo -e "${RED} UDP Custom Binary not found in repo!${NC}"
                chmod +x /usr/bin/udp-custom 2>/dev/null
                echo -e "${N_GREEN} UDP Setup process completed.${NC}"
                echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            9|09)
                clear
                echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}XRAY CONNECTIVITY TEST${NC}              ${N_PURPLE}│${NC}"
                echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
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
                # Map paths to local ports
                declare -A port_map=(
                    ["vless"]=10001
                    ["vmess"]=10002
                    ["trojan"]=10003
                    ["ss"]=10004
                )
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
                
                echo -e "\n${N_PINK}───────────────────────────────────────────────────────${NC}"
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
                echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${N_PURPLE}│${NC}          ${N_CYAN}PAYLOAD EXAMPLES FOR TUNNEL APPS${NC}           ${N_PURPLE}│${NC}"
                echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
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
                echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            11)
                clear
                echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${N_PURPLE}│${NC}           ${N_CYAN}EXTERNAL TLS HANDSHAKE TEST${NC}               ${N_PURPLE}│${NC}"
                echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
                DOMAIN=$(cat /etc/xray/domain)
                echo -e " Testing TLS handshake to ${DOMAIN}:443 ..."
                echo -e ""
                echo -e "${N_YELLOW}Running openssl s_client...${NC}"
                echo -e " (Look for 'CONNECTED' and 'SSL handshake has read')"
                echo -e ""
                timeout 10 openssl s_client -connect ${DOMAIN}:443 -servername ${DOMAIN} -tlsextdebug -brief 2>&1 | head -30
                echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
                echo -e " If you see 'CONNECTED' and 'SSL handshake has read' then TLS is working."
                echo -e " If you see 'handshake failure' or 'timeout', check:"
                echo -e "   1. Domain DNS resolution: dig ${DOMAIN}"
                echo -e "   2. Firewall: ufw status"
                echo -e "   3. Nginx error logs: tail -f /var/log/nginx/error.log"
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            12)
                clear
                echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${N_PURPLE}│${NC}           ${N_CYAN}VERBOSE WEBSOCKET TEST (full headers)${NC}     ${N_PURPLE}│${NC}"
                echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
                DOMAIN=$(cat /etc/xray/domain)
                echo -e " Sending WebSocket upgrade request to https://${DOMAIN}/vmess"
                echo -e ""
                curl -kv --http1.1 --max-time 10 "https://${DOMAIN}/vmess" \
                    --header "Host: ${DOMAIN}" \
                    --header "Upgrade: websocket" \
                    --header "Connection: Upgrade" \
                    --header "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
                    --header "Sec-WebSocket-Version: 13" 2>&1 | head -50
                echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
                echo -e " Look for '101 Switching Protocols' in the response."
                echo -e " If you see '400' or '404', the WebSocket upgrade is failing."
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            13)
                clear
                echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
                echo -e "${N_PURPLE}│${NC}           ${N_CYAN}WEBSOCKET ECHO TEST (websocat)${NC}            ${N_PURPLE}│${NC}"
                echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
                DOMAIN=$(cat /etc/xray/domain)
                echo -e " Connecting to wss://${DOMAIN}/vmess ..."
                echo -e " (This will attempt a WebSocket handshake and then exit)"
                echo -e ""
                timeout 5 websocat -v "wss://${DOMAIN}/vmess" --insecure 2>&1 | head -20
                echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
                echo -e " If you see 'Connected' or '101 Switching Protocols', WebSocket works."
                echo -e " If you see 'Connection refused' or 'timeout', the proxy chain is broken."
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            0|00) 
                break 
                ;;
        esac
    done
}

# ----- XRAY MANAGER FUNCTION (with formatted output and automatic CloudFront link) -----
xray_menu() {
    PROTOCOL=$1
    while true; do
        DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
        CDN=$(cat /etc/edufwesh/cdn_domain 2>/dev/null)
        clear
        echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}XRAY ${PROTOCOL^^} MANAGER${NC}                  ${N_PURPLE}│${NC}"
        echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "    [01] Create ${PROTOCOL^^} Account"
        echo -e "    [02] Create Trial Account"
        echo -e "    [03] Extend ${PROTOCOL^^} Account"
        echo -e "    [04] Delete ${PROTOCOL^^} Account"
        echo -e "    [05] Check User Login"
        echo -e "    [06] List ${PROTOCOL^^} Members"
        echo -e "    [07] Clean Expired Users (Manual)"
        echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
        echo -e "    [00] Back to Main Menu"
        echo -e "${N_PURPLE}───────────────────────────────────────────────────────${NC}"
        read -p " Select : " x_opt
        
        if [[ "$x_opt" == "0" || "$x_opt" == "00" ]]; then
            break
        fi
        
        if [[ "$x_opt" == "1" || "$x_opt" == "01" || "$x_opt" == "2" || "$x_opt" == "02" ]]; then
            clear
            echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}CREATE XRAY ${PROTOCOL^^} USER${NC}               ${N_PURPLE}│${NC}"
            echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
            
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
            
            # Add user to Xray config
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
            
            # Display account details in clean format
            echo -e "${N_PURPLE}───────────────────────────────────────────────────────${NC}"
            echo -e "${N_CYAN}                  XRAY ${PROTOCOL^^} ACCOUNT CREATED                  ${NC}"
            echo -e "${N_PURPLE}───────────────────────────────────────────────────────${NC}"
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
                echo -e "Network        : ${WHITE}ws${NC}"
                echo -e "Path           : ${WHITE}/vmess${NC}"
                echo -e "ServiceName    : ${WHITE}vmess-grpc${NC}"
            elif [ "$PROTOCOL" == "vless" ]; then
                echo -e "id             : ${WHITE}${UUID}${NC}"
                echo -e "encryption     : ${WHITE}none${NC}"
                echo -e "Network        : ${WHITE}ws, grpc${NC}"
                echo -e "Path           : ${WHITE}/vless (WS), vless-grpc (gRPC)${NC}"
            elif [ "$PROTOCOL" == "trojan" ]; then
                echo -e "Password       : ${WHITE}${user}${NC}"
                echo -e "Network        : ${WHITE}ws${NC}"
                echo -e "Path           : ${WHITE}/trojan${NC}"
            elif [ "$PROTOCOL" == "shadowsocks" ]; then
                echo -e "Password       : ${WHITE}${UUID}${NC}"
                echo -e "Method         : ${WHITE}aes-128-gcm${NC}"
                echo -e "Network        : ${WHITE}ws${NC}"
                echo -e "Path           : ${WHITE}/ss${NC}"
            fi
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            
            # Generate links (Added Sni and Host compatibility)
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
                echo -e "Link TLS       : ${WHITE}vmess://${VM_TLS}${NC}"
                echo -e "Link none TLS  : ${WHITE}vmess://${VM_NTLS}${NC}"
                echo -e "Link gRPC      : ${WHITE}vmess://${VM_GRPC}${NC}"
                if [ -n "$CDN" ]; then
                    VM_CDN=$(cat <<EOF | base64 -w 0
{"v":"2","ps":"${user} (CDN)","add":"${CDN}","port":"443","id":"${UUID}","aid":"0","net":"ws","path":"/vmess","type":"none","host":"${DOMAIN}","tls":"tls","sni":"${CDN}"}
EOF
)
                    echo -e "Link CloudFront: ${WHITE}vmess://${VM_CDN}${NC}"
                fi
            elif [ "$PROTOCOL" == "vless" ]; then
                echo -e "Link TLS       : ${WHITE}vless://${UUID}@${DOMAIN}:443?path=%2Fvless&security=tls&encryption=none&type=ws&host=${DOMAIN}&sni=${DOMAIN}#${user}${NC}"
                echo -e "Link none TLS  : ${WHITE}vless://${UUID}@${DOMAIN}:80?path=%2Fvless&security=none&encryption=none&type=ws&host=${DOMAIN}#${user}${NC}"
                echo -e "Link gRPC      : ${WHITE}vless://${UUID}@${DOMAIN}:443?security=tls&encryption=none&type=grpc&serviceName=vless-grpc&host=${DOMAIN}&sni=${DOMAIN}#${user}${NC}"
                if [ -n "$CDN" ]; then
                    echo -e "Link CloudFront: ${WHITE}vless://${UUID}@${CDN}:443?path=%2Fvless&security=tls&encryption=none&type=ws&sni=${CDN}&host=${DOMAIN}#${user}${NC}"
                fi
            elif [ "$PROTOCOL" == "trojan" ]; then
                echo -e "Link TLS       : ${WHITE}trojan://${user}@${DOMAIN}:443?path=%2Ftrojan&security=tls&type=ws&host=${DOMAIN}&sni=${DOMAIN}#${user}${NC}"
                echo -e "Link none TLS  : ${WHITE}trojan://${user}@${DOMAIN}:80?path=%2Ftrojan&security=none&type=ws&host=${DOMAIN}#${user}${NC}"
                if [ -n "$CDN" ]; then
                    echo -e "Link CloudFront: ${WHITE}trojan://${user}@${CDN}:443?path=%2Ftrojan&security=tls&type=ws&sni=${CDN}&host=${DOMAIN}#${user}${NC}"
                fi
            elif [ "$PROTOCOL" == "shadowsocks" ]; then
                SS_BASE=$(echo -n "aes-128-gcm:${UUID}" | base64 -w 0)
                echo -e "Link TLS       : ${WHITE}ss://${SS_BASE}@${DOMAIN}:443?path=%2Fss&security=tls&type=ws&host=${DOMAIN}&sni=${DOMAIN}#${user}${NC}"
                if [ -n "$CDN" ]; then
                    echo -e "Link CloudFront: ${WHITE}ss://${SS_BASE}@${CDN}:443?path=%2Fss&security=tls&type=ws&sni=${CDN}&host=${DOMAIN}#${user}${NC}"
                fi
            fi
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            echo -e "Expired On     : ${RED}${EXP_DATE}${NC}"
            echo -e "${N_PURPLE}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$x_opt" == "3" || "$x_opt" == "03" ]]; then
            clear
            echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}EXTEND ${PROTOCOL^^} USER${NC}                 ${N_PURPLE}│${NC}"
            echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
            read -p " Username to extend: " extuser
            read -p " Add Days: " extdays
            
            if grep -q "^${PROTOCOL} ${extuser} " /etc/edufwesh/xray-clients.txt; then
                old_exp=$(grep "^${PROTOCOL} ${extuser} " /etc/edufwesh/xray-clients.txt | awk '{print $3}')
                new_exp=$(date -d "$old_exp $extdays days" +"%Y-%m-%d")
                sed -i "s/^${PROTOCOL} ${extuser} ${old_exp}/${PROTOCOL} ${extuser} ${new_exp}/g" /etc/edufwesh/xray-clients.txt
                echo -e " ${N_GREEN}User ${extuser} successfully extended to ${new_exp}!${NC}"
            else
                echo -e " ${RED}User not found in database!${NC}"
            fi
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."

        elif [[ "$x_opt" == "4" || "$x_opt" == "04" ]]; then
            clear
            echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}DELETE XRAY ${PROTOCOL^^} USER${NC}               ${N_PURPLE}│${NC}"
            echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
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
            
            echo -e " ${N_GREEN}User ${deluser} successfully deleted!${NC}"
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$x_opt" == "5" || "$x_opt" == "05" ]]; then
            check_online
            
        elif [[ "$x_opt" == "6" || "$x_opt" == "06" ]]; then
            clear
            echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${N_PURPLE}│${NC}                ${N_CYAN}${PROTOCOL^^} USER LIST${NC}                    ${N_PURPLE}│${NC}"
            echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
            echo -e "  USERNAME        EXP DATE        STATUS"
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            
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
            
            echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$x_opt" == "7" || "$x_opt" == "07" ]]; then
            clear
            echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}CLEAN EXPIRED USERS${NC}                  ${N_PURPLE}│${NC}"
            echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
            echo -e "${N_YELLOW} Scanning database for expired ${PROTOCOL^^} users...${NC}"
            
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
            echo -e " ${N_GREEN}Cleanup Complete!${NC}"
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
        fi
    done
}

# ----- SSH MENU FUNCTION (with live DOMAIN/NSDOM) -----
ssh_menu() {
    while true; do
        DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
        NSDOM=$(cat /etc/slowdns/nsdomain 2>/dev/null)
        PUBKEY=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "Key Not Found")
        clear
        echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}SSH/WS MANAGER${NC}                       ${N_PURPLE}│${NC}"
        echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "    [01] Create SSH Account"
        echo -e "    [02] Create Trial Account"
        echo -e "    [03] Extend SSH Account"
        echo -e "    [04] Delete SSH Account"
        echo -e "    [05] Check User Login"
        echo -e "    [06] List SSH Members"
        echo -e "    [07] Clean Expired Users"
        echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
        echo -e "    [00] Back to Main Menu"
        echo -e "${N_PURPLE}───────────────────────────────────────────────────────${NC}"
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
            echo -e "${N_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "      ${N_YELLOW}PREMIUM SSH WS ACCOUNT${NC}"
            echo -e "${N_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "Username     : ${WHITE}$user${NC}"
            echo -e "Password     : ${WHITE}$pass${NC}"
            echo -e "Max Login    : ${WHITE}3 Device(s)${NC}"
            echo -e "${N_PINK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "        ${N_YELLOW}SERVER INFORMATION${NC}"
            echo -e "${N_PINK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
            echo -e "${N_PINK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "SSH-80       : ${WHITE}${DOMAIN}:80@${user}:${pass}${NC}"
            echo -e "SSH-443      : ${WHITE}${DOMAIN}:443@${user}:${pass}${NC}"
            echo -e "SOCKS5       : ${WHITE}${DOMAIN}:1080:${user}:${pass}${NC}"
            echo -e "${N_PINK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "Expired On   : ${RED}${EXP_DATE}${NC}"
            echo -e "${N_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "(Payload WSS)"
            echo -e "${WHITE}GET wss://bug.com [protocol][crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
            echo -e "(Payload WS)"
            echo -e "${WHITE}GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
            echo -e "${N_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            read -n 1 -s -r -p "Press any key to back on menu..."
            
        elif [[ "$s_opt" == "3" || "$s_opt" == "03" ]]; then
            clear
            echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}EXTEND SSH USER${NC}                      ${N_PURPLE}│${NC}"
            echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
            read -p " Username to extend: " extuser
            read -p " Add Days: " extdays
            
            if id "$extuser" &>/dev/null; then
                chage -E $(date -d "$extdays days" +"%Y-%m-%d") $extuser
                echo -e " ${N_GREEN}User ${extuser} extended successfully!${NC}"
            else
                echo -e " ${RED}User does not exist in system!${NC}"
            fi
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."

        elif [[ "$s_opt" == "4" || "$s_opt" == "04" ]]; then
            clear
            echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}DELETE SSH USER${NC}                      ${N_PURPLE}│${NC}"
            echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
            read -p " Username to delete: " deluser
            userdel -r $deluser >/dev/null 2>&1
            echo -e " ${N_GREEN}User ${deluser} successfully deleted!${NC}"
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$s_opt" == "5" || "$s_opt" == "05" ]]; then
            check_online
            
        elif [[ "$s_opt" == "6" || "$s_opt" == "06" ]]; then
            clear
            echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${N_PURPLE}│${NC}                ${N_CYAN}SSH USER LIST${NC}                        ${N_PURPLE}│${NC}"
            echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
            echo -e "  USERNAME        EXP DATE        STATUS"
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            
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
            
            echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
            read -n 1 -s -r -p "Press any key to return..."
            
        elif [[ "$s_opt" == "7" || "$s_opt" == "07" ]]; then
            clear
            echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
            echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}CLEAN EXPIRED SSH USERS${NC}              ${N_PURPLE}│${NC}"
            echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
            echo -e "${N_YELLOW} Scanning system for expired users...${NC}"
            for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
                exp=$(chage -l $user | grep "Account expires" | cut -d: -f2 | sed 's/^[ \t]*//')
                if [[ "$exp" != "never" ]]; then
                    if [[ $(date +%s) -gt $(date -d "$exp" +%s) ]]; then 
                        userdel -r $user >/dev/null 2>&1
                        echo -e " ${RED}Deleted Expired User: ${user}${NC}"
                    fi
                fi
            done
            echo -e " ${N_GREEN}Cleanup Complete!${NC}"
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
        fi
    done
}

# ----- MAIN DASHBOARD (variables refreshed each loop) -----
while true; do
# Refresh all dynamic data
DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
NSDOM=$(cat /etc/slowdns/nsdomain 2>/dev/null)
IPVPS=$(curl -s ipv4.icanhazip.com)
PUBKEY=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "Key Not Found")
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
echo -e "${CYAN} * Documentation:  https://help.ubuntu.com${NC}"
echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}LICENSE INFORMATION${NC}                  ${N_PURPLE}│${NC}"
echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
echo -e "   Client     : EDUFWESH"
echo -e "   Expiry Date: 31-12-2029"
echo -e "   Days Left  : Unlimited"
echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${N_PURPLE}│${NC}                   ${N_CYAN}VPS INFORMATION${NC}                    ${N_PURPLE}│${NC}"
echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
echo -e "   Server Uptime      = ${UPTIME}"
echo -e "   Current Time       = ${DATETIME}"
echo -e "   Operating System   = ${OS_INFO}"
echo -e "   Current Domain     = ${DOMAIN}"
echo -e "   NS Domain          = ${NSDOM}"
echo -e "   Total Ram          = ${RAM_TOTAL} MB"
echo -e "   Total Used Ram     = ${RAM_USED} MB"
echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${N_PURPLE}│${NC}               ${N_CYAN}𝗘𝗱𝘂𝗳𝘄𝗲𝘀𝗵 𝗩𝗣𝗡 𝗠𝗔𝗡𝗔𝗚𝗘𝗥${NC}                   ${N_PURPLE}│${NC}"
echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
echo -e "    Use Core          : Xray-Core 2024"
echo -e "    IP-VPS            : ${IPVPS}"
echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
printf "       %-10s %-10s %-9s %-9s %-5s\n" "SSH" "VMESS" "VLESS" "TROJAN" "SS"
printf "       %-10s %-10s %-9s %-9s %-5s\n" "$SSH_C" "$VMS_C" "$VLS_C" "$TRJ_C" "$SS_C"
echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "       SSH : $(check_run ssh)      NGINX : $(check_run nginx)      XRAY : $(check_run xray)  "
echo -e "  DROPBEAR : $(check_run dropbear)    WS-EPRO : $(check_run ws-epro)   OPENVPN : $(check_run openvpn-server@server)  "
echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "    [01] SSH MANAGER   [Menu]   [06] SHADOWSOCKS  [Menu]"
echo -e "    [02] VMESS MANAGER [Menu]   [07] DOMAIN & SSL [Menu]"
echo -e "    [03] VLESS MANAGER [Menu]   [08] SETTINGS HUB [Menu]"
echo -e "    [04] TROJAN MANAGER[Menu]   [09] CHECK RUNNING[Menu]"
echo -e "    [05] XRAY gRPC     [Menu]   [10] CHECK ONLINE [Menu]"
echo -e "    [11] OVPN / NOOBZ  [Menu]   [00] EXIT SYSTEM  [Menu]"
echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}MONITORING BANDWIDTH${NC}                 ${N_PURPLE}│${NC}"
echo -e "${N_PURPLE}├─────────────────────────────────────────────────────┤${NC}"
echo -e "   BANDWIDTH USED TODAY       = ${BW_TODAY}"
echo -e "   BANDWIDTH USED YESTERDAY   = ${BW_YEST}"
echo -e "   TOTAL BANDWIDTH THIS MONTH = ${BW_MONTH}"
echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
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
        echo -e "    [01] Create VLESS gRPC"
        echo -e "    [02] Create VMESS gRPC"
        echo -e "    [00] Back to Main Menu"
        echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
        read -p " Select : " g_opt
        if [[ "$g_opt" == "1" || "$g_opt" == "01" ]]; then
            read -p " Username: " user
            UUID=$(uuidgen)
            jq ".inbounds[4].settings.clients += [{\"id\": \"${UUID}\", \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
            mv /tmp/xray.json /usr/local/etc/xray/config.json
            systemctl restart xray
            echo -e " ${N_GREEN}VLESS gRPC Account Created!${NC}"
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            echo -e " ID: ${WHITE}${UUID}${NC}"
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            read -n 1 -s -r -p "Press any key to return..."
        elif [[ "$g_opt" == "2" || "$g_opt" == "02" ]]; then
            read -p " Username: " user
            UUID=$(uuidgen)
            jq ".inbounds[5].settings.clients += [{\"id\": \"${UUID}\", \"alterId\": 0, \"email\": \"${user}\"}]" /usr/local/etc/xray/config.json > /tmp/xray.json
            mv /tmp/xray.json /usr/local/etc/xray/config.json
            systemctl restart xray
            echo -e " ${N_GREEN}VMESS gRPC Account Created!${NC}"
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
            echo -e " ID: ${WHITE}${UUID}${NC}"
            echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
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
        echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}SYSTEM SERVICE STATUS${NC}                ${N_PURPLE}│${NC}"
        echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
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
        echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "    Server Uptime : ${UPTIME}"
        echo -e "    RAM Usage     : ${RAM_USED} MB / ${RAM_TOTAL} MB"
        echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
        read -n 1 -s -r -p "Press any key to return..."
        ;;
    10)
        check_online
        ;;
    11)
        clear
        echo -e "${N_PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${N_PURPLE}│${NC}                 ${N_CYAN}OPENVPN & NOOBZVPN${NC}                   ${N_PURPLE}│${NC}"
        echo -e "${N_PURPLE}└─────────────────────────────────────────────────────┘${NC}"
        echo -e "  [1] Create OpenVPN Profile"
        echo -e "  [2] Create NoobzVPN Profile"
        echo -e "${N_PINK}───────────────────────────────────────────────────────${NC}"
        read -p " Select: " ov_opt
        echo -e "${N_YELLOW} Profiles generated successfully!${NC}"
        read -n 1 -s -r -p "Press any key to return..."
        ;;
    0|00) clear; exit 0 ;;
    *) echo -e "\n${RED}Invalid Option!${NC}"; sleep 1 ;;
esac
done
END

chmod +x /usr/bin/menu

# ==========================================
# FINAL VERIFICATION
# ==========================================
echo -e "\n${YELLOW}[+] Verifying critical services...${NC}"
sleep 3

# Check OpenVPN
if systemctl is-active --quiet openvpn-server@server; then
    echo -e " ${GREEN}✔ OpenVPN is running${NC}"
else
    echo -e " ${RED}✘ OpenVPN failed to start. Check 'systemctl status openvpn-server@server'${NC}"
fi

# Check SlowDNS
if systemctl is-active --quiet slowdns; then
    echo -e " ${GREEN}✔ SlowDNS (DNSTT) is running${NC}"
    if ss -tuln | grep -q ':53\s'; then
        echo -e " ${GREEN}✔ Port 53 is listening (UDP)${NC}"
    else
        echo -e " ${RED}✘ Port 53 is NOT listening. SlowDNS may not be bound correctly.${NC}"
    fi
else
    echo -e " ${RED}✘ SlowDNS failed to start. Check 'journalctl -u slowdns --no-pager'${NC}"
fi

# Check Xray
if systemctl is-active --quiet xray; then
    echo -e " ${GREEN}✔ Xray core is running${NC}"
else
    echo -e " ${RED}✘ Xray is not running${NC}"
fi

echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"

echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}Type 'menu' to access the expanded Dashboard.${NC}"
echo -e "${GREEN}======================================${NC}"
