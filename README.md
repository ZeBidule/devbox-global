## Getting Started
This project uses [devbox](https://github.com/jetify-com/devbox) to manage its development environment.

## Prerequisits:

In your previous VM, make sure to backup all important files :
```sh
function backup() {
  sudo cp -Lr "${HOME}/.zsh_history" "${HOME}/.zshenv" "${HOME}/.zsh_custom" "${HOME}/.zsh_aliases" "${HOME}/.gitconfig" \
    "${HOME}/.ssh" "${HOME}/.gpg" "${HOME}/.aws" "${HOME}/.config/google-chrome/Default/Bookmarks" \
    /etc/cntlm.conf /etc/redsocks.conf /usr/local/sbin/redsocks-iptables \
    /media/sf_sharedfolder
  sudo mkdir -p /media/sf_sharedfolder/.kube
  sudo cp -r "${HOME}/.kube/kubeconfig"* "/media/sf_sharedfolder/.kube"
}
```

Mount shared folder and enable bidirectional clipboard.
```sh
# Remove sudoer password
sudo visudo
# Add NOPASSWD to line "%sudo   ALL=(ALL:ALL) NOPASSWD: ALL"

# Devbox installtion and configuration prerequisits
sudo apt install curl bzip2 git -y

# Install virtualbox guest additions

# Install VScode
sudo apt-get install wget gpg
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg
sudo apt install apt-transport-https
sudo apt update
sudo apt install code
# open vscode palete and then "Settings Sync: Show settings"
fix_jenkins_vscode_plugin

# Install chrome
sudo apt-get install libxss1 libappindicator1 libindicator7
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install ./google-chrome*.deb
rm -f google-chrome*.deb

# Network prerequisits
sudo apt install cntlm redsocks -y
sudo cp /media/sf_sharedfolder/cntlm.conf /etc/cntlm.conf
sudo cp /media/sf_sharedfolder/redsocks.conf /etc/redsocks.conf
sudo cp /media/sf_sharedfolder/redsocks-iptables /usr/local/sbin/redsocks-iptables
sudo chmod +x /usr/local/sbin/redsocks-iptables
sudo mkdir -p /etc/systemd/system/redsocks.service.d
sudo cp /media/sf_sharedfolder/redsocks.service.d_iptables.conf /etc/systemd/system/redsocks.service.d/iptables.conf
sudo systemctl daemon-reload
sudo systemctl restart cntlm.service
sudo systemctl restart redsocks.service

# terminal helpers
sudo apt install zsh -y
zsh
# type "0" and configure desired options and save
sudo chsh -s $(which zsh) $USER
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
sudo apt-get install powerline
git clone https://github.com/powerline/fonts.git --depth=1
cd fonts
./install.sh
cd ..
rm -rf fonts
sudo cp /media/sf_sharedfolder/bullet-train.zsh-theme $HOME/.oh-my-zsh/themes/
sudo chown $USER:$USER $HOME/.oh-my-zsh/themes/bullet-train.zsh-theme
sudo chmod 644 $HOME/.oh-my-zsh/themes/bullet-train.zsh-theme
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# restore previous VM config
sudo cp -r /media/sf_sharedfolder/.zsh_history /media/sf_sharedfolder/.zshenv /media/sf_sharedfolder/.zsh_custom /media/sf_sharedfolder/.zsh_aliases \
    /media/sf_sharedfolder/.gitconfig \
    /media/sf_sharedfolder/.ssh /media/sf_sharedfolder/.gpg /media/sf_sharedfolder/.aws /media/sf_sharedfolder/.kube \
    /home/$USER
sudo cp /media/sf_sharedfolder/Bookmarks ~/.config/google-chrome/Default 
sudo chown -R $USER:$USER $HOME
sudo chmod 400 $HOME/.ssh/*.pem $HOME/.ssh/id_rsa $HOME/.ssh/zebidule
if ! grep -qF '$HOME/.zsh_custom' ~/.zshrc; then echo >> ~/.zshrc; echo '# shellcheck disable=SC1091' >> ~/.zshrc; echo '. "$HOME/.zsh_custom"' >> ~/.zshrc; fi

# Install and init devbox
curl -fsSL https://get.jetpack.io/devbox | bash
devbox global pull git@github.com:ZeBidule/devbox-global.git

# Install K8S helpers
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)
kubectl krew install ctx
kubectl krew install ns
kubectl krew install view-secret

# Install AWS-SSO-cli
update_aws_sso_cli

# Install Docker
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo usermod -aG docker $USER
```

Clone git repositories:
```sh
cc git@code.tooling.prod.cdsf.io:oam/ci/gitlab-automation.git
GITLAB_HOSTNAME=code.tooling.prod.cdsf.io PRIVATE_TOKEN=$GITLAB_GTP_PRIVATE_TOKEN $HOME/dev/oam.ci.gitlab-automation/clone_each_repository.sh -g 5 --auto-approve
GITLAB_HOSTNAME=code.tooling.prod.cdsf.io PRIVATE_TOKEN=$GITLAB_GTP_PRIVATE_TOKEN $HOME/dev/oam.ci.gitlab-automation/clone_each_repository.sh -g 116 --auto-approve
GITLAB_HOSTNAME=code.tooling.prod.cdsf.io PRIVATE_TOKEN=$GITLAB_GTP_PRIVATE_TOKEN $HOME/dev/oam.ci.gitlab-automation/clone_each_repository.sh -g 195 --auto-approve
GITLAB_HOSTNAME=infra.int.be.continental.cloud PRIVATE_TOKEN=$GITLAB_INFRA_PRIVATE_TOKEN $HOME/dev/oam.ci.gitlab-automation/clone_each_repository.sh -g 25 --auto-approve
GITLAB_HOSTNAME=infra.int.be.continental.cloud PRIVATE_TOKEN=$GITLAB_INFRA_PRIVATE_TOKEN $HOME/dev/oam.ci.gitlab-automation/clone_each_repository.sh -g 6 --auto-approve
```

## Packages

* [awscli@latest](https://www.nixhub.io/packages/awscli)
* [eksctl@latest](https://www.nixhub.io/packages/eksctl)
* [kustomize@latest](https://www.nixhub.io/packages/kustomize)
* [kind@latest](https://www.nixhub.io/packages/kind)
* [vcluster@latest](https://www.nixhub.io/packages/vcluster)
* [stern@latest](https://www.nixhub.io/packages/stern)
* [argocd@latest](https://www.nixhub.io/packages/argocd)
* [aws-iam-authenticator@latest](https://www.nixhub.io/packages/aws-iam-authenticator)
* [kubernetes@1.26.3](https://www.nixhub.io/packages/kubernetes)
* [kubernetes-helm-wrapped@latest](https://www.nixhub.io/packages/kubernetes-helm-wrapped)
* [diskonaut@latest](https://www.nixhub.io/packages/diskonaut)
* [bat@latest](https://www.nixhub.io/packages/bat)
* [htop@latest](https://www.nixhub.io/packages/htop)
* [zoxide@latest](https://www.nixhub.io/packages/zoxide)
* [fzf-zsh@latest](https://www.nixhub.io/packages/fzf-zsh)
* [eza@latest](https://www.nixhub.io/packages/eza)
* [starship@latest](https://www.nixhub.io/packages/starship)
* [jq@latest](https://www.nixhub.io/packages/jq)
* [yq-go@latest](https://www.nixhub.io/packages/yq-go)
* [dive@latest](https://www.nixhub.io/packages/dive)
* [dos2unix@latest](https://www.nixhub.io/packages/dos2unix)
* [k9s@latest](https://www.nixhub.io/packages/k9s)
* [ngrok@latest](https://www.nixhub.io/packages/ngrok)
* [kubecolor@latest](https://www.nixhub.io/packages/kubecolor)
* [go@latest](https://www.nixhub.io/packages/go)
* [fzf@latest](https://www.nixhub.io/packages/fzf)
* [terraform@latest](https://www.nixhub.io/packages/terraform)
* [docker@latest](https://www.nixhub.io/packages/docker)
* [jre@19](https://www.nixhub.io/packages/jre)
