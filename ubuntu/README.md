# Upgrading from Ubuntu 22.04.5 LTS to Ubuntu 24.04.1 LTS (GNOME Edition): All Changes Summarized

This guide details every significant change when upgrading from Ubuntu 22.04.5 LTS (Jammy Jellyfish) to Ubuntu 24.04.1 LTS (Noble Numbat), focusing specifically on the GNOME variant.

---

## GNOME Desktop Environment

### GNOME Version Update

- **From GNOME 42 to GNOME 46**, including significant usability and visual improvements.

### Interface & UX Changes

- **Quick Settings Menu:** Consolidates toggles (Wi-Fi, Bluetooth, Dark Mode, etc.) with expandable options.
- **Workspace Indicator:** Shows active workspace in the top bar (replaces static "Activities").
- **Expandable Notifications:** Easier to read full notification content.
- **Accent Colors & Dark Mode:** Selectable accent colors and one-click dark mode toggle.
- **Updated Ubuntu Font:** A slimmer, modern design; classic font remains optional (`fonts-ubuntu-classic`).

### Performance & Accessibility Improvements

- **Triple Buffering:** Reduces animation stutters.
- **Enhanced multi-monitor handling:** Improved compatibility and performance.
- **Improved Touchpad Settings:** Better configuration and right-click behavior.
- **Orca Screen Reader:** Improved performance and new "sleep mode."

---

## Visual & UI Enhancements

- **Default Minimal Install:** Reduces pre-installed apps; optional "Extended Install" remains.
- **GNOME Snapshot:** Replaces Cheese as default webcam app.
- **Loupe Image Viewer:** New GPU-accelerated viewer replacing Eye of GNOME.
- **Nautilus (Files):** Faster search, folder expansion in list view, better performance, and dynamic transfer indicators.

---

## Wayland, Display, and Graphics

- **Wayland default session:** Improved support and stability, now native Wayland for Firefox.
- **Fractional Scaling:** Improved multi-DPI monitor support without blur.
- **PipeWire:** Default for audio/video processing, fully replaces PulseAudio.
- **NVIDIA Improvements:** Improved Wayland compatibility, though some setups default to Xorg for stability.
- **Remote Desktop (RDP):** Now fully supported, enabling headless remote GNOME sessions.

---

## Kernel and Hardware Updates

- **Kernel update:** From Linux 5.15 to Linux 6.8.
  - Enhanced CPU/GPU performance and power efficiency.
  - Improved support for Intel 12th/13th-gen CPUs, AMD Ryzen 7000, Intel Arc, NVIDIA RTX 4000.
  - Bluetooth 5.x and LE Audio support via BlueZ 5.72.
- **PipeWire 1.0:** Mature audio/video handling replacing PulseAudio and JACK.

---

## Performance and Efficiency

- **Reduced Input Latency & Smoother Animations** through GNOME improvements.
- **Battery Optimization:** Improved laptop battery life via kernel and scheduler enhancements.
- **Optimized Snap Updates:** Apps update silently, only apply on next launch; updates can be deferred indefinitely.
- **Faster Boot Times:** Kernel and systemd optimizations, improved disk encryption handling.

---

## Applications & Software Management

- **New App Center (Flutter-based):**

  - Replaces Ubuntu Software, combines Snap & Deb management.
  - Supports user ratings, reviews, and clearer categories.

- **Firmware Updater:** New dedicated app replacing software-center integration.

### Default Application Changes

- **Firefox & Thunderbird:** Both now default as Snap packages (Thunderbird 115 “Supernova”).
- **Steam:** Officially stable Snap with optimized gaming libraries.
- **LibreOffice 24.2 (7.6):** Improved compatibility with Microsoft Office.
- **New Default Text Editor:** Modern GNOME "Text Editor" replaces Gedit (still available optionally).

---

## Security & Privacy

- **User Namespace Restriction:** Controlled via AppArmor, significantly improving kernel security.
- **Improved AppArmor & Seccomp:** Updated profiles and stricter security defaults.
- **Camera Indicator:** Alerts user when webcam is in use.
- **Permission Controls:** Fine-grained app permissions management via Settings.

### Encryption Enhancements

- **Experimental TPM-backed disk encryption:** No password needed at boot; secures disk via TPM chip.
- **ZFS Encryption:** Optional during installation for root filesystem.

### Improved PPA Management

- **New `.sources` format:** Embeds GPG keys within source files, automatically removes keys when PPAs are deleted.
- **APT security improvements:** Stronger SHA-2/SHA-3 repository signatures.

---

## Installer & Upgrade Experience

- **New Flutter-based Installer:**

  - Improved dual-boot guidance and accessibility.
  - Minimal vs. Extended Install options clearly defined.
  - Autoinstall support (`autoinstall.yaml`) for unattended setups.

- **Upgrade Path Smoother:**
  - Automatic app migration (Deb to Snap) during upgrades.
  - Improved conflict handling and smoother transitions.

---

## Packaging: Snap, Flatpak, Deb

- **Snap Improvements:** Apps update silently in background; new "hold" feature to defer updates.
- **Flatpak:** Not pre-installed, remains available for manual installation.
- **Deb Packages:** Improved security handling, continued core system use.

---

## Enterprise & Developer Features

### Enterprise Integration

- **Active Directory (ADsys):** Enhanced Group Policy support, extensive GPO implementation.
- **Azure AD (Entra ID):** Ongoing development for cloud-based login integration (preview state).
- **Intune Support:** Official integration for device management and compliance monitoring.

### WSL Improvements (Windows Users)

- **Systemd by default:** Enables Snap and system services under WSL2.
- **Cloud-init in WSL:** Allows automatic configuration of WSL instances.

### Developer Toolchain Updates

- **GCC 14, Python 3.12, OpenJDK 21, .NET 8, LLVM 18, Go 1.22, Rust 1.75:** Updated default toolchains.
- **Multipass VM:** Improved cross-platform experience for Ubuntu VMs.
- **Year 2038 problem solved for ARM32:** Now using 64-bit time handling on 32-bit systems.

### Containers & Virtualization

- **Updated LXD, Docker, Kubernetes, QEMU/libvirt:** Enhanced performance, security, and compatibility.

---

## Ubuntu Pro & Landscape Integration

- **Ubuntu Pro:** Expanded security support for universe packages; integrated notification streamlined.
- **Landscape:** Simplified enrollment (`pro enable landscape`) into Canonical's management solution.

---

## Things to Do After Upgrading

### Update Your System

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt autoremove --purge -y
```

### Enable Extra Repositories

```bash
sudo add-apt-repository restricted universe multiverse
sudo apt update
```

### Firmware & Driver Updates

- Open **Firmware Updater**.
- Check drivers via **Settings ▸ System ▸ Firmware**.

### Improve Security and Privacy

```bash
sudo ufw enable
sudo ufw default deny incoming
```

Review **Settings ▸ Privacy** for data-sharing preferences.

### Backup Your System

- Install and configure Timeshift:

```bash
sudo apt install timeshift
```

### Install Multimedia Codecs

```bash
sudo apt install ubuntu-restricted-extras
```

### Optional Tweaks and Applications

- **GNOME Tweaks & Extensions:**

```bash
sudo apt install gnome-tweaks gnome-shell-extension-manager
```

- **Flatpak Support:**

```bash
sudo apt install flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

- **Essential Applications:** Synaptic, VLC, GIMP, Krita, Bitwarden.

---

## Conclusion

Upgrading from Ubuntu 22.04.5 LTS to 24.04.1 LTS delivers substantial improvements in usability, performance, hardware compatibility, and security, along with major developer and enterprise-friendly enhancements.

Ubuntu 24.04.1 LTS provides a polished and modern desktop experience, maintaining Ubuntu's familiar ease-of-use and reliability, and is fully supported until 2029.
