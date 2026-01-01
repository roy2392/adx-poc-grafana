# Architecture Documentation

## System Overview

This POC demonstrates a complete Azure Data Explorer (ADX) analytics solution with Grafana visualization, designed for easy client deployment.

## Component Details

### Azure Data Explorer (ADX)

**Purpose**: High-performance analytics database for time-series and log data

**Configuration**:
- Cluster SKU: `Dev(No SLA)_Standard_D11_v2` (POC) or `Standard_D11_v2` (Production)
- Auto-scale: Disabled for POC (cost control)
- Streaming ingestion: Enabled
- Purge: Enabled for data management demos

**Database Schema**:
```kql
// IoT Sensors Table
.create table IoTSensors (
    Timestamp: datetime,
    DeviceId: string,
    Temperature: real,
    Humidity: real,
    Pressure: real,
    Location: string
)

// Application Logs Table
.create table AppLogs (
    Timestamp: datetime,
    Level: string,
    Service: string,
    Message: string,
    TraceId: string
)

// Metrics Table
.create table Metrics (
    Timestamp: datetime,
    MetricName: string,
    Value: real,
    Dimensions: dynamic
)
```

**Stored Functions**:
```kql
// Get average temperature by device (last hour)
.create function AvgTempByDevice() {
    IoTSensors
    | where Timestamp > ago(1h)
    | summarize AvgTemp = avg(Temperature) by DeviceId
}

// Error rate by service
.create function ErrorRateByService() {
    AppLogs
    | where Timestamp > ago(1h)
    | summarize
        TotalLogs = count(),
        Errors = countif(Level == "Error")
        by Service
    | extend ErrorRate = round(100.0 * Errors / TotalLogs, 2)
}
```

---

### Grafana

**Purpose**: Visualization layer for ADX data

**Deployment**: Azure Container Instance
- Image: `grafana/grafana-oss:latest`
- Resources: 1 vCPU, 1.5 GB RAM
- Storage: Azure File Share for persistence

**Data Source Configuration**:
```yaml
apiVersion: 1
datasources:
  - name: Azure Data Explorer
    type: grafana-azure-data-explorer-datasource
    access: proxy
    jsonData:
      clusterUrl: https://${ADX_CLUSTER}.${REGION}.kusto.windows.net
      tenantId: ${TENANT_ID}
      clientId: ${CLIENT_ID}
    secureJsonData:
      clientSecret: ${CLIENT_SECRET}
```

**Pre-built Dashboards**:
1. **ADX Overview** - Cluster health, query performance, data volume
2. **IoT Sensors** - Real-time sensor data visualization
3. **Application Logs** - Log analysis, error tracking
4. **Metrics Explorer** - Custom metric visualization

---

### Storage Account

**Purpose**: Data ingestion source for ADX

**Configuration**:
- Kind: `StorageV2`
- Replication: `LRS` (POC)
- Containers:
  - `raw-data` - Incoming data files
  - `processed` - Archived ingested data

**Event Grid Integration** (Optional):
- Trigger ADX ingestion on blob upload
- Supports CSV, JSON, Parquet formats

---

### Key Vault

**Purpose**: Centralized secret management

**Secrets Stored**:
| Secret Name | Description |
|-------------|-------------|
| `grafana-admin-password` | Grafana admin credentials |
| `adx-client-secret` | Service principal for Grafana-ADX connection |
| `storage-connection-string` | Storage account access |

**Access Policies**:
- Grafana managed identity: `Get` secrets
- ADX cluster: `Get` secrets (for external tables)

---

## Network Architecture

### Option A: Public Access (Default for POC)

```
Internet
    │
    ├──► ADX Cluster (Public endpoint with firewall rules)
    │
    └──► Grafana ACI (Public IP)
```

**Firewall Rules**:
- ADX: Allow Azure services + specific client IPs
- Grafana: Allow all (with authentication)

### Option B: Private Network (Production)

```
┌─────────────────────────────────────────────┐
│                 Virtual Network              │
│                 10.0.0.0/16                 │
├─────────────────────────────────────────────┤
│  ┌─────────────┐      ┌─────────────┐       │
│  │ ADX Subnet  │      │ ACI Subnet  │       │
│  │ 10.0.1.0/24 │      │ 10.0.2.0/24 │       │
│  │             │      │             │       │
│  │ ┌─────────┐ │      │ ┌─────────┐ │       │
│  │ │   ADX   │ │◄─────│ │ Grafana │ │       │
│  │ │ Private │ │      │ │   ACI   │ │       │
│  │ │Endpoint │ │      │ └─────────┘ │       │
│  │ └─────────┘ │      │             │       │
│  └─────────────┘      └─────────────┘       │
│                                              │
│  ┌─────────────────────────────────┐        │
│  │        Bastion Subnet           │        │
│  │        10.0.3.0/27              │        │
│  └─────────────────────────────────┘        │
└─────────────────────────────────────────────┘
           │
           ▼
    Azure Bastion (Secure Access)
```

---

## Authentication & Authorization

### Service Principal (for Grafana)

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "sp-grafana-adx-reader" \
  --role "Reader" \
  --scopes "/subscriptions/{sub}/resourceGroups/{rg}"

# Grant ADX database viewer permission
az kusto database-principal-assignment create \
  --cluster-name {adx-cluster} \
  --database-name {database} \
  --principal-id {sp-object-id} \
  --principal-type App \
  --role Viewer \
  --resource-group {rg} \
  --name "grafana-viewer"
```

### Managed Identity (Recommended)

```hcl
# Terraform - Assign system identity to ACI
resource "azurerm_container_group" "grafana" {
  identity {
    type = "SystemAssigned"
  }
}

# Grant ADX access to managed identity
resource "azurerm_kusto_database_principal_assignment" "grafana" {
  name                = "grafana-viewer"
  principal_id        = azurerm_container_group.grafana.identity[0].principal_id
  principal_type      = "App"
  role                = "Viewer"
  tenant_id           = data.azurerm_client_config.current.tenant_id
}
```

---

## Data Flow

```
1. Sample Data Generation
   └──► CSV/JSON files in Storage Account

2. Data Ingestion
   └──► ADX ingestion (Event Grid or direct)

3. Data Processing
   └──► KQL queries & materialized views

4. Visualization
   └──► Grafana dashboards with ADX plugin

5. User Access
   └──► Browser ──► Grafana UI ──► ADX queries
```

---

## Scaling Considerations

### ADX Cluster

| Scenario | Recommended SKU | Nodes |
|----------|-----------------|-------|
| POC/Dev | Dev(No SLA)_Standard_D11_v2 | 1 |
| Small Production | Standard_D11_v2 | 2 |
| Medium Production | Standard_D13_v2 | 3-5 |
| Large Production | Standard_D14_v2 | 5+ |

### Grafana

| Scenario | CPU | Memory |
|----------|-----|--------|
| POC | 1 vCPU | 1.5 GB |
| Production | 2 vCPU | 4 GB |
| High Availability | Use Azure Managed Grafana |

---

## Monitoring

### Metrics to Track

1. **ADX Cluster**
   - Ingestion latency
   - Query duration
   - Cache utilization
   - CPU/Memory usage

2. **Grafana**
   - Container health
   - Request latency
   - Active sessions

### Alerts (Optional)

```hcl
resource "azurerm_monitor_metric_alert" "adx_cpu" {
  name                = "adx-high-cpu"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_kusto_cluster.main.id]

  criteria {
    metric_namespace = "Microsoft.Kusto/clusters"
    metric_name      = "CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
}
```

---

## Disaster Recovery

### Backup Strategy

1. **ADX Data**: Use `.export` commands for critical data
2. **Grafana Dashboards**: JSON files in Git repository
3. **Configuration**: Terraform state in remote backend

### Recovery Procedure

1. Re-run `terraform apply` in new region
2. Restore ADX data from exports
3. Dashboards auto-provisioned from repository
