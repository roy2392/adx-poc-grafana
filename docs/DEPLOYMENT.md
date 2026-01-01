# Deployment Guide

## Prerequisites

### Azure Requirements

1. **Azure Subscription** with the following permissions:
   - Contributor access to create resources
   - User Access Administrator (for RBAC assignments)
   - Application Administrator in Azure AD (for service principal creation)

2. **Resource Providers** - Ensure these are registered:
   ```bash
   az provider register --namespace Microsoft.Kusto
   az provider register --namespace Microsoft.ContainerInstance
   az provider register --namespace Microsoft.KeyVault
   az provider register --namespace Microsoft.Storage
   ```

3. **Quota** - Verify sufficient quota for:
   - ADX cluster VMs (D11_v2 or your chosen SKU)
   - Container Instances (1 vCPU, 1.5 GB RAM minimum)

### Local Requirements

- [Terraform](https://terraform.io/downloads) >= 1.5.0
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) >= 2.50.0
- [Git](https://git-scm.com/)
- (Optional) [kubectl](https://kubernetes.io/docs/tasks/tools/) for troubleshooting

---

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/adx-poc-dns.git
cd adx-poc-dns/terraform
```

### 2. Authenticate to Azure

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify
az account show
```

### 3. Configure Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Minimum required configuration:**

```hcl
# terraform.tfvars

resource_group_name    = "rg-adx-poc"
location               = "eastus"
grafana_admin_password = "YourSecurePassword123!"  # Change this!

# Optional: restrict access to your IP
allowed_ip_ranges = ["YOUR_PUBLIC_IP/32"]
```

### 4. Initialize Terraform

```bash
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### 5. Review the Plan

```bash
terraform plan
```

Review the resources that will be created:
- Resource group
- ADX cluster and database
- Storage account
- Key Vault
- Container Instance (Grafana)

### 6. Deploy

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes approximately **15-25 minutes** (ADX cluster provisioning is the longest step).

### 7. Access Grafana

After deployment completes, get the Grafana URL:

```bash
terraform output grafana_url
```

Open the URL in your browser and login:
- **Username**: `admin`
- **Password**: The value you set in `grafana_admin_password`

---

## Step-by-Step Deployment

### Step 1: Resource Group and Core Infrastructure

The deployment creates these resources first:
- Resource group
- Key Vault for secrets
- Storage account for data ingestion

### Step 2: ADX Cluster Provisioning

The ADX cluster is created with:
- Selected SKU (Dev/Test by default)
- System-assigned managed identity
- Streaming ingestion enabled

**Note**: This step takes 10-15 minutes.

### Step 3: ADX Database Setup

After the cluster is ready:
- Database is created with retention policies
- Schema script creates tables and functions
- Ingestion mappings are configured

### Step 4: Grafana Deployment

Container Instance is deployed with:
- ADX data source plugin pre-installed
- Service principal for ADX authentication
- Persistent storage for dashboards

### Step 5: Access Configuration

Final steps include:
- RBAC assignments for Grafana → ADX access
- Network security rules (if private networking enabled)

---

## Post-Deployment Steps

### 1. Configure Grafana Data Source

The ADX plugin is installed but needs manual configuration on first use:

1. Login to Grafana
2. Go to **Configuration** → **Data Sources**
3. Click **Add data source**
4. Select **Azure Data Explorer Datasource**
5. Configure:
   - **Cluster URL**: `https://adxpoc{suffix}.{region}.kusto.windows.net`
   - **Authentication**: App Registration
   - **Tenant ID**: (shown in Terraform output)
   - **Client ID**: (shown in Terraform output)
   - **Client Secret**: (stored in Key Vault)
6. Click **Save & Test**

### 2. Import Dashboard

1. Go to **Dashboards** → **Import**
2. Upload `dashboards/adx-overview.json` from this repository
3. Select the ADX data source
4. Click **Import**

### 3. Ingest Sample Data

```bash
# Run the sample data script
./scripts/deploy.sh ingest-sample-data
```

Or manually using Azure CLI:

```bash
# Upload sample data to storage
az storage blob upload \
  --account-name $(terraform output -raw storage_account_name) \
  --container-name raw-data \
  --name iot-sensors.json \
  --file ../sample-data/iot-sensors.json

# Trigger ingestion in ADX
az kusto data-connection create \
  --cluster-name $(terraform output -raw adx_cluster_name) \
  --database-name $(terraform output -raw adx_database_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --name storage-connection \
  --kind EventGrid \
  --storage-account-resource-id $(az storage account show -n $(terraform output -raw storage_account_name) --query id -o tsv) \
  --blob-storage-event-type Microsoft.Storage.BlobCreated
```

---

## Deployment Options

### Option A: Public Access (Default)

Suitable for POC and development:
- ADX: Public endpoint with optional IP restrictions
- Grafana: Public IP with authentication

```hcl
enable_private_network = false
allowed_ip_ranges      = ["YOUR_IP/32"]  # Optional
```

### Option B: Private Network

For production or sensitive data:
- ADX: Private endpoint only
- Grafana: Private IP, access via VPN/Bastion

```hcl
enable_private_network = true
```

Additional requirements:
- Azure VPN or ExpressRoute for access
- Or deploy Azure Bastion for browser access

### Option C: Hybrid

ADX private, Grafana public (with Azure AD auth):

```hcl
enable_private_network = true
grafana_public_access  = true
enable_azure_ad_auth   = true
```

---

## Validation

### Verify ADX Cluster

```bash
# Check cluster status
az kusto cluster show \
  --name $(terraform output -raw adx_cluster_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --query "state" -o tsv

# Expected: Running
```

### Verify Database

```bash
# List databases
az kusto database list \
  --cluster-name $(terraform output -raw adx_cluster_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --query "[].name" -o tsv
```

### Verify Grafana

```bash
# Check container status
az container show \
  --name grafana-adx-poc \
  --resource-group $(terraform output -raw resource_group_name) \
  --query "instanceView.state" -o tsv

# Expected: Running

# View logs
az container logs \
  --name grafana-adx-poc \
  --resource-group $(terraform output -raw resource_group_name)
```

### Test ADX Query

```bash
# Run a test query
az kusto query \
  --cluster $(terraform output -raw adx_cluster_uri) \
  --database $(terraform output -raw adx_database_name) \
  --query "print 'Hello from ADX!'"
```

---

## Cleanup

To remove all resources:

```bash
terraform destroy
```

**Warning**: This will delete all data in ADX. Export important data first:

```kql
.export to csv (
    h@"https://storageaccount.blob.core.windows.net/backup;SECRET_KEY"
) <| IoTSensors
```

---

## Troubleshooting

### ADX Cluster Stuck in "Creating"

Wait up to 30 minutes. If still stuck:
```bash
az kusto cluster show --name CLUSTER_NAME --resource-group RG_NAME
```

Check for errors in the response.

### Grafana Container Failing

Check logs:
```bash
az container logs --name grafana-adx-poc --resource-group RG_NAME
```

Common issues:
- Invalid admin password (must meet complexity requirements)
- Network connectivity to ADX blocked

### Cannot Connect to ADX from Grafana

1. Verify service principal has database access:
   ```bash
   az kusto database-principal-assignment list \
     --cluster-name CLUSTER_NAME \
     --database-name DATABASE_NAME \
     --resource-group RG_NAME
   ```

2. Check if ADX firewall allows Grafana:
   ```bash
   az kusto cluster show --name CLUSTER_NAME --resource-group RG_NAME \
     --query "trustedExternalTenants"
   ```

### Terraform State Issues

If state becomes corrupted:
```bash
# Refresh state
terraform refresh

# Or import existing resources
terraform import azurerm_resource_group.main /subscriptions/SUB_ID/resourceGroups/RG_NAME
```

---

## Support

For issues:
1. Check the [Troubleshooting Guide](./TROUBLESHOOTING.md)
2. Review Azure service health: https://status.azure.com
3. Open an issue in this repository
