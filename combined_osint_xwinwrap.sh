#!/bin/bash
# Combined Minimal OSINT + Xwinwrap Setup for Kali (Debian-based)
#
# 1. Installs minimal OSINT environment:
#    - Tor, Proxychains, Firefox ESR, Git, Python3-Pip, theHarvester, Dmitry
#    - Clones recon-ng, Sherlock, Holehe via Proxychains (if desired)
#    - Configures Proxychains to use Tor
#
# 2. Installs Xwinwrap:
#    - Installs dependencies and compiles xwinwrap from source
#    - Installs mpv for animated/video wallpapers
#
# Run this script as root (sudo).

set -e  # Exit on error

##############################
# 1. Minimal OSINT Setup
##############################

echo "[*] Minimal OSINT Setup..."

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (e.g., sudo ./script.sh)."
  exit 1
fi

echo "[*] Updating package lists (minimal, to save space)..."
apt-get update

echo "[*] Installing essential OSINT packages..."
apt-get install -y tor proxychains firefox-esr git python3-pip theharvester dmitry

echo "[*] Starting Tor service..."
service tor start

echo "[*] Backing up and configuring Proxychains..."
PROXYCHAINS_CONF="/etc/proxychains.conf"
cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak"

# Use SOCKS5 on 127.0.0.1:9050
sed -i 's/^socks4.*/socks5\t127.0.0.1\t9050/' "$PROXYCHAINS_CONF"

# Uncomment if you prefer 'dynamic_chain' (often more forgiving than 'strict_chain'):
# sed -i 's/^strict_chain/#strict_chain/' "$PROXYCHAINS_CONF"
# sed -i 's/^#dynamic_chain/dynamic_chain/' "$PROXYCHAINS_CONF"

echo "[*] (Optional) Installing additional OSINT tools via Proxychains..."

# recon-ng
if [ ! -d "/opt/recon-ng" ]; then
  echo "  -> Installing recon-ng..."
  proxychains git clone https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
  cd /opt/recon-ng || exit
  proxychains pip3 install -r REQUIREMENTS
  cd - || exit
else
  echo "  -> /opt/recon-ng already exists, skipping."
fi

# Sherlock
if [ ! -d "/opt/sherlock" ]; then
  echo "  -> Installing Sherlock..."
  proxychains git clone https://github.com/sherlock-project/sherlock.git /opt/sherlock
else
  echo "  -> /opt/sherlock already exists, skipping."
fi

# Holehe
if [ ! -d "/opt/holehe" ]; then
  echo "  -> Installing Holehe..."
  proxychains git clone https://github.com/megadose/holehe.git /opt/holehe
  cd /opt/holehe || exit
  proxychains pip3 install -r requirements.txt
  cd - || exit
else
  echo "  -> /opt/holehe already exists, skipping."
fi

echo "[*] Cleaning up unused packages and cache..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

echo ""
echo "[*] Minimal OSINT environment installed!"
echo "    To launch Firefox via Tor, run: proxychains firefox-esr"
echo "    For more privacy in Firefox, open about:config and set: privacy.resistFingerprinting = true"
echo ""

##############################
# 2. Xwinwrap Installation
##############################

echo "[*] Proceeding with Xwinwrap installation..."

echo "📦 Installing required dependencies for Xwinwrap..."
apt-get update
apt-get install -y xorg-dev build-essential libx11-dev x11proto-xext-dev libxrender-dev libxext-dev mpv

echo "🔄 Cloning xwinwrap repository..."
git clone https://github.com/mmhobi7/xwinwrap.git
cd xwinwrap

echo "🔧 Compiling xwinwrap..."
make
sudo make install

echo "🧹 Cleaning up build files..."
make clean

cd - || exit

echo "✅ Xwinwrap installation completed!"
echo ""
echo "You can now use xwinwrap to set animated or video wallpapers (using mpv, for example)."
echo "Refer to xwinwrap documentation for usage instructions."
echo ""
echo "Script finished successfully!"
