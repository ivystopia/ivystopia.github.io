# Building a Spiral Linux ISO Using a Debian Docker Container

This guide provides detailed instructions for building a Spiral Linux ISO file using a Debian Docker container. It includes steps for downloading and extracting the necessary tarball from the Spiral Linux GitHub repository.

## Prerequisites

- **Docker** installed on your host system.
- **Sufficient disk space** (at least 20 GB free) for the build process.
- **Stable internet connection** to download necessary packages.

---

## Step 1: Install Docker (If Not Already Installed)

If Docker is not already installed on your system, install it using the following commands:

### **On Ubuntu/Debian-based Systems**

```shell
sudo apt-get update
sudo apt-get install -y docker.io
```

### **On Fedora/CentOS/RHEL-based Systems**

```shell
sudo dnf install -y docker
sudo systemctl start docker
sudo systemctl enable docker
```

---

## Step 2: Download and Extract the Spiral Linux Tarball

1. **Create a Directory for the Project**

```shell
mkdir -p ~/spirallinux
cd ~/spirallinux
```

2. **Download the Tarball from GitHub**

```shell
wget "https://github.com/SpiralLinux/SpiralLinux-project/raw/refs/heads/main/SpiralLinux-Plasma.tar.gz"
```

**Note**: Replace `SpiralLinux-Plasma.tar.gz` with the desired desktop environment tarball, e.g., `SpiralLinux-LXQt.tar.gz` for the LXQt version.

3. **Extract the Tarball**

```shell
tar xvf SpiralLinux-Plasma.tar.gz
```

---

## Step 3: Run the Debian Docker Container with Elevated Privileges

Run the Docker container with the `--privileged` flag to allow necessary permissions for the build process.

```shell
sudo docker run --privileged -it --name spiral-build -v ~/spirallinux/SpiralLinux-Plasma:/spiral debian:bookworm /bin/bash
```

**Explanation:**

- `--privileged`: Grants the container extended privileges required for mounting filesystems.
- `-it`: Runs the container interactively with a terminal.
- `--name spiral-build`: Names the container for easy reference.
- `-v ~/spirallinux/SpiralLinux-Plasma:/spiral`: Mounts your project directory into the container at `/spiral`.
- `debian:bookworm /bin/bash`: Specifies the Docker image and command to run.

---

## Step 4: Update and Upgrade Packages Inside the Container

Once inside the container, update the package lists and upgrade installed packages.

```shell
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
```

---

## Step 5: Install Necessary Dependencies

Install the required packages for building the Spiral Linux ISO.

```shell
apt-get install -y \
    live-build \
    debootstrap \
    cdebootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-common \
    syslinux \
    wget \
    curl \
    ca-certificates \
    gnupg \
    apt-transport-https \
    git \
    patch
```

---

## Step 6: Navigate to the Project Directory

```shell
cd /spiral
```

---

## Step 7: Apply Necessary Patches

### **Copy the Patched `firmwarelists.sh`**

```shell
cp firmwarelists.sh /usr/share/live/build/functions/firmwarelists.sh
```

### **Apply the `live-build_memtest.patch`**

```shell
if [ ! -f /root/live-build_memtest_patch_applied ]; then
    patch -f -d/ -p0 < live-build_memtest.patch
    touch /root/live-build_memtest_patch_applied
fi
```

---

## Step 8: Ensure the `spiral` Script Is Executable

```shell
chmod +x spiral
```

---

## Step 9: Run the Build Script

Execute the `spiral` script with the ISO option.

```shell
./spiral -i
```

**Note**: For building an HDD image instead of an ISO, use `./spiral -d`.

---

## Step 10: Monitor the Build Process

- The build process may take a significant amount of time depending on your system resources and internet connection.
- Monitor the terminal output for any errors.
- If errors occur, take note of them for troubleshooting.

---

## Step 11: Retrieve the Built ISO

After the build completes, the ISO file will be located in the `/spiral` directory inside the container, which is mapped to your host's `~/spirallinux/SpiralLinux-Plasma` directory.

- **ISO File**: `SpiralLinux_Plasma_12.231120_x86-64.iso`
- **Package List**: `SpiralLinux_Plasma_12.231120_x86-64.packages`

---

## Step 12: Test the ISO

### **Option 1: Using a Virtual Machine**

#### **VirtualBox**

1. **Create a New Virtual Machine**

   - Select "Linux" and "Debian (64-bit)" as the OS type.
   - Allocate appropriate resources (e.g., 2 GB RAM, 20 GB disk space).

2. **Attach the ISO**

   - In the VM settings, under "Storage", attach the ISO file as a virtual CD/DVD.

3. **Start the VM and Boot from the ISO**

#### **QEMU/KVM**

```shell
qemu-system-x86_64 -cdrom SpiralLinux_Plasma_12.231120_x86-64.iso -m 2048
```

### **Option 2: Creating a Bootable USB**

**Warning**: Be very careful with the device identifier to avoid data loss.

```shell
sudo dd if=SpiralLinux_Plasma_12.231120_x86-64.iso of=/dev/sdX bs=4M status=progress && sync
```

- Replace `/dev/sdX` with your USB drive's device identifier (e.g., `/dev/sdb`).
- Boot your computer from the USB drive.

---

## Step 13: Clean Up

After you're done, you can exit the Docker container and remove it.

### **Exit the Container**

```shell
exit
```

### **Remove the Container**

```shell
sudo docker rm spiral-build
```

---

## Additional Notes

- **Building Other Desktop Environments**: If you wish to build a different desktop environment (e.g., LXQt), download the corresponding tarball from the Spiral Linux GitHub repository and adjust the directory names accordingly.

```shell
wget "https://github.com/SpiralLinux/SpiralLinux-project/raw/refs/heads/main/SpiralLinux-LXQt.tar.gz"
```

- **Updating Before Building**: It's recommended to run `apt-get update` and `apt-get upgrade` inside the container before installing dependencies to ensure all packages are up-to-date.

---

## Troubleshooting

- **Permission Denied Errors**: Ensure you run the Docker container with the `--privileged` flag to allow necessary mount operations.
- **Network Issues**: Verify that the container has internet access to download packages.
- **Disk Space**: Ensure sufficient disk space is available for the build process.
- **Build Failures**: Review the terminal output for error messages to identify and resolve issues.

---

## References

- [Spiral Linux GitHub Repository](https://github.com/SpiralLinux/SpiralLinux-project)
- [Docker Documentation](https://docs.docker.com/)
- [Debian Live Build Manual](https://live-team.pages.debian.net/live-manual/)

---

**Disclaimer**: Use this guide at your own risk. Be cautious when performing operations that can affect your system, such as using `dd` for creating bootable USB drives.
