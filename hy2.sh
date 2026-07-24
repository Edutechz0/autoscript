#!/bin/bash
# ==============================================================================
# EDUFWESH HYSTERIA2 STANDALONE - GITHUB FRONT DOOR
# ==============================================================================

VAULT_GATEWAY="https://hy2-vault.edufwesh.workers.dev/setup.sh"

echo "Connecting to Edufwesh Hysteria Vault..."
wget -qO setup.sh "$VAULT_GATEWAY"

if [ -f setup.sh ]; then
    chmod +x setup.sh
    ./setup.sh
else
    echo "Error: Vault connection blocked or IP not authorized."
    exit 1
fi