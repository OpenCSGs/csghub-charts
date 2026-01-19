#!/usr/bin/env bash
set -Eeuo pipefail

################################################################################
# quick_install.sh - Improved dry-run support
# Usage: ./quick_install.sh --domain example.com [--dry-run] [...]
################################################################################

LOG_FILE="./quick-install.log"
KUBECONFIG="/root/.kube/config"
export DEBIAN_FRONTEND=noninteractive

# Default values
DOMAIN=""
DATA_DIR="/var/lib/rancher/k3s"

ENABLE_NVIDIA_GPU=false
ENABLE_NFS_PV=true

INSTALL_CN=false
HOSTS_ALIAS=true

EXTRA_ARGS=()

DRY_RUN=false
VERBOSE=false

GHPROXY=""

INTERFACE=""
TIMEOUT=300

K3S_SERVER=""
K3S_TOKEN=""
K3S_VERSION="v1.34.3+k3s1"


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
    ATTE) color="\033[0;34m" ;;
    CMD)  color="\033[0;36m" ;;
    *) color="\033[0m" ;;
  esac

  # Output to terminal with color
  echo -e "${color}[${ts}] [$level] $msg${reset}"

  # Only log to file when not in dry-run mode
  [[ "${DRY_RUN:-false}" != "true" ]] && echo "[${ts}] [$level] $msg" >> "$LOG_FILE"
}

# Do not trigger ERR trap when dry-run
trap '[[ "${DRY_RUN:-false}" == "true" ]] || log ERRO "Error on line $LINENO: Command [${BASH_COMMAND}]"' ERR

################################################################################
# Argument Parsing
################################################################################
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Required:
  --domain <domain>                Target domain for installation

Optional:
  --data <data_dir>                Custom data directory for K3S and components
  --enable-gpu                     Enable NVIDIA GPU support
  --enable-nfs-pv                  Enable NFS server and RWX persistent volumes
  --install-cn                     Use CN registry mirrors for faster downloads
  --hosts-alias                    Add local /etc/hosts aliases for services
  --extra-args "<args>"            Additional Helm parameters (e.g. --set key=value)
  --dry-run                        Print the commands without executing them
  --verbose                        Enable verbose logging output
  --ghproxy <url>                  GitHub proxy for helm/script downloads (e.g. https://ghfast.top)
  --interface <name>               Network interface to use (default: auto-detected)
  --timeout <seconds>              Timeout for waiting pods to become Ready
  --k3s-server <server_url>        Join an existing K3S cluster as an agent node
  --k3s-token <server_token>       K3S cluster join token (required with --k3s-server)
  --k3s-version <version>          K3S cluster version (e.g. v1.34.3+k3s1)
  --help                           Show this help message and exit
EOF
  exit 0
}

TEMP=$(getopt -o h --long help,domain:,data:,enable-gpu,,install-cn,hosts-alias,enable-nfs-pv,extra-args:,dry-run,verbose,ghproxy:,interface:,timeout:,k3s-server:,k3s-token:,k3s-version: -n "$0" -- "$@") || usage
eval set -- "$TEMP"

while true; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --data) DATA_DIR="$2"; shift 2 ;;
    --enable-gpu) ENABLE_NVIDIA_GPU=true; shift ;;
    --install-cn) INSTALL_CN=true; shift ;;
    --hosts-alias) HOSTS_ALIAS=true; shift ;;
    --enable-nfs-pv) ENABLE_NFS_PV=true; shift ;;
    --extra-args) EXTRA_ARGS+=($2); shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    --ghproxy) GHPROXY="$2"; shift 2 ;;
    --interface) INTERFACE="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --k3s-server) K3S_SERVER="$2"; shift 2 ;;
    --k3s-token) K3S_TOKEN="$2"; shift 2 ;;
    --k3s-version) K3S_VERSION="$2"; shift 2 ;;
    -h|--help) usage ;;
    --) shift; break ;;
    *) log ERRO "Unknown argument: $1"; usage ;;
  esac
done

if [[ "${DRY_RUN:-false}" == "true" ]]; then
  set +e
fi

[[ -z "$DOMAIN" ]] && { log ERRO "--domain is required."; exit 1; }

################################################################################
# Utility Functions (dry-run aware)
################################################################################
check_command() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would check command: $1"
    return 0
  fi
  command -v "$1" &>/dev/null || { log ERRO "Command '$1' not found."; exit 1; }
}

retry() {
  local max=${1:-3}; shift
  local cmd="$*"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "[dry-run] $cmd"
    return 0
  fi
  local count=0
  local ret=1
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
    sleep $((5 * count))
  done
  set -e
  log ERRO "Command failed after $max retries: $cmd"
  return $ret
}

run_cmd() {
  local cmd="$*"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "$cmd"
    return 0
  else
    retry 5 "$cmd"
  fi
}

# Safe write helper — prints contents in dry-run, writes otherwise
safe_write() {
  local target="$1"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would write to file: $target"
    # pass through content to stdout so caller can still see content in logs
    cat
  else
    cat > "$target"
  fi
}

update_pkg_cache() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would update package cache (apt/yum/apk/dnf)"
    return 0
  fi
  if command -v apt-get &>/dev/null; then
    retry 3 "apt-get update"
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
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would install package(s): $pkg"
    return 0
  fi
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
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would restart k3s service"
    return 0
  fi

  local service=k3s
  if [[ ! -z "$K3S_SERVER" ]]; then
    service="k3s-agent"
  fi

  if command -v systemctl &>/dev/null; then
    run_cmd "systemctl restart ${service}"
  elif command -v rc-service &>/dev/null; then
    run_cmd "rc-service ${service} restart"
  fi
}

manage_service() {
  local service="$1"
  local action="${2:-restart}"
  local os
  os=$(detect_os)

  if [[ "$service" == "nfs-server" ]]; then
    case "$os" in
      ubuntu|debian) service="nfs-kernel-server" ;;
      alpine) service="nfs" ;;
    esac
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would manage service '$service' with action '$action'"
    return 0
  fi

  case "$os" in
    alpine)
      if [[ "$action" == "enable" ]]; then
        run_cmd "rc-update add $service"
      else
        run_cmd "rc-service $service $action"
      fi
      ;;
    ubuntu|debian)
      run_cmd "systemctl $action $service"
      ;;
    centos|rhel|rocky|alma|fedora)
      run_cmd "systemctl $action $service"
      ;;
    *)
      if command -v systemctl &>/dev/null; then
        run_cmd "systemctl $action $service"
      elif command -v service &>/dev/null; then
        run_cmd "service $service $action"
      else
        log WARN "Unknown OS and no recognized service manager, fallback manual execution"
        case "$action" in
          restart|stop) run_cmd "pkill -9 $service || true" ;;
          start) run_cmd "nohup $service >/var/log/${service}.log 2>&1 &" ;;
        esac
      fi
      ;;
  esac
}

wait_for_pods_ready() {
  local ns=$1
  local timeout=${2:-$TIMEOUT}
  log INFO "Waiting for all pods in namespace $ns to be Ready..."
  run_cmd "kubectl wait --for=condition=Ready pods --all -n $ns --timeout=${timeout}s"
}

################################################################################
# Detect OS and install dependencies (dry-run aware)
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
      run_cmd "apt-get update"
      run_cmd "apt-get install -y bash curl jq iproute2 grep sed coreutils util-linux gettext-base gnupg2"
      ;;
    centos|rhel|rocky|alma|fedora)
      if command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
      else
        PKG_MGR="yum"
      fi
      run_cmd "$PKG_MGR install -y epel-release || true"
      run_cmd "$PKG_MGR install -y bash curl jq iproute grep sed coreutils util-linux gettext gnupg2"
      ;;
    *)
      log WARN "Unknown OS: $os. Skipping dependency installation."
      ;;
  esac

  ################################################################################
  # Helm installation with idempotency checks (dry-run aware)
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

################################################################################
# Pre-install NVIDIA GPU dependencies
################################################################################
if [[ "$ENABLE_NVIDIA_GPU" == "true" ]]; then
  update_pkg_cache
  # Install dependencies
  install_pkg alsa-utils

  os=$(detect_os)
  log INFO "Installing NVIDIA GPU prerequisites for $os..."
  case "$os" in
    alpine)
      log INFO "NVIDIA Container Toolkit doesn't support Alpine..."
      ;;
    ubuntu|debian)
      # Ensure keyrings directory exists
      run_cmd "mkdir -p /usr/share/keyrings"
      # Download NVIDIA GPG key if not present
      if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log CMD "Would fetch NVIDIA GPG key and add to /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
      else
        if [ ! -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg ]; then
          retry 5 "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
        else
          log INFO "NVIDIA GPG key already exists, skipping download"
        fi
      fi

      if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log CMD "Would create /etc/apt/sources.list.d/nvidia-container-toolkit.list with NVIDIA repo"
      else
        if [ ! -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]; then
          retry 5 "curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list"
        else
          log INFO "NVIDIA container toolkit list already exists, skipping"
        fi
      fi

      update_pkg_cache
      # Install NVIDIA container toolkit and runtime
      install_pkg nvidia-container-toolkit nvidia-container-toolkit-base nvidia-container-runtime libnvidia-container-tools libnvidia-container1
      ;;
    centos|rhel|rocky|alma|fedora)
      if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log CMD "Would add NVIDIA yum repo file /etc/yum.repos.d/nvidia-container-toolkit.repo"
      else
        if [ ! -f /etc/yum.repos.d/nvidia-container-toolkit.repo ]; then
          retry 5 "curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | tee /etc/yum.repos.d/nvidia-container-toolkit.repo"
        else
          log INFO "NVIDIA container toolkit list already exists, skipping"
        fi
      fi
      update_pkg_cache
      install_pkg nvidia-container-toolkit nvidia-container-toolkit-base nvidia-container-runtime libnvidia-container-tools libnvidia-container1
      ;;
    *)
      log WARN "Unknown OS: $os. Skipping dependency installation."
      ;;
  esac

  log INFO "Configuring kernel parameters for inotify..."
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would add fs.inotify.max_user_instances = 256 to /etc/sysctl.conf if missing and run sysctl -p"
  else
    grep -qF "fs.inotify.max_user_instances = 256" /etc/sysctl.conf || echo "fs.inotify.max_user_instances = 256" | tee -a /etc/sysctl.conf >/dev/null
    retry 3 "sysctl -p | sort -u"
  fi
fi

################################################################################
# Install K3S (always enabled)
################################################################################
log INFO "Installing K3S..."
if [[ "${DRY_RUN:-false}" == "true" ]]; then
  interface="${INTERFACE:-eth0}"
  ip_addr="127.0.0.1"
else
  interface="${INTERFACE:-$(ip route show default | awk '/default/ {print $5}')}"
  ip_addr=$(ip addr show "$interface" | awk '/inet /{print $2}' | cut -d/ -f1)
fi
log INFO "Using network interface: $interface (IP: $ip_addr)"

run_cmd "mkdir -p /etc/rancher/k3s"
run_cmd "mkdir -p ${DATA_DIR}"
[[ -w "$DATA_DIR" ]] || log ERRO "DATA_DIR is not writable: $DATA_DIR"

# registries.yaml creation: use safe_write to avoid file writes in dry-run
cat <<EOF | safe_write /etc/rancher/k3s/registries.yaml
mirrors:
  docker.io:
    endpoint:
      - "https://opencsg-registry.cn-beijing.cr.aliyuncs.com"
EOF

K3S_URL="https://get.k3s.io"
K3S_ENV=(
  "INSTALL_K3S_VERSION=${K3S_VERSION}"
)

K3S_ARGS=(
  "--data-dir=${DATA_DIR}"
  "--flannel-iface=${interface}"
  "--kubelet-arg=eviction-hard="
)

if [[ -z "$K3S_SERVER" ]]; then
  log INFO "Installing K3S server node..."
  K3S_ARGS+=(
    "--node-name=k3s-master"
    "--disable=traefik"
  )
else
  log INFO "Installing K3S agent node..."
  if [[ -z "$K3S_TOKEN" ]]; then
    log ERRO "--k3s-token is required when --k3s-server is set"
    log WARN "Get join token from ${DATA_DIR}/server/token"
    exit 1
  fi

  K3S_ENV+=(
    "K3S_URL=$K3S_SERVER"
    "K3S_TOKEN=$K3S_TOKEN"
  )
  K3S_ARGS+=("--node-name=k3s-agent-${ip_addr//./-}")
fi

if [[ "$INSTALL_CN" == "true" ]]; then
  K3S_URL="https://rancher-mirror.rancher.cn/k3s/k3s-install.sh"
  K3S_ENV+=("INSTALL_K3S_MIRROR=cn")
  K3S_ENV+=("K3S_SYSTEM_DEFAULT_REGISTRY=opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq")
fi

if [[ "$ENABLE_NVIDIA_GPU" == "true" && $(detect_os) != "alpine" ]]; then
  K3S_ARGS+=("--default-runtime=nvidia")
fi

run_cmd "curl -sfL ${K3S_URL} | ${K3S_ENV[*]} sh -s - ${K3S_ARGS[*]}"

log INFO "Waiting for k3s started..."
# In dry-run emulate presence of file
K3S_KUBE_CONFIG="/etc/rancher/k3s/k3s.yaml"
if [[ "${DRY_RUN:-false}" == "true" ]]; then
  log CMD "Would wait for ${K3S_KUBE_CONFIG} to be created"
fi

if [[ -n "$K3S_SERVER" && "${DRY_RUN:-false}" != "true" && ! -f "$K3S_KUBE_CONFIG" ]]; then
  log ATTE "Please copy server ~/.kube/config from the master node to agent ${K3S_KUBE_CONFIG}."
  user_input=""
  while [[ "$user_input" != "continue" ]]; do
    read -rp "Type 'continue' to proceed: " user_input
  done

  retry 10 "test -f ${K3S_KUBE_CONFIG}"
fi

if [[ "${DRY_RUN:-false}" == "true" ]]; then
  log CMD "Would chmod 0400 ${K3S_KUBE_CONFIG}"
else
  chmod 0400 "$K3S_KUBE_CONFIG" || true
fi

export KUBECONFIG="$K3S_KUBE_CONFIG"
log INFO "K3S installed (or simulated)."

if [[ -z "$K3S_SERVER" ]]; then
  mkdir -p ~/.kube
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would copy ${K3S_KUBE_CONFIG} to ~/.kube/config and sed replace 127.0.0.1 with ${ip_addr}"
  else
    cp -f "$K3S_KUBE_CONFIG" ~/.kube/config
    chmod 0400 ~/.kube/config
    sed -i "s/127.0.0.1/${ip_addr}/g" ~/.kube/config
  fi
fi

log INFO "Waiting for K3S nodes to become Ready..."
if [[ "${DRY_RUN:-false}" == "true" ]]; then
  log CMD "Would run: kubectl wait --for=condition=Ready node --all --timeout=300s"
else
  retry 5 "kubectl wait --for=condition=Ready node --all --timeout=300s"
  wait_for_pods_ready kube-system
fi

################################################################################
# PVC ReadWriteMany Support (NFS Subdir External Provisioner)
################################################################################
if [[ "${ENABLE_NFS_PV:-true}" == "true" && -z "$K3S_SERVER" ]]; then
  NFS_SERVER="${ip_addr:-}"
  NFS_PATH="${NFS_PATH:-/data/sharedir}"

  log INFO "Installing NFS components (client + optional server)..."
  os=$(detect_os)
  update_pkg_cache

  case "$os" in
    alpine)
      install_pkg nfs-utils
      ;;
    ubuntu|debian)
      install_pkg nfs-common nfs-kernel-server
      ;;
    centos|rhel|rocky|alma|fedora)
      install_pkg nfs-utils
      ;;
    *)
      log WARN "Unknown OS: $os. Skipping NFS installation."
      ;;
  esac


  # ------------------------------------------------------------------------------
  # If server installation is enabled
  # ------------------------------------------------------------------------------
  log INFO "Configuring NFS server..."

  manage_service "nfs-server" "enable"
  manage_service "nfs-server" "start"

  # Create and export directory
  run_cmd "mkdir -p ${NFS_PATH}"
  run_cmd "chmod 777 ${NFS_PATH}"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would update /etc/exports with ${NFS_PATH} *(rw,sync,no_root_squash,no_subtree_check)"
  else
    sed -i "\|${NFS_PATH}|d" /etc/exports 2>/dev/null || true
    echo "${NFS_PATH} *(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports
    run_cmd "exportfs -rav"
  fi

  manage_service "nfs-server" "restart"

  # ------------------------------------------------------------------------------
  # Install NFS provisioner if NFS_SERVER is defined
  # ------------------------------------------------------------------------------
  if [[ -n "$NFS_SERVER" ]]; then
    log INFO "Configuring NFS dynamic provisioner (server: $NFS_SERVER, path: $NFS_PATH)..."

    NFS_EXTRA_ARGS+=()
    NFS_SUBDIR_CHART_URL="https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/"
    if [[ "$INSTALL_CN" == "true" ]]; then
      NFS_EXTRA_ARGS+=(--set image.repository=opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq/sig-storage/nfs-subdir-external-provisioner)
      NFS_EXTRA_ARGS+=(--set image.tag=v4.0.2)

      NFS_SUBDIR_CHART_URL="https://charts.opencsg.com/nfs-subdir-external-provisioner/"
    fi

    run_cmd "timeout 30s helm repo add nfs $NFS_SUBDIR_CHART_URL --force-update"
    run_cmd "timeout 30s helm upgrade --install nfs-subdir-external-provisioner nfs/nfs-subdir-external-provisioner \
      --namespace nfs-provisioner --create-namespace \
      --set nfs.server=${NFS_SERVER} \
      --set nfs.path=${NFS_PATH} \
      --set storageClass.name=nfs-client \
      ${NFS_EXTRA_ARGS[*]}"

    wait_for_pods_ready nfs-provisioner
  else
    log WARN "NFS_SERVER not set, skipping NFS provisioner installation."
  fi
fi

################################################################################
# NVIDIA GPU Support
################################################################################
if [[ "$ENABLE_NVIDIA_GPU" == "true" && $(detect_os) != "alpine" ]]; then
  log INFO "Installing NVIDIA device plugin and configuring runtime..."
  run_cmd "nvidia-ctk runtime configure --runtime=containerd --config=/var/lib/rancher/k3s/agent/etc/containerd/config.toml"
  restart_service

  NVDP_EXTRA_ARGS+=()
  NVDP_CHART_URL="https://nvidia.github.io/k8s-device-plugin/"
  if [[ "$INSTALL_CN" == "true" ]]; then
    NVDP_EXTRA_ARGS+=(--set image.repository=opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq/nvidia/k8s-device-plugin)
    NVDP_EXTRA_ARGS+=(--set nfd.image.repository=opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq/nfd/node-feature-discovery)

    NVDP_CHART_URL="https://charts.opencsg.com/k8s-device-plugin/"
  fi

  if [[ -z "$K3S_SERVER" ]]; then
    run_cmd "timeout 10s helm repo add nvdp $NVDP_CHART_URL --force-update"
    run_cmd "timeout 10s helm upgrade -i nvdp nvdp/nvidia-device-plugin --namespace nvdp --create-namespace \
      --version v0.18.0 \
      --set gfd.enabled=true \
      --set runtimeClassName=nvidia \
      ${NVDP_EXTRA_ARGS[*]}"

    log INFO "Waiting for NVIDIA Device Plugin pods..."
    wait_for_pods_ready nvdp
  fi
fi

################################################################################
# Label Kubernetes Nodes
################################################################################
if [[ "$ENABLE_NVIDIA_GPU" == "true" ]]; then
  log INFO "Labeling nodes for NVIDIA GPU..."
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would query kubectl get nodes and label each node with nvidia labels"
  else
    NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    for NODE in $NODES; do
      if [[ -n "$NODE" ]]; then
        retry 3 "kubectl label node $NODE nvidia.com/mps.capable=true nvidia.com/gpu=true --overwrite"
      fi
    done

    log INFO "Adding NVIDIA Name label based on gpu.product..."
    for NODE in $NODES; do
      if [[ -n "$NODE" ]]; then
        for i in {1..12}; do
          GPU_PRODUCT=$(kubectl get node "$NODE" -o jsonpath='{.metadata.labels.nvidia\.com/gpu\.product}' 2>/dev/null || true)
          if [[ -z "$GPU_PRODUCT" ]]; then
            GPU_PRODUCT=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1 | tr ' ' '-')
          fi
          [[ -n "$GPU_PRODUCT" ]] && break
          sleep 5
        done

        if [[ -n "$GPU_PRODUCT" ]]; then
          NVIDIA_NAME=$(echo "$GPU_PRODUCT" | sed -E 's/GeForce-//;s/(RTX-|GTX-|GT-|Tesla-|Quadro-|TITAN-)//; s/-(Laptop-)?GPU.*$//')
          retry 3 "kubectl label node $NODE nvidia.com/nvidia_name=$NVIDIA_NAME --overwrite"
        fi
      fi
    done
  fi
fi

################################################################################
# Install CSGHub Helm Chart
################################################################################
if [[ -z "$K3S_SERVER" ]]; then
  log INFO "Installing CSGHub Helm Chart..."
  run_cmd "timeout 10s helm repo add csghub https://charts.opencsg.com/csghub/ --force-update"

  # Compose extra args array for helm
  if [[ "$ENABLE_NFS_PV" == "true" ]]; then
    HELM_EXTRA_ARGS+=(--set dataflow.dataflow.persistence.storageClass='nfs-client')
    HELM_EXTRA_ARGS+=(--set csgship.web.persistence.storageClass='nfs-client')
  else
    HELM_EXTRA_ARGS+=(--set dataflow.dataflow.persistence.accessModes[0]="ReadWriteOnce")
  fi

  HELM_EXTRA_ARGS+=(--set global.edition='ee')
  HELM_EXTRA_ARGS+=(--set global.ingress.domain="${DOMAIN}")
  HELM_EXTRA_ARGS+=(--set global.ingress.service.type=NodePort)
  HELM_EXTRA_ARGS+=(--set ingress-nginx.controller.service.type=NodePort)
  HELM_EXTRA_ARGS+=(--set csgship.enabled='false')

  if [[ "$INSTALL_CN" == "true" ]]; then
    HELM_EXTRA_ARGS+=(--set global.image.registry=opencsg-registry.cn-beijing.cr.aliyuncs.com)
    HELM_EXTRA_ARGS+=(--set gitaly.image.registry=opencsg-registry.cn-beijing.cr.aliyuncs.com)
    HELM_EXTRA_ARGS+=(--set gitlabShell.image.registry=opencsg-registry.cn-beijing.cr.aliyuncs.com)
  fi

  HELM_EXTRA_ARGS+=("${EXTRA_ARGS[@]}")

  # Helm install/upgrade with proper array handling
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would run helm upgrade --install csghub csghub/csghub --namespace csghub --create-namespace \
      ${HELM_EXTRA_ARGS[*]} | tee ./login.txt"
  else
    retry 2 kubectl delete jobs --all -n csghub
    retry 5 helm upgrade --install csghub csghub/csghub \
      --namespace csghub \
      --create-namespace \
      "${HELM_EXTRA_ARGS[@]}" | tee ./login.txt
  fi

  # Patch kourier svc to NodePort, wait for it to be created first
  log INFO "Waiting for kourier service to be created in kourier-system namespace..."
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would wait for kourier svc in kourier-system and patch to NodePort"
  else
    retry 10 "kubectl get svc kourier -n kourier-system"
    log INFO "Patching kourier to NodePort..."
    run_cmd "kubectl patch svc kourier -p '{\"spec\":{\"type\":\"NodePort\"}}' -n kourier-system"
  fi

################################################################################
# Configure local hosts alias
################################################################################
  if [[ "$HOSTS_ALIAS" == "true" ]]; then
    log INFO "Configuring local domain aliases..."
    
    NEW_DOMAIN="csghub.${DOMAIN}"
    PUBLIC_DOMAIN="public.${DOMAIN}"
    USE_TOP=false
    HOST_SET=false
    for arg in "${HELM_EXTRA_ARGS[@]}"; do
      case "$arg" in
        global.ingress.host=*)
          value="${arg#*=}"
          if [[ "$value" != *.* ]]; then
            NEW_DOMAIN="${value}.${DOMAIN}"
          else
            NEW_DOMAIN="$value"
          fi
          HOST_SET=true
          ;;
        global.ingress.publicHost=*)
          value="${arg#*=}"
          if [[ "$value" != *.* ]]; then
            PUBLIC_DOMAIN="${value}.${DOMAIN}"
          else
            PUBLIC_DOMAIN="$value"
          fi
          ;;
        global.ingress.useTop=*)
          value="${arg#*=}"
          [[ "$value" == "true" ]] && USE_TOP=true
          ;;
      esac
    done

    if [[ "$USE_TOP" == "true" && "$HOST_SET" != "true" ]]; then
      NEW_DOMAIN="${DOMAIN}"
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
      log CMD "Would apply ConfigMap for coredns-custom with domain ${DOMAIN} and ip ${ip_addr}"
    else
      run_cmd "kubectl apply -f -" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  ${DOMAIN}.server: |
    ${DOMAIN} {
      hosts {
        ${ip_addr} ${NEW_DOMAIN} csghub
        ${ip_addr} casdoor.${DOMAIN} casdoor
        ${ip_addr} minio.${DOMAIN} minio
        ${ip_addr} csgship.${DOMAIN} csgship
        ${ip_addr} csgship-api.${DOMAIN} csgship-api
        ${ip_addr} runner.${DOMAIN} runner
        ${ip_addr} dataflow.${DOMAIN} dataflow
        ${ip_addr} label-studio.${DOMAIN} label-studio
      }
    }

  ${PUBLIC_DOMAIN}.server: |
    ${PUBLIC_DOMAIN} {
      template IN A ${PUBLIC_DOMAIN} {
        answer "{{ .Name }} 3600 IN A ${ip_addr}"
      }
      log
      errors
    }
EOF
    fi

    entries=(
      "${ip_addr} ${NEW_DOMAIN} csghub"
      "${ip_addr} casdoor.${DOMAIN} casdoor"
      "${ip_addr} minio.${DOMAIN} minio"
      "${ip_addr} csgship.${DOMAIN} csgship"
      "${ip_addr} csgship-api.${DOMAIN} csgship-api"
      "${ip_addr} runner.${DOMAIN} runner"
      "${ip_addr} dataflow.${DOMAIN} dataflow"
      "${ip_addr} label-studio.${DOMAIN} label-studio"
    )
    for entry in "${entries[@]}"; do
      if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log CMD "Would append to /etc/hosts: $entry"
      elif ! grep -qF "$entry" /etc/hosts; then
        echo "$entry" >> /etc/hosts
      fi
    done
  fi
fi

################################################################################
# Configure Private Registry for K3S
################################################################################
log INFO "Waiting for csghub-docker-credential secret to be created..."
if [[ "${DRY_RUN:-false}" == "true" ]]; then
  log CMD "Would wait for secret csghub-docker-credential in namespace spaces"
else
  retry 20 "kubectl -n spaces get secret csghub-docker-credential &>/dev/null"
fi

log INFO "Configuring private registry access for K3S..."
if [[ "${DRY_RUN:-false}" == "true" ]]; then
  log CMD "DRY_RUN: Would fetch csghub-docker-credential and update /etc/rancher/k3s/registries.yaml"
else
  SECRET_JSON=$(kubectl -n spaces get secret csghub-docker-credential -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d)
  REGISTRY=$(echo "$SECRET_JSON" | jq -r '.auths | keys[]' 2>/dev/null || true)
  REGISTRY_USERNAME=$(echo "$SECRET_JSON" | jq -r '.auths | to_entries[] | .value | .username' 2>/dev/null || true)
  REGISTRY_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.auths | to_entries[] | .value | .password' 2>/dev/null || true)

  cat <<EOF | safe_write /etc/rancher/k3s/registries.yaml
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
fi

log INFO "CSGHub installation finished."
log ATTE "Local domain resolution:"
log ATTE "  • Configure /etc/hosts on worker nodes based on the master /etc/hosts"
log ATTE "Access CSGHub:"
log ATTE "  • CSGHub may take longer to become ready"
log ATTE "  • Check status with: kubectl get pods -n csghub"
log ATTE "  • Login info saved to: ./login.txt"
log INFO "✅ Installation completed successfully."
[[ "${DRY_RUN:-false}" == "true" ]] && log INFO "Dry-run mode completed: no changes applied."