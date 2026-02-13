# Configure networking for WSL VM to have internet access using the transparent proxy

1. Download `wsl-vpnkit.tar.gz` from https://github.com/sakai135/wsl-vpnkit/releases/latest

2. Open a POWERSHELL window **WITHOUT ADMIN RIGHTS** and execute the following commands (make sure to replace the path of the tar.gz file if needed) :
    ```
    wsl.exe --set-default-version 2
    wsl --import wsl-vpnkit --version 2 $env:USERPROFILE\wsl-vpnkit "C:\Users\uia59190\Downloads\wsl-vpnkit.tar.gz"
    ```

3. Open Ubuntu from the Windows menu and execute the following commands to start wsl-vpnkit :
    ```sh
    nohup wsl.exe -d wsl-vpnkit --cd /app wsl-vpnkit start </dev/null >/dev/null 2>&
    curl ip.me
    ```

4. Open Ubuntu from the Windows menu and execute the following script to install wsl-vpnkit, cntlm and redsocks as linux services :
    ```sh
    curl https://raw.githubusercontent.com/ZeBidule/devbox-global/refs/heads/main/install_network.sh -o /tmp/install_network.sh
    chmod +x /tmp/install_network.sh
    sudo bash -x /tmp/install_network.sh
    ```
