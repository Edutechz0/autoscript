#!/bin/bash
# ==============================================================================
# EDUFWESH OPENVPN STANDALONE BOOTSTRAPPER
# ==============================================================================

clear
echo "=========================================================="
echo "   Initiating Edufwesh OpenVPN Secure Installer...        "
echo "=========================================================="

# Securely pull the real master installer from your dedicated OpenVPN Cloudflare Vault
wget -qO /tmp/setup.sh "https://openvpn-vault.edufwesh.workers.dev/setup.sh"

# Verify download success and execute
if [ -s /tmp/setup.sh ]; then
    chmod +x /tmp/setup.sh
    /tmp/setup.sh
    
    # Clean up traces after execution
    rm -f /tmp/setup.sh
else
    echo -e "\033[0;31m[!] Error: Failed to reach the secure Cloudflare Vault. Your IP may not be whitelisted, or the server is down.\033[0m"
    exit 1
fi
