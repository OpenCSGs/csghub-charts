# CSGHub Edition Configuration Guide

This guide explains how to configure CSGHub to deploy either the Community Edition (CE) or Enterprise Edition (EE) using the Helm chart.

## Overview

CSGHub supports two editions:
- **Community Edition (CE)**: Basic features without Starship components
- **Enterprise Edition (EE)**: Full feature set including Starship components

## Configuration

### Global Edition Setting

The edition is controlled by the `global.edition` parameter in your values.yaml file:

```yaml
global:
  edition: "ee"  # or "ce"
```

### Default Behavior

- **Default**: If not specified, the system defaults to "ee" (Enterprise Edition)
- **Image Tags**: The system automatically appends the edition suffix to image tags
- **Starship**: Automatically disabled for EE

## Usage Examples

### Deploy Community Edition

```bash
# Using --set flag
helm install csghub ./charts/csghub --set global.edition=ce

# Using custom values file
cat > values-ce.yaml << EOF
global:
  edition: "ce"
  image:
    registry: "your-registry.com"
    tag: "v1.8.0"  # Will become v1.8.0-ce automatically
EOF

helm install csghub ./charts/csghub -f values-ce.yaml
```

### Deploy Enterprise Edition

```bash
# Using --set flag (default behavior)
helm install csghub ./charts/csghub --set global.edition=ee

# Using custom values file
cat > values-ee.yaml << EOF
global:
  edition: "ee"
  image:
    registry: "your-registry.com"
    tag: "v1.8.0"  # Will become v1.8.0-ee automatically
EOF

helm install csghub ./charts/csghub -f values-ee.yaml
```

## Component Differences

### Components Available in Both Editions
- Server
- Portal
- Mirror
- Dataviewer
- AIGateway
- Accounting
- Notification
- Runner
- User
- Moderation
- PostgreSQL
- Redis
- Minio
- Gitaly
- Casdoor
- Temporal
- NATS

### Components Only in Enterprise Edition
- Starship (including all sub-components):
  - Web
  - Frontend
  - Billing
  - Agentic
  - Celery Worker
  - MegaLinter Server
  - MegaLinter Worker
  - Security Scanner

**Note**: Starship components will only be deployed when both `global.edition=ee` AND `starship.enabled=true`.

## Image Tag Behavior

The system automatically handles image tag suffixes:

1. **Base Tag**: Specify the base version without suffix
   ```yaml
   global:
     image:
       tag: "v1.8.0"
   ```

2. **Automatic Suffix**: The system adds the edition suffix
   - CE: `v1.8.0-ce`
   - EE: `v1.8.0-ee`

3. **Pre-suffixed Tags**: If your tag already contains a suffix, it won't be modified
   ```yaml
   global:
     image:
       tag: "v1.8.0-ee"  # Will remain as-is
   ```

## Starship Configuration

### Enablement Requirements
Starship will only be deployed when **BOTH** conditions are met:
1. `global.edition` is set to "ee" (Enterprise Edition)
2. `starship.enabled` is explicitly set to `true`

### Configuration Examples

#### Enable Starship in EE
```yaml
global:
  edition: "ee"

starship:
  enabled: true  # Explicitly enable Starship
```

#### Disable Starship in EE
```yaml
global:
  edition: "ee"

starship:
  enabled: false  # Starship will not be deployed
```

#### CE Edition (Starship Never Available)
```yaml
global:
  edition: "ce"

starship:
  enabled: true  # This will be ignored - Starship never deploys in CE
```

## Migration Between Editions

### From CE to EE
1. Update your values file:
   ```yaml
   global:
     edition: "ee"
   ```
2. Upgrade the deployment:
   ```bash
   helm upgrade csghub ./charts/csghub -f your-values.yaml
   ```

### From EE to CE
1. Update your values file:
   ```yaml
   global:
     edition: "ce"
   ```
2. Upgrade the deployment:
   ```bash
   helm upgrade csghub ./charts/csghub -f your-values.yaml
   ```

**Note**: When downgrading from EE to CE, Starship components will be removed.

## Troubleshooting

### Image Pull Errors
If you encounter image pull errors, verify:
1. The correct edition images exist in your registry
2. The image tags are properly formatted with edition suffixes
3. Your registry credentials are correctly configured

### Starship Not Starting
If Starship components don't start in EE:
1. Check that `global.edition` is set to "ee"
2. Verify Starship is not manually disabled
3. Check resource availability for additional components

## Example Configurations

The `examples/` directory contains sample values files for different deployment scenarios:

- `values-ce.yaml`: Community Edition deployment
- `values-ee.yaml`: Enterprise Edition with Starship enabled
- `values-ee-no-starship.yaml`: Enterprise Edition with Starship disabled

