# Install WSL VM with devbox

This readme explain how to [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) VM with [devbox](https://github.com/jetify-com/devbox) to manage a development environment.

## Prerequisits

In your previous VM, make sure to backup all important files in a folder located on your windows filesystem (e.g. /mnt/d/sharedfolder) :
```sh
function backup() {
  sudo cp -Lr "${HOME}/.bash_history" "${HOME}/.bash_env" "${HOME}/.bash_custom" "${HOME}/.bash_aliases" \
    "${HOME}/.config/starship.toml" "${HOME}/.gitconfig" \
    "${HOME}/.ssh" "${HOME}/.gpg" "${HOME}/.aws" \
    /etc/cntlm.conf "$(devbox global path)/devbox.json" \
    /mnt/d/sharedfolder
  sudo mkdir -p /mnt/d/sharedfolder/.kube
  sudo cp -r "${HOME}/.kube/kubeconfig"* "/mnt/d/sharedfolder/.kube"
}
```
Note: you can use the files located in this Github repository and adapt them to your needs if you don't have a previous VM or if you don't want to backup/restore your previous configuration files.

## Setup WSL VM

1. Open a POWERSHELL window **AS ADMINISTRATOR** (run as administrator) and execute the following commands to enable WSL and Virtual Machine Platform features and update WSL to the latest version :
    ```
    wsl --update
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    ```

2. Restart your computer

3. Download and install the latest WSL kernel update and the latest Ubuntu distribution from the Microsoft store :
- https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi
- https://apps.microsoft.com/detail/9pdxgncfsczv?hl=fr-FR&gl=DE

4. Restart your computer

## Configure networking for WSL VM to have internet access using the transparent proxy

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

## Restore previous VM config
```sh
cp -r /mnt/d/sharedfolder/.bash_history /mnt/d/sharedfolder/.bash_env /mnt/d/sharedfolder/.bash_custom /mnt/d/sharedfolder/.bash_aliases \
    /mnt/d/sharedfolder/.gitconfig \
    /mnt/d/sharedfolder/.ssh /mnt/d/sharedfolder/.gpg /mnt/d/sharedfolder/.aws /mnt/d/sharedfolder/.kube \
    "${HOME}"
cp /mnt/d/sharedfolder/starship.toml "${HOME}/.config/starship.toml"
chmod 400 $HOME/.ssh/*.pem $HOME/.ssh/id_rsa

# Replace '.bash_aliases' by '.bash_custom' in $HOME/.bashrc because all the files source and startup logic is in .bash_custom
sed -i 's/\.bash_aliases/.bash_custom/g' "$HOME/.bashrc"

# import your PGP keys to gpg
gpg --import "$HOME/.gpg/xxx.asc"
```

## Remove sudoer password
```sh
sudo visudo
```
=> Add NOPASSWD to line "%sudo   ALL=(ALL:ALL) NOPASSWD: ALL"

## Install and init devbox
```sh
curl -fsSL https://get.jetpack.io/devbox | bash
cp /mnt/d/sharedfolder/devbox.json /home/antoine/.local/share/devbox/global/default
devbox completion bash | sudo tee /etc/bash_completion.d/devbox
nix-store --gc && nix-store --optimise
eval "$(devbox global shellenv --preserve-path-stack -r)" && hash -r
```

## Install terminal helpers
```sh
curl -sS https://starship.rs/install.sh | sh
krew install view-secret
```

## Install AWS-SSO-cli
```sh
update_aws_sso_cli
```
=> Modify your "sso_login" alias to replace "aws-sso-cli configure browser none" by "aws-sso-cli configure browser default"

## Install kubectx and kubens manually because completion does not work if installed with krew
```sh
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
COMPDIR=$(pkg-config --variable=completionsdir bash-completion)
ln -sf /opt/kubectx/completion/kubens.bash $COMPDIR/kubens
ln -sf /opt/kubectx/completion/kubectx.bash $COMPDIR/kubectx
```

## Install Docker
```sh
curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker $USER && newgrp docker
```

## Launch and configure VScode
1. Install VSCode on your windows system and install the "WSL" extension.
2. Just execute `code` in your WSL terminal to open a new VScode window on your Windows system connected to your WSL filesystem. It will take several minutes to open the first time because it needs to install the VSCode server on WSL and install all extensions. After that, it will be much faster to open new windows.
3. Configure your VSCode settings and install your favorite extensions using the settings sync feature of VSCode. You can also copy the settings.json file from your backup folder to the WSL filesystem if you don't want to use the settings sync feature.

## Clone git repositories:
```sh
cc "git@${GITLAB_GTP_HOSTNAME}:oam/ci/gitlab-automation.git"
GITLAB_INSTANCE=GTP $HOME/dev/oam.ci.gitlab-automation/clone_each_repository.sh -g 5 --auto-approve
GITLAB_INSTANCE=GTP $HOME/dev/oam.ci.gitlab-automation/clone_each_repository.sh -g 116 --auto-approve
GITLAB_INSTANCE=GTP $HOME/dev/oam.ci.gitlab-automation/clone_each_repository.sh -g 195 --auto-approve
GITLAB_INSTANCE=INFRA $HOME/dev/oam.ci.gitlab-automation/clone_each_repository.sh -g 25 --auto-approve
GITLAB_INSTANCE=INFRA $HOME/dev/oam.ci.gitlab-automation/clone_each_repository.sh -g 6 --auto-approve
```
