#!/usr/bin/env bash
set -uo pipefail

################################################################################
# quick_uninstall.sh - Clean uninstall for CSGHub quick install
# Usage: ./quick_uninstall.sh [--force] [--dry-run] [...]
################################################################################

LOG_FILE="./quick-uninstall.log"
export DEBIAN_FRONTEND=noninteractive

# Default values
DATA_DIR="/var/lib/rancher/k3s"

ENABLE_NVIDIA_GPU=false
ENABLE_NFS_PV=true

DRY_RUN=false
VERBOSE=false
NFS_PATH="${NFS_PATH:-/data/sharedir}"

KUBECONFIG=""
K3S_SERVER=""

# Track uninstall results
SKIPPED_COMPONENTS=()
UNINSTALLED_COMPONENTS=()
FAILED_COMPONENTS=()

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

################################################################################
# Argument Parsing
################################################################################
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Optional:
  --data <data_dir>                Data directory used during installation (default: /var/lib/rancher/k3s)
  --enable-gpu                     Also uninstall NVIDIA GPU support
  --enable-nfs-pv                  Also uninstall NFS server and provisioner (default: true)
  --k3s-server <server_url>        Uninstall as an agent node (joined via this server URL)
  --dry-run                        Print the commands without executing them
  --verbose                        Enable verbose logging output
  --help                           Show this help message and exit
EOF
  exit 0
}

TEMP=$(getopt -o h --long help,data:,enable-gpu,enable-nfs-pv,k3s-server:,dry-run,verbose -n "$0" -- "$@") || usage
eval set -- "$TEMP"

while true; do
  case "$1" in
    --data) DATA_DIR="$2"; shift 2 ;;
    --enable-gpu) ENABLE_NVIDIA_GPU=true; shift ;;
    --enable-nfs-pv) ENABLE_NFS_PV=true; shift ;;
    --k3s-server) K3S_SERVER="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    -h|--help) usage ;;
    --) shift; break ;;
    *) log ERRO "Unknown argument: $1"; usage ;;
  esac
done

################################################################################
# Utility Functions (dry-run aware)
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

run_cmd() {
  local cmd="$*"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "$cmd"
    return 0
  fi
  local ret=0
  bash -c "$cmd" || ret=$?
  if (( ret != 0 )); then
    log ERRO "Command failed (exit code: $ret): $cmd"
  fi
  return $ret
}

# Run a component function with interactive error handling at component level.
# On failure, ask user to retry the whole component or skip it.
# Usage: run_component_safe "ComponentName" component_function
run_component_safe() {
  local name="$1"
  local func="$2"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    $func
    return 0
  fi
  while true; do
    local ret=0
    $func || ret=$?
    if (( ret == 0 )); then
      return 0
    fi
    log ERRO "Component '$name' uninstall encountered errors."
    echo ""
    read -rp "  [r] Retry '$name' / [s] Skip / [a] Abort? [r/s/A] " choice
    case "$choice" in
      r|R) continue ;;
      s|S) log WARN "Skipping component '$name'."; return 1 ;;
      *)   log INFO "Aborting."; exit 1 ;;
    esac
  done
}

# Confirm before uninstalling a component
# Usage: confirm_component "Component Name" "description text"
# Returns 0 to proceed, 1 to skip
confirm_component() {
  local name="$1"
  local desc="$2"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    return 0
  fi

  echo ""
  echo -e "\033[0;34m============================================================================="
  echo -e "\033[0;34m  * Component: $name"
  echo -e "\033[0;34m  * $desc"
  echo -e "\033[0;34m=============================================================================\033[0m"
  read -rp "Uninstall $name? [y/N] " confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    return 0
  fi
  return 1
}

manage_service() {
  local service="$1"
  local action="${2:-stop}"
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
      if [[ "$action" == "disable" ]]; then
        run_cmd "rc-update del $service"
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
      fi
      ;;
  esac
}

uninstall_pkg() {
  local pkg="$*"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would uninstall package(s): $pkg"
    return 0
  fi
  if command -v apt-get &>/dev/null; then
    run_cmd "apt-get remove -y $pkg"
  elif command -v apk &>/dev/null; then
    run_cmd "apk del --no-cache $pkg"
  elif command -v dnf &>/dev/null; then
    run_cmd "dnf remove -y $pkg"
  elif command -v yum &>/dev/null; then
    run_cmd "yum remove -y $pkg"
  fi
}

remove_line_from_file() {
  local file="$1"
  local pattern="$2"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would remove lines matching '$pattern' from $file"
    return 0
  fi
  if [[ -f "$file" ]]; then
    sed -i "/${pattern}/d" "$file" 2>/dev/null
  fi
}

################################################################################
# Resolve kubeconfig
################################################################################
K3S_KUBE_CONFIG="/etc/rancher/k3s/k3s.yaml"
if [[ -f "$K3S_KUBE_CONFIG" ]]; then
  export KUBECONFIG="$K3S_KUBE_CONFIG"
elif [[ -f ~/.kube/config ]]; then
  export KUBECONFIG=~/.kube/config
else
  log WARN "No kubeconfig found, some Kubernetes cleanup steps will be skipped."
fi

HAS_KUBEACCESS=false
if [[ -n "${KUBECONFIG:-}" ]] && command -v kubectl &>/dev/null; then
  if kubectl cluster-info &>/dev/null; then
    HAS_KUBEACCESS=true
  fi
fi

log INFO "Starting CSGHub uninstall..."
log INFO "Data directory: $DATA_DIR"

################################################################################
# Component Uninstall Functions
# Each function returns 0 on success, non-zero on any failure.
################################################################################

do_uninstall_csghub() {
  log INFO "Uninstalling CSGHub Helm chart..."
  if [[ "$HAS_KUBEACCESS" == "true" ]]; then
    # Delete CR instances while their controllers are still running.
    # Some operators (e.g. Knative Operator) add finalizers to CRDs reactively
    # when helm uninstall starts deleting resources — the operator sees the
    # deletion, adds a finalizer to the CRD to perform cleanup, but then the
    # operator pod itself is killed by helm uninstall, leaving the CRD stuck in
    # Terminating with no controller to clear the finalizer.  Deleting CR
    # instances first ensures the operator processes them normally, so no
    # reactive finalizer is added and helm uninstall can delete the CRD cleanly.
    log INFO "Removing CR instances before Helm uninstall..."
    for cr in knativeservings; do
      if kubectl get "$cr" -A 2>/dev/null | grep -qv "NAME"; then
        run_cmd "kubectl delete $cr --all -A --timeout 180s" || true
      fi
    done

    # Delete Gateway API resources while the controller is still running,
    # so the controller can properly clean up associated resources.
    log INFO "Removing Gateway API resources before Helm uninstall..."
    for gw_res in httproutes gateways; do
      if kubectl get "$gw_res" -A 2>/dev/null | grep -qv "NAME"; then
        run_cmd "kubectl delete $gw_res --all -n csghub --timeout 180s" || true
      fi
    done

    # Uninstall Helm release
    log INFO "Uninstalling CSGHub Helm release..."
    if helm list -n csghub -f csghub 2>/dev/null | grep -q csghub; then
      run_cmd "helm uninstall csghub -n csghub --wait --timeout 120s" || return 1
    else
      log INFO "CSGHub Helm chart not found."
    fi

    # Uninstall standalone Helm releases before deleting their namespaces,
    # so cluster-scoped resources (StorageClass, ClusterRole, etc.) are removed.
    local standalone_releases=("nfs-provisioner nfs-subdir-external-provisioner")
    [[ "$ENABLE_NVIDIA_GPU" == "true" ]] && standalone_releases+=("nvdp nvdp")
    for release_info in "${standalone_releases[@]}"; do
      read -r ns release <<< "$release_info"
      if helm list -n "$ns" 2>/dev/null | grep -q "$release"; then
        log INFO "Uninstalling Helm release '$release' from namespace '$ns'..."
        run_cmd "helm uninstall $release -n $ns --wait --timeout 120s" || true
      fi
    done

    # Delete namespaces
    log INFO "Deleting CSGHub-related namespaces..."
    local namespaces=("csghub" "spaces" "nfs-provisioner")
    [[ "$ENABLE_NVIDIA_GPU" == "true" ]] && namespaces+=("nvdp")
    for ns in "${namespaces[@]}"; do
      if kubectl get ns "$ns" &>/dev/null; then
        run_cmd "kubectl delete ns $ns --ignore-not-found" || return 1
      fi
    done

    # Remove remaining CRDs labeled by CSGHub
    log INFO "Removing remaining CSGHub-related CRDs..."
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
      log CMD "Would delete CRDs: kubectl delete crd -l app.kubernetes.io/name=csghub --ignore-not-found"
    else
      run_cmd "kubectl delete crd -l app.kubernetes.io/name=csghub --ignore-not-found --timeout 120s" || true
    fi

    # Remove CoreDNS custom config
    log INFO "Removing CoreDNS custom config if exists..."
    if kubectl get configmap coredns-custom -n kube-system &>/dev/null; then
      run_cmd "kubectl delete configmap coredns-custom -n kube-system --timeout 120s" || return 1
      run_cmd "kubectl rollout restart deploy coredns -n kube-system" || return 1
    fi

    # Remove helm repos
    log INFO "Removing CSGHub-related Helm repos..."
    local helm_repos=("csghub" "nfs")
    [[ "$ENABLE_NVIDIA_GPU" == "true" ]] && helm_repos+=("nvdp")
    for repo in "${helm_repos[@]}"; do
      run_cmd "helm repo remove $repo" || true
    done
  else
    log ERROR "No Kubernetes cluster access, skipping Helm/K8s cleanup."
    return 1
  fi
  return 0
}

do_uninstall_nvidia() {
  log INFO "Uninstalling NVIDIA GPU support..."
  os=$(detect_os)

  if [[ "$HAS_KUBEACCESS" == "true" ]]; then
    NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    for NODE in $NODES; do
      if [[ -n "$NODE" ]]; then
        run_cmd "kubectl label node $NODE nvidia.com/mps.capable- nvidia.com/gpu- nvidia.com/nvidia_name- --overwrite"
      fi
    done
  fi

  if [[ "$os" != "alpine" ]]; then
    uninstall_pkg nvidia-container-toolkit nvidia-container-toolkit-base nvidia-container-runtime libnvidia-container-tools libnvidia-container1 alsa-utils

    case "$os" in
      ubuntu|debian)
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
          log CMD "Would remove /etc/apt/sources.list.d/nvidia-container-toolkit.list"
          log CMD "Would remove /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
        else
          rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
          rm -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        fi
        ;;
      centos|rhel|rocky|alma|fedora)
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
          log CMD "Would remove /etc/yum.repos.d/nvidia-container-toolkit.repo"
        else
          rm -f /etc/yum.repos.d/nvidia-container-toolkit.repo
        fi
        ;;
    esac
  fi
  return 0
}

do_uninstall_nfs() {
  log INFO "Uninstalling NFS components..."

  # Stop and disable NFS server
  manage_service "nfs-server" "stop"
  manage_service "nfs-server" "disable"

  # Remove NFS export entry
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would remove NFS export '${NFS_PATH}' from /etc/exports"
  else
    if [[ -f /etc/exports ]]; then
      sed -i "\|${NFS_PATH}|d" /etc/exports 2>/dev/null
      run_cmd "exportfs -rav || true"
    fi
  fi

  # Remove NFS shared directory
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would remove NFS shared directory: ${NFS_PATH}"
  else
    if [[ -d "$NFS_PATH" ]]; then
      rm -rf "$NFS_PATH"
      log INFO "NFS shared directory removed: ${NFS_PATH}"
    fi
  fi

  # Uninstall NFS packages
  os=$(detect_os)
  case "$os" in
    alpine) uninstall_pkg nfs-utils ;;
    ubuntu|debian) uninstall_pkg nfs-common nfs-kernel-server ;;
    centos|rhel|rocky|alma|fedora) uninstall_pkg nfs-utils ;;
  esac
  return 0
}

do_uninstall_k3s() {
  log INFO "Uninstalling K3S..."

  # Lazy-unmount any remaining NFS volumes under kubelet before invoking the
  # k3s uninstall script.  The uninstall order stops NFS first and then K3S,
  # so by the time we get here the NFS server is already gone.  The built-in
  # k3s uninstall script calls "umount -f" on these mounts, which hangs
  # forever when the NFS server is unreachable.  Lazy unmount (-l) detaches
  # the mount immediately without contacting the server; the resulting empty
  # local directories are removed later by the k3s uninstall script and the
  # "rm -rf /var/lib/rancher" cleanup below.
  log INFO "Cleaning up stale NFS mounts under /var/lib/kubelet..."
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would umount -lf all NFS mounts under /var/lib/kubelet"
  else
    mount | grep ' /var/lib/kubelet/.*nfs' | awk '{print $3}' | while read -r mntp; do
      if mountpoint -q "$mntp" 2>/dev/null; then
        log INFO "Lazy unmounting: $mntp"
        umount -lf "$mntp" || true
      fi
    done
  fi

  if [[ -n "$K3S_SERVER" ]]; then
    K3S_UNINSTALL="${DATA_DIR}/bin/k3s-agent-uninstall.sh"
    if [[ ! -f "$K3S_UNINSTALL" ]]; then
      K3S_UNINSTALL="/usr/local/bin/k3s-agent-uninstall.sh"
    fi
  else
    K3S_UNINSTALL="${DATA_DIR}/bin/k3s-uninstall.sh"
    if [[ ! -f "$K3S_UNINSTALL" ]]; then
      K3S_UNINSTALL="/usr/local/bin/k3s-uninstall.sh"
    fi
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would run K3S uninstall script: $K3S_UNINSTALL"
  else
    if [[ -f "$K3S_UNINSTALL" ]]; then
      run_cmd "$K3S_UNINSTALL" || return 1
    else
      log WARN "K3S uninstall script not found at $K3S_UNINSTALL."
    fi
  fi

  # Remove kubeconfig
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would remove ~/.kube/config"
    log CMD "Would remove /etc/rancher/k3s/k3s.yaml"
  else
    rm -f ~/.kube/config
    rm -rf /var/lib/rancher /etc/rancher
  fi
  return 0
}

do_uninstall_system() {
  log INFO "Performing system cleanup..."

  # Remove sysctl config added by installer
  remove_line_from_file /etc/sysctl.conf "fs.inotify.max_user_instances = 256"
  if [[ "${DRY_RUN:-false}" != "true" ]]; then
    if command -v sysctl &>/dev/null; then
      sysctl -p 2>/dev/null
    fi
  fi

  # Remove /etc/hosts entries added by installer
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log CMD "Would clean up /etc/hosts entries for csghub-related domains"
  else
    sed -i '/casdoor\./d; /minio\./d; /csghub\./d' /etc/hosts 2>/dev/null
  fi
  return 0
}

################################################################################
# Execute Uninstall (with per-component confirm + error handling)
################################################################################

# 1. CSGHub (server node only)
if [[ -z "$K3S_SERVER" ]]; then
  if confirm_component "CSGHub" "Will uninstall CSGHub Helm chart, namespaces (csghub/spaces/nfs-provisioner/nvdp), CRDs, CoreDNS custom config, and Helm repos."; then
    if run_component_safe "CSGHub" do_uninstall_csghub; then
      UNINSTALLED_COMPONENTS+=("CSGHub")
    else
      FAILED_COMPONENTS+=("CSGHub")
    fi
  else
    log INFO "Skipping CSGHub uninstall."
    SKIPPED_COMPONENTS+=("CSGHub")
  fi
fi

# 2. NVIDIA GPU
if [[ "$ENABLE_NVIDIA_GPU" == "true" ]]; then
  if confirm_component "NVIDIA GPU" "Will remove node labels, uninstall NVIDIA container toolkit packages, and remove repo files."; then
    if run_component_safe "NVIDIA GPU" do_uninstall_nvidia; then
      UNINSTALLED_COMPONENTS+=("NVIDIA GPU")
    else
      FAILED_COMPONENTS+=("NVIDIA GPU")
    fi
  else
    log INFO "Skipping NVIDIA GPU uninstall."
    SKIPPED_COMPONENTS+=("NVIDIA GPU")
  fi
fi

# 3. NFS (server node only)
if [[ "${ENABLE_NFS_PV:-true}" == "true" && -z "$K3S_SERVER" ]]; then
  if confirm_component "NFS" "Will stop NFS server, remove exports, delete shared directory (${NFS_PATH}), and uninstall NFS packages."; then
    if run_component_safe "NFS" do_uninstall_nfs; then
      UNINSTALLED_COMPONENTS+=("NFS")
    else
      FAILED_COMPONENTS+=("NFS")
    fi
  else
    log INFO "Skipping NFS uninstall."
    SKIPPED_COMPONENTS+=("NFS")
  fi
fi

# 4. K3S
if confirm_component "K3S" "Will run the K3S uninstall script and remove kubeconfig files. This will destroy the entire K3S cluster."; then
  if run_component_safe "K3S" do_uninstall_k3s; then
    UNINSTALLED_COMPONENTS+=("K3S")
  else
    FAILED_COMPONENTS+=("K3S")
  fi
else
  log INFO "Skipping K3S uninstall."
  SKIPPED_COMPONENTS+=("K3S")
fi

# 5. System Config
if confirm_component "System Config" "Will remove sysctl inotify config and /etc/hosts entries added during installation."; then
  if run_component_safe "System Config" do_uninstall_system; then
    UNINSTALLED_COMPONENTS+=("System Config")
  else
    FAILED_COMPONENTS+=("System Config")
  fi
else
  log INFO "Skipping system cleanup."
  SKIPPED_COMPONENTS+=("System Config")
fi

# Optionally uninstall Helm
if helm version &>/dev/null; then
  log INFO "Helm is still installed. To remove: rm -f /usr/local/bin/helm"
fi

################################################################################
# Summary
################################################################################
echo ""
echo -e "\033[0;34m============================================================================="
echo -e "\033[0;34m                              Uninstall Summary"
echo -e "\033[0;34m=============================================================================\033[0m"

if [[ ${#UNINSTALLED_COMPONENTS[@]} -gt 0 ]]; then
  log INFO "Uninstalled: ${UNINSTALLED_COMPONENTS[*]}"
fi
if [[ ${#SKIPPED_COMPONENTS[@]} -gt 0 ]]; then
  log WARN "Skipped:     ${SKIPPED_COMPONENTS[*]}"
fi
if [[ ${#FAILED_COMPONENTS[@]} -gt 0 ]]; then
  log ERRO "Failed:      ${FAILED_COMPONENTS[*]}"
fi

if [[ ${#UNINSTALLED_COMPONENTS[@]} -eq 0 && ${#SKIPPED_COMPONENTS[@]} -eq 0 ]]; then
  log INFO "No components were processed."
fi

echo -e "\033[0;34m============================================================================="
echo -e "\033[0;34mPost-uninstall notes:"
echo -e "\033[0;34m  - Remove /etc/hosts entries on worker nodes manually if needed"
echo -e "\033[0;34m  - Remove Helm manually if desired: rm -f /usr/local/bin/helm"
echo -e "\033[0;34mUninstallation completed."
[[ "${DRY_RUN:-false}" == "true" ]] && echo -e "\033[0mDry-run mode completed: no changes applied."
