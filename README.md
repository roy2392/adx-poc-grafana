# Azure Data Explorer POC with Grafana

A production-ready POC demonstrating Azure Data Explorer (ADX) analytics with Grafana visualization. Deploy to your Azure subscription with a single command.

## Features

- **Azure Data Explorer** cluster with pre-configured database and sample schema
- **Grafana** with ADX plugin and out-of-the-box dashboards
- **Infrastructure as Code** using Terraform
- **Sample Data Pipeline** for immediate demos
- **Security Best Practices** with managed identities and Key Vault

## Quick Start

### Prerequisites

- Azure subscription with Contributor access
- [Terraform](https://terraform.io/downloads) >= 1.5.0
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) >= 2.50.0

### Deploy

```bash
# Clone repository
git clone https://github.com/your-org/adx-poc-dns.git
cd adx-poc-dns

# Use the helper script
./scripts/deploy.sh check   # Verify prerequisites
./scripts/deploy.sh init    # Initialize Terraform
./scripts/deploy.sh apply   # Deploy infrastructure
./scripts/deploy.sh ingest  # Load sample data
```

Or manually:

```bash
cd terraform

# Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
terraform init
terraform apply
```

Deployment takes ~15-20 minutes. When complete:

```bash
# Get Grafana URL
terraform output grafana_url

# Login with admin / your-configured-password
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Azure Subscription                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐         ┌─────────────────┐            │
│  │  Azure Data     │◄────────│    Grafana      │            │
│  │  Explorer       │         │    (ACI)        │            │
│  │  Cluster        │         └─────────────────┘            │
│  └────────┬────────┘                                        │
│           │                                                  │
│  ┌────────▼────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  ADX Database   │  │   Storage    │  │  Key Vault   │   │
│  │  - IoTSensors   │  │   Account    │  │  (Secrets)   │   │
│  │  - AppLogs      │  └──────────────┘  └──────────────┘   │
│  │  - Metrics      │                                        │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
adx-poc-dns/
├── README.md                    # This file
├── dashboards/                  # Grafana dashboard JSON files
│   └── adx-overview.json
├── docs/                        # Documentation
│   ├── PLAN.md                  # Implementation plan
│   ├── ARCHITECTURE.md          # Detailed architecture
│   ├── DEPLOYMENT.md            # Step-by-step deployment guide
│   └── TERRAFORM.md             # Terraform reference
├── sample-data/                 # Sample data for demos
│   ├── iot-sensors.json
│   └── app-logs.json
├── scripts/                     # Helper scripts
│   ├── deploy.sh                # Deployment automation
│   └── generate-sample-data.py  # Generate more sample data
└── terraform/                   # Infrastructure as Code
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── providers.tf
    ├── versions.tf
    ├── terraform.tfvars.example
    └── modules/
        ├── adx/                 # ADX cluster & database
        ├── grafana/             # Grafana container
        └── networking/          # VNet (optional)
```

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `resource_group_name` | Resource group name | `rg-adx-poc` |
| `location` | Azure region | `eastus` |
| `adx_sku_name` | ADX cluster SKU | `Dev(No SLA)_Standard_D11_v2` |
| `grafana_admin_password` | Grafana admin password | (required) |
| `enable_private_network` | Use private endpoints | `false` |

See [terraform.tfvars.example](terraform/terraform.tfvars.example) for all options.

## Cost Estimate

| Resource | Monthly Cost (Est.) |
|----------|---------------------|
| ADX Cluster (Dev SKU) | ~$150 |
| Container Instance | ~$30 |
| Storage & Key Vault | ~$6 |
| **Total** | **~$186** |

## Documentation

| Document | Description |
|----------|-------------|
| [Implementation Plan](docs/PLAN.md) | High-level plan, phases, and milestones |
| [Architecture](docs/ARCHITECTURE.md) | Detailed component architecture |
| [Deployment Guide](docs/DEPLOYMENT.md) | Step-by-step deployment instructions |
| [Terraform Reference](docs/TERRAFORM.md) | Terraform modules and configuration |

## Sample Dashboards

After deployment, import the pre-built Grafana dashboard:

1. Open Grafana (`terraform output grafana_url`)
2. Go to **Dashboards** > **Import**
3. Upload `dashboards/adx-overview.json`
4. Select your ADX data source

Dashboard features:
- **Total Sensor Readings** - Count of IoT data points
- **Active Devices** - Number of unique sensors
- **Error Rate** - Application error percentage
- **Temperature Charts** - Real-time sensor visualization
- **Log Analysis** - Log volume by level

## Cleanup

```bash
# Using helper script
./scripts/deploy.sh destroy

# Or manually
cd terraform
terraform destroy
```

## License

MIT
