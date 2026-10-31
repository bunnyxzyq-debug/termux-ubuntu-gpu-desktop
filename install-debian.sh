#!/data/data/com.termux/files/usr/bin/bash
# ------------------------------------------------------------------
#  Debian + desktop of your choice + Adreno GPU (KGSL) acceleration
#  Non-rooted Android - Termux (F-Droid/GitHub build) + Termux:X11 app.
#
#  Recipe: proot-distro Debian + patched Mesa (Turnip with KGSL backend)
#          + Zink (OpenGL on Vulkan)
#
#  Debian 13 (trixie) still ships the Plasma X11 session, so KDE works here.
#  STATUS: tested on a Redmi M2101K6P (Adreno 618, Android 12). 
#
#  Usage:
#    bash install-debian.sh                        interactive menu
#    DESKTOPS=kde YES=1 bash install-debian.sh     non-interactive
#        DESKTOPS = kde | xfce | lxqt | mate | all (space/comma separated)
#        MESA_TAG = patched Mesa release tag (default below)
#
#  After install:
#    start-debian              (menu, or the only desktop installed)
#    start-debian kde          (kde | xfce | lxqt | mate)
#    start-debian kde gl       (KDE with GPU compositing - may glitch)
#    start-debian kde nogpu    (software rendering fallback)
#    debian-gpucheck           (lists the Vulkan GPU)
# ------------------------------------------------------------------
set -e

DISTRO="debian"
GUEST_USER="droid"
MESA_TAG="${MESA_TAG:-mesa-26.2.0-devel-20260709}"

g="\033[1;32m"; y="\033[1;33m"; r="\033[1;31m"; n="\033[0m"
say()  { echo -e "${g}==>${n} $*"; }
warn() { echo -e "${y}[!]${n} $*"; }
die()  { echo -e "${r}[x]${n} $*"; exit 1; }

# ask "prompt" "default" -> works even when the script is piped (reads /dev/tty)
ask() {
  local ans=""
  if [ -t 0 ]; then read -rp "$1" ans
  elif [ -r /dev/tty ]; then read -rp "$1" ans </dev/tty
  fi
  echo "${ans:-$2}"
}

[ -d /data/data/com.termux ] || die "Run this inside Termux."
[ "$(uname -m)" = "aarch64" ] || die "64-bit ARM (aarch64) only."

# ---------- Desktop selection ----------
NAMES=("KDE Plasma" "XFCE (light)" "LXQt (very light)" "MATE (classic)")
PKGS=("kde-plasma-desktop kwin-x11" "xfce4 xfce4-goodies" "lxqt" "mate-desktop-environment-core")
CMDS=("startplasma-x11" "startxfce4" "startlxqt" "mate-session")
IDS=("kde" "xfce" "lxqt" "mate")

SEL=()
if [ -n "${DESKTOPS:-}" ]; then
  if [ "$DESKTOPS" = "all" ]; then SEL=(0 1 2 3)
  else
    for w in ${DESKTOPS//,/ }; do
      for i in "${!IDS[@]}"; do
        if [ "${IDS[$i]}" = "$w" ]; then SEL+=("$i"); fi
      done
    done
  fi
else
  echo
  echo "Which desktop(s) do you want?"
  for i in "${!NAMES[@]}"; do echo "  $((i+1))) ${NAMES[$i]}"; done
  echo "  a) All"
  CHOICE="$(ask "Numbers separated by spaces [default: 1]: " "1")"
  if [[ "$CHOICE" =~ ^[aA]$ ]]; then SEL=(0 1 2 3)
  else
    for x in $CHOICE; do
      if [[ "$x" =~ ^[1-4]$ ]]; then SEL+=($((x-1))); fi
    done
  fi
fi
[ ${#SEL[@]} -gt 0 ] || die "No valid desktop choice."

ALLPKGS=""
for i in "${SEL[@]}"; do ALLPKGS+=" ${PKGS[$i]}"; done

if [ "${YES:-0}" != "1" ]; then
  warn "Needs 6-10 GB free. Keep Termux open (a wakelock is acquired)."
  yn="$(ask "Continue? [Y/n] " "Y")"
  [[ "$yn" =~ ^[Yy]$ ]] || exit 0
fi

termux-wake-lock 2>/dev/null || true

# ---------- Termux packages ----------
say "Installing Termux packages..."
pkg update -y
pkg install -y x11-repo
pkg install -y proot-distro termux-x11-nightly pulseaudio wget curl

# ---------- Debian ----------
ROOTFS=""
find_rootfs() {
  local d
  for d in "$PREFIX/var/lib/proot-distro/containers/$DISTRO" \
           "$PREFIX/var/lib/proot-distro/containers/$DISTRO/rootfs" \
           "$PREFIX/var/lib/proot-distro/installed-rootfs/$DISTRO"; do
    if [ -f "$d/etc/os-release" ]; then ROOTFS="$d"; return 0; fi
  done
  return 1
}

if find_rootfs; then
  say "Debian already installed - reusing it."
else
  say "Installing Debian..."
  proot-distro install "$DISTRO"
  find_rootfs || die "Could not find the Debian rootfs."
fi

# ---------- Guest setup ----------
cat > "$ROOTFS/root/guest-setup.sh" <<'EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
apt-get install -y --no-install-recommends sudo dbus-x11 locales wget curl ca-certificates \
  xdg-utils pulseaudio-utils mesa-utils vulkan-tools x11-xserver-utils xorg fonts-noto
echo "[guest] installing desktops: $PKGS"
apt-get install -y $PKGS
apt-get install -y firefox-esr || echo "[guest] WARNING: could not install firefox-esr"
if dpkg -s kwin-x11 >/dev/null 2>&1 && apt-cache show plasma-session-x11 >/dev/null 2>&1; then
  apt-get install -y plasma-session-x11
fi

if ! id "$GUEST_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -G sudo,audio,video "$GUEST_USER"
  echo "$GUEST_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$GUEST_USER
  chmod 440 /etc/sudoers.d/$GUEST_USER
fi

# Patched Mesa with KGSL backend (installed AFTER desktops so nothing overwrites it)
. /etc/os-release
VER="${MESA_TAG#mesa-}"
URL="https://github.com/lfdevs/mesa-for-android-container/releases/download/${MESA_TAG}/mesa-for-android-container_${VER}_${ID}_${VERSION_CODENAME}_arm64.tar.gz"
echo "[guest] Debian codename: ${VERSION_CODENAME}"
echo "[guest] downloading patched Mesa: $URL"
if wget -qO /tmp/mesa.tar.gz "$URL"; then
  tar -zxf /tmp/mesa.tar.gz -C /
  ldconfig
  rm -f /tmp/mesa.tar.gz
  for p in libegl-mesa0 libgbm1 libgl1-mesa-dri libglx-mesa0 mesa-libgallium mesa-vulkan-drivers; do
    if dpkg -s "$p" >/dev/null 2>&1; then apt-mark hold "$p" || true; fi
  done
  echo "[guest] patched Mesa installed"
else
  echo "[guest] WARNING: could not download patched Mesa (no GPU acceleration)."
  echo "[guest] Get the ${ID}_${VERSION_CODENAME}_arm64 tar.gz from the releases page"
  echo "[guest] of github.com/lfdevs/mesa-for-android-container and extract it with: tar -zxf FILE -C /"
fi
echo "[guest] done"
EOF

say "Installing inside Debian (long step)..."
proot-distro login "$DISTRO" -- env PKGS="$ALLPKGS" GUEST_USER="$GUEST_USER" MESA_TAG="$MESA_TAG" \
  bash /root/guest-setup.sh

# ---------- Desktop registry ----------
REG="$HOME/.debian-desktops"; : > "$REG"
for i in "${SEL[@]}"; do echo "${IDS[$i]}|${NAMES[$i]}|${CMDS[$i]}" >> "$REG"; done

# ---------- Launcher ----------
cat > "$PREFIX/bin/start-debian" <<'LAUNCH'
#!/data/data/com.termux/files/usr/bin/bash
DISTRO="debian"; GUEST_USER="droid"; REG="$HOME/.debian-desktops"
mapfile -t LINES < "$REG"

want="$1"; GPU=1; GL=0
for a in "$@"; do [ "$a" = "nogpu" ] && GPU=0; [ "$a" = "gl" ] && GL=1; done
case "$want" in nogpu|gl) want="";; esac

SELL=""
if [ -n "$want" ]; then
  for l in "${LINES[@]}"; do [[ "${l%%|*}" == "$want" ]] && SELL="$l"; done
  [ -n "$SELL" ] || { echo "Unknown desktop: $want"; exit 1; }
elif [ ${#LINES[@]} -eq 1 ]; then SELL="${LINES[0]}"
else
  echo "Choose a desktop:"
  for i in "${!LINES[@]}"; do IFS='|' read -r id nm cm <<< "${LINES[$i]}"; echo "  $((i+1))) $nm"; done
  read -rp "> " k; SELL="${LINES[$((k-1))]}"
  [ -n "$SELL" ] || { echo "Invalid choice"; exit 1; }
fi
IFS='|' read -r ID NAME CMD <<< "$SELL"

ENVV="DISPLAY=:1 XDG_RUNTIME_DIR=/tmp PULSE_SERVER=127.0.0.1 LANG=C.UTF-8"
BIND=""
if [ $GPU -eq 1 ] && [ -e /dev/kgsl-3d0 ]; then
  BIND="--bind /dev/kgsl-3d0"
  ENVV+=" MESA_LOADER_DRIVER_OVERRIDE=zink TURNIP_KMD=kgsl FD_FORCE_KGSL=1 TU_DEBUG=noconform"
  echo "GPU: Adreno via KGSL (Turnip + Zink)"
else
  ENVV+=" LIBGL_ALWAYS_SOFTWARE=1"
  echo "GPU: software rendering"
fi
if [ $GL -eq 1 ]; then ENVV+=" KWIN_COMPOSE=O2"; else ENVV+=" KWIN_COMPOSE=N"; fi

pkill -f termux.x11 2>/dev/null; pkill -f pulseaudio 2>/dev/null; sleep 1
pulseaudio --start --exit-idle-time=-1 \
  --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" 2>/dev/null
export XDG_RUNTIME_DIR="$TMPDIR"
termux-x11 :1 >/dev/null 2>&1 &
sleep 2
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 \
  || echo "Open the Termux:X11 app manually."

echo "Starting $NAME ..."
exec proot-distro login "$DISTRO" --user "$GUEST_USER" --shared-tmp $BIND -- \
  bash -lc "export $ENVV; exec dbus-run-session $CMD"
LAUNCH
chmod +x "$PREFIX/bin/start-debian"

# ---------- GPU check helper ----------
cat > "$PREFIX/bin/debian-gpucheck" <<'CHK'
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login debian --user droid --shared-tmp --bind /dev/kgsl-3d0 -- bash -c \
 'TURNIP_KMD=kgsl FD_FORCE_KGSL=1 TU_DEBUG=noconform XDG_RUNTIME_DIR=/tmp vulkaninfo --summary 2>&1 | grep -iE "deviceName|driverName"'
CHK
chmod +x "$PREFIX/bin/debian-gpucheck"

echo
say "Done!"
cat <<DONE

  1. Install the Termux:X11 APK (github.com/termux/termux-x11/releases)
  2. In Termux:X11 preferences set touch mode to "Direct touch" (to drag/select).
  3. Run:  start-debian            (or: start-debian kde)
  4. Check GPU:  debian-gpucheck   (should list "Turnip Adreno")
     Inside the desktop:  glxinfo -B | grep -i renderer   (should say zink + Turnip)

  Do NOT run apt upgrade on the held Mesa packages.
  User inside Debian: $GUEST_USER (sudo, no password)

DONE
