# Aegis 🛡️

**Aegis** is a secure, interactive CLI tool that simplifies setting up SSH key-based authentication for your servers.

## Features
- **Interactive Wizard**: Guides you step-by-step.
- **Key Generation**: Supports Ed25519 (recommended) and RSA.
- **Auto-Copy**: Uses `ssh-copy-id` to transfer keys securely.
- **Config Management**: Optionally creates a convenient alias in `~/.ssh/config`.

## Usage

1.  Make the script executable:
    ```bash
    chmod +x aegis.sh
    ```

2.  Run the wizard:
    ```bash
    ./aegis.sh
    ```

3.  Follow the on-screen prompts to:
    - Select or generate an SSH key.
    - Enter your remote server details (User, Host, Port).
    - Copy the key to the server.
    - (Optional) Create a shortcut alias (e.g., `ssh myserver`).

## Requirements
- Bash
- OpenSSH Client (`ssh`, `ssh-keygen`, `ssh-copy-id`)
- Access to a remote server (password required for initial setup)
