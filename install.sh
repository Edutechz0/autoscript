#!/bin/bash
clear
echo -e "\033[0;34m┌────────────────────────────────────────────────────────┐\033[0m"
echo -e "\033[0;34m│\033[0m            \033[0;32mEDUFWESH SECURE INSTALLER\033[0m                   \033[0;34m│\033[0m"
echo -e "\033[0;34m└────────────────────────────────────────────────────────┘\033[0m"

IP=$(curl -s -4 ifconfig.me)
echo -e "\n\033[0;33m> Authenticating IP: $IP...\033[0m"

# Your Secure Cloudflare Vault
VAULT_URL="https://vault-gateway.edufwesh.workers.dev/"

# Attempt to download from the secure vault
wget -qO /tmp/edufwesh-installer "$VAULT_URL"

# Verify if Cloudflare allowed the download or blocked it
if ! file /tmp/edufwesh-installer | grep -q "ELF"; then
    echo -e "\033[0;31m[!] ACCESS DENIED: Your IP ($IP) is not registered.\033[0m"
    echo -e "\033[0;33mPlease click 'Whitelist VPS IP' in the Edufwesh Telegram Bot to authorize this server.\033[0m"
    rm -f /tmp/edufwesh-installer
    exit 1
fi

chmod +x /tmp/edufwesh-installer
echo -e "\033[0;32m[+] Authentication successful! Starting installation...\033[0m\n"

# Run the encrypted installer
/tmp/edufwesh-installer

# Delete it from the VPS immediately after it finishes running
rm -f /tmp/edufwesh-installer