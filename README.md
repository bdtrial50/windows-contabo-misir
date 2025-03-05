# Windows Server on a Contabo VPS - Installation Guide

## Introduction

This guide provides step-by-step instructions for installing Windows 10 on a Contabo VPS. Please be aware that you assume full responsibility for all risks associated with this installation.

## Prerequisites

- VNC Viewer application installed. Download it from [here](https://www.realvnc.com/en/connect/download/viewer/).
- A Contabo VPS
- Microsoft Remote Desktop for RDP connection to the machine.

## Steps for installation

### 1. Prepare the VPS for installation

- Purchase a new Ubuntu VPS
- Log in to the Contabo user panel and navigate to the "Your services" section.
- On your VPS click the "Manage" button and select "Rescue System".
- Choose "Debian 10 - Live" from the "Rescue System Version" dropdown menu.
- Set a password and start the Rescue System.
- From the control panel go to "VPS control".
- Click the "Manage" button and select "VNC password".
- Set the VNC password. It must be 8 characters long, containing at least one uppercase and one lowercase character, and one number. Avoid using any special characters.
  
### 2. Connect to the VPS via SSH

- Open Terminal on MacOS or PuTTY on Windows.
- Log in with the command `ssh root@<MACHINE-IP>` and enter your Rescue System password.
- Execute the following commands:
  - `apt install git -y`
  - `git clone https://github.com/TasikIslam/windows-contabo.git`
  - `cd windows-contabo`
  - `chmod +x windows-install.sh`
  - `./windows-install.sh`
  - The process takes approximately 15 minutes and completes when the ssh session disconnects due to the machine rebooting.

### 3. Connnect to the VPS with VNC to install Windows

- Open your VNC app and create a new connection using the IP and PORT found on the VPS control page. Hover over "Manage" and click on "VNC Information"
- Upon connecting, you will see a screen as shown in the image. Press Enter.

  ![text](https://i.ibb.co/j8Ckb0x/windows-installer.png)

- Follow the on-screen prompts to install Windows.

- Click on "Custom: Install Windows Only (advanced)"

  ![text](https://i.ibb.co/X7swb6C/custom-install.png)

### 5. Allow Remote Access Connection for RDP

- Search for `allow remote connections to this computer` and select the first option.

  ![text](https://i.ibb.co/Xb4hwQp/allow-remote.png)

- In the Remote Desktop section, click on `Show settings`
  
  ![text](https://i.ibb.co/kD4tN2P/show-settings.png)

- Choose `Allow remote connections to this computer`, click "Apply" and then "Ok"
  
  ![text](https://i.ibb.co/Rv0R5L1/allow-remote-connections.png)

- Now, connect remotely using your Remote Desktop Connection program with the credentials created during the Windows installation.

## Conclusions

Congratulations! You should now have a fully operational Windows 10 installation on your Contabo VPS. Remember to proceed with these instructions at your own risk and ensure that all software and applications used are legal and compliant with the respective licenses.
