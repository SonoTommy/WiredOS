#!/bin/bash
# Combined Minimal OSINT + Xwinwrap Installation Script for Kali
#
# 1. Installs system OSINT packages: Tor, Proxychains, Firefox ESR, Git, Python3-Pip, python3-venv, theHarvester, Dmitry
# 2. Configures Proxychains to use Tor (socks5 on 127.0.0.1:9050)
# 3. Clones recon-ng, Sherlock, Holehe into /opt and installs Python dependencies in local virtual environments
# 4. Installs xwinwrap (with dependencies), compiles from source, and cleans up
# 5. Avoids "externally-managed-environment" error by using venv for Python tools
#
# Run this script as root (sudo).

set -e  # Exit on any error

#######################################
# 1. Check if running as root
#######################################
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (e.g. sudo ./osint_xwinwrap_setup.sh)."
  exit 1
fi

#######################################
# 2. Update and install essential packages
#######################################
echo "[*] Updating package lists..."
apt-get update

echo "[*] Installing essential packages..."
apt-get install -y tor proxychains firefox-esr git python3-pip python3-venv theharvester dmitry

echo "[*] Starting Tor service..."
service tor start

#######################################
# 3. Configure Proxychains
#######################################
echo "[*] Backing up and configuring Proxychains..."
PROXYCHAINS_CONF="/etc/proxychains.conf"
cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak"

# Switch from socks4 to socks5 on 127.0.0.1:9050
sed -i 's/^socks4.*/socks5\t127.0.0.1\t9050/' "$PROXYCHAINS_CONF"

# Uncomment this if you prefer 'dynamic_chain' instead of 'strict_chain'
# sed -i 's/^strict_chain/#strict_chain/' "$PROXYCHAINS_CONF"
# sed -i 's/^#dynamic_chain/dynamic_chain/' "$PROXYCHAINS_CONF"

#######################################
# 4. Install Additional OSINT Tools (cloned in /opt), each with a venv
#######################################

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
  # Install dependencies inside the venv (using proxychains if you wish)
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

#######################################
# 5. Clean up to save space (OSINT portion)
#######################################
echo "[*] Cleaning up OSINT installation..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

#######################################
# 6. Install xwinwrap
#######################################
echo "[*] Installing xwinwrap dependencies..."
apt-get update
apt-get install -y xorg-dev build-essential libx11-dev x11proto-xext-dev libxrender-dev libxext-dev mpv

echo "[*] Cloning xwinwrap repository into /opt/xwinwrap..."
if [ ! -d "/opt/xwinwrap" ]; then
  git clone https://github.com/mmhobi7/xwinwrap.git /opt/xwinwrap
else
  echo "    -> /opt/xwinwrap already exists, skipping clone."
fi

echo "[*] Compiling and installing xwinwrap..."
cd /opt/xwinwrap || exit
make
make install
make clean
cd - >/dev/null || exit

echo "[*] Xwinwrap installation completed!"

#######################################
# 7. Final Output
#######################################
echo ""
echo "=================================================="
echo "[*] Minimal OSINT environment + Xwinwrap installed!"
echo ""
echo "OSINT Tools (system-wide): theHarvester, Dmitry"
echo "OSINT Tools (in /opt with .venv each): recon-ng, Sherlock, Holehe"
echo ""
echo "To run Firefox via Tor:"
echo "  proxychains firefox-esr"
echo ""
echo "For more privacy in Firefox:"
echo "  - Open about:config and set privacy.resistFingerprinting = true"
echo ""
echo "To use recon-ng (example):"
echo "  cd /opt/recon-ng"
echo "  source .venv/bin/activate"
echo "  python recon-ng"
echo "  deactivate"
echo ""
echo "Xwinwrap is now installed (check 'which xwinwrap' or run 'xwinwrap')."
echo "Use it with mpv for animated wallpapers, for example:"
echo "  xwinwrap -ni -fs -un -b -nf -- mpv --wid=%WID --loop /path/to/video.mp4"
echo "=================================================="
