#!/bin/bash
# Minimal OSINT Setup + Xwinwrap Installer + Wallpaper Setter for Kali
#
# Changes:
#  - Holehe is installed via pipx instead of GitHub clone.
#  - The wallpaper is downloaded from v0.1 (instead of v0.1.0).
#
# Steps:
#  1. Downloads a wallpaper GIF into /home/kali/wallpapers.
#  2. Installs minimal OSINT essentials: Tor, Proxychains, Firefox ESR, Git, Python3-Pip, python3-venv, theHarvester, Dmitry.
#  3. Installs pipx, then uses it to install Holehe.
#  4. Configures Proxychains to use Tor (socks5 on 127.0.0.1:9050).
#  5. Installs Recon-ng from GitHub in /opt (with a local .venv).
#  6. Installs Sherlock via apt (with Proxychains).
#  7. Installs Xwinwrap (cloned into /home/kali/xwinwrap) plus dependencies (mpv, xorg-dev, etc.).
#  8. Sets the wallpaper with xwinwrap + mpv (if on Xorg at DISPLAY=:0).
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

echo "[*] Downloading wallpaper_n1.gif from v0.1 into /home/kali/wallpapers..."
wget -O /home/kali/wallpapers/wallpaper_n1.gif \
  "https://github.com/JustSouichi/WiredOS/releases/download/v0.1/wallpaper_n1.gif"

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
# 4. Install pipx and Holehe via pipx
###############################################################################
echo "[*] Installing pipx..."
apt-get install -y python3-pipx

echo "[*] Installing Holehe with pipx (via Proxychains)..."
# If you prefer not to route pipx through Tor, remove 'proxychains'
proxychains pipx install holehe

###############################################################################
# 5. Configure Proxychains
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
# 6. Helper function to create a venv and install requirements
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
# 7. Install Recon-ng from GitHub (with local venv)
###############################################################################
echo "[*] Installing recon-ng..."
if [ ! -d "/opt/recon-ng" ]; then
  proxychains git clone https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
  create_venv_and_install "/opt/recon-ng" "REQUIREMENTS"
else
  echo "    -> /opt/recon-ng already exists, skipping clone."
  create_venv_and_install "/opt/recon-ng" "REQUIREMENTS"
fi

###############################################################################
# 8. Install Sherlock via apt
###############################################################################
echo "[*] Installing Sherlock via apt (with Proxychains)..."
proxychains apt-get install -y sherlock

###############################################################################
# 9. Clean up OSINT environment
###############################################################################
echo "[*] Cleaning up unused packages..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

echo ""
echo "[*] Minimal OSINT environment installed!"
echo "[*] Tools installed system-wide: theHarvester, Dmitry, Sherlock"
echo "[*] Tools installed via pipx: Holehe (check 'pipx list')"
echo "[*] Recon-ng cloned in /opt/recon-ng with a local Python venv (.venv)."
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
echo "4. To run Holehe (installed via pipx):"
echo "     holehe --help"
echo "   (Ensure pipx is in your PATH; open a new shell or run 'pipx ensurepath'.)"
echo ""

###############################################################################
# 10. Xwinwrap Installation
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
# 11. Set the wallpaper using xwinwrap + mpv
###############################################################################
echo "[*] Attempting to set the wallpaper with xwinwrap..."
echo "    (Requires a running X session on DISPLAY=:0)"
echo ""

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
