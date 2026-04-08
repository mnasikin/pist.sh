# Control Panel System Requirements

This document outlines the minimum system requirements for each control panel supported by **pist.sh**. Most panels require a **fresh OS installation** to avoid port conflicts and service failures.

---

## Paid Control Panels
| Panel | Supported OS | Min CPU | Min RAM | Min Disk |
| :--- | :--- | :--- | :--- | :--- |
| **cPanel/WHM** | CentOS, AlmaLinux, Rocky | 1 Core | 1 GB | 20 GB |
| **Plesk** | Ubuntu, Debian, CentOS, AlmaLinux, Rocky | 1 Core | 1 GB | 4 GB |
| **Webuzo** | Ubuntu, CentOS, AlmaLinux, Rocky, RHEL, CloudLinux | 1 Core | 1 GB | 5 GB |
| **DirectAdmin** | Alma, Rocky, CentOS, Ubuntu, Debian | 1 Core | 1 GB | 2 GB |
| **InterWorx** | RHEL, CentOS, AlmaLinux, Rocky | 1 Core | 1 GB | 10 GB |
| **ISPmanager** | Ubuntu, Debian, AlmaLinux, Rocky | 1 Core | 1 GB | 10 GB |
| **FASTPANEL** | Debian, Ubuntu, CentOS, Alma, Rocky | 1 Core | 1 GB | 10 GB |
| **Enhance** | Ubuntu 22.04 / 24.04 | 1 Core | 2 GB | 10 GB |
| **ApisCP** | CentOS, AlmaLinux, Rocky | 1 Core | 2 GB | 10 GB |
| **Virtualmin Pro** | Ubuntu, Debian, CentOS, Alma, Rocky | 1 Core | 1 GB | 10 GB |

> [!NOTE]
> Paid panels require a valid license or subscription to operate beyond the trial period.

---

## Free Control Panels
| Panel | Supported OS | Min CPU | Min RAM | Min Disk |
| :--- | :--- | :--- | :--- | :--- |
| **aaPanel** | Ubuntu, Debian, CentOS, AlmaLinux, Rocky | 1 Core | 512 MB | 10 GB |
| **CyberPanel** | Ubuntu, CentOS, AlmaLinux | 1 Core | 1 GB | 10 GB |
| **CloudPanel** | Ubuntu (22/24), Debian (11/12) | 1 Core | 2 GB | 10 GB |
| **Webmin** | Multi-OS | 1 Core | 256 MB | 10 GB |
| **VestaCP** | Ubuntu, Debian, CentOS | 1 Core | 512 MB | 3 GB |
| **HestiaCP** | Ubuntu, Debian | 1 Core | 512 MB | 3 GB |
| **CWP (CentOS Web Panel)** | CentOS, AlmaLinux, Rocky | 1 Core | 512 MB | 5 GB |
| **ISPConfig** | Ubuntu, Debian | 1 Core | 1 GB | 5 GB |
| **Ajenti** | Multi-OS | 1 Core | 512 MB | 10 GB |
| **1Panel** | Ubuntu, Debian, CentOS, Rocky | 1 Core | 1 GB | 10 GB |
| **OpenPanel** | Ubuntu, Debian | 1 Core | 1 GB | 10 GB |
| **Coolify** | Multi-OS (Docker based) | 1 Core | 2 GB | 10 GB |
| **Easypanel** | Multi-OS (Docker based) | 1 Core | 2 GB | 10 GB |
| **YunoHost** | Debian | 1 Core | 512 MB | 10 GB |

---

## General Prerequisites

- **User Privileges**: You must have `root` access or `sudo` privileges.
- **Fresh OS**: It is highly recommended to start with a "clean" or "fresh" OS installation.
- **Connectivity**: Stable internet connection for downloading packages and script installers.
- **Architecture**: Most panels target `x86_64` (amd64) architecture; support for `ARM` varies by panel.

> [!CAUTION]
> Installing multiple control panels on the same server is NOT supported and will likely break your system.
