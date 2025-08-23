# Apigee Hybrid Terraform

This repository contains Terraform configurations for deploying and managing Apigee Hybrid. The project supports deployment on multiple Kubernetes platforms including Google Kubernetes Engine (GKE), Azure Kubernetes Service (AKS), Elastic Kubernetes Service (EKS), and other supported Kubernetes platforms. This setup is ideal for creating an evaluation Apigee instance to test features and functionality.

## Project Structure

```
├── apigee-hybrid-core/    # Core Apigee Hybrid infrastructure components
├── apigee-on-aks/         # AKS-specific deployment configurations
├── apigee-on-gke/         # GKE-specific deployment configurations
├── apigee-on-eks/         # EKS-specific deployment configurations
├── apigee-on-others/      # Install Apigee on other Kubernetes Provider/
```

## Prerequisites

### Required Tools
- Terraform >= 1.0.0
- Google Cloud SDK (gcloud CLI) >= 400.0.0
- kubectl >= 1.24.0
- Helm >= 3.15.0

### GCP Project Setup
- A GCP project with billing enabled
- Appropriate IAM permissions (Owner/Editor role)
- Required APIs enabled (handled automatically by Terraform):
  - Compute Engine API
  - Container (GKE) API
  - Cloud Resource Manager API
  - Apigee API
  - Apigee Connect API
  - Cloud KMS API
  - Service Networking API
  - Cloud Monitoring API
  - Cloud Logging API
  - Cloud Storage API
  - Cloud SQL Admin API

### Organization Policies
The following organization policies should use Google's default settings:
- `disableServiceAccountKeyCreation`
- `requireOsLogin`
- `requireShieldedVm`
- `vmExternalIpAccess`

To apply these policies, run:
```bash
./apply_org_policies.sh
```

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/your-username/apigee-hybrid-terraform.git
   cd apigee-hybrid-terraform
   ```

2. Choose your deployment target:
   - For GKE deployment: Navigate to `apigee-on-gke/`
   - For AKS deployment: Navigate to `apigee-on-aks/`
   - For EKS deployment: Navigate to `apigee-on-eks/`
   - For other Kubernetes Provider deployment: Navigate to `apigee-on-others/`

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Configure your variables:
   - Edit `terraform.tfvars` with required values. You can refer `terraform.tfvars.sample`
   - Update the variables with your specific values

5. Apply the configuration:
   ```bash
   terraform plan
   terraform apply
   ```

6. Verify the deployment:
   ```bash
   kubectl get pods -n apigee
   ```

## Components

### Core Infrastructure (`apigee-hybrid-core/`)

The core module provides the fundamental infrastructure components required for Apigee Hybrid, including:
- IAM configurations
- Service accounts
- Core GCP resources

### GKE Deployment ([`apigee-on-gke/`](apigee-on-gke/))

Specific configurations for deploying Apigee Hybrid on Google Kubernetes Engine, including:
- GKE cluster configuration
- Apigee runtime components
- Network configurations
- Load balancer setup

### AKS Deployment ([`apigee-on-aks/`](apigee-on-aks/))

Configurations for deploying Apigee Hybrid on Azure Kubernetes Service, including:
- AKS cluster setup
- Network configurations
- Load balancer setup
- Apigee Runtime Installation


### EKS Deployment ([`apigee-on-eks/`](apigee-on-eks/))

Configurations for deploying Apigee Hybrid on AWS Kubernetes Service, including:
- EKS cluster setup
- Network configurations
- Load balancer setup
- Apigee Runtime Installation

### Other K8s Deployment ([`apigee-on-others/`](apigee-on-others/))

Configurations for deploying Apigee Hybrid on other Kubernetes Service, including:

- Apigee Runtime Installation

## Maintenance

### Upgrading

1. Review the release notes for the target version
2. Update the Apigee runtime version in your configuration
3. Apply the changes using Terraform:
   ```bash
   terraform plan
   terraform apply
   ```
4. Verify the upgrade:
   ```bash
   kubectl get pods -n apigee
   ```

### Backup and Recovery

- Regular backups of the Apigee runtime data
- Terraform state backup
- Configuration version control
- Disaster recovery procedures

### Health Checks

Regular health checks should be performed:
```bash
kubectl get pods -n apigee
kubectl get services -n apigee
kubectl describe pods -n apigee
```

## Known Issues and Solutions

### Terraform Provider Warnings

1. **Deprecated `local_file` Resource**
   ```
   Warning: Attribute Deprecated
   Use the `local_sensitive_file` resource instead
   ```
   - **Solution**: Update the code to use `local_sensitive_file` instead of `local_file` for sensitive content
   - **Location**: `apigee-hybrid-core/main.tf`

2. **Deprecated `inline_policy` in AWS IAM Role**
   ```
   Warning: Argument is deprecated
   inline_policy is deprecated. Use the aws_iam_role_policy resource instead
   ```
   - **Solution**: Replace `inline_policy` with separate `aws_iam_role_policy` resources
   - **Location**: EKS module configuration

### Provider Inconsistencies

1. **Google Service Account Inconsistency**
   ```
   Error: Provider produced inconsistent result after apply
   When applying changes to module.apigee_hybrid.google_service_account.apigee_non_prod_sa
   ```
   - **Solution**: 
     1. Remove the service account from GCP Project
     2. Reapply the terraform configuration 'terraform apply'

### Common Issues

1. **Cluster Creation Fails**
   - Check IAM permissions
   - Verify quota availability
   - Review network configurations
   - Check resource limits

2. **Apigee Runtime Issues**
   - Check pod status: `kubectl get pods -n apigee`
   - Review logs: `kubectl logs -n apigee`
   - Verify connectivity to Apigee control plane
   - Check resource constraints

3. **Network Connectivity Issues**
   - Verify VPC configurations
   - Check firewall rules
   - Validate DNS settings
   - Review load balancer configuration

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

### Development Guidelines
- Follow Terraform best practices
- Include documentation for new features
- Add tests for new functionality
- Update version numbers appropriately

## License

This project is licensed under the terms of the license included in the repository.

## Support

For issues and feature requests, please create an issue in the GitHub repository.

### Getting Help
- Check the [FAQ](docs/FAQ.md)
- Review the [troubleshooting guide](docs/TROUBLESHOOTING.md)
- Join the community Slack channel
- Contact the maintainers

## Additional Resources

- [Apigee Hybrid Documentation](https://cloud.google.com/apigee/docs/hybrid)
- [Terraform Documentation](https://www.terraform.io/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [AKS Documentation](https://docs.microsoft.com/azure/aks)
- [EKS Documentation](https://docs.aws.amazon.com/eks)
- [Kubernetes Documentation](https://kubernetes.io/docs)
- [Helm Documentation](https://helm.sh/docs)
