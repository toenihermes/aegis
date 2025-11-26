# Aegis 🛡️

**Aegis** is a secure, interactive CLI tool that simplifies setting up SSH key-based authentication for your servers.

## Features
- **Interactive Wizard**: Guides you step-by-step.
- **Key Generation**: Supports Ed25519 (recommended) and RSA.
- **Auto-Copy**: Uses `ssh-copy-id` to transfer keys securely.
- **Config Management**: Optionally creates a convenient alias in `~/.ssh/config`.

## Installation

### Linux / macOS
You can run **Aegis** directly without downloading it manually. 

**Recommended (preserves interactive input):**
```bash
bash <(curl -sL https://raw.githubusercontent.com/toenihermes/aegis/main/aegis.sh)
```

**Alternative:**
```bash
curl -sL https://raw.githubusercontent.com/toenihermes/aegis/main/aegis.sh | bash
```

### Windows (PowerShell)
Run the following command in PowerShell:

```powershell
irm https://raw.githubusercontent.com/toenihermes/aegis/main/aegis.ps1 | iex
```

## Usage

Alternatively, if you want to download and run it manually:

### Linux / macOS
1.  Clone or download the script:
    ```bash
    git clone https://github.com/toenihermes/aegis.git
    cd aegis
    chmod +x aegis.sh
    ```
2.  Run the wizard:
    ```bash
    ./aegis.sh
    ```

### Windows
1.  Clone or download the script.
2.  Run in PowerShell:
    ```powershell
    .\aegis.ps1
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
