# Ubuntu / Debian + GPU-accelerated desktop on Android (no root)

One installer that sets up **Ubuntu 26.04** or **Debian 13** in Termux with a desktop of your choice (KDE Plasma, XFCE, LXQt, MATE) and real Adreno GPU acceleration through KGSL, shown on screen with Termux:X11.

The GPU path is: patched Mesa (Turnip with a KGSL backend) → Zink (OpenGL on Vulkan) → Termux:X11.

## Requirements

- Android phone with a Qualcomm Adreno GPU, 64-bit ARM (aarch64)
- **Termux** from F-Droid or GitHub (not the Play Store build)
- **Termux:X11** app: https://github.com/termux/termux-x11/releases
- 6–10 GB of free storage per distro, and a few GB of RAM

## Install

In Termux:

```bash
curl -fsSL https://raw.githubusercontent.com/bunnyxzyq-debug/termux-ubuntu-gpu-desktop/main/install.sh -o install.sh
bash install.sh
```

It asks for a distro (Ubuntu or Debian), then a desktop, and runs the matching script (`install-ubuntu.sh` or `install-debian.sh`).

Non-interactive:

```bash
DISTRO=debian DESKTOPS=kde YES=1 bash install.sh
# DISTRO   = ubuntu | debian
# DESKTOPS = kde | xfce | lxqt | mate | all (space or comma separated)
```

You can install both distros on the same phone. Each has its own launcher.

## Use

```bash
start-ubuntu              # or start-debian (menu if several desktops are installed)
start-ubuntu kde          # kde | xfce | lxqt | mate
start-ubuntu kde gl       # GPU-composited KWin effects (may glitch)
start-ubuntu kde nogpu    # software rendering fallback
ubuntu-gpucheck           # or debian-gpucheck: lists the Vulkan GPU
```

Inside the desktop, confirm GPU rendering with:

```bash
glxinfo -B | grep -i renderer     # expect: zink Vulkan ... (Turnip Adreno ...)
```

Login inside the distro is user `droid` (sudo, no password).

## Notes

- **Do not run `apt upgrade` on the held Mesa packages.** The script holds them so an upgrade can't replace the patched driver.
- KWin compositing is **off by default** (`KWIN_COMPOSE=N`) because GPU compositing can glitch. Taskbar window previews are black for this reason. Try `gl` if you want effects.
- The logout/shutdown buttons don't work (no systemd in PRoot). Close Termux:X11 or press Ctrl+C in Termux to quit.
- In Termux:X11 preferences, set touch mode to **Direct touch** to drag and select. In KDE, set *System Settings → Window Management → Titlebar Actions → Double-click → Do nothing* to stop taps from maximizing windows.
- MATE can take up to a minute to appear on first start. Its network, sound and power panel applets can fail inside PRoot; delete them when asked.
- Logs full of D-Bus, PipeWire, udev and polkit errors are normal inside PRoot.
- `top` and System Monitor show wrong CPU and sensor values under PRoot. Use the load average instead.
- KDE needs an X11 session. Plasma 6.8 removed it, so KDE here relies on the distro keeping an older Plasma (Ubuntu 26.04 LTS: Plasma 6.6, Debian 13: Plasma 6.3).

## How the Mesa download works

The scripts download a prebuilt patched Mesa from [lfdevs/mesa-for-android-container](https://github.com/lfdevs/mesa-for-android-container/releases) that matches the container's distro and codename. Nothing is redistributed here. To use a different release:

```bash
MESA_TAG=mesa-26.2.0-devel-20260709 bash install.sh
```

If no build exists for your release, the install finishes without GPU acceleration and prints a manual download hint.

## Status

Tested on a Redmi M2101K6P (Adreno 618, Android 12). Ubuntu 26.04 with KDE Plasma 6.6 and Debian 13 (trixie) with KDE Plasma 6.3 both run on X11 through Termux:X11. In GPU mode OpenGL renders through Zink on Turnip (Adreno 618). The `nogpu` option falls back to llvmpipe (CPU). Other devices may differ, and reports are welcome as issues.

## Credits

- Built with help from [Claude](https://claude.ai) (Anthropic)
- [lfdevs/mesa-for-android-container](https://github.com/lfdevs/mesa-for-android-container): patched Mesa with the KGSL backend
- [Termux](https://github.com/termux/termux-app), [Termux:X11](https://github.com/termux/termux-x11) and [proot-distro](https://github.com/termux/proot-distro)
- [Mesa](https://www.mesa3d.org/) (Turnip, Zink)
