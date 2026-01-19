# CSGHub Helm Charts

This repository contains the Helm charts for deploying **CSGHub** components in Kubernetes clusters.

For detailed installation and configuration instructions, please refer to the official documentation:

- [Prerequisites](https://opencsg.com/docs/en/csghub/101/install/kubernetes/prerequisites)
- [Quick Start](https://opencsg.com/docs/en/csghub/101/install/kubernetes/quick_install)
- [Standard Deployment Guide](https://opencsg.com/docs/en/csghub/101/install/kubernetes/standard)

---

## Chart Components

| Chart       | Description |
|------------|-------------|
| **common** | Provides shared **Helm templates (tpl)** used by other charts. It does not deploy a service on its own. |
| **[csgship](https://opencsg.com/docs/en/csghub/101/install/kubernetes/csgship)** | Backend service for the IDE coding assistant **CodeSouler**, responsible for handling data shipping and task management. |
| **[dataflow](https://opencsg.com/docs/en/csghub/101/install/kubernetes/dataflow)** | A dataset processing chart, mainly for data preprocessing, cleaning, and transformation; integrates with **Label Studio** for labeling tasks. |
| **[runner](https://opencsg.com/docs/en/csghub/101/install/kubernetes/runner)** | Acts as a proxy deployed in the Kubernetes cluster, responsible for executing deployment tasks. |

---

## Key Updates

- The runner is now an agent, supporting both integrated and standalone deployments.
- Dataflow charts have been refactored to the latest version.

## Support

For issues related to upgrades, deployments, or data migration, please [create an issue](https://github.com/OpenCSGs/csghub-charts/issues) in this repository.

---

_The CSGHub Support Team_