#!/usr/bin/env bash

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
log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

print_header() {
    clear
    printf "${CYAN}\n"
    printf "========================================\n"
    printf "       Aegis - Secure SSH Setup         \n"
    printf "========================================\n"
    printf "${NC}\n"
}

# Check for dependencies
check_dependency() {
    command -v "$1" >/dev/null 2>&1
}

# Determine input source for interactive prompts
# This is critical for 'curl | bash' usage where stdin is the script itself
if [ -c /dev/tty ]; then
    INPUT_SOURCE="/dev/tty"
else
    INPUT_SOURCE="/dev/stdin"
fi

# Main Wizard
print_header

printf "This wizard will help you set up SSH key-based authentication to a remote server.\n\n"

# Step 1: SSH Key Selection
printf "${YELLOW}Step 1: SSH Key Setup${NC}\n"
printf "Do you want to generate a new SSH key or use an existing one?\n"
printf "1) Generate new key (Recommended for new setups)\n"
printf "2) Use existing key\n"
read -p "Select [1/2]: " key_choice < "$INPUT_SOURCE"

SSH_KEY_PATH=""

if [[ "$key_choice" == "1" ]]; then
    printf "\nChoose key type:\n"
    printf "1) Ed25519 (Modern, secure, fast - Recommended)\n"
    printf "2) RSA (Legacy compatibility)\n"
    read -p "Select [1/2]: " type_choice < "$INPUT_SOURCE"

    if [[ "$type_choice" == "2" ]]; then
        KEY_TYPE="rsa"
        DEFAULT_NAME="id_rsa"
    else
        KEY_TYPE="ed25519"
        DEFAULT_NAME="id_ed25519"
    fi

    read -p "Enter file name for new key (default: ~/.ssh/$DEFAULT_NAME): " key_name < "$INPUT_SOURCE"
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
        read -p "Overwrite? (y/N): " overwrite < "$INPUT_SOURCE"
        if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
            log_error "Aborted by user."
            exit 1
        fi
    fi

    printf "Generating $KEY_TYPE key...\n"
    ssh-keygen -t "$KEY_TYPE" -f "$SSH_KEY_PATH" -C "aegis-$(date +%Y%m%d)"
    log_success "Key generated at $SSH_KEY_PATH"

elif [[ "$key_choice" == "2" ]]; then
    printf "\nAvailable keys in ~/.ssh/:\n"
    # Portable way to list keys, handling no matches gracefully
    if ls "$HOME/.ssh/"id_* 1> /dev/null 2>&1; then
        ls "$HOME/.ssh/"id_* 2>/dev/null | grep -v ".pub" || printf "No standard keys found.\n"
    else
        printf "No standard keys found in ~/.ssh/\n"
    fi
    printf "\n"
    read -p "Enter full path to your private key (e.g., ~/.ssh/id_ed25519): " input_path < "$INPUT_SOURCE"
    # Expand tilde manually if needed
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
printf "\n${YELLOW}Step 2: Remote Server Details${NC}\n"
read -p "Remote User (e.g., root, ubuntu): " REMOTE_USER < "$INPUT_SOURCE"
read -p "Remote Host (IP or Domain): " REMOTE_HOST < "$INPUT_SOURCE"
read -p "Remote Port (default: 22): " REMOTE_PORT < "$INPUT_SOURCE"
REMOTE_PORT=${REMOTE_PORT:-22}

if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" ]]; then
    log_error "User and Host are required."
    exit 1
fi

# Step 3: Copy ID
printf "\n${YELLOW}Step 3: Copying Public Key to Remote${NC}\n"
printf "Attempting to copy public key to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT...\n"
printf "You may be asked for the remote user's password.\n"

PUB_KEY="${SSH_KEY_PATH}.pub"

if check_dependency ssh-copy-id; then
    # Use ssh-copy-id if available
    ssh-copy-id -i "$PUB_KEY" -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST"
    COPY_STATUS=$?
else
    # Fallback for macOS/systems without ssh-copy-id
    log_info "ssh-copy-id not found. Using manual fallback..."
    cat "$PUB_KEY" | ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    COPY_STATUS=$?
fi

if [[ $COPY_STATUS -eq 0 ]]; then
    log_success "Public key successfully added to remote host!"
else
    log_error "Failed to copy ID. Please check connectivity and password."
    printf "Manual fallback: Copy the content of $PUB_KEY to ~/.ssh/authorized_keys on the remote server.\n"
    exit 1
fi

# Step 4: Config Alias
printf "\n${YELLOW}Step 4: SSH Config Alias (Optional)${NC}\n"
read -p "Do you want to create a shortcut alias? (e.g., 'ssh myserver') [y/N]: " create_alias < "$INPUT_SOURCE"

if [[ "$create_alias" == "y" || "$create_alias" == "Y" ]]; then
    read -p "Enter alias name (e.g., production): " ALIAS_NAME < "$INPUT_SOURCE"
    
    CONFIG_FILE="$HOME/.ssh/config"
    mkdir -p "$HOME/.ssh"
    touch "$CONFIG_FILE"

    if grep -q "Host $ALIAS_NAME" "$CONFIG_FILE"; then
        log_warn "Host '$ALIAS_NAME' already exists in $CONFIG_FILE. Skipping."
    else
        printf "\n" >> "$CONFIG_FILE"
        printf "Host $ALIAS_NAME\n" >> "$CONFIG_FILE"
        printf "    HostName $REMOTE_HOST\n" >> "$CONFIG_FILE"
        printf "    User $REMOTE_USER\n" >> "$CONFIG_FILE"
        printf "    Port $REMOTE_PORT\n" >> "$CONFIG_FILE"
        printf "    IdentityFile $SSH_KEY_PATH\n" >> "$CONFIG_FILE"
        
        log_success "Alias '$ALIAS_NAME' added to $CONFIG_FILE"
        printf "You can now connect using: ssh $ALIAS_NAME\n"
    fi
fi

# Step 5: Test
printf "\n${YELLOW}Step 5: Verification${NC}\n"
read -p "Do you want to test the connection now? [y/N]: " test_conn < "$INPUT_SOURCE"
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

printf "\nSetup complete. Happy hacking!\n"
