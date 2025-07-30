#!/usr/bin/env bash

# Check for correct usage
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <domain> (e.g., $0 example.com)"
  exit 1
fi

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with root privileges."
  exit 1
fi

# Set default values for environment variables
: "${ENABLE_K3S:=true}"
: "${ENABLE_DYNAMIC_PV:=false}"
: "${ENABLE_NVIDIA_GPU:=false}"
: "${ENABLE_STARSHIP:=false}"
: "${HOSTS_ALIAS:=true}"
: "${INSTALL_HELM:=true}"
: "${KNATIVE_INTERNAL_DOMAIN:=app.internal}"
: "${KNATIVE_INTERNAL_HOST:=127.0.0.1}"
: "${KNATIVE_INTERNAL_PORT:=80}"
: "${INGRESS_SERVICE_TYPE:=NodePort}"
: "${KOURIER_SERVICE_TYPE:=NodePort}"
: "${EDITION:=ee}"
: "${INSTALL_CN:=false}"

# Get the domain from the command line argument
: "${DOMAIN:=$1}"

# Retrieve the local IP address
: "${default_interface:=$(ip route show default | awk '/default/ {print $5}')}"
: "${IP_ADDRESS:=$(ip addr show "$default_interface" | awk '/inet / {print $2}' | cut -d/ -f1)}"

# Function to detect the operating system and architecture, and install dependencies
install_dependencies() {
  # Check architecture
  local ARCH=$(uname -m)
  if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    log "ERRO" "Unsupported architecture. This script supports only x86_64(amd64) and aarch64(arm64)."
    exit 1
  fi

  local OS=""
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case $ID in
      ubuntu|debian)
        OS="debian-based"
        log "INFO" "Installing dependencies for Debian/Ubuntu..."
        apt update &>/dev/null && apt install -y curl wget unzip jq apt-transport-https &>/dev/null
        ;;
#      centos|rhel|fedora)
#        OS="fedora-based"
#        log "INFO" "Installing dependencies for CentOS/RHEL/Fedora..."
#        yum install -y curl wget unzip jq &>/dev/null || dnf install -y curl wget unzip jq &>/dev/null
#        ;;
#      arch)
#        OS="arch"
#        log "INFO" "Installing dependencies for Arch Linux..."
#        pacman -Syu --noconfirm curl wget unzip jq &>/dev/null
#        ;;
      *)
        log "ERRO" "Unsupported Linux distribution: $ID."
        exit 1
        ;;
    esac
  else
    log "ERRO" "Cannot determine the operating system."
    exit 1
  fi
  log "INFO" "Detected OS: ${OS} on ${ARCH} architecture."
}

# Format log output
log() {
  local log_level="$1"
  local message="$2"
  local color
  local reset="\033[0m"
  local timestamp="$(date +"%Y-%m-%d %H:%M:%S")"

  # Set color based on log level
  case "$log_level" in
    INFO) color="\033[0;32m" ;;  # Green
    WARN) color="\033[0;33m" ;;  # Yellow
    ERRO) color="\033[0;31m" ;;  # Red
    *)    color="\033[0m" ;;     # Reset
  esac

  # Print logs with timestamp, log level, and color
  echo -e "${color}[${timestamp}] [${log_level}] ${message}${reset}"
  [ "$log_level" = "ERRO" ] && return 1
}

# Function to retry a command up to a specified number of times if it fails
retry() {
  local n=1 max=5 delay=10
  while ! "$@"; do
    ((n++))
    if ((n > max)); then
      log "ERRO" "The command has failed after $max attempts."
      return 1
    fi

    log "WARN" "Command failed. Attempt $n/$max:"
    sleep $delay
  done
}

# Confirmation function
confirm_action() {
  while true; do
    read -p "Do you want to continue? (yes/no): " confirm
    case "${confirm,,}" in  # Convert input to lowercase
      yes)
        log "INFO" "Continuing with the process..."
        return 0  # Success
        ;;
      no)
        log "INFO" "Exiting the process..."
        exit 1  # Failure
        ;;
      *)
        log "ERRO" "Invalid input. Please enter 'yes' or 'no'."
        ;;
    esac
  done
}

# Function to verify if a specific pod is running
verify_pod_running() {
  local namespace="$1"
  local attempt=1 max_attempts=10 delay=10

  log "INFO" "Verifying that the pods in namespace '${namespace}' are running..."

  while [ $attempt -le $max_attempts ]; do
    local NOT_RUNNING=$(kubectl get pods --namespace "$namespace" | grep -v -c -E 'Running|Completed|STATUS')
    if [ "$NOT_RUNNING" -eq 0 ]; then
      log "INFO" "All pods in namespace '${namespace}' are running."
      return 0
    else
      log "WARN" "Not all pods in namespace '${namespace}' are running yet. Attempt ${attempt}/${max_attempts}."
      sleep $delay
    fi
    ((attempt++))
  done

  log "ERRO" "Not all pods in namespace '${namespace}' are running after ${max_attempts} attempts."
  return 1
}

# Verify PersistentVolumes (PVs) have been created
verify_pvs_created() {
    local attempt=1 max_attempts=10 delay=10

    log "INFO" "Verifying that PersistentVolumes (PVs) have been created..."
    while (( attempt <= max_attempts )); do
        local not_available
        not_available=$(kubectl get pv | grep -v -Ec 'Available|Released')
        if (( not_available == 0 )); then
            log "INFO" "All PersistentVolumes (PVs) are in the desired state (Available or Released)."
            return 0
        fi
        log "WARN" "PersistentVolumes are not in the desired state yet. Attempt ${attempt}/${max_attempts}. Remaining unavailable PVs: $not_available."
        (( attempt++ ))
        sleep $delay
    done

    log "ERRO" "PersistentVolumes are not in the desired state after ${max_attempts} attempts."
    return 1
}

# Function to check if K3S cluster is up and running
check_k3s_cluster() {
  local max_attempts=10
  local delay=10

  log "INFO" "Checking if K3S cluster is up and running..."

  for attempt in $(seq 1 $max_attempts); do
    sleep $delay

    local READY=$(kubectl get nodes | grep -c 'Ready')
    local NOT_RUNNING=$(kubectl get pods -n kube-system | grep -vcE 'Running|Completed|STATUS')

    if [[ "$READY" -eq 1 && "$NOT_RUNNING" -eq 0 ]]; then
      log "INFO" "K3S cluster is up and running."
      return 0
    fi

    log "WARN" "K3S cluster is not ready yet. Attempt ${attempt}/${max_attempts}."
  done

  log "ERRO" "K3S cluster is not up after ${max_attempts} attempts."
  return 1
}

# Restart k3s
restart_k3s_cluster() {
  log "INFO" "- Restarting k3s..."
  systemctl restart k3s

  if ! systemctl is-active --quiet k3s; then
    log "ERRO" "k3s failed to start. Please check the service status."
    exit 1
  fi
}

####################################################################################
# Dependencies Installation
####################################################################################
# Call the function to install dependencies
install_dependencies

####################################################################################
# Configure K3S
# https://docs.k3s.io/advanced?_highlight=nvidia#nvidia-container-runtime-support
####################################################################################
# Start installing k3s
if [ "$ENABLE_K3S" == "true" ]; then
  log "INFO" "Creating mirror registry files."
  mkdir -p /etc/rancher/k3s && chmod -R 0755 /etc/rancher/k3s

  cat <<EOF > /etc/rancher/k3s/registries.yaml
mirrors:
  docker.io:
    endpoint:
      - "https://opencsg-registry.cn-beijing.cr.aliyuncs.com"
    rewrite:
      "^rancher/(.*)": "opencsg_public/rancher/\$1"
EOF

  log "INFO" "Installing K3S..."
  install_command="curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn INSTALL_K3S_VERSION=v1.30.4+k3s1 sh -s - --disable=traefik --flannel-iface=${default_interface}"
  [ "$ENABLE_NVIDIA_GPU" == "true" ] && install_command+=" --default-runtime=nvidia"

  retry bash -c "$install_command"

  chmod 0400 /etc/rancher/k3s/k3s.yaml
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  if ! check_k3s_cluster; then
    log "ERRO" "K3S installation failed or cluster status verification failed."
    exit 1
  fi
  log "INFO" "K3S installed successfully."

  log "INFO" "Copying kube config file to the user's home directory."
  mkdir -p ~/.kube
  cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config && chmod 0400 ~/.kube/config
  sed -i "s/127.0.0.1/${IP_ADDRESS}/g" ~/.kube/config
fi

####################################################################################
# Install HELM3
####################################################################################
if [ "$INSTALL_HELM" == "true" ]; then
  log "INFO" "Install helm for helm repo operations."
  curl -sf https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" > /etc/apt/sources.list.d/helm-stable-debian.list
  apt-get update &>/dev/null && apt-get install -y helm &>/dev/null

  if helm version &> /dev/null; then
    log "INFO" "Helm installation verified successfully."
  else
    log "ERRO" "Helm installation verification failed."
    exit 1
  fi
fi

####################################################################################
# Simulate k8s volume management
####################################################################################
if [[ "$ENABLE_K3S" == "false" && "$ENABLE_DYNAMIC_PV" == "true" ]]; then
  log "INFO" "Install sig-storage-local-static-provisioner."

  # Create StorageClass
  cat <<EOF | kubectl apply -f -
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: fast-disks
    annotations:
      storageclass.kubernetes.io/is-default-class: "true"
  provisioner: kubernetes.io/no-provisioner
  volumeBindingMode: WaitForFirstConsumer
  reclaimPolicy: Delete
  allowVolumeExpansion: true
EOF

  # Create resources
  kubectl create namespace local-path-storage 2>/dev/null
  retry helm repo add sig-storage-local-static-provisioner https://kubernetes-sigs.github.io/sig-storage-local-static-provisioner --force-update
  retry helm repo update
  retry helm template --debug sig-storage-local-static-provisioner/local-static-provisioner --namespace local-path-storage | sed 's/registry.k8s.io/opencsg-registry.cn-beijing.cr.aliyuncs.com\/opencsghq/g'> local-volume-provisioner.generated.yaml
  retry kubectl apply -f local-volume-provisioner.generated.yaml

  # Verify that the local-path-storage pod is running
  verify_pod_running "local-path-storage"

  # Additional script content can go here
  log "INFO" "- Binding local path to fast disks."
  for FLAG in {a..z}; do
    mkdir -p /mnt/fake-disks/sd"$FLAG" /mnt/fast-disks/sd"$FLAG" 2>/dev/null
    mount --bind /mnt/fake-disks/sd"$FLAG" /mnt/fast-disks/sd"$FLAG"
    echo "/mnt/fake-disks/sd"$FLAG" /mnt/fast-disks/sd"$FLAG" none bind 0 0" >> /etc/fstab
  done

  # Invoke the verify_pvs_created function to check the PV status
  verify_pvs_created

  # Additional operations or script content can go here
  log "INFO" "Successfully install sig-storage-local-static-provisioner."
fi

####################################################################################
# Configure Argo Workflow
####################################################################################
# Argo Workflow install Replaced by csghub helm chart post-configure job.

####################################################################################
# Configure Knative Serving
####################################################################################
# Knative Serving install Replaced by csghub helm chart post-configure job.

####################################################################################
# Self-managed Kubernetes api-server address verify
####################################################################################
log "INFO" "Verify the validity of kube config."
export KUBECONFIG="/root/.kube/config"
error_messages=()
if [ ! -f "$KUBECONFIG" ]; then
  error_messages+=("The kubeconfig file ($KUBECONFIG) does not exist. Please make sure it is placed in /root.")
fi

if [ -f "$KUBECONFIG" ]; then
  api_server=$(grep -oP 'server:\s*\K(http[s]?://\S+)' "$KUBECONFIG" | awk -F[/:] '{print $4}')
  if [[ "$api_server" == "127.0.0.1" || "$api_server" == "localhost" ]]; then
    error_messages+=("The api-server address in $KUBECONFIG is set to $api_server, which is not allowed. Please use a valid non-localhost address.")
  fi
fi

if [ "${#error_messages[@]}" -gt 0 ]; then
  echo "The following issues were detected:"
  for msg in "${error_messages[@]}"; do
    echo "- $msg"
  done
  confirm_action
fi

####################################################################################
# Configure NVIDIA DEVICE PLUGIN
####################################################################################
if [[ "$ENABLE_NVIDIA_GPU" == "true" ]]; then
  log "INFO" "Install nvidia-device-plugin."

  log "INFO" "- Patch Containerd using nvidia-ctk."
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && \
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

  apt update && apt-get install -y alsa-utils nvidia-container-toolkit
  nvidia-ctk runtime configure --runtime=containerd --config=/var/lib/rancher/k3s/agent/etc/containerd/config.toml

  restart_k3s_cluster

  log "INFO" "- Add nvidia helm repository."
  retry helm repo add nvdp https://nvidia.github.io/k8s-device-plugin --force-update
  retry helm repo update

  log "INFO" "- Installing NVIDIA helm chart..."
  retry helm upgrade -i nvdp nvdp/nvidia-device-plugin \
    --namespace nvdp \
    --create-namespace \
    --version v0.17.0 \
    --set gfd.enabled=true \
    --set runtimeClassName=nvidia \
    --set image.repository=opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq/nvidia/k8s-device-plugin \
    --set nfd.image.repository=opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq/nfd/node-feature-discovery

  log "INFO" "- Patch device-discovery-strategy to nvml."
  ## value enums: auto, tegra, nvml
  retry kubectl -n nvdp patch ds nvdp-nvidia-device-plugin --type='json' \
          --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/args", "value": ["--device-discovery-strategy=nvml"]}]'

  log "INFO" "Add labels for all nodes to enable Multi-Process Service."
  NODES=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.allocatable}{"\n"}{end}' | awk '{print $1}')
  for NODE in $NODES; do
    kubectl label node "$NODE" nvidia.com/mps.capable=true nvidia.com/gpu=true
  done

  verify_pod_running "nvdp"
fi

####################################################################################
# Start install csghub helm chart
####################################################################################
log "INFO" "CSGHub helm chart installation."
log "INFO" "- Creating Namespace csghub."
if ! kubectl get ns csghub &>/dev/null; then
  retry kubectl create ns csghub
  kubectl config set-context --current --namespace=csghub
fi

log "INFO" "- Creating Secret csghub-kube-configs."
kubectl -n csghub delete secret csghub-kube-configs &>/dev/null
retry kubectl -n csghub create secret generic csghub-kube-configs --from-file=/root/.kube/

log "INFO" "- Add csghub helm repo."
retry helm repo add csghub https://charts.opencsg.com/repository/csghub/ --force-update && helm repo update

log "INFO" "- Retrieve knative service info."
KNATIVE_INTERNAL_HOST="$IP_ADDRESS"
if [[ "$KOURIER_SERVICE_TYPE" == "NodePort" ]]; then
  KNATIVE_INTERNAL_PORT="30213"
fi

log "INFO" "- Installing csghub helm chart..."
EXTRA_ARGS=""
if [ "$INSTALL_CN" = "true" ]; then
  EXTRA_ARGS="\
    --set global.image.registry=opencsg-registry.cn-beijing.cr.aliyuncs.com"
fi

retry helm upgrade --install csghub csghub/csghub \
  --namespace csghub \
  --create-namespace \
  --set global.edition="$EDITION" \
  --set starship.enabled="$ENABLE_STARSHIP" \
  --set global.ingress.domain="$DOMAIN" \
  --set global.ingress.service.type="$INGRESS_SERVICE_TYPE" \
  --set ingress-nginx.controller.service.type="$INGRESS_SERVICE_TYPE" \
  --set global.deploy.knative.serving.services[0].type="$KOURIER_SERVICE_TYPE" \
  --set global.deploy.knative.serving.services[0].domain="$KNATIVE_INTERNAL_DOMAIN" \
  --set global.deploy.knative.serving.services[0].host="$KNATIVE_INTERNAL_HOST" \
  --set global.deploy.knative.serving.services[0].port="$KNATIVE_INTERNAL_PORT" \
  $EXTRA_ARGS | tee ./login.txt

####################################################################################
# Configuring local domain name resolution
####################################################################################
if [ "$HOSTS_ALIAS" == true ]; then
  log "INFO" "Configuring local domain name resolution."

  retry kubectl apply -f - <<EOF
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: coredns-custom
    namespace: kube-system
  data:
    ${DOMAIN}.server: |
      ${DOMAIN} {
        hosts {
          ${IP_ADDRESS} csghub.${DOMAIN} csghub
          ${IP_ADDRESS} casdoor.${DOMAIN} casdoor
          ${IP_ADDRESS} registry.${DOMAIN} registry
          ${IP_ADDRESS} minio.${DOMAIN} minio
          ${IP_ADDRESS} temporal.${DOMAIN} temporal
          ${IP_ADDRESS} starship.${DOMAIN} starship
          ${IP_ADDRESS} starship-api.${DOMAIN} starship-api
        }
      }

    public.${DOMAIN}.server: |
      public.${DOMAIN} {
        template IN A public.${DOMAIN} {
          answer "{{ .Name }} 3600 IN A ${IP_ADDRESS}"
        }
        log
        errors
      }
EOF

  log "INFO" "- Rollout restart deployment coredns."
  retry kubectl -n kube-system rollout restart deploy coredns

  log "INFO" "- Add domain resolution to /etc/hosts."
  HOST_ENTRIES=(
    "${IP_ADDRESS} csghub.${DOMAIN} csghub"
    "${IP_ADDRESS} casdoor.${DOMAIN} casdoor"
    "${IP_ADDRESS} registry.${DOMAIN} registry"
    "${IP_ADDRESS} minio.${DOMAIN} minio"
    "${IP_ADDRESS} temporal.${DOMAIN} temporal"
    "${IP_ADDRESS} starship.${DOMAIN} starship"
    "${IP_ADDRESS} starship-api.${DOMAIN} starship-api"
  )

  for ENTRY in "${HOST_ENTRIES[@]}"; do
    if ! grep -qF "$ENTRY" /etc/hosts; then
      echo "$ENTRY" >> /etc/hosts
    fi
  done
fi

####################################################################################
# Configuring Private Container Registry for K3S
####################################################################################
if [ "$ENABLE_K3S" == "true" ]; then
  log "INFO" "Configure insecure private container registry."

  SECRET_JSON=$(kubectl -n spaces get secret csghub-docker-credential -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d)
  REGISTRY=$(echo "$SECRET_JSON" | jq -r '.auths | keys[]')
  REGISTRY_USERNAME=$(echo "$SECRET_JSON" | jq -r '.auths | to_entries[] | .value | .username')
  REGISTRY_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.auths | to_entries[] | .value | .password')

cat <<EOF > /etc/rancher/k3s/registries.yaml
mirrors:
  docker.io:
    endpoint:
      - "https://opencsg-registry.cn-beijing.cr.aliyuncs.com"
    rewrite:
      "^rancher/(.*)": "opencsg_public/rancher/\$1"
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

  restart_k3s_cluster
else
  log "INFO" "Please refer to https://github.com/containerd/containerd/blob/main/docs/hosts.md."
fi

log "INFO" "CSGHub is deployed and the login information is located at login.txt."
