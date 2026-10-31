#!/data/data/com.termux/files/usr/bin/bash
# ------------------------------------------------------------------
#  Chooser: Ubuntu or Debian (container) or native Termux KDE Plasma.
#  Downloads install-<distro>.sh from this repo and runs it.
#
#  Usage:
#    bash install.sh                                     menu
#    DISTRO=debian bash install.sh                       skip the menu (ubuntu | debian | native)
#    DISTRO=ubuntu DESKTOPS=kde YES=1 bash install.sh    fully non-interactive
#  Other variables (DESKTOPS, YES, MESA_TAG) are passed through.
# ------------------------------------------------------------------
set -e

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/bunnyxzyq-debug/termux-ubuntu-gpu-desktop/main}"

g="\033[1;32m"; y="\033[1;33m"; r="\033[1;31m"; n="\033[0m"
say() { echo -e "${g}==>${n} $*"; }
die() { echo -e "${r}[x]${n} $*"; exit 1; }

ask() {
  local ans=""
  if [ -t 0 ]; then read -rp "$1" ans
  elif [ -r /dev/tty ]; then read -rp "$1" ans </dev/tty
  fi
  echo "${ans:-$2}"
}

[ -d /data/data/com.termux ] || die "Run this inside Termux."
command -v curl >/dev/null 2>&1 || die "curl is missing. Run: apt update && apt full-upgrade -y"

IDS=("ubuntu" "debian" "native")
NAMES=("Ubuntu 26.04 (container)" "Debian 13 (container)" "Native Termux: KDE Plasma, no container")

CHOICE=""
if [ -n "${DISTRO:-}" ]; then
  for i in "${!IDS[@]}"; do
    if [ "${IDS[$i]}" = "$DISTRO" ]; then CHOICE="$DISTRO"; fi
  done
  [ -n "$CHOICE" ] || die "Unknown DISTRO: $DISTRO (use ubuntu, debian or native)"
else
  echo
  echo "Which setup do you want?"
  for i in "${!NAMES[@]}"; do echo "  $((i+1))) ${NAMES[$i]}"; done
  N="$(ask "Number [default: 1]: " "1")"
  if [[ "$N" =~ ^[1-3]$ ]]; then CHOICE="${IDS[$((N-1))]}"; else die "Invalid choice."; fi
fi

TARGET="$HOME/install-$CHOICE.sh"
say "Downloading install-$CHOICE.sh ..."
curl -fL --retry 3 -o "$TARGET" "$REPO_RAW/install-$CHOICE.sh" \
  || die "Could not download $REPO_RAW/install-$CHOICE.sh"

say "Starting the $CHOICE installer..."
exec bash "$TARGET"
