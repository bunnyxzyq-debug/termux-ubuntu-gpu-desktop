# Ubuntu + GPU-accelerated desktop on Android (no root)

One script that sets up Ubuntu in Termux with a desktop of your choice (KDE Plasma, XFCE, LXQt, MATE) and real Adreno GPU acceleration through KGSL, shown on screen with Termux:X11.

The GPU path is: patched Mesa (Turnip with a KGSL backend) → Zink (OpenGL on Vulkan) → Termux:X11.

## Requirements

- Android phone with a Qualcomm Adreno GPU, 64-bit ARM (aarch64)
- **Termux** from F-Droid or GitHub (not the Play Store build)
- **Termux:X11** app: https://github.com/termux/termux-x11/releases
- 6–10 GB of free storage, and a few GB of RAM

## Install

In Termux:

```bash
curl -fsSL https://raw.githubusercontent.com/bunnyxzyq-debug/termux-ubuntu-gpu-desktop/main/install.sh -o install.sh
bash install.sh
```

Non-interactive:

```bash
DESKTOPS=kde YES=1 bash install.sh      # kde | xfce | lxqt | mate | all
```

## Use

```bash
start-ubuntu              # menu (or the only desktop installed)
start-ubuntu kde          # kde | xfce | lxqt | mate
start-ubuntu kde gl       # GPU-composited KWin effects (may glitch)
start-ubuntu kde nogpu    # software rendering fallback
ubuntu-gpucheck           # lists the Vulkan GPU
```

Inside the desktop, confirm GPU rendering with:

```bash
glxinfo -B | grep -i renderer     # expect: zink Vulkan ... (Turnip Adreno ...)
```

Login inside Ubuntu is user `droid` (sudo, no password).

## Notes

- **Do not run `apt upgrade` on the held Mesa packages.** The script holds them so an upgrade can't replace the patched driver.
- KWin compositing is **off by default** (`KWIN_COMPOSE=N`) because GPU compositing can glitch. Window previews in the taskbar are black for this reason. Try `start-ubuntu kde gl` if you want effects.
- The logout/shutdown buttons don't work (no systemd in PRoot). Close Termux:X11 or press Ctrl+C in Termux to quit.
- In Termux:X11 preferences, set touch mode to **Direct touch** to drag and select. In KDE, set *System Settings → Window Management → Titlebar Actions → Double-click → Do nothing* to stop taps from maximizing windows.
- Logs full of D-Bus, PipeWire, udev and polkit errors are normal inside PRoot.
- `top` and System Monitor show wrong CPU and sensor values under PRoot. Use the load average instead.

## How the Mesa download works

The script downloads a prebuilt patched Mesa from [lfdevs/mesa-for-android-container](https://github.com/lfdevs/mesa-for-android-container/releases) that matches the container's Ubuntu codename. Nothing is redistributed here. To use a different release:

```bash
MESA_TAG=mesa-26.2.0-devel-20260709 bash install.sh
```

If no build exists for your Ubuntu release, the install finishes without GPU acceleration and prints a manual download hint.

## Status

The recipe was confirmed on a Redmi M2101K6P (Snapdragon 732G / Adreno 618, Android 12) with Ubuntu 26.04 and KDE Plasma 6.6. Reports for other devices are welcome as issues.


## Credits
- Built with help from [Claude](https://claude.ai) (Anthropic)

- [lfdevs/mesa-for-android-container](https://github.com/lfdevs/mesa-for-android-container): patched Mesa with the KGSL backend
- [Termux](https://github.com/termux/termux-app), [Termux:X11](https://github.com/termux/termux-x11) and [proot-distro](https://github.com/termux/proot-distro)
- [Mesa](https://www.mesa3d.org/) (Turnip, Zink)
