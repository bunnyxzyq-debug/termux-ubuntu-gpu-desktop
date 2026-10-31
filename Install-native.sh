#!/data/data/com.termux/files/usr/bin/bash
# ------------------------------------------------------------------
#  Native KDE Plasma (X11) in Termux - no PRoot, no container.
#  GPU: Zink on Turnip, from Termux's own packages (mesa + mesa-vulkan-icd-freedreno).
#  Non-rooted Android, Termux (F-Droid/GitHub build) + Termux:X11 app.
#
#  Usage:    bash install-native.sh        (YES=1 skips the question)
#  Start:    start-native-kde              (or: start-native-kde nogpu)
#  Check:    glxinfo -B | grep -i renderer     (in a terminal inside the desktop)
#
#  STATUS: tested on a Redmi M2101K6P (Adreno 618, Android 12). Needs the x11-repo
#  packages plasma-desktop and kwin-x11
#  (Plasma 6.7.x). Plasma 6.8 removed the X11 session, so the Plasma packages
#  are held to stop an update from breaking the session.
# ------------------------------------------------------------------
set -e

g="\033[1;32m"; y="\033[1;33m"; r="\033[1;31m"; n="\033[0m"
say()  { echo -e "${g}==>${n} $*"; }
warn() { echo -e "${y}[!]${n} $*"; }
die()  { echo -e "${r}[x]${n} $*"; exit 1; }

ask() {
  local ans=""
  if [ -t 0 ]; then read -rp "$1" ans
  elif [ -r /dev/tty ]; then read -rp "$1" ans </dev/tty
  fi
  echo "${ans:-$2}"
}

[ -d /data/data/com.termux ] || die "Run this inside Termux."
[ "$(uname -m)" = "aarch64" ] || die "64-bit ARM (aarch64) only."

if [ "${YES:-0}" != "1" ]; then
  warn "Before you start:"
  echo "  - Plug in your phone. The download is large (several GB) and slow on a bad mirror."
  echo "  - Android 12+ can kill Termux during long installs. Disable the Phantom Process Killer first."
  echo "  - Slow download? Run termux-change-repo first and pick a nearby mirror."
  yn="$(ask "Install native KDE Plasma now? [Y/n] " "Y")"
  [[ "$yn" =~ ^[Yy]$ ]] || exit 0
fi

termux-wake-lock 2>/dev/null || true
export DEBIAN_FRONTEND=noninteractive

say "Updating Termux..."
apt update
apt full-upgrade -y -o Dpkg::Options::=--force-confold
pkg install -y x11-repo

# mesa-zink (old, from TUR) conflicts with the current mesa package
if dpkg -s mesa-zink >/dev/null 2>&1; then
  say "Removing old mesa-zink (2022 build)..."
  pkg remove -y mesa-zink
fi

say "Installing X server, audio and GPU drivers..."
pkg install -y termux-x11-nightly pulseaudio dbus mesa mesa-vulkan-icd-freedreno mesa-demos vulkan-tools

say "Installing KDE Plasma (long step)..."
for p in plasma-desktop kwin-x11 konsole dolphin systemsettings kscreen breeze; do
  pkg install -y "$p" || warn "could not install $p (skipped)"
done

command -v startplasma-x11 >/dev/null 2>&1 \
  || die "startplasma-x11 was not found. Send the output of: pkg search plasma-workspace"

# Plasma 6.8 dropped the X11 session: hold Plasma so an update can't remove it
for p in plasma-desktop plasma-workspace kwin-x11; do
  if dpkg -s "$p" >/dev/null 2>&1; then apt-mark hold "$p" || true; fi
done

# ---------- Launcher ----------
cat > "$PREFIX/bin/start-native-kde" <<'LAUNCH'
#!/data/data/com.termux/files/usr/bin/bash
GPU=1
for a in "$@"; do [ "$a" = "nogpu" ] && GPU=0; done

pkill -f termux-x11 2>/dev/null; pkill -f pulseaudio 2>/dev/null; sleep 1
rm -f "$TMPDIR/.X11-unix/X0" "$TMPDIR/.X0-lock"
export XDG_RUNTIME_DIR="$TMPDIR"
pulseaudio --start --exit-idle-time=-1 \
  --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" 2>/dev/null
termux-x11 :0 >/dev/null 2>&1 &
sleep 3
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 \
  || echo "Open the Termux:X11 app manually."

export DISPLAY=:0 PULSE_SERVER=127.0.0.1 XDG_CURRENT_DESKTOP=KDE KWIN_COMPOSE=N QT_QPA_PLATFORM=xcb
if [ $GPU -eq 1 ]; then
  export MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink TURNIP_KMD=kgsl FD_FORCE_KGSL=1 TU_DEBUG=noconform
  echo "GPU: Adreno via KGSL (Turnip + Zink)"
else
  export LIBGL_ALWAYS_SOFTWARE=1
  echo "GPU: software rendering"
fi
echo "Starting KDE Plasma ..."
exec dbus-run-session startplasma-x11
LAUNCH
chmod +x "$PREFIX/bin/start-native-kde"

echo
say "Done!"
cat <<DONE

  Start:   start-native-kde        (or: start-native-kde nogpu)
  Check:   glxinfo -B | grep -i renderer   (in a terminal in the desktop; zink + Turnip)

  Plasma packages are held. To update them on purpose:
    apt-mark unhold plasma-desktop plasma-workspace kwin-x11

DONE
