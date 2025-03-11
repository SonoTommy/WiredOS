#!/bin/bash
# Minimal OSINT Setup Script for Kali Live
#
# Installs:
#   - System essentials: Tor, Proxychains, Firefox ESR, Git, Python3-Pip
#   - Lightweight OSINT tools: theHarvester, dmitry
#   - Additional OSINT tools (cloned via Git with Proxychains): recon-ng, Sherlock, Holehe
# Configures Proxychains to use Tor (socks5 on 127.0.0.1:9050).
#
# Note: Run as root.

# 1. Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (e.g., sudo ./osint_setup.sh)."
  exit 1
fi

# 2. Update package lists (skipping full upgrade to save space)
echo "[*] Updating package lists..."
apt-get update

# 3. Install essential packages
echo "[*] Installing essential packages..."
apt-get install -y tor proxychains firefox-esr git python3-pip theharvester dmitry

# 4. Start Tor service
echo "[*] Starting Tor service..."
service tor start

# 5. Configure Proxychains to use Tor
echo "[*] Backing up and configuring Proxychains..."
PROXYCHAINS_CONF="/etc/proxychains.conf"
cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak"

# Use SOCKS5 on 127.0.0.1:9050
sed -i 's/^socks4.*/socks5\t127.0.0.1\t9050/' "$PROXYCHAINS_CONF"

# 6. Clone and install additional OSINT tools via Proxychains

# recon-ng
echo "[*] Installing recon-ng..."
if [ ! -d "/opt/recon-ng" ]; then
  proxychains git clone https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
  cd /opt/recon-ng || exit
  proxychains pip3 install -r REQUIREMENTS
  cd - || exit
else
  echo "    -> /opt/recon-ng already exists, skipping."
fi

# Sherlock
echo "[*] Installing Sherlock..."
if [ ! -d "/opt/sherlock" ]; then
  proxychains git clone https://github.com/sherlock-project/sherlock.git /opt/sherlock
else
  echo "    -> /opt/sherlock already exists, skipping."
fi

# Holehe
echo "[*] Installing Holehe..."
if [ ! -d "/opt/holehe" ]; then
  proxychains git clone https://github.com/megadose/holehe.git /opt/holehe
  cd /opt/holehe || exit
  proxychains pip3 install -r requirements.txt
  cd - || exit
else
  echo "    -> /opt/holehe already exists, skipping."
fi

# 7. Clean up to save space
echo "[*] Cleaning up unused packages and cache..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean
# Optionally remove the local apt cache if needed:
# rm -rf /var/cache/apt/archives/*

echo ""
echo "[*] Minimal OSINT installation completed."
echo ""
echo "=== Usage Instructions ==="
echo "1. To launch Firefox via Tor, run:"
echo "     proxychains firefox-esr"
echo ""
echo "2. For more privacy in Firefox, open about:config and set:"
echo "     privacy.resistFingerprinting = true"
echo "   And consider installing privacy add-ons like CanvasBlocker."
echo ""
echo "3. Tools installed:"
echo "   - theHarvester, dmitry (installed via apt)"
echo "   - recon-ng, Sherlock, Holehe (cloned in /opt)"
echo ""
echo "Enjoy your minimal OSINT environment!"
