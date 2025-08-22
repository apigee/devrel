
## Apigee Hybrid Setup Script

The `setup_apigee.sh` script automates the installation and configuration of Apigee Hybrid. It handles the deployment of all necessary components including the operator, datastore, telemetry, and ingress configurations.

### Prerequisites

Before running the script, ensure you have:

1. Access to a running Kubernetes cluster
2. Required files:
   - `overrides.yaml`: Apigee configuration overrides
   - `service.yaml`: Service template configuration
   - Service account key JSON file
   - TLS certificate and private key for environment group
3. Required tools:
   - `kubectl` configured to access your Kubernetes cluster
   - `helm` (version 3.10+)
   - `gcloud` CLI configured with appropriate permissions

### Script Parameters

The script accepts the following parameters:

| Parameter | Short | Required | Default | Description |
|-----------|-------|----------|---------|-------------|
| `--version` | `-v` | No | 1.14.2-hotfix.1 | Apigee version to install |
| `--namespace` | `-n` | No | apigee | Kubernetes namespace for Apigee components |
| `--kubeconfig` | `-f` | No | - | Kubernetes Config File |
| `--sa_email` | `-a` | Yes | - | Service Account email |
| `--overrides` | `-o` | Yes | - | Path to overrides.yaml file |
| `--service` | `-s` | Yes | - | Path to service template file |
| `--key` | `-k` | Yes | - | Path to service account key JSON file |
| `--cert` | `-c` | Yes | - | Path to environment group certificate file |
| `--private-key` | `-p` | Yes | - | Path to environment group private key file |
| `--help` | `-h` | No | - | Display help message |

### Sample Usage


1. **Custom Version and Namespace**:
   ```bash
   ./setup_apigee.sh \
     --version "1.14.2-hotfix.1" \
     --namespace "apigee-prod" \
     --kubeconfig "/path/to/kubeconfig" \
     --sa_email "apigee-svc-tf@project.gserviceaccount.com" \
     --overrides "/path/to/overrides.yaml" \
     --service "/path/to/service.yaml" \
     --key "/path/to/sa-key.json" \
     --cert "/path/to/cert.pem" \
     --private-key "/path/to/key.pem"
   ```

2. **Using Short Options**:
   ```bash
   ./setup_apigee.sh \
     -v "1.14.2-hotfix.1" \
     -n "apigee" \
     -f "/path/to/kubeconfig" \
     -a "apigee-svc-tf@project.gserviceaccount.com" \
     -o "/path/to/overrides.yaml" \
     -s "/path/to/service.yaml" \
     -k "/path/to/sa-key.json" \
     -c "/path/to/cert.pem" \
     -p "/path/to/key.pem"
   ```

### What the Script Does

1. **Setup Phase**:
   - Creates necessary directories
   - Pulls required Helm charts
   - Copies configuration files to appropriate locations

2. **Installation Phase**:
   - Creates Kubernetes namespace
   - Enables control plane access
   - Installs CRDs
   - Installs cert-manager
   - Installs Apigee operator
   - Installs datastore
   - Installs telemetry
   - Installs Redis
   - Installs ingress manager
   - Installs organization
   - Installs environment
   - Installs environment group
   - Sets up ingress

### Troubleshooting

If you encounter issues:

1. **Check Prerequisites**:
   ```bash
   # Verify kubectl access
   kubectl cluster-info
   
   # Verify helm version
   helm version
   
   # Verify gcloud configuration
   gcloud config list
   ```

2. **Check Logs**:
   ```bash
   # Check operator logs
   kubectl logs -n apigee -l app=apigee-controller
   
   # Check datastore logs
   kubectl logs -n apigee -l app=apigee-datastore
   ```

3. **Verify Installation**:
   ```bash
   # Check all pods
   kubectl get pods -n apigee
   
   # Check services
   kubectl get services -n apigee
   ```