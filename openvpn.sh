#!/bin/bash
# ==============================================================================
# EDUFWESH OPENVPN STANDALONE BOOTSTRAPPER
# ==============================================================================

clear
echo "=========================================================="
echo "   Initiating Edufwesh OpenVPN Secure Installer...        "
echo "=========================================================="

# Securely pull the real master installer from your Cloudflare Vault
wget -qO /tmp/setup_ovpn.sh "https://vault-gateway.edufwesh.workers.dev/openvpn/setup.sh"

# Verify download success and execute
if [ -s /tmp/setup_ovpn.sh ]; then
    chmod +x /tmp/setup_ovpn.sh
    /tmp/setup_ovpn.sh
    # Clean up traces after execution
    rm -f /tmp/setup_ovpn.sh
else
    echo -e "\033[0;31m[!] Error: Failed to reach the secure Cloudflare Vault. Please check your internet connection.\033[0m"
    exit 1
fi