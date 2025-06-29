#!/bin/bash

# install.sh - Universal Program Installer

# Check if a program name was provided
if [ -z "$1" ]; then
    echo "Usage: ./install.sh <program_name>"
    echo "Example: ./install.sh nmap"
    echo "Example: ./install.sh hydra"
    echo "Example: ./install.sh code"
    exit 1
fi

PROGRAM_NAME="$1"
SUCCESS=false

echo "Attempting to install '$PROGRAM_NAME' using various package managers..."
echo "---------------------------------------------------------------------"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Linux Package Managers ---

# APT (Debian/Ubuntu)
if command_exists apt-get; then
    echo "Trying with apt (Debian/Ubuntu)..."
    sudo apt-get update -y && sudo apt-get install -y "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "APT: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "APT: Failed to install '$PROGRAM_NAME'."
    fi
fi

# DNF (Fedora)
if command_exists dnf; then
    echo "Trying with dnf (Fedora)..."
    sudo dnf install -y "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "DNF: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "DNF: Failed to install '$PROGRAM_NAME'."
    fi
fi

# YUM (CentOS/RHEL older)
if command_exists yum; then
    echo "Trying with yum (CentOS/RHEL older)..."
    sudo yum install -y "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "YUM: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "YUM: Failed to install '$PROGRAM_NAME'."
    fi
fi

# Pacman (Arch Linux)
if command_exists pacman; then
    echo "Trying with pacman (Arch Linux)..."
    sudo pacman -S --noconfirm "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Pacman: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Pacman: Failed to install '$PROGRAM_NAME'."
    fi
fi

# Zypper (openSUSE)
if command_exists zypper; then
    echo "Trying with zypper (openSUSE)..."
    sudo zypper install -y "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Zypper: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Zypper: Failed to install '$PROGRAM_NAME'."
    fi
fi

# APK (Alpine Linux)
if command_exists apk; then
    echo "Trying with apk (Alpine Linux)..."
    sudo apk add "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "APK: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "APK: Failed to install '$PROGRAM_NAME'."
    fi
fi

# Nix Package Manager (Cross-platform, highly declarative)
if command_exists nix-env; then
    echo "Trying with Nix package manager..."
    nix-env -iA nixpkgs."$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Nix: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Nix: Failed to install '$PROGRAM_NAME'."
    fi
fi

# Snap (Universal Linux packaging)
if command_exists snap; then
    echo "Trying with snap..."
    sudo snap install "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Snap: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Snap: Failed to install '$PROGRAM_NAME'."
    fi
fi

# Flatpak (Universal Linux packaging)
if command_exists flatpak; then
    echo "Trying with flatpak..."
    flatpak install -y flathub "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Flatpak: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Flatpak: Failed to install '$PROGRAM_NAME'."
    fi
fi

# --- macOS Package Managers ---

# Homebrew (macOS)
if command_exists brew; then
    echo "Trying with Homebrew (macOS)..."
    brew install "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Homebrew: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Homebrew: Failed to install '$PROGRAM_NAME'."
    fi
fi

# MacPorts (macOS)
if command_exists port; then
    echo "Trying with MacPorts (macOS)..."
    sudo port install "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "MacPorts: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "MacPorts: Failed to install '$PROGRAM_NAME'."
    fi
fi

# --- Language-specific / Cross-platform Package Managers ---

# Pip (Python) - Common for many tools
if command_exists pip; then
    echo "Trying with pip (Python)..."
    pip install "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Pip: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Pip: Failed to install '$PROGRAM_NAME'."
    fi
elif command_exists pip3; then
    echo "Trying with pip3 (Python)..."
    pip3 install "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Pip3: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Pip3: Failed to install '$PROGRAM_NAME'."
    fi
fi

# Gem (Ruby)
if command_exists gem; then
    echo "Trying with gem (Ruby)..."
    gem install "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Gem: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Gem: Failed to install '$PROGRAM_NAME'."
    fi
fi

# npm (Node.js)
if command_exists npm; then
    echo "Trying with npm (Node.js)..."
    npm install -g "$PROGRAM_NAME" # -g for global installation
    if [ $? -eq 0 ]; then
        echo "npm: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "npm: Failed to install '$PROGRAM_NAME'."
    fi
fi

# Cargo (Rust)
if command_exists cargo; then
    echo "Trying with cargo (Rust)..."
    cargo install "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Cargo: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Cargo: Failed to install '$PROGRAM_NAME'."
    fi
fi

# Go (Go modules)
if command_exists go; then
    echo "Trying with go get (Go modules)..."
    go install "$PROGRAM_NAME"@latest # Example for Go modules, might need adjustment
    if [ $? -eq 0 ]; then
        echo "Go: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Go: Failed to install '$PROGRAM_NAME'."
    fi
fi

# Composer (PHP)
if command_exists composer; then
    echo "Trying with composer (PHP)..."
    composer global require "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Composer: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Composer: Failed to install '$PROGRAM_NAME'."
    fi
fi

# --- Windows Package Managers (via WSL/Git Bash compatibility) ---

# Chocolatey (Windows) - Will only work if Chocolatey is in your WSL/Git Bash PATH
if command_exists choco; then
    echo "Trying with Chocolatey (Windows - via choco command)..."
    # Note: Requires PowerShell execution policy to allow scripts, or running from admin shell
    # This might fail if not in a proper Windows environment or if permissions are off.
    choco install -y "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Chocolatey: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Chocolatey: Failed to install '$PROGRAM_NAME'."
    fi
fi

# Scoop (Windows) - Will only work if Scoop is in your WSL/Git Bash PATH
if command_exists scoop; then
    echo "Trying with Scoop (Windows - via scoop command)..."
    scoop install "$PROGRAM_NAME"
    if [ $? -eq 0 ]; then
        echo "Scoop: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Scoop: Failed to install '$PROGRAM_NAME'."
    fi
fi

# Winget (Windows 10/11) - Will only work if winget is in your WSL/Git Bash PATH
if command_exists winget; then
    echo "Trying with Winget (Windows - via winget command)..."
    winget install --id "$PROGRAM_NAME" --accept-source-agreements --accept-package-agreements
    if [ $? -eq 0 ]; then
        echo "Winget: Successfully installed '$PROGRAM_NAME'."
        SUCCESS=true
    else
        echo "Winget: Failed to install '$PROGRAM_NAME'."
    fi
fi

echo "---------------------------------------------------------------------"
if [ "$SUCCESS" = true ]; then
    echo "Installation attempt for '$PROGRAM_NAME' completed. At least one manager reported success."
else
    echo "Installation attempt for '$PROGRAM_NAME' completed. No manager reported successful installation."
    echo "Please check the output for errors or try installing manually with your preferred package manager."
fi

exit 0
