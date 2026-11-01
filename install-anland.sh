#!/data/data/com.termux/files/usr/bin/bash
# ------------------------------------------------------------------
#  Anland: Wayland KDE Plasma on Android (no root), in a PRoot container.
#  Uses the apps and ready-made images from github.com/lfdevs/anland-termux.
#  GPU: Freedreno (KGSL), drawn through the Anland display app.
#
#  Usage:    bash install-anland.sh
#            IMAGE=debian|ubuntu YES=1 bash install-anland.sh
#  Start:    start-anland-kde
#
#  STATUS: the steps were tested by hand on a Redmi M2101K6P (Adreno 618,
#  Android 12, GitHub Termux, Debian image). This script itself is untested.
# ------------------------------------------------------------------
set -e

ANLAND_VER="${ANLAND_VER:-5.13.3}"
BASE="https://github.com/lfdevs/anland-termux/releases/download/$ANLAND_VER"

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

# ---------- Which Anland app do we need? ----------
FLAVOR="${TERMUX_APK_RELEASE:-${TERMUX_APP__APK_RELEASE:-}}"
COMPAT=0
if [ "$FLAVOR" = "F_DROID" ]; then COMPAT=1; fi
if [ -z "$FLAVOR" ]; then warn "Could not detect your Termux build; assuming the GitHub build."; fi

# ---------- Which image? ----------
IMG=""
if [ -n "${IMAGE:-}" ]; then
  case "$IMAGE" in
    debian|ubuntu) IMG="$IMAGE" ;;
    *) die "Unknown IMAGE: $IMAGE (use debian or ubuntu)" ;;
  esac
else
  echo
  echo "Which image do you want?"
  echo "  1) Debian 13 + KDE Plasma 6.3"
  echo "  2) Ubuntu 26.04 + KDE Plasma 6.6"
  N="$(ask "Number [default: 1]: " "1")"
  case "$N" in 1) IMG=debian ;; 2) IMG=ubuntu ;; *) die "Invalid choice." ;; esac
fi
case "$IMG" in
  debian) REF="ghcr.io/lfdevs/debian:trixie-anland-plasma"; NAME="debian-anland" ;;
  ubuntu) REF="ghcr.io/lfdevs/ubuntu:resolute-anland-plasma"; NAME="ubuntu-anland" ;;
esac

if [ "${YES:-0}" != "1" ]; then
  warn "Needs about 4-8 GB free and a long download. Plug in your phone."
  yn="$(ask "Install Anland + $IMG now? [Y/n] " "Y")"
  [[ "$yn" =~ ^[Yy]$ ]] || exit 0
fi

termux-wake-lock 2>/dev/null || true
export DEBIAN_FRONTEND=noninteractive

say "Updating Termux..."
apt update
apt full-upgrade -y -o Dpkg::Options::=--force-confold
pkg install -y proot-distro curl

# ---------- Anland app (APK) + Termux daemon ----------
APK="AnlandTermux-$ANLAND_VER.apk"
if [ $COMPAT -eq 1 ]; then APK="AnlandTermux-$ANLAND_VER-compatible.apk"; fi
DEST="$HOME/storage/downloads"
[ -d "$DEST" ] || DEST="$HOME"

say "Downloading $APK ..."
curl -fL --retry 3 -o "$DEST/$APK" "$BASE/$APK"
sha256sum "$DEST/$APK"

DEB="$HOME/anland_${ANLAND_VER}_aarch64.deb"
say "Downloading the Termux daemon ..."
curl -fL --retry 3 -o "$DEB" "$BASE/anland_${ANLAND_VER}_aarch64.deb"
sha256sum "$DEB"
pkg install -y "$DEB"

# ---------- Container image ----------
CDIR="$PREFIX/var/lib/proot-distro/containers/$NAME"
if [ -d "$CDIR" ] || proot-distro list 2>/dev/null | grep -q "$NAME"; then
  say "$NAME is already installed - reusing it."
else
  df -h "$HOME" | tail -1
  say "Installing the $IMG image (large download)..."
  proot-distro install "$REF" --name "$NAME"
fi

# ---------- Launcher ----------
cat > "$PREFIX/bin/start-anland-kde" <<'LAUNCH'
#!/data/data/com.termux/files/usr/bin/bash
NAME="@NAME@"; COMPAT="@COMPAT@"
pkill -x anland 2>/dev/null; sleep 1
anland >/dev/null 2>&1 &
if [ "$COMPAT" = "1" ]; then
  pkill -TERM -x anland-compatible 2>/dev/null
  anland-compatible >/dev/null 2>&1 &
fi
sleep 2
echo "Now switch to the Anland Termux app. The desktop can take a minute to appear."
exec proot-distro login "$NAME" --shared-tmp -- bash -c "startplasma-anland"
LAUNCH
sed -i -e "s|@NAME@|$NAME|" -e "s|@COMPAT@|$COMPAT|" "$PREFIX/bin/start-anland-kde"
chmod +x "$PREFIX/bin/start-anland-kde"

echo
say "Done!"
cat <<DONE

  1. Install the Anland app (once): open $DEST/$APK
       termux-open "$DEST/$APK"
     Allow installs from Termux if Android asks.
  2. Start:  start-anland-kde
     Then switch to the "Anland Termux" app.

  Do NOT run apt upgrade inside $NAME: the patched Mesa and KWin are held.
  Anland has no touchpad mode for a broken touchscreen; use a mouse, or Termux:X11.

DONE
