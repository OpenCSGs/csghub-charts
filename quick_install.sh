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
DOMAIN=""
KNATIVE_INTERNAL_DOMAIN="$DOMAIN"
INGRESS_SERVICE_TYPE="NodePort"
KOURIER_SERVICE_TYPE="$INGRESS_SERVICE_TYPE"
EDITION="ee"
INSTALL_CN=false
VERBOSE=false
DRY_RUN=false
GHPROXY=""
EXTRA_ARGS=""
INTERFACE=""

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
  --extra-args "<args>"            Additional Helm chart parameters to pass, e.g. "--set replicas=2"
  --dry-run                        Print commands only, do not execute
  --verbose                        Enable detailed logging
  --ghproxy <url>                  Set GitHub proxy for raw.githubusercontent.com and github.com links (default: https://ghfast.top)
  --knative-domain <domain>        Set Knative internal domain (default: =domain)
  --ingress-service-type <type>    Set ingress service type (default: NodePort)
  --kourier-service-type <type>    Set Kourier service type (default: NodePort)
  --interface <name>               Specify the network interface to use (default: first default route interface)
  --help                           Show this help and exit
EOF
  exit 0
}

TEMP=$(getopt -o h --long help,domain:,enable-gpu,edition:,install-cn,hosts-alias,enable-csgship,extra-args:,dry-run,verbose,ghproxy:,knative-domain:,ingress-service-type:,kourier-service-type,interface: -n "$0" -- "$@") || usage
eval set -- "$TEMP"

while true; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --enable-gpu) ENABLE_NVIDIA_GPU=true; shift ;;
    --edition) EDITION="$2"; shift 2 ;;
    --install-cn) INSTALL_CN=true; shift ;;
    --hosts-alias) HOSTS_ALIAS=true; shift ;;
    --enable-csgship) ENABLE_CSGSHIP=true; shift ;;
    --extra-args) EXTRA_ARGS="$EXTRA_ARGS $2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    --ghproxy) GHPROXY="$2"; shift 2 ;;
    --knative-domain) KNATIVE_INTERNAL_DOMAIN="$2"; shift 2 ;;
    --ingress-service-type) INGRESS_SERVICE_TYPE="$2"; shift 2 ;;
    --kourier-service-type) KOURIER_SERVICE_TYPE="$2"; shift 2 ;;
    --interface) INTERFACE="$2"; shift 2 ;;
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
    retry 3 "$cmd"
  fi
}

retry() {
  local max=${1:-3}; shift
  local cmd="$*"
  local count=0
  local ret=1

  if [[ "$DRY_RUN" == "true" ]]; then
    log CMD "$cmd"
    return 0
  fi

  # Allow failures inside the retry loop without exiting the whole script
  set +e

  while (( count < max )); do
    bash -c "$cmd"
    ret=$?
    if (( ret == 0 )); then
      set -e
      return 0
    fi
    ((count++))
    log WARN "Retry $count/$max: $cmd (exit code: $ret)"
    # linear backoff (increase sleep each retry)
    sleep $((5 * count))
  done

  # restore errexit behavior
  set -e
  log ERRO "Command failed after $max retries: $cmd"
  return $ret
}

update_pkg_cache() {
  if command -v apt-get &>/dev/null; then
    retry 3 "apt-get update -qq"
  elif command -v apk &>/dev/null; then
    retry 3 "apk update"
  elif command -v dnf &>/dev/null; then
    retry 3 "dnf makecache"
  elif command -v yum &>/dev/null; then
    retry 3 "yum makecache"
  else
    log ERRO "No supported package manager found (apt/yum/dnf/apk) to update cache."
    exit 1
  fi
}

install_pkg() {
  local pkg="$*"
  if command -v apt-get &>/dev/null; then
    retry 3 "apt-get install -y $pkg"
  elif command -v apk &>/dev/null; then
    retry 3 "apk add --no-cache $pkg"
  elif command -v dnf &>/dev/null; then
    retry 3 "dnf install -y $pkg"
  elif command -v yum &>/dev/null; then
    retry 3 "yum install -y $pkg"
  else
    log ERRO "No supported package manager found (apt/yum/dnf/apk)."
    exit 1
  fi
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

wait_for_pods_ready() {
  local ns=$1
  local timeout=${2:-300}
  log INFO "Waiting for all pods in namespace $ns to be Ready..."
  retry 5 "kubectl wait --for=condition=Ready pods --all -n $ns --timeout=${timeout}s"
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
    centos|rhel|rocky|alma|fedora|kylin)
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
  local helm_url="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
  if [[ -n "$GHPROXY" ]]; then
    helm_url="${GHPROXY%/}/$helm_url"
  fi

  if ! command -v helm &>/dev/null; then
      log INFO "Helm not found, installing..."
      run_cmd "curl -fsSL -o get_helm.sh \"$helm_url\""
      run_cmd "chmod 700 get_helm.sh"
      run_cmd "./get_helm.sh"
  else
      log INFO "Helm is already installed, skipping installation"
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
  update_pkg_cache
  install_pkg alsa-utils

  if [ ! -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg ]; then
    retry 3 "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
  else
    log INFO "NVIDIA GPG key already exists, skipping download"
  fi

  if [ ! -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]; then
    retry 3 "curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list"
  else
    log INFO "NVIDIA container toolkit list already exists, skipping"
  fi

  install_pkg nvidia-container-toolkit nvidia-container-runtime
  log INFO "Configuring kernel parameters for inotify..."
  grep -qF "fs.inotify.max_user_instances = 256" /etc/sysctl.conf || echo "fs.inotify.max_user_instances = 256" | tee -a /etc/sysctl.conf >/dev/null
  retry 3 "sysctl -p | sort -u"
fi

################################################################################
# Install K3S (always enabled)
################################################################################
log INFO "Installing K3S..."
interface="${INTERFACE:-$(ip route show default | awk '/default/ {print $5}')}"
log INFO "Using network interface: $interface"
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
    --disable=traefik --node-name=k3s-master --flannel-iface=${interface} \
    --kubelet-arg="eviction-hard=" --default-runtime=nvidia"
else
  retry 3 "curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn INSTALL_K3S_VERSION=v1.30.4+k3s1 sh -s - \
    --disable=traefik --node-name=k3s-master --flannel-iface=${interface}" \
    --kubelet-arg="eviction-hard="
fi

log INFO "Waiting for k3s started..."
retry 10 "test -f /etc/rancher/k3s/k3s.yaml"

chmod 0400 /etc/rancher/k3s/k3s.yaml || true
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
log INFO "K3S installed successfully."

mkdir -p ~/.kube
cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 0400 ~/.kube/config
sed -i "s/127.0.0.1/${ip_addr}/g" ~/.kube/config

log INFO "Waiting for K3S nodes to become Ready..."
retry 5 "kubectl wait --for=condition=Ready node --all --timeout=300s"

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
    update_pkg_cache
  else
    log INFO "NVIDIA container toolkit list already exists, skipping"
  fi

  install_pkg nvidia-container-toolkit
  retry 3 "nvidia-ctk runtime configure --runtime=containerd --config=/var/lib/rancher/k3s/agent/etc/containerd/config.toml"
  restart_service
  retry 3 "timeout 10s helm repo add nvdp https://nvidia.github.io/k8s-device-plugin --force-update"
  retry 3 "timeout 10s helm upgrade -i nvdp nvdp/nvidia-device-plugin --namespace nvdp --create-namespace \
    --version v0.17.4 \
    --set gfd.enabled=true \
    --set runtimeClassName=nvidia \
    --set image.repository=opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq/nvidia/k8s-device-plugin \
    --set nfd.image.repository=opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq/nfd/node-feature-discovery"

  log INFO "Waiting for NVIDIA Device Plugin pods..."
  wait_for_pods_ready nvdp 300
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
        NVIDIA_NAME=$(echo "$GPU_PRODUCT" | sed -E 's/(RTX-|GTX-|GT-|Tesla-|Quadro-|TITAN-)//; s/-(Laptop-)?GPU.*$//')
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

[[ "ENABLE_CSGSHIP" == "true" ]] && EXTRA_ARGS="$EXTRA_ARGS --set csgship.enabled=true"
[[ "$INSTALL_CN" == "true" ]] && EXTRA_ARGS="$EXTRA_ARGS --set global.image.registry=opencsg-registry.cn-beijing.cr.aliyuncs.com"

retry 3 "helm upgrade --install csghub csghub/csghub \
  --namespace csghub \
  --create-namespace \
  --set global.edition=\"$EDITION\" \
  --set csgship.enabled=\"$ENABLE_CSGSHIP\" \
  --set global.ingress.domain=\"$DOMAIN\" \
  --set global.ingress.service.type=\"$INGRESS_SERVICE_TYPE\" \
  --set ingress-nginx.controller.service.type=\"$INGRESS_SERVICE_TYPE\" \
  $EXTRA_ARGS" | tee ./login.txt

if [[ "$INGRESS_SERVICE_TYPE" == "NodePort" ]]; then
  if kubectl get svc kourier -n kourier-system &>/dev/null; then
    log INFO "Patching kourier to NodePort..."
    run_cmd "kubectl patch svc kourier -p '{\"spec\":{\"type\":\"NodePort\"}}' -n kourier-system"
  else
    log WARN "Kourier service not found in kourier-system namespace, skipping patch."
  fi
fi

################################################################################
# Configure local hosts alias
################################################################################
if [[ "$HOSTS_ALIAS" == "true" ]]; then
  log INFO "Configuring local domain aliases..."

  retry 3 kubectl apply -f - <<EOF
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: coredns-custom
      namespace: kube-system
    data:
      ${DOMAIN}.server: |
        ${DOMAIN} {
          hosts {
            ${ip_addr} csghub.${DOMAIN} csghub
            ${ip_addr} casdoor.${DOMAIN} casdoor
            ${ip_addr} registry.${DOMAIN} registry
            ${ip_addr} minio.${DOMAIN} minio
            ${ip_addr} temporal.${DOMAIN} temporal
            ${ip_addr} csgship.${DOMAIN} csgship
            ${ip_addr} csgship-api.${DOMAIN} csgship-api
          }
        }

      public.${DOMAIN}.server: |
        public.${DOMAIN} {
          template IN A public.${DOMAIN} {
            answer "{{ .Name }} 3600 IN A ${ip_addr}"
          }
          log
          errors
        }
EOF

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
log INFO "Waiting for csghub-docker-credential secret to be created..."
retry 20 "kubectl -n spaces get secret csghub-docker-credential &>/dev/null"

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