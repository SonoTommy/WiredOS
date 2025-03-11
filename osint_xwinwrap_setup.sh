#!/bin/bash
# Minimal OSINT Setup + Xwinwrap Installer + Wallpaper Setter for Kali
#
# Changes from previous version:
#  - Installs Sherlock via apt (proxychains) instead of GitHub clone.
#  - Installs Holehe from GitHub.
#  - Everything else remains similar to the previous combined script.
#
# Run this script as root (sudo).
# Make sure you're logged into an X session if you want the wallpaper to appear immediately.

set -e  # Exit on error

###############################################################################
# 1. Check if running as root
###############################################################################
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (e.g., sudo ./osint_xwinwrap_setup.sh)."
  exit 1
fi

###############################################################################
# 2. Create wallpapers directory & download wallpaper
###############################################################################
echo "[*] Creating /home/kali/wallpapers directory..."
mkdir -p /home/kali/wallpapers

echo "[*] Downloading wallpaper_n1.gif into /home/kali/wallpapers..."
wget -O /home/kali/wallpapers/wallpaper_n1.gif "https://github.com/JustSouichi/WiredOS/releases/download/v0.1/wallpaper_n1.gif"

###############################################################################
# 3. Update and install essential OSINT packages
###############################################################################
echo "[*] Updating package lists..."
apt-get update

echo "[*] Installing essential OSINT packages..."
apt-get install -y tor proxychains firefox-esr git python3-pip python3-venv theharvester dmitry

echo "[*] Starting Tor service..."
service tor start

###############################################################################
# 4. Configure Proxychains
###############################################################################
echo "[*] Backing up and configuring Proxychains..."
PROXYCHAINS_CONF="/etc/proxychains.conf"
cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak"

# Switch from socks4 to socks5 on 127.0.0.1:9050
sed -i 's/^socks4.*/socks5\t127.0.0.1\t9050/' "$PROXYCHAINS_CONF"

# Uncomment these lines if you prefer 'dynamic_chain' instead of 'strict_chain'
# sed -i 's/^strict_chain/#strict_chain/' "$PROXYCHAINS_CONF"
# sed -i 's/^#dynamic_chain/dynamic_chain/' "$PROXYCHAINS_CONF"

###############################################################################
# 5. Helper function to create a venv and install requirements
###############################################################################
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

###############################################################################
# 6. Install Additional OSINT Tools
###############################################################################
# 6a. Recon-ng (from GitHub, in /opt)
echo "[*] Installing recon-ng..."
if [ ! -d "/opt/recon-ng" ]; then
  proxychains git clone https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
  create_venv_and_install "/opt/recon-ng" "REQUIREMENTS"
else
  echo "    -> /opt/recon-ng already exists, skipping clone."
  create_venv_and_install "/opt/recon-ng" "REQUIREMENTS"
fi

# 6b. Holehe (from GitHub, in /opt)
echo "[*] Installing Holehe..."
if [ ! -d "/opt/holehe" ]; then
  proxychains git clone https://github.com/megadose/holehe.git /opt/holehe
  create_venv_and_install "/opt/holehe" "requirements.txt"
else
  echo "    -> /opt/holehe already exists, skipping clone."
  create_venv_and_install "/opt/holehe" "requirements.txt"
fi

# 6c. Sherlock (from apt, using proxychains)
echo "[*] Installing Sherlock via apt..."
proxychains apt-get install -y sherlock

###############################################################################
# 7. Clean up OSINT environment
###############################################################################
echo "[*] Cleaning up unused packages..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

echo ""
echo "[*] Minimal OSINT environment installed!"
echo "[*] Tools installed system-wide: theHarvester, Dmitry, Sherlock"
echo "[*] Tools cloned in /opt: recon-ng, Holehe"
echo "    Each has a local Python venv in its own folder (.venv)."
echo ""
echo "=== Usage Instructions for OSINT Tools ==="
echo "1. To run Firefox via Tor, use:"
echo "     proxychains firefox-esr"
echo "2. For more privacy in Firefox, open about:config and set:"
echo "     privacy.resistFingerprinting = true"
echo "3. To run recon-ng (as an example):"
echo "     cd /opt/recon-ng"
echo "     source .venv/bin/activate"
echo "     python recon-ng"
echo "   Then 'deactivate' to exit the venv."
echo ""
echo "4. To run Holehe (as an example):"
echo "     cd /opt/holehe"
echo "     source .venv/bin/activate"
echo "     holehe --help"
echo "   Then 'deactivate' to exit the venv."
echo ""

###############################################################################
# 8. Xwinwrap Installation
###############################################################################
echo "[*] Installing xwinwrap dependencies..."
apt-get update
apt-get install -y xorg-dev build-essential libx11-dev x11proto-xext-dev libxrender-dev libxext-dev mpv

echo "[*] Cloning xwinwrap repository into /home/kali..."
cd /home/kali
git clone https://github.com/mmhobi7/xwinwrap.git

echo "[*] Compiling and installing xwinwrap..."
cd xwinwrap
make
sudo make install

echo "[*] Cleaning up xwinwrap build files..."
make clean

cd ~
echo "✅ Xwinwrap installation completed!"

###############################################################################
# 9. Set the wallpaper using xwinwrap + mpv
###############################################################################
echo "[*] Attempting to set the wallpaper with xwinwrap..."
echo "    (Requires a running X session on DISPLAY=:0)"
echo ""

# If you are indeed logged into an X session on :0, this will immediately set the wallpaper.
# If you're on a different display or using Wayland, it won't work as expected.
DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \
  -vf="scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black" \
  /home/kali/wallpapers/wallpaper_n1.gif &

echo "====================================================="
echo "All steps completed. If you're on Xorg (DISPLAY=:0),"
echo "you should now see the wallpaper looping via xwinwrap."
echo "If not, ensure you are running an X session and try:"
echo ""
echo "   DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \\"
echo "       -vf=\"scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black\" \\"
echo "       /home/kali/wallpapers/wallpaper_n1.gif"
echo "====================================================="
