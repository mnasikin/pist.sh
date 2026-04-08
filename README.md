# VPS Control Panel Auto Installer (pist.sh)

A comprehensive, all-in-one bash script to automatically install various popular VPS control panels. The script automatically detects your server's operating system, CPU cores, and RAM, and dynamically displays only the control panels that are fully compatible with your current server specifications.

Repository: https://github.com/mnasikin/pist.sh

## Features

- **Auto-Detection**: Automatically identifies OS distribution, version, and server constraints (RAM, CPU, Disk Space) to prevent installation failures.
- **Multiple Panels**: Supports automatic installation for 11 different control panels.
- **Installation Modes**:
  - **Quick Mode**: Runs installations non-interactively using default settings. Good for fast and automated deployments.
  - **Normal Mode**: Runs the standard interactive installer, allowing for custom configuration during the process.
- **System Benchmark**: Includes an option to safely run a complete system benchmark using YABS (Yet Another Bench Script).
- **Safe Execution**: Ensures the script is run with `root` privileges.

## Supported Control Panels

The script currently supports the following panels (availability depends on your server OS and specifications):

1. **cPanel/WHM** (Commercial)
2. **Plesk Panel** (Commercial)
3. **aaPanel** (Free)
4. **CyberPanel** (Free - OpenLiteSpeed)
5. **CloudPanel** (Free)
6. **Webmin** (Free - Lightweight)
7. **VestaCP** (Free)
8. **HestiaCP** (Free - VestaCP Fork)
9. **CentOS Web Panel / CWP** (Free)
10. **ISPConfig** (Free)
11. **Ajenti** (Free)

## Requirements

- A fresh Unix-like minimal OS installation (Ubuntu, Debian, CentOS, AlmaLinux, or Rocky Linux).
- Root privileges.
- An active internet connection.

## Usage

To use the auto-installer, download the script and execute it as the root user.

```bash
# Download the script
wget https://raw.githubusercontent.com/mnasikin/pist.sh/main/pist.sh

# Make it executable
chmod +x pist.sh

# Run the installer
./pist.sh
```

Follow the on-screen instructions:
1. Review your server's automatically detected specifications.
2. Enter the number corresponding to the control panel you wish to install.
3. Select your preferred installation mode (Quick or Normal).
4. Wait for the automated setup to complete and take note of the default panel access details provided at the end.

## Disclaimer

- Software such as cPanel and Plesk requires a commercial license. The script does not bypass licensing checks and you will need to provide or purchase a license to use them.
- Always use this script on a clean, newly deployed VPS. Running control panel installers on a server with existing websites or databases may result in data loss or configuration conflicts.
- Made with Claude