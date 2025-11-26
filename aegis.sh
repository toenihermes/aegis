#!/bin/bash

# Aegis
# Secure and simple SSH key authentication setup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    clear
    echo -e "${CYAN}"
    echo "========================================"
    echo "       Aegis - Secure SSH Setup         "
    echo "========================================"
    echo -e "${NC}"
}

# Main Wizard
print_header

echo "This wizard will help you set up SSH key-based authentication to a remote server."
echo ""

# Step 1: SSH Key Selection
echo -e "${YELLOW}Step 1: SSH Key Setup${NC}"
echo "Do you want to generate a new SSH key or use an existing one?"
echo "1) Generate new key (Recommended for new setups)"
echo "2) Use existing key"
read -p "Select [1/2]: " key_choice

SSH_KEY_PATH=""

if [[ "$key_choice" == "1" ]]; then
    echo ""
    echo "Choose key type:"
    echo "1) Ed25519 (Modern, secure, fast - Recommended)"
    echo "2) RSA (Legacy compatibility)"
    read -p "Select [1/2]: " type_choice

    if [[ "$type_choice" == "2" ]]; then
        KEY_TYPE="rsa"
        DEFAULT_NAME="id_rsa"
    else
        KEY_TYPE="ed25519"
        DEFAULT_NAME="id_ed25519"
    fi

    read -p "Enter file name for new key (default: ~/.ssh/$DEFAULT_NAME): " key_name
    if [[ -z "$key_name" ]]; then
        SSH_KEY_PATH="$HOME/.ssh/$DEFAULT_NAME"
    else
        # Handle absolute vs relative paths
        if [[ "$key_name" = /* ]]; then
            SSH_KEY_PATH="$key_name"
        else
            SSH_KEY_PATH="$HOME/.ssh/$key_name"
        fi
    fi

    if [[ -f "$SSH_KEY_PATH" ]]; then
        log_warn "Key already exists at $SSH_KEY_PATH"
        read -p "Overwrite? (y/N): " overwrite
        if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
            log_error "Aborted by user."
            exit 1
        fi
    fi

    echo "Generating $KEY_TYPE key..."
    ssh-keygen -t "$KEY_TYPE" -f "$SSH_KEY_PATH" -C "ssh-wizard-$(date +%Y%m%d)"
    log_success "Key generated at $SSH_KEY_PATH"

elif [[ "$key_choice" == "2" ]]; then
    echo ""
    echo "Available keys in ~/.ssh/:"
    ls "$HOME/.ssh/"id_* 2>/dev/null | grep -v ".pub" || echo "No standard keys found."
    echo ""
    read -p "Enter full path to your private key (e.g., ~/.ssh/id_ed25519): " input_path
    # Expand tilde manually if needed, though shell usually handles it on input
    SSH_KEY_PATH="${input_path/#\~/$HOME}"
    
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        log_error "File not found: $SSH_KEY_PATH"
        exit 1
    fi
    log_info "Using key: $SSH_KEY_PATH"
else
    log_error "Invalid selection."
    exit 1
fi

# Step 2: Remote Host Info
echo ""
echo -e "${YELLOW}Step 2: Remote Server Details${NC}"
read -p "Remote User (e.g., root, ubuntu): " REMOTE_USER
read -p "Remote Host (IP or Domain): " REMOTE_HOST
read -p "Remote Port (default: 22): " REMOTE_PORT
REMOTE_PORT=${REMOTE_PORT:-22}

if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" ]]; then
    log_error "User and Host are required."
    exit 1
fi

# Step 3: Copy ID
echo ""
echo -e "${YELLOW}Step 3: Copying Public Key to Remote${NC}"
echo "Attempting to copy public key to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT..."
echo "You may be asked for the remote user's password."

ssh-copy-id -i "${SSH_KEY_PATH}.pub" -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST"

if [[ $? -eq 0 ]]; then
    log_success "Public key successfully added to remote host!"
else
    log_error "Failed to copy ID. Please check connectivity and password."
    echo "Manual fallback: Copy the content of ${SSH_KEY_PATH}.pub to ~/.ssh/authorized_keys on the remote server."
    exit 1
fi

# Step 4: Config Alias
echo ""
echo -e "${YELLOW}Step 4: SSH Config Alias (Optional)${NC}"
read -p "Do you want to create a shortcut alias? (e.g., 'ssh myserver') [y/N]: " create_alias

if [[ "$create_alias" == "y" || "$create_alias" == "Y" ]]; then
    read -p "Enter alias name (e.g., production): " ALIAS_NAME
    
    CONFIG_FILE="$HOME/.ssh/config"
    mkdir -p "$HOME/.ssh"
    touch "$CONFIG_FILE"

    if grep -q "Host $ALIAS_NAME" "$CONFIG_FILE"; then
        log_warn "Host '$ALIAS_NAME' already exists in $CONFIG_FILE. Skipping."
    else
        echo "" >> "$CONFIG_FILE"
        echo "Host $ALIAS_NAME" >> "$CONFIG_FILE"
        echo "    HostName $REMOTE_HOST" >> "$CONFIG_FILE"
        echo "    User $REMOTE_USER" >> "$CONFIG_FILE"
        echo "    Port $REMOTE_PORT" >> "$CONFIG_FILE"
        echo "    IdentityFile $SSH_KEY_PATH" >> "$CONFIG_FILE"
        
        log_success "Alias '$ALIAS_NAME' added to $CONFIG_FILE"
        echo "You can now connect using: ssh $ALIAS_NAME"
    fi
fi

# Step 5: Test
echo ""
echo -e "${YELLOW}Step 5: Verification${NC}"
read -p "Do you want to test the connection now? [y/N]: " test_conn
if [[ "$test_conn" == "y" || "$test_conn" == "Y" ]]; then
    if [[ -n "$ALIAS_NAME" ]]; then
        ssh -q "$ALIAS_NAME" exit
    else
        ssh -q -p "$REMOTE_PORT" -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_HOST" exit
    fi

    if [[ $? -eq 0 ]]; then
        log_success "Connection successful!"
    else
        log_error "Connection failed. Please troubleshoot manually."
    fi
fi

echo ""
echo "Setup complete. Happy hacking!"
