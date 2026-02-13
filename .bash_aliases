#!/bin/bash

# Personnal aliases
alias edssh='code ${HOME}/.ssh/config'
alias rea='. ${HOME}/.bash_aliases && . ${HOME}/.bash_env'
alias eda='code ${HOME}/.bash_aliases'
alias ede='code ${HOME}/.bash_env'
alias edc='code ${HOME}/.bash_custom'
alias eds='code ${HOME}/.config/starship.toml'
alias edd='code $(devbox global path)/devbox.json'

alias c='code'
alias cr='code -r'

alias dr='devbox run'
alias tt='devbox run test'

GOPATH=$(go env GOPATH)
export PATH="$PATH:$GOPATH/bin"

alias sc='search_code'
function search_code() {
  grep -I -R "$1" "${HOME}/dev"
}

alias findz="find ./* -type f | fzf --preview 'bat --color=always {}' --preview-window '~3'"

# https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip
function install_fonts() {
  font_url=$1
  if [[ $font_url == "" ]]
  then
    echo "${RED}[Error] missing parameter : font URL"
    return 1
  fi
  font_name=${font_url##*/} && \
    wget "${font_url}" && \
    unzip "${font_name}" -d ~/.fonts && \
    fc-cache -fv
}

function update() {
  title0 "Update system and devbox packages"
  devbox version update
  eval "$(devbox global shellenv --recompute)"
  refresh-global
  devbox global update
  [[ -f "./devbox.json" ]] && devbox update
  refresh-global
  update_aws_sso_cli
  kubectl krew upgrade
  ok
}

function backup() {
  sudo cp -Lr "${HOME}/.bash_history" "${HOME}/.bash_env" "${HOME}/.bash_custom" "${HOME}/.bash_aliases" \
    "${HOME}/.config/starship.toml" "${HOME}/.gitconfig" "${HOME}/.aws" \
    /etc/cntlm.conf "$(devbox global path)/devbox.json" \
    /mnt/d/sharedfolder
    sudo mkdir -p /mnt/d/sharedfolder/.ssh
    for file in "${HOME}/.ssh/"*; do
      filename=$(basename "$file")
      sudo rm -f "/mnt/d/sharedfolder/.ssh/$filename"
      sudo cp -L "$file" "/mnt/d/sharedfolder/.ssh/$filename"
    done
    for file in "${HOME}/.gpg/"*; do
      filename=$(basename "$file")
      sudo rm -f "/mnt/d/sharedfolder/.gpg/$filename"
      sudo cp -L "$file" "/mnt/d/sharedfolder/.gpg/$filename"
    done

  sudo mkdir -p /mnt/d/sharedfolder/.kube
  sudo cp -r "${HOME}/.kube/kubeconfig"* "/mnt/d/sharedfolder/.kube"

  # copy in my github repo
  sudo cp "${HOME}/.bash_custom" "${HOME}/.config/starship.toml" \
    "$(devbox global path)/devbox.json" \
    "${HOME}/dev/ZeBidule.devbox-global"
  pushd "${HOME}/dev/ZeBidule.devbox-global" > /dev/null || return
  git add .bash_custom starship.toml > /dev/null
  git commit -m "Update config files" > /dev/null
  git add devbox.json > /dev/null
  git commit -m "Update packages list" > /dev/null
  git push
  popd > /dev/null 2>&1 || true
}

function free_space() {
  title0 "Free space"
  echo -e "${GRAY}Disk space before cleaning :"
  df -h /dev/sda2
  echo "------------------------------------------------${DEFAULT}"
  sudo apt-get -y clean
  sudo apt -y autoclean
  sudo apt-get -y autoremove --purge
  [[ -d "${HOME}/.cache/cloud-code/installer" ]] && rm -rf "${HOME}/.cache/cloud-code/installer"
  # go clean -cache -modcache -i -r
  sudo rm -rf /var/lib/snapd/cache/* > /dev/null 2>&1
  sudo journalctl --rotate
  sudo journalctl --vacuum-time=1s > /dev/null 2>&1
  docker system prune -a -f --volumes
  for item in $(find "${HOME}" -name ".terraform" -type d | grep -E "^/home"); do rm -rf "$item"; done
  devbox global run -- nix store gc --extra-experimental-features nix-command
  echo "${GRAY}------------------------------------------------"
  echo "Disk space after cleaning :"
  df -h /dev/sda2
  echo "------------------------------------------------${DEFAULT}"
}

function github_api_rate_limit {
  echo -n "${GRAY}GitHub API remaining calls : ${DEFAULT}"
  curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/rate_limit | jq '.rate.remaining'
  echo -n "${GRAY}GitHub API reset time : ${DEFAULT}"
  curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/rate_limit | jq -r '.rate.reset' | xargs -I{} date -d @{}
}

########################################
#                Formatting
########################################

export DEFAULT="\e[39m"
export RED="\e[31m"
export GREEN="\e[32m"
export BLUE="\e[34m"
export MAGENTA="\e[35m"
export YELLOW="\e[33m"
export CYAN="\e[36m"
export GRAY="\e[90m"

function title0 {
  [[ ($OUTPUT == "light" || $OUTPUT == "none") && ! $DEBUG ]] && return
  echo
  echo -e "${MAGENTA}===================================================================${DEFAULT}"
  echo -e "${MAGENTA}${1}${DEFAULT}"
  echo -e "${MAGENTA}===================================================================${DEFAULT}"
}

function title1 {
  [[ ($OUTPUT == "light" || $OUTPUT == "none") && ! $DEBUG ]] && return
  echo
  echo -e "${BLUE}===================================================================${DEFAULT}"
  echo -e "${BLUE}${1^}${DEFAULT}"
  echo -e "${BLUE}===================================================================${DEFAULT}"
}

function title_sep {
  [[ ($OUTPUT == "light" || $OUTPUT == "none") && ! $DEBUG ]] && return
  echo -e "${BLUE}---------------- ${1^} ----------------"
}

function title2 {
  [[ ($OUTPUT == "light" || $OUTPUT == "none") && ! $DEBUG ]] && return
  echo
  echo -e "${CYAN}=> ${1^}...${DEFAULT}"
}

# shellcheck disable=SC2120
function ok {
  [[ $OUTPUT == "none" && ! $DEBUG ]] && return
  if [[ -n "$1" ]]
  then
    echo -e "${GREEN}OK${DEFAULT} (${1})"
  else
    echo -e "${GREEN}OK${DEFAULT}"
  fi
}

function error {
  [[ $OUTPUT == "none" && ! $DEBUG ]] && return
  echo -e "${RED}[ERROR] ${error_message_prefix:-}${1^} !${DEFAULT}"
  errors+=( "${1^}" )
}

function warn {
  [[ $OUTPUT == "none" && ! $DEBUG ]] && return
  echo -e "${YELLOW}[WARN] ${1^}${DEFAULT}"
}

function info {
  [[ $OUTPUT == "none" && ! $DEBUG ]] && return
  echo -e "${GRAY}[INFO] ${1^}${DEFAULT}"
}

function debug {
  if [[ $DEBUG ]]
  then
    echo -e "${GRAY}[DEBUG] ${1}${DEFAULT}"
  fi
}

########################################
#                Jenkins
########################################
function get_jenkins_job_url() {
  git_root_folder=${1:-$(pwd)}
  get_root_url=${2:-false}

  pushd "${git_root_folder}" > /dev/null || return
  git_url=$(git remote get-url origin)
  git_branch=$(git rev-parse --abrev-ref HEAD)
  popd > /dev/null 2>&1 || true

  git_project_name=$(echo "$git_url" | perl -lne 'print $1 if /git@.+:(.+)\.git/')
  if [[ $git_project_name == "" ]]
  then
    echo -e "${RED}Error, malformed git URL : '$git_url' don't match 'git@xxx:xxx.git'"
    return 1
  fi
  jenkins_organization_name="$(echo "${git_project_name%%/*}" | tr '[:lower:]' '[:upper:]')"
  if [[ $get_root_url == "true" ]]
  then
    echo -n "https://${JENKINS_GTP_HOSTNAME}/job/${jenkins_organization_name}/job/${git_project_name//\//%2F}"
  else
    echo -n "https://${JENKINS_GTP_HOSTNAME}/job/${jenkins_organization_name}/job/${git_project_name//\//%2F}/job/${git_branch}"
  fi
}

function allow_jenkins_slave_ssh() {
  ssh "admin@${JENKINS_GTP_HOSTNAME}" << EOF
sudo sed -i 's/^AllowTcpForwarding.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd
EOF
}

alias tj='trigger_jenkins_scan'
function trigger_jenkins() {
  trigger_jenkins_job "$1" || trigger_jenkins_scan "$1"
}

function trigger_jenkins_scan() {
  username=$JENKINS_GTP_USER
  password=$JENKINS_GTP_API_TOKEN
  job_root_url=$(get_jenkins_job_url '' 'true')
  curl -u "$username:$password" -X POST "$job_root_url/build"
}

function trigger_jenkins_job() {
  username=$JENKINS_GTP_USER
  password=$JENKINS_GTP_API_TOKEN
  job_root_url=$(get_jenkins_job_url)

  JENKINS_HOSTNAME=${JENKINS_GTP_HOSTNAME}
  current_git_branch=$2
  [[ $current_git_branch == "" ]] && current_git_branch=$(git rev-parse --abbrev-ref HEAD)
  job=${job_root_url#*/job/}
  job=${job//\/job/}
  job=${job//$(get_main_branch_name)/$current_git_branch}
  jenkins_cli_jar_path=$(mktemp --suffix=.jar)
  wget -q "https://${JENKINS_HOSTNAME}/jnlpJars/jenkins-cli.jar" -O "${jenkins_cli_jar_path}"
  echo "=> Trigger Jenkins job '${job}'"
  java -jar "$jenkins_cli_jar_path" -http -s "https://${JENKINS_HOSTNAME}" -auth "${username}:${password}" build "$job"
}

########################################
#                Git
########################################
alias gib='branches=$(git branch -a) && echo "$branches"'
alias gicp='git cherry-pick'
alias gil='git log --graph --oneline --color --decorate'
alias gir="git_rebase_origin"
alias gipc="git_propagate_commits"
alias giri='git rebase -i '
alias girst='git reset --hard '
alias gip='git update-index --chmod=+x '
alias gia='git commit --amend --no-edit'
alias giap='git commit --amend --no-edit && git push -f'
alias gidb='delete_git_branch'
alias girsto='git_reset_to_origin'
alias girc='GIT_EDITOR=true git rebase --continue'
alias cc='clonecode'

function delete_git_branch() {
  if [[ $1 != "" ]]
  then
    git push --delete origin "$1"
    git branch -D "$1"
  fi
  deleteOldBranches
}

function close_git_branch() {
  source_branch=$1
  if [[ -z $source_branch ]]
  then
    source_branch=$(get_main_branch_name)
  fi
  git_rebase_origin "$source_branch"
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  git checkout "$source_branch"
  git pull
  git merge "$current_branch"
  git branch -D "$current_branch"
  git push --delete origin "$current_branch"
}

function git_propagate_commits() {
  target_branch=$1
  if [[ -z $target_branch ]]
  then
    echo "${RED}[ERROR] target_branch is required"
    return 1
  fi
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  git checkout "$target_branch" && \
    git pull && \
    git rebase "$current_branch" && \
    if [[ $2 == "" ]]
    then
      git push -f && \
      git checkout "$current_branch"
    fi
}

function git_rebase_origin() {
  source_branch=$1
  if [[ -z $source_branch ]]
  then
    source_branch=$(get_main_branch_name)
  fi
  git fetch && git rebase "origin/$source_branch"
}

function get_main_branch_name() {
  repo=${1:-origin}
  if [[ $(git ls-remote --heads "$repo" main) != "" ]];
  then
    echo "main"
  else
    echo "master"
  fi
}

function git_reset_to_origin() {
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ $current_branch != "" ]];
  then
    git reset --hard "origin/$current_branch"
  fi
}

function deleteOldBranches() {
  git fetch -p
  git branch -vv | grep -E ': (disparue|gone)]' | grep -v "\*" | awk '{ print $1; }' | xargs -r git branch -D
  if [[ ! $SILENT ]]
  then
    branches=$(git branch -a)
    echo "$branches"
  fi
}

function deleteOldBranchesInEachRepo() {
  title0 "Delete old git branches in each repository"
  for git_folder in "${HOME}/dev/"*/.git
  do
    [[ -d "$git_folder" ]] || continue
    cd "${git_folder%/.git}" && deleteOldBranches
  done
}

function clonecode() {
  git_url=$1
  target_dir=$(echo "$git_url" | perl -lne 'print $1 if /git@.+:(.+)\.git/' | tr '/' '.')
  if [[ "$target_dir" == "" ]]
  then
    target_dir=$(echo "$git_url" | perl -lne 'print $1 if /https:\/\/.+?\/(.+)\.git/' | tr '/' '.')
  fi
  if [[ "$target_dir" == "" ]]
  then
    echo -e "${RED}Error, malformed git URL : '$git_url' don't match 'git@xxx:xxx.git' nor 'https://xxx/xxx.git'"
    return 1
  fi
  if [[ ! -d "${HOME}/dev/$target_dir" ]]
  then
    echo "=> Git clone \"$target_dir\""
    git clone "$git_url" "${HOME}/dev/$target_dir"
  fi
  echo "=> Open \"$target_dir\" in VScode"
  code "${HOME}/dev/$target_dir"
}

function custom_rebase() {
  if [[ "$1" == "" ]];
  then
    echo -e "${RED}Error, one argument required : git ref of new desired base"
    return 1
  fi
  tmp=$(mktemp)
  git archive --format=tar HEAD > "$tmp"
  git reset --hard "$1"
  if [[ "$2" == "-d" ]];
  then
    rm -rf ./*
  fi
  tar xf "$tmp"
  rm -f "$tmp"
}

function cross_cherry_pick() {
  source_repo_name=$1
  if [[ "$source_repo_name" == "" ]];
  then
    echo -e "${RED}Error, one argument required : git repo name that contains the commit to import"
    return 1
  fi
  gitlab_hostname=${3}
  [[ $gitlab_hostname == "" ]] && gitlab_hostname=$(git remote get-url origin | sed -n 's#.*@\([^:/]*\).*#\1#p')
  git remote add cross_cherry_pick "git@${gitlab_hostname}:${source_repo_name}.git"
  git fetch cross_cherry_pick

  git_ref=${2}
  [[ $git_ref == "" ]] && git_ref="$(get_main_branch_name cross_cherry_pick)"
  git cherry-pick "cross_cherry_pick/$git_ref"
  git remote remove cross_cherry_pick
}

############################################################
#                          Proxy
############################################################

DEFAULT="\e[39m"
GREEN="\e[32m"
RED="\e[31m"

alias cls='clock_sync'
function clock_sync() {
  sudo /usr/sbin/VBoxService --timesync-set-start --timesync-set-on-restore --timesync-set-threshold 1000 --timesync-interval 5000
  return
}

# Check internet access, fail after 15s
function check_internet_connection() {
  if [[ "$(curl -m 5 -L -s -o /dev/null -I -w '%{http_code}' http://www.google.fr)" == "200" ]]
  then
    echo -e "${GREEN}OK"
    return 0
  else
    echo -e "${RED}KO"
    return 1
  fi
}

# Check corporate access, fail after 15s
function check_corporate_connection() {
  if [[ "$(curl -m 5 -L -s -o /dev/null -I -w '%{http_code}' https://xxx)" == "200" ]]
  then
    echo -e "${GREEN}OK"
    return 0
  else
    echo -e "${RED}KO"
    return 1
  fi
}

# Check DNS
function check_dns() {
  if dig +short www.google.fr +time=5 +tries=3 > /dev/null
  then
    echo -e "${GREEN}OK"
    return 0
  else
    echo -e "${RED}KO"
    return 1
  fi
}

alias prs='proxy_status'
function proxy_status() {
  echo -en "${DEFAULT}WSL-VPNKIT : ${GREEN}"; sudo systemctl is-active wsl-vpnkit
  echo -en "${DEFAULT}CNTLM : ${GREEN}"; sudo systemctl is-active cntlm
  echo -en "${DEFAULT}GOST : ${GREEN}"; sudo systemctl is-active gost
  echo -en "${DEFAULT}INTERNET CONNECTION : "; check_internet_connection
  echo -en "${DEFAULT}CORPORATE_CONNECTION : "; check_corporate_connection
  echo -en "${DEFAULT}DNS_CONNECTION : "; check_dns
  echo -en "${DEFAULT}"
}

# Proxy management
alias proxy_unset='unset http{s,}_proxy && unset HTTP{S,}_PROXY && unset FTP_PROXY && unset ftp_proxy && unset ALL_PROXY && unset all_proxy'

alias red='dns_restart'
function dns_restart() {
  sudo systemctl daemon-reload
  sudo systemctl restart systemd-resolved
  sleep 5
  proxy_status
}

########################################
#             Docker
########################################
function docker_prune() {
    docker container prune
    docker image prune
}
function docker_run() {
    docker run --rm -it --network=host -u root -v "$(pwd):/current" -w /current --entrypoint "" -v "${HOME}/.ssh:/root/.ssh" -v "${HOME}/.aws:/root/.aws" -e AWS_PROFILE -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION -e ANSIBLE_SSH_ARGS="-F /dev/null" "$@"
}
function docker_bash() {
    docker_run "$1" bash
}
function docker_sh() {
    docker_run "$1" sh
}
function docker_enter() {
    docker_bash "$1" || docker_sh "$1"
}

alias dop='docker_prune'
alias dor='docker_run'
alias dob='docker_bash'
alias dos='docker_sh'
alias doi='docker images'
alias doe='docker_enter'

alias push_to_all_ecr='$HOME/dev/oam.builds.jenkins.shared-lib.common/resources/gtp/push_to_ecr.sh -e all -i '

# Portainer
alias portainer='docker run -d -p 9001:9000 --name portainer -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer'
alias portainer_stop='docker rm -f portainer'

function dockerhub_rate_limit() {
  TOKEN=$(curl -s --user "$DOCKERHUB_USERNAME:$DOCKERHUB_TOKEN" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
  curl -s --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest | grep 'ratelimit'
}

########################################
#                 K8S
########################################
# shellcheck disable=SC1090
source <(kubectl completion bash)

alias k='kubecolor'
alias kubectl='kubecolor'
# alias kon='kubeon'
alias kns='kubens'
alias kcx='set_kubeconfigs && kubectx'
alias kga='kubectl get all'
alias kgn='kubectl get nodes'
alias kgp='kubectl get po'
alias kgd='kubectl get deploy'
alias kgap='kubectl get app -n argocd'
alias kgas='kubectl get appset -n argocd'
alias kg='kubectl get'
alias kgy='kubectl get -o yaml'
alias kgj='kubectl get -o json'
alias kd='kubectl describe'
alias kdr='kubectl describe rollout'
alias kda='kubectl describe analysisruns'
alias klf='kubectl logs -f --tail 100'
alias ks="kubectl get -o jsonpath='{.status}'"
alias kkyv='kubectl describe polr | grep "Result: \+fail" -B10'
alias kgpf='kubectl get po -A | grep -v Running | grep -v Completed'
alias kgpfw='kubectl get po -A -o wide | grep -v Running | grep -v Completed'
alias kgps='kubectl get pods -A -o wide --field-selector spec.nodeName='
alias kgi='kubectl get pods -o jsonpath="{..image}" | tr -s "[[:space:]]" "\n" | sort | uniq -c'
alias kgia='kubectl get pods -A -o jsonpath="{..image}" | tr -s "[[:space:]]" "\n" | sort | uniq -c'
alias kgda="get_po_disruption_issue"

alias kv='view_k8s_manifest'
function view_k8s_manifest () {
  temp_file=$(mktemp --suffix=.yaml)
  kubectl get -o yaml "$@" > "$temp_file"
  [[ -s $temp_file ]] && code "$temp_file"
}

function disable_kyverno () {
  kubectl label ns "$1" webhooks.kyverno.io/exclude=''
}
function enable_kyverno () {
  kubectl label ns "$1" webhooks.kyverno.io/exclude-
}

function open_cloud_init() {
  # shellcheck disable=SC2001
  ip=$(echo "${1?}" | sed 's/ip-\([0-9]\{1,3\}-[0-9]\{1,3\}-[0-9]\{1,3\}-[0-9]\{1,3\}\).*/\1/')
  ip=${ip//-/.}
  temp_file=$(mktemp --suffix=.log)
  scp "${ip}:/var/log/cloud-init-output.log" "$temp_file"
  code "$temp_file"
}

function get_po_disruption_issue () {
  k get pdb -A -o json | jq -r '.items[] | select(.status.disruptionsAllowed == 0) | "\(.metadata.namespace)/\(.metadata.name)"'
}

function k_get_all() {
  # shellcheck disable=SC2068
  NAMES="$(kubectl api-resources \
                  --namespaced \
                  --verbs list \
                  -o name | tr '\n' ,)" \
  && export NAMES && kubectl get "${NAMES:0:-1}" --show-kind $@
}

function k_remove_finalizers() {
  kubectl patch "$1" --type json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'
}

function k_force_remove_finalizers() {
  namespace=$1
  kubectl get ns "$namespace" -o json | jq '.spec = {"finalizers":[]}' | kubectl replace --raw "/api/v1/namespaces/$namespace/finalize" -f
}

function kg_composition_errors() {
  kubectl get "$1" "$2" -o=jsonpath='{.spec.resourceRef}{" "}{.spec.resourceRefs}' | jq '.[] | select( .name == null)'
}

function argocd_sync_app() {
  app=${1?}
  argocd login --core
  argocd app terminate-op "$app"
  argocd app sync "$app"
}

function enable_argocd() {
  kubectl scale sts,deploy --replicas 1 --all -n argocd
}

function disable_argocd() {
  kubectl scale sts,deploy --replicas 0 --all -n argocd
}

function kubeops() {
  echo "Searching kube config..."
  if [ -z "$1" ]; then
    if [[ -e $KUBECONFIG ]]; then
      echo "No argument => loading current KUBECONFIG ($KUBECONFIG) !"
      CONFIGFILE=$(basename "$KUBECONFIG")
    else
      echo "No KUBECONFIG : Either set KUBECONFIG env var or pass a kubeconfig name as argument"
      echo ""
      echo "Usage: ${0} <kube-config-name> "
      echo ""
      echo "------------------------------------"
      echo "List of available kube config :"
      echo "------------------------------------"
      find "${HOME}/.kube/" -maxdepth 1 -name "*config*" -exec sh -c 'basename "$1"' find-sh {} \;
      return
    fi
  else
    CONFIGFILE=${1}
  fi
  echo "Using kube config : ${CONFIGFILE}..."
  docker run -it --net=host -v "${HOME}:${HOME}" hjacobs/kube-ops-view --kubeconfig-path="${HOME}/.kube/${CONFIGFILE}"
}

function k() {
  kubectl "$@"
}

function kimg () {
  cat << EOF > "${HOME}/.kube/k8s-images.fmt"
NAMESPACE            NAME           IMAGE            INIT_IMAGE
metadata.namespace   metadata.name  spec.containers[0].image    spec.initContainers[0].image
EOF
  kubectl get pods -o custom-columns-file="${HOME}/.kube/k8s-images.fmt" "$@"
}

function kssh {
  # shellcheck disable=SC2001
  ip=$(echo "$1" | sed 's/ip-\([0-9]\{1,3\}-[0-9]\{1,3\}-[0-9]\{1,3\}-[0-9]\{1,3\}\).*/\1/')
  ip=${ip//-/.}
  ssh "$ip"
}

function convert_to_kustomize {
  dir=${1:=.}
  # shellcheck disable=SC1091
  [[ -f ".version" ]] && source .version
  pushd "$dir" || return
  [[ -f "kustomization.yaml" ]] && rm "kustomization.yaml"
  [[ -d "result" ]] && rm -rf "result"
  kustomize create
  [[ $ADDON_NAMESPACE != "" ]] && kustomize edit set namespace "$ADDON_NAMESPACE"
  find . -type f -name '*.yaml' -not -path "./kustomization.yaml" -exec sh -c 'kustomize edit add resource "$1"' find-sh {} \;
  mkdir "result"
  kustomize build . -o result
  popd > /dev/null 2>&1 || true
}

############################################################
#                       Terraform
############################################################

function tfinit() {
  rm -rf ".terraform"
  mkdir ".terraform"
  cp "$HOME/.terraform.d/providers_cache/.terraform.lock.hcl" ".terraform"
  cp -R "$HOME/.terraform.d/providers_cache/providers" ".terraform"
  terraform init -reconfigure -get=true -upgrade=true
}

function get_tf_backend_s3_path() {
  bucket=$(grep -ohP 'bucket\s*=\s+"\K[^"]+' backend.tf)
  workspace_key_prefix=$(grep -ohP 'workspace_key_prefix\s*=\s+"\K[^"]+' backend.tf)
  key=$(grep -ohP 'key\s*=\s+"\K[^"]+' backend.tf)

  echo "s3://${bucket}/${workspace_key_prefix}/${TERRAFORM_WORKSPACE:=PROD}/${key}"
}
function show_tf_backend() {
  aws --profile backend s3 cp "$(get_tf_backend_s3_path)" -
}
function pull_tf_backend() {
  aws --profile backend s3 cp "$(get_tf_backend_s3_path)" "$(grep -ohP 'key\s*=\s+"\K[^"]+' backend.tf).json"
}
function push_tf_backend() {
  aws --profile backend s3 cp "$(get_tf_backend_s3_path)" "$(get_tf_backend_s3_path).backup" \
  && echo 'backup created !' \
  && aws --profile backend s3 cp "$(grep -ohP 'key\s*=\s+"\K[^"]+' backend.tf).json" "$(get_tf_backend_s3_path)"
}

##################################################################
#                          Certificates
##################################################################
function gencert() {
  mkdir -p /tmp/cert
  echo "test DNS command : dig -t txt +short _acme-challenge.${1} @8.8.8.8"
  docker run --rm -it --network=host -v /tmp/cert:/etc/letsencrypt certbot/certbot certonly --manual -d "$1" -d \*."$1" --preferred-challenges dns && \
  sudo mv "${HOME}/.certs/${1}.pem" "${HOME}/.certs/${1}_$(date '+%Y%m%d').pem" | true && \
  sudo mv "${HOME}/.certs/${1}.key" "${HOME}/.certs/${1}_$(date '+%Y%m%d').key" | true && \
  sudo cp "/tmp/cert/live/${1}/fullchain.pem" "${HOME}/.certs/${1}.pem" && \
  sudo cp "/tmp/cert/live/${1}/privkey.pem" "${HOME}/.certs/${1}.key" && \
  sudo chown "${USER}:" "${HOME}/.certs/${1}."* && \
  sudo rm -rf /tmp/cert
  ls -lrt "${HOME}/.certs"
}

##################################################################
#                              SSH
##################################################################
function import_ssh_key() {
  if [[ "$1" == "" ]];
  then
    ls /mnt/d/sharedfolder/.ssh
  else
    cp "/mnt/d/sharedfolder/.ssh/$1" "${HOME}/.ssh"
    chmod 400 "${HOME}/.ssh/$1"
  fi
}

function write_public_ssh_key() {
  ssh-keygen -y -f "${HOME}/.ssh/$1" > "${HOME}/.ssh/${1%.pem}.pub"
  chmod 644 "${HOME}/.ssh/${1%.pem}.pub"
}

function set_ssh_config() {
  if [[ "$1" == "" ]];
  then
    ln -sf "${HOME}/.ssh/config_global" "${HOME}/.ssh/config"
  else
    ln -sf "${HOME}/.ssh/config_$1" "${HOME}/.ssh/config"
  fi
}

function manage_pgp() {
  gpg --list-secret-keys --keyid-format LONG
  echo "Create new key : vi ${HOME}/.gpg/config && gpg --batch --gen-key ${HOME}/.gpg/config"
  echo "Delete key : gpg --delete-secret-and-public-key --batch --yes XXXXXXXXXXXXXXXXX"
  echo "Import key : gpg --import ${HOME}/.gpg/xxxxxxxxxxx.asc"
  echo "Export public key : gpg --export --armor XXXXXXXXXXXXXXXXX > ${HOME}/.gpg/gpg_xxxxxxxxxxx_public.asc && chmod 644 ${HOME}/.gpg/gpg_xxxxxxxxxxx_public.asc"
  echo "Export private key : gpg --export-secret-keys --armor XXXXXXXXXXXXXXXXX > ${HOME}/.gpg/gpg_xxxxxxxxxxx.asc && chmod 400 ${HOME}/.gpg/gpg_xxxxxxxxxxx.asc"
}

#################################
# AWS
#################################

function check_aws_connection() {
  echo -en "${DEFAULT}Check AWS connection using '${1:=current}' profile : "
  [[ $1 != "" ]] && profile_param="--profile $1"
  # shellcheck disable=SC2086
  if eval "aws sts get-caller-identity $profile_param"
  then
    echo -e "${GREEN}OK"
    return 0
  else
    echo -e "${RED}KO"
    return 1
  fi
}

function aws_decode-authorization-message() {
  temp_file=$(mktemp --suffix=.json)
  aws sts decode-authorization-message --encoded-message "$1" --query 'DecodedMessage' --output text | jq > "$temp_file"
  code "$temp_file"
}
