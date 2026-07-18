#!/bin/bash -v
#
# <UDF name="ClientNames" label="Client Names" example="laptop,phone,tablet" description="Comma-separated list of client names to provision." />
# <UDF name="WIREGUARD_PORT" label="Server Port" example="51820" description="Port for the WireGuard server to listen on." />
# <UDF name="BackupLocation" label="Backup Location" default="/mnt/long-term" example="/mnt/long-term" description="Location to store WireGuard backup files." />

set -euo pipefail

# 1. Define paths and network parameters
MOUNT_DIR="${BackupLocation:-/mnt/long-term}"
KEY_DIR="$MOUNT_DIR/wireguard_keys"
WG_DIR="/etc/wireguard"
IP_PREFIX="172.29.0"
SERVER_IP="${IP_PREFIX}.1"
CLIENT_IP_CIDR_SUFFIX="/24"
SERVER_PUBLIC_IP=$(curl -s https://ipify.org) # Dynamically fetches your Linode's public IP
SERVER_PORT="${WIREGUARD_PORT:-51820}" # port to be provided by the user in the UDF, or you can hardcode it here

# 2. Ensure WireGuard and QR tools are installed
apt-get update && apt-get install -y wireguard qrencode

# 3. Create persistent directories
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"
mkdir -p "$WG_DIR"

# 4. Generate or Import Server Keys
if [ -f "$KEY_DIR/server.private" ] && [ -f "$KEY_DIR/server.pub" ]; then
    SERVER_PRIV_KEY=$(cat "$KEY_DIR/server.private")
    SERVER_PUB_KEY=$(cat "$KEY_DIR/server.pub")
else
    SERVER_PRIV_KEY=$(wg genkey)
    SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)
    echo "$SERVER_PRIV_KEY" > "$KEY_DIR/server.private"
    echo "$SERVER_PUB_KEY" > "$KEY_DIR/server.pub"
    chmod 600 "$KEY_DIR/server.private"
fi

# 5. Initialize the base server configuration file
cat <<EOF > "$WG_DIR/wg0.conf"
[Interface]
PrivateKey = $SERVER_PRIV_KEY
Address = ${SERVER_IP}${CLIENT_IP_CIDR_SUFFIX}
ListenPort = $SERVER_PORT
EOF

# 6. Parse and Loop through the $ClientNames variable
CLIENT_LIST=$(echo "$ClientNames" | tr ',' ' ')
IP_COUNTER=2 

for CLIENT in $CLIENT_LIST; do
    # use xargs to trim whitespace from the client name
    CLIENT=$(echo "$CLIENT" | xargs | tr -d '\n')
    
    CLIENT_IP="${IP_PREFIX}.${IP_COUNTER}"
    CLIENT_PUB_FILE="$KEY_DIR/${CLIENT}.pub"
    CLIENT_PSK_FILE="$KEY_DIR/${CLIENT}.psk"

    # Track if the client has already been provisioned in the past
    # We check for the public key file, since the private key is never stored
    if [ -f "$CLIENT_PUB_FILE" ] && [ -f "$CLIENT_PSK_FILE" ]; then
        echo "Client credentials for '$CLIENT' already exist on storage. Skipping setup..."
        C_PUB=$(cat "$CLIENT_PUB_FILE")
        C_PSK=$(cat "$CLIENT_PSK_FILE")
        
        # Append the existing client to the server configuration
        cat <<EOF >> "$WG_DIR/wg0.conf"

[Peer]
Name = $CLIENT
PublicKey = $C_PUB
PresharedKey = $C_PSK
AllowedIPs = $CLIENT_IP/32
EOF

    else
        echo "Creating brand new IN-MEMORY configuration for client: $CLIENT"
        
        # 1. Generate keys strictly inside RAM variables
        C_PRIV=$(wg genkey)
        C_PUB=$(echo "$C_PRIV" | wg pubkey)
        C_PSK=$(wg genpsk)

        # 2. Persist ONLY the Public Key and PSK to disk
        echo "$C_PUB" > "$CLIENT_PUB_FILE"
        echo "$C_PSK" > "$CLIENT_PSK_FILE"
        chmod 600 "$CLIENT_PUB_FILE" "$CLIENT_PSK_FILE"

        # 3. Append to the server configuration (Server does NOT need the client's private key)
        cat <<EOF >> "$WG_DIR/wg0.conf"

[Peer]
Name = $CLIENT
PublicKey = $C_PUB
PresharedKey = $C_PSK
AllowedIPs = $CLIENT_IP/32
EOF

        # 4. Generate the client profile text inside a RAM variable (No file creation)
        CLIENT_CONF_TEXT=$(cat <<EOF
[Interface]
PrivateKey = $C_PRIV
Address = ${CLIENT_IP}${CLIENT_IP_CIDR_SUFFIX}

[Peer]
PublicKey = $SERVER_PUB_KEY
PresharedKey = $C_PSK
Endpoint = $SERVER_PUBLIC_IP:$SERVER_PORT
AllowedIPs = $SERVER_IP/32
EOF
)

        # 5. Output the configuration and QR code to the terminal log
        echo "=========================================================="
        echo " FIRST-TIME CONFIGURATION GENERATED FOR CLIENT: $CLIENT"
        echo " WARNING: The PrivateKey below is NOT saved to this server!"
        echo " Save it now or scan the QR code. It cannot be recovered."
        echo "=========================================================="
        echo "$CLIENT_CONF_TEXT"
        echo ""
        echo " SCAN QR CODE BELOW FOR: $CLIENT"
        echo "----------------------------------------------------------"
        # Pipe the string variable directly into qrencode via a here-string
        qrencode -t ansiutf8 <<< "$CLIENT_CONF_TEXT"
        echo "=========================================================="
        echo ""

        # 6. Explicitly clear the sensitive private variables from memory immediately
        unset C_PRIV
        unset CLIENT_CONF_TEXT
    fi

    IP_COUNTER=$((IP_COUNTER + 1))
done

# 7. Start the WireGuard Interface
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0
