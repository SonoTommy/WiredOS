#!/bin/bash
# WiredOS LIVE
#
# Note:
#  - All wallpapers wallpaper_n1.gif to wallpaper_n7.gif are downloaded, with wallpaper_n1.gif as the default.
#  - The script /usr/local/bin/change_wallpaper2.sh and alias "cw2" are created
#    to change the xwinwrap background, independently from any previous script or alias.
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
# 2. Create wallpapers directory & download wallpapers (n1 to n7)
###############################################################################
echo "[*] Creating /home/kali/wallpapers directory..."
mkdir -p /home/kali/wallpapers

for i in {1..7}; do
  echo "[*] Downloading wallpaper_n${i}.gif..."
  wget -O /home/kali/wallpapers/wallpaper_n${i}.gif \
    "https://github.com/JustSouichi/WiredOS/releases/download/v0.1/wallpaper_n${i}.gif"
done

###############################################################################
# 3. Update and install essential OSINT packages
###############################################################################
echo "[*] Updating package lists..."
apt-get update

echo "[*] Installing essential OSINT packages..."
apt-get install -y tor proxychains git python3-pip python3-venv theharvester dmitry

# (Firefox ESR was removed as per your requirement)
# If needed again, simply uncomment or re-add: apt-get install -y firefox-esr

echo "[*] Starting Tor service..."
service tor start



###############################################################################
# 4. Configure Proxychains
###############################################################################
echo "[*] Backing up and configuring Proxychains..."
PROXYCHAINS_CONF="/etc/proxychains.conf"
cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak"
sed -i 's/^socks4.*/socks5\t127.0.0.1\t9050/' "$PROXYCHAINS_CONF"
# Uncomment these lines if you prefer 'dynamic_chain' instead of 'strict_chain'
# sed -i 's/^strict_chain/#strict_chain/' "$PROXYCHAINS_CONF"
# sed -i 's/^#dynamic_chain/dynamic_chain/' "$PROXYCHAINS_CONF"

###############################################################################
# 5. Helper function to create a virtual environment and install requirements
###############################################################################
create_venv_and_install() {
  local repo_dir="$1"
  local requirements_file="$2"
  
  cd "$repo_dir" || exit
  if [ ! -d ".venv" ]; then
    echo "    -> Creating virtual environment in $repo_dir/.venv"
    python3 -m venv .venv
  fi
  source .venv/bin/activate
  if [ -f "$requirements_file" ]; then
    echo "    -> Installing dependencies from $requirements_file"
    proxychains pip install -r "$requirements_file"
  fi
  deactivate
  cd - >/dev/null || exit
}

###############################################################################
# 6. Install Recon-ng from GitHub (with local virtual environment)
###############################################################################
echo "[*] Installing Recon-ng..."
if [ ! -d "/opt/recon-ng" ]; then
  proxychains git clone https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
  create_venv_and_install "/opt/recon-ng" "REQUIREMENTS"
else
  echo "    -> /opt/recon-ng already exists, skipping clone."
  create_venv_and_install "/opt/recon-ng" "REQUIREMENTS"
fi

###############################################################################
# 7. Install Holehe via pipx (with proxychains)
###############################################################################
echo "[*] Installing Holehe with pipx..."
proxychains pipx install holehe


###############################################################################
# 8. Install Sherlock via apt
###############################################################################
echo "[*] Installing Sherlock via apt (using Proxychains)..."
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
echo "[*] Recon-ng cloned in /opt/recon-ng with a local Python virtual environment (.venv)."
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
# 11. Set the default wallpaper using xwinwrap + mpv (using wallpaper_n1.gif)
###############################################################################
echo "[*] Setting the default wallpaper with xwinwrap (wallpaper_n1.gif)..."
DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \
  -vf="scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black" \
  /home/kali/wallpapers/wallpaper_n1.gif &

###############################################################################
# 12. Create the second wallpaper changer script and alias (cw2)
###############################################################################
echo "[*] Creating wallpaper changer script /usr/local/bin/change_wallpaper2.sh..."

cat << 'EOF' > /usr/local/bin/change_wallpaper2.sh
#!/bin/bash
# Script to change the wallpaper using xwinwrap.
# Usage: change_wallpaper2.sh [1-7]

WALLPAPER_DIR="/home/kali/wallpapers"

# Check if xwinwrap is installed
if ! command -v xwinwrap &> /dev/null; then
    echo "Error: xwinwrap is not installed or not in PATH."
    exit 1
fi

# Check if mpv is installed
if ! command -v mpv &> /dev/null; then
    echo "Error: mpv is not installed or not in PATH."
    exit 1
fi

# Verify that the DISPLAY variable is set
if [ -z "$DISPLAY" ]; then
    echo "Error: The DISPLAY variable is not set. Make sure you are running an X session."
    exit 1
fi

if [ -z "$1" ]; then
  echo "Usage: change_wallpaper2.sh [1-7]"
  exit 1
fi

WP_NUM="$1"
if [[ "$WP_NUM" -lt 1 || "$WP_NUM" -gt 7 ]]; then
  echo "Error: Please choose a number between 1 and 7."
  exit 1
fi

WALLPAPER_FILE="$WALLPAPER_DIR/wallpaper_n${WP_NUM}.gif"

if [ ! -f "$WALLPAPER_FILE" ]; then
  echo "Error: File $WALLPAPER_FILE does not exist."
  exit 1
fi

echo "Changing wallpaper to wallpaper_n${WP_NUM}.gif..."

# Terminate any running instances of xwinwrap and mpv
pkill xwinwrap || true
pkill mpv || true

# Launch xwinwrap with the new wallpaper using mpv
DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black" \
  "$WALLPAPER_FILE" &

echo "Wallpaper changed to wallpaper_n${WP_NUM}.gif"
EOF

chmod +x /usr/local/bin/change_wallpaper2.sh

BASHRC="/home/kali/.bashrc"
ALIAS_LINE="alias cw2='sudo /usr/local/bin/change_wallpaper2.sh'"

# Check if the alias is already in .bashrc
if grep -Fxq "$ALIAS_LINE" "$BASHRC"; then
    echo "[*] Alias cw2 is already present in $BASHRC."
else
    echo "[*] Adding alias cw2 to $BASHRC..."
    echo "$ALIAS_LINE" >> "$BASHRC"
fi









echo "====================================================="
echo "All operations have been completed."
echo "By default, wallpaper_n1.gif is used."
echo "A second wallpaper changer script has been created at:"
echo "  /usr/local/bin/change_wallpaper2.sh"
echo "To change the wallpaper, open a new shell (or run 'source /root/.bashrc') and use:"
echo "   sudo /usr/local/bin/chnage_wallpaper2.sh [number from 1 to 7]"
echo "For example:"
echo "   sudo /usr/local/bin/chnage_wallpaper2.sh 3"
echo "This will change the xwinwrap background to the selected wallpaper."
echo "====================================================="
