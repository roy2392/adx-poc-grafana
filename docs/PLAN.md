# Azure Data Explorer POC - Implementation Plan

## Overview

This repository provides a production-ready POC for Azure Data Explorer (ADX) with Grafana visualization. Clients can deploy the entire stack to their Azure subscription using Terraform with minimal configuration.

## Goals

1. **One-Click Deployment** - Clients deploy with `terraform apply`
2. **Out-of-the-Box Dashboard** - Pre-configured Grafana dashboards for ADX data
3. **Sample Data Pipeline** - Demo data ingestion to showcase ADX capabilities
4. **Security Best Practices** - Managed identities, private endpoints (optional)
5. **Cost Optimization** - Dev/Test SKU options for POC environments

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Subscription                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │  Azure Data      │    │  Azure Container │                   │
│  │  Explorer (ADX)  │◄───│  Instance        │                   │
│  │  Cluster         │    │  (Grafana)       │                   │
│  └────────┬─────────┘    └──────────────────┘                   │
│           │                       ▲                              │
│           │                       │                              │
│  ┌────────▼─────────┐            │                              │
│  │  ADX Database    │            │                              │
│  │  - Sample Tables │────────────┘                              │
│  │  - Functions     │   (ADX Data Source)                       │
│  └──────────────────┘                                           │
│                                                                  │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │  Storage Account │    │  Key Vault       │                   │
│  │  (Data Ingestion)│    │  (Secrets)       │                   │
│  └──────────────────┘    └──────────────────┘                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Azure Data Explorer Cluster
- **SKU**: Dev/Test (D11_v2) for POC, Standard for production
- **Database**: Pre-configured with sample schema
- **Tables**: Time-series demo data (IoT sensors, logs, metrics)
- **Functions**: Common KQL queries as stored functions

### 2. Grafana (Azure Container Instance)
- **Image**: Official Grafana OSS
- **Data Source**: ADX plugin pre-configured
- **Dashboards**: JSON provisioned dashboards
- **Authentication**: Azure AD integration (optional)

### 3. Supporting Infrastructure
- **Storage Account**: For data ingestion demos
- **Key Vault**: Store ADX connection strings and Grafana secrets
- **Virtual Network**: Optional private networking
- **Log Analytics**: Monitoring and diagnostics

---

## Project Structure

```
adx-poc-dns/
├── PLAN.md                    # This file
├── README.md                  # Quick start guide
├── docs/
│   ├── ARCHITECTURE.md        # Detailed architecture
│   ├── DEPLOYMENT.md          # Step-by-step deployment
│   ├── CONFIGURATION.md       # Configuration options
│   └── TROUBLESHOOTING.md     # Common issues
├── terraform/
│   ├── main.tf                # Root module
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   ├── providers.tf           # Provider configuration
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── adx/               # ADX cluster & database
│       ├── grafana/           # Grafana container
│       └── networking/        # VNet, subnets (optional)
├── dashboards/
│   └── adx-overview.json      # Grafana dashboard definitions
├── scripts/
│   ├── setup-sample-data.kql  # KQL scripts for sample data
│   ├── deploy.sh              # Deployment helper script
│   └── cleanup.sh             # Resource cleanup
└── sample-data/
    └── iot-sensors.csv        # Sample data files
```

---

## Implementation Phases

### Phase 1: Core Infrastructure (Terraform)
- [ ] ADX cluster module
- [ ] ADX database with sample schema
- [ ] Storage account for ingestion
- [ ] Key Vault for secrets

### Phase 2: Grafana Deployment
- [ ] Azure Container Instance for Grafana
- [ ] ADX data source configuration
- [ ] Dashboard provisioning
- [ ] Managed identity for ADX access

### Phase 3: Sample Data & Dashboards
- [ ] Create sample tables (IoT, logs, metrics)
- [ ] Ingest demo data
- [ ] Build overview dashboard
- [ ] Build drill-down dashboards

### Phase 4: Documentation & Polish
- [ ] README with quick start
- [ ] Architecture documentation
- [ ] Deployment guide
- [ ] Configuration reference
- [ ] Troubleshooting guide

---

## Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `resource_group_name` | Name of the resource group | `rg-adx-poc` |
| `location` | Azure region | `eastus` |
| `adx_cluster_name` | ADX cluster name | `adxpoc{random}` |
| `adx_sku` | ADX SKU | `Dev(No SLA)_Standard_D11_v2` |
| `grafana_admin_password` | Grafana admin password | (required) |
| `enable_private_network` | Use private endpoints | `false` |
| `tags` | Resource tags | `{}` |

---

## Deployment Steps (Summary)

1. Clone repository
2. Copy `terraform.tfvars.example` to `terraform.tfvars`
3. Configure required variables
4. Run `terraform init && terraform apply`
5. Access Grafana URL from outputs
6. Explore pre-built dashboards

---

## Cost Estimate (POC)

| Resource | SKU | Est. Monthly Cost |
|----------|-----|-------------------|
| ADX Cluster | Dev/Test D11_v2 | ~$150 |
| Container Instance | 1 vCPU, 1.5GB | ~$30 |
| Storage Account | Standard LRS | ~$5 |
| Key Vault | Standard | ~$1 |
| **Total** | | **~$186/month** |

*Note: Actual costs vary by region and usage*

---

## Security Considerations

1. **Managed Identities** - No credentials in code
2. **Key Vault** - Centralized secret management
3. **Network Isolation** - Optional VNet integration
4. **RBAC** - Least privilege access
5. **TLS** - All communications encrypted

---

## Next Steps After POC

1. Scale ADX cluster for production workloads
2. Integrate real data sources
3. Customize dashboards for specific use cases
4. Enable Azure AD authentication for Grafana
5. Set up alerting and monitoring
