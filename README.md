# Fedora STEELITE

A heavily customized, immutable [Fedora Kinoite](https://fedoraproject.org/kinoite/) image built with [bootc](https://containers.github.io/bootc/), designed for developers and gaming enthusiasts who need a turnkey system with sensible defaults.

## What's Included

### Development & DevOps
- **Docker** (daemon, CLI, buildx, docker-compose)
- **Visual Studio Code** 
- **Tabby** terminal emulator
- **Python 3** with pip
- Android SDK tools
- RPM development tools

### Gaming & Media
- **Steam** with gaming optimizations
- **MangoHUD** for FPS monitoring and overlay
- **Gamescope** Proton compatibility layer
- **WinBoat** for seamless Windows app integration
- **LACT** for GPU metrics, fan control, and overclocking
- **libratbag** for Logitech peripheral configuration
- Advanced codec support (OpenH.264, VA-API, etc.)

### Security & System
- **Bitwarden** desktop with biometric and SSH-Agent support
- NFSync module support
- Optimized zram-based swap (75% of RAM, max 12GB)
- Tuned journald, vm, and disk behavior for performance
- Proper audio and gamemode group management

### Hardware Support
- NVIDIA GPU drivers (proprietary + open source options)
- AMD firmware and microcode
- Full Linux firmware support
- CPU-DMA latency permissions for real-time performance
- SCSI link power management tuning

## System Optimizations

This image includes several persistent optimizations:
- **zram-generator**: Compressed swap memory configuration
- **Transparent HugePage**: Automatic transparency with conservative settings
- **vm.swappiness**: Set to 10 for gaming and interactive responsiveness
- **systemd-journald**: Limited to 150MB to prevent log bloat
- **udev rules**: GPU reset handling, SCSI link performance, CPU-DMA latency

## Building

This project uses Fedora's modern bootc image-based approach. Build with:

```bash
just build-image
```

Or use `bootc build` directly if you have containerization tools installed.

## Installation

⚠️ **WARNING**: This is not a standard Fedora image. Review [build_files/build.sh](build_files/build.sh) carefully before deploying. The image makes aggressive changes to the base system that may not suit general-purpose use.

If you understand the implications and want to proceed, follow your container host's bootc deployment procedures. This typically involves either:
- Direct bootc deployment on systems that support it
- Building an ISO with bootc-image-builder for traditional installation

## Why This Exists

This image encodes opinionated defaults for a specific use case: a developer workstation that's also gaming-capable. It bakes in configurations that would be tedious to apply manually across multiple systems while maintaining the immutability and reproducibility benefits of image-based systems.

## Customization

To customize for your own needs:
1. Fork this repository
2. Edit [build_files/build.sh](build_files/build.sh) to add/remove packages and configurations
3. Optionally adjust the base image in [Containerfile](Containerfile)
4. Build and deploy your variant

## Not For Everyone

This image is optimized for a **specific workflow** and makes **aggressive customizations** to the base Kinoite image. Standard Fedora or Kinoite will serve most users better. Only use this if you:
- Understand exactly what [build.sh](build_files/build.sh) does
- Want these specific tools and optimizations
- Are comfortable with immutable systems
- Can tolerate potential breakage from experimental configurations

## License

See [LICENSE](LICENSE) file for details.