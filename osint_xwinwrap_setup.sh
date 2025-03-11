#!/bin/bash
# Minimal OSINT Setup + Xwinwrap Installer + Wallpaper Setter for Kali
#
# 1. Downloads a wallpaper GIF into /home/kali/wallpapers.
# 2. Installs system packages for OSINT (Tor, Proxychains, Firefox ESR, Git, Python3-Pip, python3-venv, theHarvester, Dmitry).
# 3. Configures Proxychains to use Tor (socks5 on 127.0.0.1:9050).
# 4. Clones recon-ng, Sherlock, Holehe into /opt, each with a local .venv for Python dependencies.
# 5. Installs Xwinwrap (cloned into /home/kali/xwinwrap).
# 6. Sets the wallpaper with xwinwrap + mpv, looping the downloaded GIF.
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
wget -O /home/kali/wallpapers/wallpaper_n1.gif "https://github.com/JustSouichi/WiredOS/releases/download/v0.1.0/wallpaper_n1.gif"

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
# 6. Install Additional OSINT Tools (cloned in /opt), each with a venv
###############################################################################
echo "[*] Installing recon-ng..."
if [ ! -d "/opt/recon-ng" ]; then
  proxychains git clone https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
  create_venv_and_install "/opt/recon-ng" "REQUIREMENTS"
else
  echo "    -> /opt/recon-ng already exists, skipping clone."
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

###############################################################################
# 7. Clean up OSINT environment
###############################################################################
echo "[*] Cleaning up unused packages..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

echo ""
echo "[*] Minimal OSINT environment installed!"
echo "[*] Tools installed system-wide: theHarvester, Dmitry"
echo "[*] Tools cloned in /opt: recon-ng, Sherlock, Holehe"
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
echo "   (Replace with your preferred usage. Then 'deactivate' to exit venv.)"
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

# If you are indeed logged into an X session on :0, this will immediately set the wallpaper.
# If you're on a different display or using Wayland, it won't work as expected.
DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \
  -vf="scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black" \
  /home/kali/wallpapers/wallpaper_n1.gif &

echo ""
echo "====================================================="
echo "All steps completed. If you are on Xorg (DISPLAY=:0),"
echo "you should now see the wallpaper looping via xwinwrap."
echo "If not, ensure you are running an X session and try:"
echo ""
echo "   DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \\"
echo "       -vf=\"scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black\" \\"
echo "       /home/kali/wallpapers/wallpaper_n1.gif"
echo "====================================================="
