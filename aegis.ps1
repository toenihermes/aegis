<#
.SYNOPSIS
    Aegis - Secure SSH Setup Wizard (PowerShell Edition)
.DESCRIPTION
    A wizard to easily bridge the gap to your remote servers (SSH setup) on Windows.
#>

$ErrorActionPreference = "Stop"

# Colors
function Write-Info ($Message) { Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success ($Message) { Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warn ($Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-ErrorMsg ($Message) { Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Show-Header {
    Clear-Host
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "       Aegis - Secure SSH Setup         " -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

Show-Header

Write-Host "This wizard will help you set up SSH key-based authentication to a remote server.`n"

# Step 1: SSH Key Selection
Write-Host "Step 1: SSH Key Setup" -ForegroundColor Yellow
Write-Host "Do you want to generate a new SSH key or use an existing one?"
Write-Host "1) Generate new key (Recommended for new setups)"
Write-Host "2) Use existing key"
$keyChoice = Read-Host "Select [1/2]"

$sshKeyPath = ""

if ($keyChoice -eq "1") {
    Write-Host "`nChoose key type:"
    Write-Host "1) Ed25519 (Modern, secure, fast - Recommended)"
    Write-Host "2) RSA (Legacy compatibility)"
    $typeChoice = Read-Host "Select [1/2]"

    if ($typeChoice -eq "2") {
        $keyType = "rsa"
        $defaultName = "id_rsa"
    } else {
        $keyType = "ed25519"
        $defaultName = "id_ed25519"
    }

    $keyName = Read-Host "Enter file name for new key (default: ~\.ssh\$defaultName)"
    if ([string]::IsNullOrWhiteSpace($keyName)) {
        $sshKeyPath = "$HOME\.ssh\$defaultName"
    } elseif ($keyName -match "^[a-zA-Z]:" -or $keyName -match "^\\") {
        $sshKeyPath = $keyName
    } else {
        $sshKeyPath = "$HOME\.ssh\$keyName"
    }

    if (Test-Path $sshKeyPath) {
        Write-Warn "Key already exists at $sshKeyPath"
        $overwrite = Read-Host "Overwrite? (y/N)"
        if ($overwrite -ne "y" -and $overwrite -ne "Y") {
            Write-ErrorMsg "Aborted by user."
            exit 1
        }
    }

    # Ensure .ssh directory exists
    $sshDir = Split-Path $sshKeyPath -Parent
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
    }

    Write-Host "Generating $keyType key..."
    ssh-keygen -t $keyType -f $sshKeyPath -C "aegis-$(Get-Date -Format 'yyyyMMdd')"
    Write-Success "Key generated at $sshKeyPath"

} elseif ($keyChoice -eq "2") {
    Write-Host "`nAvailable keys in ~\.ssh\:"
    if (Test-Path "$HOME\.ssh") {
        Get-ChildItem "$HOME\.ssh\id_*" -Exclude "*.pub" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    } else {
        Write-Host "No .ssh directory found."
    }
    
    Write-Host ""
    $inputPath = Read-Host "Enter full path to your private key (e.g., C:\Users\Name\.ssh\id_ed25519)"
    # Expand tilde if present
    if ($inputPath.StartsWith("~")) {
        $inputPath = $inputPath.Replace("~", $HOME)
    }
    $sshKeyPath = $inputPath

    if (-not (Test-Path $sshKeyPath)) {
        Write-ErrorMsg "File not found: $sshKeyPath"
        exit 1
    }
    Write-Info "Using key: $sshKeyPath"
} else {
    Write-ErrorMsg "Invalid selection."
    exit 1
}

# Step 2: Remote Host Info
Write-Host "`nStep 2: Remote Server Details" -ForegroundColor Yellow
$remoteUser = Read-Host "Remote User (e.g., root, ubuntu)"
$remoteHost = Read-Host "Remote Host (IP or Domain)"
$remotePort = Read-Host "Remote Port (default: 22)"
if ([string]::IsNullOrWhiteSpace($remotePort)) { $remotePort = "22" }

if ([string]::IsNullOrWhiteSpace($remoteUser) -or [string]::IsNullOrWhiteSpace($remoteHost)) {
    Write-ErrorMsg "User and Host are required."
    exit 1
}

# Step 3: Copy ID
Write-Host "`nStep 3: Copying Public Key to Remote" -ForegroundColor Yellow
Write-Host "Attempting to copy public key to $remoteUser@$remoteHost`:$remotePort..."
Write-Host "You may be asked for the remote user's password."

$pubKeyPath = "$sshKeyPath.pub"
if (-not (Test-Path $pubKeyPath)) {
    Write-ErrorMsg "Public key not found at $pubKeyPath"
    exit 1
}

$pubKeyContent = Get-Content -Path $pubKeyPath -Raw
# Clean up newlines for the command
$pubKeyContent = $pubKeyContent.Trim()

# Windows doesn't have ssh-copy-id, so we do it manually via ssh
# We use a script block to ensure proper quoting and execution on the remote side
try {
    # Construct the command to run on the remote server
    # We echo the key, make the dir, and append to authorized_keys
    $remoteCommand = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubKeyContent' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    
    ssh -p $remotePort "$remoteUser@$remoteHost" $remoteCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Public key successfully added to remote host!"
    } else {
        throw "SSH command returned exit code $LASTEXITCODE"
    }
} catch {
    Write-ErrorMsg "Failed to copy ID. Please check connectivity and password."
    Write-Host "Manual fallback: Copy the content of $pubKeyPath to ~/.ssh/authorized_keys on the remote server."
    exit 1
}

# Step 4: Config Alias
Write-Host "`nStep 4: SSH Config Alias (Optional)" -ForegroundColor Yellow
$createAlias = Read-Host "Do you want to create a shortcut alias? (e.g., 'ssh myserver') [y/N]"

if ($createAlias -eq "y" -or $createAlias -eq "Y") {
    $aliasName = Read-Host "Enter alias name (e.g., production)"
    
    $configFile = "$HOME\.ssh\config"
    if (-not (Test-Path "$HOME\.ssh")) {
        New-Item -ItemType Directory -Force -Path "$HOME\.ssh" | Out-Null
    }
    if (-not (Test-Path $configFile)) {
        New-Item -ItemType File -Path $configFile | Out-Null
    }

    $configContent = Get-Content $configFile -Raw -ErrorAction SilentlyContinue
    if ($configContent -match "Host $aliasName") {
        Write-Warn "Host '$aliasName' already exists in $configFile. Skipping."
    } else {
        $newEntry = "`nHost $aliasName`n    HostName $remoteHost`n    User $remoteUser`n    Port $remotePort`n    IdentityFile $sshKeyPath`n"
        Add-Content -Path $configFile -Value $newEntry
        
        Write-Success "Alias '$aliasName' added to $configFile"
        Write-Host "You can now connect using: ssh $aliasName"
    }
}

# Step 5: Test
Write-Host "`nStep 5: Verification" -ForegroundColor Yellow
$testConn = Read-Host "Do you want to test the connection now? [y/N]"
if ($testConn -eq "y" -or $testConn -eq "Y") {
    if (-not [string]::IsNullOrWhiteSpace($aliasName)) {
        ssh -q $aliasName exit
    } else {
        ssh -q -p $remotePort -i $sshKeyPath "$remoteUser@$remoteHost" exit
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Connection successful!"
    } else {
        Write-ErrorMsg "Connection failed. Please troubleshoot manually."
    }
}

Write-Host "`nSetup complete. Happy hacking!"
