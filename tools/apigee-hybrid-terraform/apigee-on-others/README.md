# Apigee Hybrid on Existing Kubernetes Clusters

This directory contains Terraform configurations for deploying Apigee Hybrid on an existing Kubernetes cluster. This setup assumes that you already have a Kubernetes cluster running and properly configured with the necessary node pools for Apigee Hybrid.

## Prerequisites

1. **Existing Kubernetes Cluster**:
   - A running Kubernetes cluster (version 1.29 or later)
   - At least two node pools:
     - Runtime node pool for Apigee runtime components with node labels set with key cloud.google.com/gke-nodepool and value apigee-runtime
     - Data node pool for Apigee data with node labels set with key cloud.google.com/gke-nodepool and value apigee-data
   - Proper network configuration for the cluster

2. **Kubernetes Access**:
   - `kubectl` configured to access your cluster
   - `KUBECONFIG` environment variable set or config file in `~/.kube/config`
   - Proper RBAC permissions in the cluster

3. **Google Cloud Setup**:
   - Google Cloud SDK installed and configured
   - Optional: Project with Apigee API enabled. The script enables it.
   - Optional: Service account with necessary permissions. The script automatically creates it.
   - Organization Policy allowing service account key creation

4. **Configure Google Cloud Authentication**:
   There are two ways to authenticate with Google Cloud:

   a) **User Account Authentication**:
   * Ensure you have the Google Cloud SDK (gcloud) installed and configured
   * Run `gcloud auth application-default login` to authenticate
   * Set your project: `gcloud config set project <your-project-id>`

   b) **Service Account Authentication**:
   * Create a service account with appropriate permissions (Owner/Editor)
   * Download the service account key JSON file
   * Set the environment variable: `export GOOGLE_APPLICATION_CREDENTIALS="path/to/your/service-account-key.json"`
   * Run `gcloud auth activate-service-account --key-file="path/to/your/service-account-key.json"`
   * Set your project: `gcloud config set project <your-project-id>`
   * Alternatively, you can specify the credentials file path in your Terraform provider configuration:
     ```hcl
     provider "google" {
       credentials = file("path/to/your/service-account-key.json")
       project     = "<your-project-id>"
     }
     ```

   Note: 
   * Ensure that Organization Policy is not disabled to create service account and associated Service Account Key
   * Ensure that the user or service account performing terraform has the permissions to access Google Cloud resources. While not recommended but roles like `roles/editor` or `roles/owner` should ensure all tasks completes successfully

5. **Required Tools**:
   - Terraform >= 1.0.0
   - Helm >= 3.10.0
   - kubectl
   - gcloud CLI

## Configuration

1. **Set up your variables**:
   Update `terraform.tfvars` file with your specific values:

   ```hcl
   project_id = "apigee-gke-example3"
   region     = "us-central1"        # Default region, change if needed
   apigee_org_name          = "apigee-gke-example3"
   apigee_env_name          = "dev"
   apigee_envgroup_name     = "dev-group"
   cluster_name             = "apigee"
   apigee_namespace         = "apigee"
   apigee_version           = "1.14.2-hotfix.1"
   apigee_org_display_name  = "My Company Apigee Organization"
   apigee_env_display_name  = "Development Environment"
   apigee_instance_name     = "apigee-instance"
   apigee_cassandra_replica_count = 1

   hostnames = [
   "api.mycompany.com",           # Production API endpoint
   "api-dev.mycompany.com"        # Development API endpoint
   ]
   ingress_name = "apigee-ingress"

   ```

2. **Verify Kubernetes Access**:
   ```bash
   kubectl get nodes
   ```

3. **Verify Node Pools**:
   ```bash
   kubectl get nodes --show-labels
   ```
   Ensure you have nodes with the appropriate labels for Apigee runtime and data components.

## Deployment

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Review the Plan**:
   ```bash
   terraform plan
   ```

3. **Apply the Configuration**:
   ```bash
   terraform apply
   ```

## What Gets Deployed

1. **Apigee Organization**:
   - Creates or uses existing Apigee organization
   - Sets up environment and environment group
   - Configures runtime settings

2. **Kubernetes Resources**:
   - Creates necessary namespaces
   - Deploys Apigee runtime components
   - Configures service accounts and RBAC
   - Sets up ingress and load balancing

3. **SSL/TLS Configuration**:
   - Generates or uses provided SSL certificates
   - Configures TLS for the runtime

## Verification

1. **Check Apigee Components**:
   ```bash
   kubectl get pods -n apigee
   ```

2. **Verify Environment Group**:
   ```bash
   gcloud apigee envgroups list --organization=$PROJECT_ID
   ```

3. **Verify Apigee Endpoint**:

* Get the ingress IP/DNS to access Apigee
```bash
kubectl get pods -n apigee
kubectl get svc dev-group -n apigee -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```
* Add the ingress IP/DNS to Apigee Environment Group Hostnames through Apigee UI

* Access the healthz endpoint
```bash
curl -H 'User-Agent: GoogleHC' https://api.example.com/healthz/ingress -k \
  --resolve "api.example.com:443:your-ingress-ip>"
```
   
## Cleanup

1. **Remove Apigee Components**:
   ```bash
   helm uninstall apigee-hybrid -n apigee
   ```

2. **Destroy Terraform Resources**:
   ```bash
   terraform destroy
   ```

3. **Clean Up Local Files**:
   ```bash
   rm -rf output/${PROJECT_ID}/
   ```

## Troubleshooting

1. **Kubernetes Connection Issues**:
   - Verify `kubectl` configuration
   - Check cluster accessibility
   - Ensure proper RBAC permissions

2. **Apigee Deployment Issues**:
   - Check pod status and logs
   - Verify node pool labels
   - Review Apigee runtime logs

3. **SSL/TLS Issues**:
   - Verify certificate validity
   - Check ingress configuration
   - Review TLS settings

## Additional Resources

- [Apigee Hybrid Documentation](https://cloud.google.com/apigee/docs/hybrid)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Helm Documentation](https://helm.sh/docs/) 