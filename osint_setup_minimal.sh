#!/bin/bash
# Minimal OSINT Setup Script for Kali
# 
# - Installs system packages: Tor, Proxychains, Firefox ESR, Git, Python3-Pip, theHarvester, Dmitry
# - Configures Proxychains to use Tor (socks5 on 127.0.0.1:9050)
# - Clones recon-ng, Sherlock, Holehe and installs their Python dependencies in local virtual environments
# - Avoids "externally-managed-environment" error by using venv
#
# Run this script as root (sudo).

set -e  # Exit on error

# 1. Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (e.g. sudo ./osint_setup_minimal.sh)."
  exit 1
fi

# 2. Update and install essential packages
echo "[*] Updating package lists..."
apt-get update

echo "[*] Installing essential packages..."
apt-get install -y tor proxychains firefox-esr git python3-pip python3-venv theharvester dmitry

echo "[*] Starting Tor service..."
service tor start

# 3. Configure Proxychains
echo "[*] Backing up and configuring Proxychains..."
PROXYCHAINS_CONF="/etc/proxychains.conf"
cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak"

# Switch from socks4 to socks5 on 127.0.0.1:9050
sed -i 's/^socks4.*/socks5\t127.0.0.1\t9050/' "$PROXYCHAINS_CONF"

# Uncomment this if you prefer 'dynamic_chain' instead of 'strict_chain'
# sed -i 's/^strict_chain/#strict_chain/' "$PROXYCHAINS_CONF"
# sed -i 's/^#dynamic_chain/dynamic_chain/' "$PROXYCHAINS_CONF"

# 4. Install Additional OSINT Tools (cloned in /opt), each with a venv

# Helper function to create a venv and install requirements
create_venv_and_install() {
  local repo_dir="$1"
  local requirements_file="$2"
  
  cd "$repo_dir" || exit
  # Create a virtual environment named .venv if it doesn't exist
  if [ ! -d ".venv" ]; then
    echo "    -> Creating virtual environment in $repo_dir/.venv"
    python3 -m venv .venv
  fi
  # Activate venv
  source .venv/bin/activate
  # Install dependencies inside the venv
  if [ -f "$requirements_file" ]; then
    echo "    -> Installing dependencies from $requirements_file"
    proxychains pip install -r "$requirements_file"
  fi
  deactivate
  cd - >/dev/null || exit
}

echo "[*] Installing recon-ng..."
if [ ! -d "/opt/recon-ng" ]; then
  proxychains git clone https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
  create_venv_and_install "/opt/recon-ng" "REQUIREMENTS"
else
  echo "    -> /opt/recon-ng already exists, skipping clone."
  # Still ensure requirements are installed
  create_venv_and_install "/opt/recon-ng" "REQUIREMENTS"
fi

echo "[*] Installing Sherlock..."
if [ ! -d "/opt/sherlock" ]; then
  proxychains git clone https://github.com/sherlock-project/sherlock.git /opt/sherlock
  # Sherlock's dependencies are in requirements.txt
  create_venv_and_install "/opt/sherlock" "requirements.txt"
else
  echo "    -> /opt/sherlock already exists, skipping clone."
  create_venv_and_install "/opt/sherlock" "requirements.txt"
fi

echo "[*] Installing Holehe..."
if [ ! -d "/opt/holehe" ]; then
  proxychains git clone https://github.com/megadose/holehe.git /opt/holehe
  create_venv_and_install "/opt/holehe" "requirements.txt"
else
  echo "    -> /opt/holehe already exists, skipping clone."
  create_venv_and_install "/opt/holehe" "requirements.txt"
fi

# 5. Clean up to save space
echo "[*] Cleaning up..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

# 6. Done!
echo ""
echo "[*] Minimal OSINT environment installed!"
echo "[*] Tools installed system-wide: theHarvester, Dmitry"
echo "[*] Tools cloned in /opt: recon-ng, Sherlock, Holehe"
echo "    Each has a local Python venv in its own folder (.venv)."
echo ""
echo "=== How to Use ==="
echo "1. To run Firefox via Tor, use:"
echo "     proxychains firefox-esr"
echo "2. For more privacy in Firefox, open about:config and set:"
echo "     privacy.resistFingerprinting = true"
echo "3. To run recon-ng (as an example):"
echo "     cd /opt/recon-ng"
echo "     source .venv/bin/activate"
echo "     python recon-ng"
echo "   (Replace with your preferred usage. Then 'deactivate' to exit venv.)"
echo ""
echo "Enjoy your minimal OSINT environment!"
