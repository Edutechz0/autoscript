#!/bin/bash
# ==============================================================================
# EDUFWESH OPENVPN STANDALONE - GITHUB FRONT DOOR
# ==============================================================================

VAULT_GATEWAY="https://openvpn-vault.edufwesh.workers.dev/setup.sh"

echo "Connecting to Edufwesh Vault..."
wget -qO setup.sh "$VAULT_GATEWAY"

if [ -f setup.sh ]; then
    chmod +x setup.sh
    ./setup.sh
else
    echo "Error: Vault connection blocked or IP not authorized."
    exit 1
fi