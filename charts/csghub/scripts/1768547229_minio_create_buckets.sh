#!/bin/bash

# MinIO Bucket Creation Script
# Environment variables: MINIO_ROOT_USER, MINIO_ROOT_PASSWORD, MINIO_DEFAULT_BUCKETS

# Default configuration
DEFAULT_ENDPOINT="${MINIO_ENDPOINT:-http://csghub-minio:9000}"
DEFAULT_ACCESS_KEY="${MINIO_ROOT_USER:-minioadmin}"
DEFAULT_SECRET_KEY="${MINIO_ROOT_PASSWORD:-minioadmin}"
DEFAULT_REGION="${MINIO_DEFAULT_REGION:-us-east-1}"
DEFAULT_POLICY="${MINIO_DEFAULT_POLICY:-none}"

# Show help information
show_help() {
    cat << EOF
MinIO Bucket Creation Script

Environment Variables:
    MINIO_ENDPOINT        MinIO server address [default: http://csghub-minio:9000]
    MINIO_ROOT_USER       MinIO root user [default: minioadmin]
    MINIO_ROOT_PASSWORD   MinIO root password [default: minioadmin]
    MINIO_DEFAULT_BUCKETS Buckets to create, format: bucket1:region:policy,bucket2:region:policy
    MINIO_DEFAULT_REGION  Default region [default: us-east-1]
    MINIO_DEFAULT_POLICY  Default policy [default: none]

Bucket Format:
    bucket:region:policy    - Full format
    bucket:region           - Use default policy
    bucket                  - Use default region and policy

Policy Options:
    none             - Disable anonymous access to the ALIAS
    public           - Enable download and upload access to the ALIAS
    download         - Enable download-only access to the ALIAS
    upload           - Enable upload-only access to the ALIAS

Examples:
    export MINIO_DEFAULT_BUCKETS="data:us-east-1:public,logs:eu-west-1:private,backup:none"
    ./create-minio-buckets.sh

    # Or use directly
    MINIO_DEFAULT_BUCKETS="app-data:public,static-files:eu-central-1:readonly" ./create-minio-buckets.sh
EOF
}

# Parse bucket configuration string
parse_bucket_config() {
    local config="$1"
    local bucket_name=""
    local bucket_region=""
    local bucket_policy=""

    # Count colons to determine format
    local colon_count=$(echo "$config" | tr -cd ':' | wc -c)

    case $colon_count in
        0)
            # Format: bucket
            bucket_name="$config"
            bucket_region="$DEFAULT_REGION"
            bucket_policy="$DEFAULT_POLICY"
            ;;
        1)
            # Format: bucket:region or bucket:policy
            bucket_name=$(echo "$config" | cut -d':' -f1)
            local second_part=$(echo "$config" | cut -d':' -f2)

            # Determine if second part is region or policy
            if [[ "$second_part" =~ ^(none|private|public|download|readonly|writeonly|readwrite)$ ]]; then
                bucket_region="$DEFAULT_REGION"
                bucket_policy="$second_part"
            else
                bucket_region="$second_part"
                bucket_policy="$DEFAULT_POLICY"
            fi
            ;;
        2)
            # Format: bucket:region:policy
            bucket_name=$(echo "$config" | cut -d':' -f1)
            bucket_region=$(echo "$config" | cut -d':' -f2)
            bucket_policy=$(echo "$config" | cut -d':' -f3)
            ;;
        *)
            echo "Error: Invalid bucket configuration format: $config"
            return 1
            ;;
    esac

    # Validate bucket name (S3 naming rules)
    if ! [[ "$bucket_name" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]]; then
        echo "Error: Invalid bucket name: $bucket_name"
        return 1
    fi

    echo "${bucket_name}:${bucket_region}:${bucket_policy}"
}

# Check required tools
check_dependencies() {
    if ! command -v mc &> /dev/null; then
        echo "Error: mc command not found. Please install MinIO client first."
        echo "Installation: https://min.io/docs/minio/linux/reference/minio-mc.html"
        exit 1
    fi
}

# Configure MinIO client alias
configure_mc_alias() {
    local alias_name="minio_$(date +%s)"

    echo "Configuring MinIO connection: $ENDPOINT"

    if ! mc alias set "$alias_name" "$ENDPOINT" "$ACCESS_KEY" "$SECRET_KEY"; then
        echo "Error: Cannot connect to MinIO endpoint $ENDPOINT"
        exit 1
    fi

    echo "$alias_name"
}

# Create single bucket
create_single_bucket() {
    local alias_name="$1"
    local bucket_name="$2"
    local bucket_region="$3"
    local bucket_policy="$4"

    echo "Creating Bucket: $bucket_name (Region: $bucket_region, Policy: $bucket_policy)"

    # Check if bucket already exists and is accessible
    if mc ls "${alias_name}/${bucket_name}" > /dev/null 2>&1; then
        echo "  ⚠️  Bucket already exists, skipping creation"
    else
        # Attempt to create bucket and show debug info on failure
        if ! mc mb --region "$bucket_region" "${alias_name}/${bucket_name}" 2>&1; then
            echo "  ❌ Bucket creation failed for $bucket_name"
            return 1
        else
            echo "  ✓ Bucket created successfully"
        fi
    fi

    # After creation or if exists, verify bucket is accessible
    if ! mc ls "${alias_name}/${bucket_name}" > /dev/null 2>&1; then
        echo "  ❌ Bucket exists but is not accessible or cannot be listed: $bucket_name"
        return 1
    fi

    # Set policy
    if ! set_bucket_policy "$alias_name" "$bucket_name" "$bucket_policy"; then
        echo "  ❌ Failed to set bucket policy for $bucket_name"
        return 1
    fi

    # Enable versioning (optional, uncomment if needed)
    # mc version enable "${alias_name}/${bucket_name}" > /dev/null 2>&1 && echo "  ✓ Versioning enabled"

    return 0
}

# Set bucket policy
set_bucket_policy() {
    local alias_name="$1"
    local bucket_name="$2"
    local policy="$3"

    case "$policy" in
        download)
            if mc anonymous set download "${alias_name}/${bucket_name}"; then
                echo "  ✓ Set to download-only policy"
                return 0
            else
                echo "  ❌ Failed to set download-only policy"
                return 1
            fi
            ;;
        upload)
            if mc anonymous set upload "${alias_name}/${bucket_name}"; then
                echo "  ✓ Set to upload-only policy"
                return 0
            else
                echo "  ❌ Failed to set upload-only policy"
                return 1
            fi
            ;;
        public)
            if mc anonymous set public "${alias_name}/${bucket_name}"; then
                echo "  ✓ Set to public (download & upload) policy"
                return 0
            else
                echo "  ❌ Failed to set public policy"
                return 1
            fi
            ;;
        none)
            if mc anonymous set none "${alias_name}/${bucket_name}"; then
                echo "  ✓ Disabled anonymous access"
                return 0
            else
                echo "  ❌ Failed to disable anonymous access"
                return 1
            fi
            ;;
        *)
            echo "  ⚠️  Unknown policy: $policy, using 'none' as default"
            if mc anonymous set none "${alias_name}/${bucket_name}"; then
                return 0
            else
                echo "  ❌ Failed to set default 'none' policy"
                return 1
            fi
            ;;
    esac
}

# Cleanup MC alias
cleanup_alias() {
    # shellcheck disable=SC2317
    local alias_name="$1"
    # shellcheck disable=SC2317
    if [[ -n "$alias_name" ]]; then
        mc alias remove "$alias_name" > /dev/null 2>&1
    fi
}

# Main execution function
main() {
    # Use environment variables or defaults
    local ENDPOINT="${ENDPOINT:-$DEFAULT_ENDPOINT}"
    local ACCESS_KEY="${ACCESS_KEY:-$DEFAULT_ACCESS_KEY}"
    local SECRET_KEY="${SECRET_KEY:-$DEFAULT_SECRET_KEY}"

    # Display configuration info
    echo "=== MinIO Bucket Creation Script ==="
    echo "Endpoint: $ENDPOINT"
    echo "User: $ACCESS_KEY"
    echo "Default Region: $DEFAULT_REGION"
    echo "Default Policy: $DEFAULT_POLICY"
    echo "===================================="

    # Check dependencies
    check_dependencies

    # Check if there are buckets to create
    if [[ -z "$MINIO_DEFAULT_BUCKETS" ]]; then
        echo "Info: MINIO_DEFAULT_BUCKETS environment variable not set"
        show_help
        exit 0
    fi

    # Configure MC client
    local alias_name=$(configure_mc_alias | tail -1)

    # Set trap to ensure alias cleanup on exit
    trap 'cleanup_alias "$alias_name"' EXIT INT TERM

    # Parse and create buckets
    IFS=',' read -ra BUCKET_CONFIGS <<< "$MINIO_DEFAULT_BUCKETS"
    local success_count=0
    local failure_count=0
    local total_count=0

    for config in "${BUCKET_CONFIGS[@]}"; do
        config="${config#"${config%%[![:space:]]*}"}" # Trim left whitespace
        config="${config%"${config##*[![:space:]]}"}" # Trim right whitespace
        if [[ -z "$config" ]]; then
            continue
        fi

        ((total_count++))

        # Parse configuration
        local parsed_config=$(parse_bucket_config "$config")
        if [[ $? -ne 0 ]]; then
            echo "❌ Configuration parsing failed: $config"
            ((failure_count++))
            continue
        fi

        local bucket_name=$(echo "$parsed_config" | cut -d':' -f1)
        local bucket_region=$(echo "$parsed_config" | cut -d':' -f2)
        local bucket_policy=$(echo "$parsed_config" | cut -d':' -f3)

        # Create bucket
        if create_single_bucket "$alias_name" "$bucket_name" "$bucket_region" "$bucket_policy"; then
            ((success_count++))
        else
            echo "❌ Failed to create or access bucket: $bucket_name"
            ((failure_count++))
        fi

        echo ""  # Empty line separator
    done

    # Output summary
    echo "=== Execution Completed ==="
    echo "Success: $success_count/$total_count"
    echo "Failures: $failure_count"

    if [[ $failure_count -eq 0 ]]; then
        echo "✓ All buckets created and accessible successfully"
        exit 0
    else
        echo "⚠️  Some buckets failed to create or are inaccessible"
        exit 1
    fi
}

# Support command line help
case "${1:-}" in
    -h|--help|help)
        show_help
        exit 0
        ;;
    *)
        main
        ;;
esac