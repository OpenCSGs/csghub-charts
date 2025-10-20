#!/usr/bin/env bash
set -Eeuo pipefail

################################################################################
# Global Settings
################################################################################
LOG_FILE="./quick-install.log"
KUBECONFIG="/root/.kube/config"
export DEBIAN_FRONTEND=noninteractive

# Default values
ENABLE_NVIDIA_GPU=false
ENABLE_CSGSHIP=false
HOSTS_ALIAS=true
KNATIVE_INTERNAL_DOMAIN="app.internal"
INGRESS_SERVICE_TYPE="NodePort"
KOURIER_SERVICE_TYPE="NodePort"
EDITION="ee"
INSTALL_CN=false
DOMAIN=""
VERBOSE=false
DRY_RUN=false
GHPROXY="https://ghfast.top"

################################################################################
# Logging and Error Handling
################################################################################
log() {
  local level="$1"; shift
  local msg="$*"
  local ts
  ts="$(date +'%F %T')"
  local color reset="\033[0m"
  case "$level" in
    INFO) color="\033[0;32m" ;;
    WARN) color="\033[0;33m" ;;
    ERRO) color="\033[0;31m" ;;
    CMD)  color="\033[0;36m" ;;
    *) color="\033[0m" ;;
  esac

  # Output to terminal with color
  echo -e "${color}[${ts}] [$level] $msg${reset}"

  # Write to log file, remove ANSI color codes
  echo "[${ts}] [$level] $msg" >> "$LOG_FILE"
}

trap 'log ERRO "Error on line $LINENO: Command [${BASH_COMMAND}]"' ERR

################################################################################
# Argument Parsing
################################################################################
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]
Options:
  --domain <domain>                Target domain (required)
  --enable-gpu                     Enable NVIDIA GPU support
  --edition [ee|ce]                Edition type (default: ee)
  --install-cn                     Use CN registry mirror
  --hosts-alias                    Enable adding domain aliases to /etc/hosts
  --enable-csgship                 Enable CSGShip service
  --dry-run                        Print commands only, do not execute
  --verbose                        Enable detailed logging
  --ghproxy <url>                  Set GitHub proxy for raw.githubusercontent.com and github.com links (default: https://ghfast.top)
  --knative-domain <domain>        Set Knative internal domain (default: app.internal)
  --ingress-service-type <type>    Set ingress service type (default: NodePort)
  --kourier-service-type <type>    Set Kourier service type (default: NodePort)
  --help                           Show this help and exit
EOF
  exit 0
}

TEMP=$(getopt -o h --long help,domain:,enable-gpu,edition:,install-cn,hosts-alias,enable-csgship,dry-run,verbose,ghproxy:,knative-domain:,ingress-service-type:,kourier-service-type: -n "$0" -- "$@") || usage
eval set -- "$TEMP"

while true; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --enable-gpu) ENABLE_NVIDIA_GPU=true; shift ;;
    --edition) EDITION="$2"; shift 2 ;;
    --install-cn) INSTALL_CN=true; shift ;;
    --hosts-alias) HOSTS_ALIAS=true; shift ;;
    --enable-csgship) ENABLE_CSGHIP=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    --ghproxy) GHPROXY="$2"; shift 2 ;;
    --knative-domain) KNATIVE_INTERNAL_DOMAIN="$2"; shift 2 ;;
    --ingress-service-type) INGRESS_SERVICE_TYPE="$2"; shift 2 ;;
    --kourier-service-type) KOURIER_SERVICE_TYPE="$2"; shift 2 ;;
    -h|--help) usage ;;
    --) shift; break ;;
    *) log ERRO "Unknown argument: $1"; usage ;;
  esac
done

[[ -z "$DOMAIN" ]] && { log ERRO "--domain is required."; exit 1; }

################################################################################
# Utility Functions
################################################################################
check_command() {
  command -v "$1" &>/dev/null || { log ERRO "Command '$1' not found."; exit 1; }
}

run_cmd() {
  local cmd="$*"
  if [[ "$DRY_RUN" == "true" ]]; then
    log CMD "$cmd"
  else
    eval "$cmd"
  fi
}

retry() {
  local max=${1:-3}; shift
  local cmd="$*"
  local count=0
  local ret=1

  # Save and disable global ERR trap
  local old_trap
  old_trap=$(trap -p ERR)
  trap '' ERR

  if [[ "$DRY_RUN" == "true" ]]; then
    log CMD "$cmd"
    eval "$old_trap"
    return 0
  fi

  while ((count < max)); do
    bash -c "$cmd"
    ret=$?
    if ((ret == 0)); then
      eval "$old_trap"
      return 0
    fi
    ((count++))
    log WARN "Retry $count/$max: $cmd (exit code: $ret)"
    sleep 5
  done

  eval "$old_trap"
  log ERRO "Command failed after $max retries: $cmd"
  return $ret
}

restart_service() {
  if command -v systemctl &>/dev/null; then
    run_cmd "systemctl restart k3s"
  elif command -v rc-service &>/dev/null; then
    run_cmd "rc-service k3s restart"
  else
    log WARN "Cannot determine service manager, restarting k3s manually."
    run_cmd "pkill -9 k3s || true"
    run_cmd "nohup k3s server >/var/log/k3s-restart.log 2>&1 &"
  fi
}

################################################################################
# Detect OS and install dependencies
################################################################################
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
  else
    OS_ID=$(uname -s | tr '[:upper:]' '[:lower:]')
  fi
  echo "$OS_ID"
}

install_packages() {
  local os
  os=$(detect_os)
  log INFO "Detected OS: $os"
  case "$os" in
    alpine)
      run_cmd "apk update"
      run_cmd "apk add --no-cache bash curl jq iproute2 grep sed coreutils util-linux gettext openrc"
      ;;
    ubuntu|debian)
      run_cmd "apt-get update -qq"
      run_cmd "apt-get install -y bash curl jq iproute2 grep sed coreutils util-linux gettext-base"
      ;;
    centos|rhel|rocky|alma|fedora)
      if command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
      else
        PKG_MGR="yum"
      fi
      run_cmd "$PKG_MGR install -y epel-release"
      run_cmd "$PKG_MGR install -y bash curl jq iproute grep sed coreutils util-linux gettext"
      ;;
    *)
      log WARN "Unknown OS: $os. Skipping dependency installation."
      ;;
  esac

  # Ensure timeout is installed (from coreutils)
  case "$os" in
    alpine)
      run_cmd "apk add --no-cache coreutils"
      ;;
    ubuntu|debian)
      run_cmd "apt-get install -y coreutils"
      ;;
    centos|rhel|rocky|alma|fedora)
      if command -v dnf &>/dev/null; then
        run_cmd "dnf install -y coreutils"
      else
        run_cmd "yum install -y coreutils"
      fi
      ;;
    *)
      log WARN "Could not determine how to install timeout/coreutils for OS: $os"
      ;;
  esac

  ################################################################################
  # Helm installation with idempotency checks
  ################################################################################
  log INFO "Installing Helm via official script..."
  if [ ! -f /usr/share/keyrings/helm.gpg ]; then
    run_cmd "curl -fsSL -o get_helm.sh \"${GHPROXY}/https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3\""
    run_cmd "chmod 700 get_helm.sh"
    run_cmd "./get_helm.sh"
  else
    log INFO "Helm GPG key already exists, skipping download"
  fi

  if [ ! -f /etc/apt/sources.list.d/helm-stable-debian.list ]; then
    run_cmd "echo \"deb [arch=$(dpkg --print-architecture)] https://baltocdn.com/helm/stable/debian/ all main\" | tee /etc/apt/sources.list.d/helm-stable-debian.list"
    run_cmd "apt-get update -qq"
  else
    log INFO "Helm repo list file already exists, skipping"
  fi
}

################################################################################
# System & Dependency Installation
################################################################################
log INFO "Checking system dependencies..."
install_packages
for cmd in curl jq awk ip; do check_command "$cmd"; done
# Note: kubectl is installed with K3S, helm is installed manually above.

################################################################################
# Pre-install NVIDIA GPU dependencies
################################################################################
if [[ "$ENABLE_NVIDIA_GPU" == "true" ]]; then
  log INFO "Installing NVIDIA GPU prerequisites..."
  retry 3 "apt-get update -qq"
  retry 3 "apt-get install -y alsa-utils"

  if [ ! -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg ]; then
    retry 3 "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
  else
    log INFO "NVIDIA GPG key already exists, skipping download"
  fi

  if [ ! -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]; then
    retry 3 "curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list"
    retry 3 "apt-get update -qq"
  else
    log INFO "NVIDIA container toolkit list already exists, skipping"
  fi

  retry 3 "apt-get install -y nvidia-container-toolkit nvidia-container-runtime"
  log INFO "Configuring kernel parameters for inotify..."
  grep -qF "fs.inotify.max_user_instances = 256" /etc/sysctl.conf || echo "fs.inotify.max_user_instances = 256" | tee -a /etc/sysctl.conf >/dev/null
  retry 3 "sysctl -p | sort -u"
fi

################################################################################
# Install K3S (always enabled)
################################################################################
log INFO "Installing K3S..."
interface=$(ip route show default | awk '/default/ {print $5}')
ip_addr=$(ip addr show "$interface" | awk '/inet /{print $2}' | cut -d/ -f1)

run_cmd "mkdir -p /etc/rancher/k3s"
cat <<EOF | tee /etc/rancher/k3s/registries.yaml >/dev/null
mirrors:
  docker.io:
    endpoint:
      - "https://opencsg-registry.cn-beijing.cr.aliyuncs.com"
    rewrite:
      "^rancher/(.*)": "opencsg_public/rancher/\$1"
EOF


if [[ "$ENABLE_NVIDIA_GPU" == "true" ]]; then
  retry 3 "curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn INSTALL_K3S_VERSION=v1.30.4+k3s1 sh -s - \
    --disable=traefik --flannel-iface=${interface} --default-runtime=nvidia"
else
  retry 3 "curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn INSTALL_K3S_VERSION=v1.30.4+k3s1 sh -s - \
    --disable=traefik --flannel-iface=${interface}"
fi

chmod 0400 /etc/rancher/k3s/k3s.yaml || true
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
log INFO "K3S installed successfully."

mkdir -p ~/.kube
cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 0400 ~/.kube/config
sed -i "s/127.0.0.1/${ip_addr}/g" ~/.kube/config

################################################################################
# NVIDIA GPU Support
################################################################################
if [[ "$ENABLE_NVIDIA_GPU" == "true" ]]; then
  log INFO "Installing NVIDIA device plugin..."
  if [ ! -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg ]; then
    retry 3 "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
  else
    log INFO "NVIDIA GPG key already exists, skipping download"
  fi

  if [ ! -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]; then
    retry 3 "curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list"
    retry 3 "apt-get update -qq"
  else
    log INFO "NVIDIA container toolkit list already exists, skipping"
  fi

  retry 3 "apt-get install -y nvidia-container-toolkit -qq"
  retry 3 "nvidia-ctk runtime configure --runtime=containerd --config=/var/lib/rancher/k3s/agent/etc/containerd/config.toml"
  restart_service
  retry 3 "timeout 10s helm repo add nvdp https://nvidia.github.io/k8s-device-plugin --force-update"
  retry 3 "timeout 10s helm upgrade -i nvdp nvdp/nvidia-device-plugin --namespace nvdp --create-namespace \
    --version v0.17.4 \
    --set gfd.enabled=true \
    --set runtimeClassName=nvidia \
    --set image.repository=opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq/nvidia/k8s-device-plugin \
    --set nfd.image.repository=opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq/nfd/node-feature-discovery"
fi

################################################################################
# Label Kubernetes Nodes
################################################################################
if [[ "$ENABLE_NVIDIA_GPU" == "true" ]]; then
  log INFO "Labeling nodes for NVIDIA GPU..."
  NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
  for NODE in $NODES; do
    if [[ -n "$NODE" ]]; then
      retry 3 "kubectl label node $NODE nvidia.com/mps.capable=true nvidia.com/gpu=true --overwrite"
    fi
  done

  log INFO "Adding NVIDIA Name label based on gpu.product..."
  for NODE in $NODES; do
    if [[ -n "$NODE" ]]; then
      GPU_PRODUCT=$(kubectl get node "$NODE" -o jsonpath='{.metadata.labels.nvidia\.com/gpu\.product}')
      if [[ -n "$GPU_PRODUCT" ]]; then
        NVIDIA_NAME=$(echo "$GPU_PRODUCT" | awk -F'-' '{print $NF}')
        retry 3 "kubectl label node $NODE nvidia.com/nvidia_name=$NVIDIA_NAME --overwrite"
      fi
    fi
  done
fi

################################################################################
# Install CSGHub Helm Chart
################################################################################
log INFO "Installing CSGHub Helm Chart..."
retry 3 "timeout 10s helm repo add csghub https://charts.opencsg.com/repository/csghub/ --force-update"
retry 3 "helm repo update"

EXTRA_ARGS=""
[[ "$INSTALL_CN" == "true" ]] && EXTRA_ARGS="--set global.image.registry=opencsg-registry.cn-beijing.cr.aliyuncs.com"

retry 3 "helm upgrade --install csghub csghub/csghub \
  --namespace csghub \
  --create-namespace \
  --set global.edition=\"$EDITION\" \
  --set csgship.enabled=\"$ENABLE_CSGSHIP\" \
  --set global.ingress.domain=\"$DOMAIN\" \
  --set global.ingress.service.type=\"$INGRESS_SERVICE_TYPE\" \
  --set ingress-nginx.controller.service.type=\"$INGRESS_SERVICE_TYPE\" \
  --set global.knative.serving.services[0].type=\"$KOURIER_SERVICE_TYPE\" \
  --set global.knative.serving.services[0].domain=\"$KNATIVE_INTERNAL_DOMAIN\" \
  $EXTRA_ARGS | tee ./login.txt"

################################################################################
# Configure local hosts alias
################################################################################
if [[ "$HOSTS_ALIAS" == "true" ]]; then
  log INFO "Configuring local domain aliases..."
  entries=(
    "${ip_addr} csghub.${DOMAIN} csghub"
    "${ip_addr} casdoor.${DOMAIN} casdoor"
    "${ip_addr} registry.${DOMAIN} registry"
    "${ip_addr} minio.${DOMAIN} minio"
    "${ip_addr} temporal.${DOMAIN} temporal"
    "${ip_addr} csgship.${DOMAIN} csgship"
    "${ip_addr} csgship-api.${DOMAIN} csgship-api"
  )
  for entry in "${entries[@]}"; do
    grep -qF "$entry" /etc/hosts || echo "$entry" >> /etc/hosts
  done
fi

################################################################################
# Configure Private Registry for K3S
################################################################################
log INFO "Configuring private registry access for K3S..."
SECRET_JSON=$(kubectl -n spaces get secret csghub-docker-credential -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d)
REGISTRY=$(echo "$SECRET_JSON" | jq -r '.auths | keys[]')
REGISTRY_USERNAME=$(echo "$SECRET_JSON" | jq -r '.auths | to_entries[] | .value | .username')
REGISTRY_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.auths | to_entries[] | .value | .password')

cat <<EOF >/etc/rancher/k3s/registries.yaml
mirrors:
  docker.io:
    endpoint:
      - "https://opencsg-registry.cn-beijing.cr.aliyuncs.com"
  ${REGISTRY}:
    endpoint:
      - "http://${REGISTRY}"
configs:
  "${REGISTRY}":
    auth:
      username: ${REGISTRY_USERNAME}
      password: ${REGISTRY_PASSWORD}
    tls:
      insecure_skip_verify: true
      plain-http: true
EOF

restart_service

log INFO "✅ Installation completed successfully."
log INFO "Login info saved to ./login.txt"
[[ "$DRY_RUN" == "true" ]] && log INFO "Dry-run mode: no changes were actually applied."