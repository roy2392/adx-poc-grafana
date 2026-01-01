# ==============================================================================
# Azure Data Explorer Cluster
# ==============================================================================

resource "azurerm_kusto_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = var.sku_name
    capacity = var.capacity
  }

  identity {
    type = "SystemAssigned"
  }

  streaming_ingestion_enabled = var.enable_streaming_ingestion
  purge_enabled               = var.enable_purge

  # Auto-stop for dev clusters to save costs
  auto_stop_enabled = startswith(var.sku_name, "Dev") ? true : false

  tags = var.tags
}

# ==============================================================================
# ADX Database
# ==============================================================================

resource "azurerm_kusto_database" "main" {
  name                = var.database_name
  resource_group_name = var.resource_group_name
  location            = var.location
  cluster_name        = azurerm_kusto_cluster.main.name

  hot_cache_period   = var.hot_cache_period
  soft_delete_period = var.soft_delete_period
}

# ==============================================================================
# Database Schema Setup Script
# ==============================================================================

resource "azurerm_kusto_script" "setup_schema" {
  name                               = "setup-schema"
  database_id                        = azurerm_kusto_database.main.id
  continue_on_errors_enabled         = false
  force_an_update_when_value_changed = "v1"

  script_content = <<-KQL
    // ==============================================================================
    // IoT Sensors Table - Time-series sensor data
    // ==============================================================================
    .create-merge table IoTSensors (
        Timestamp: datetime,
        DeviceId: string,
        Temperature: real,
        Humidity: real,
        Pressure: real,
        Location: string
    )

    // Enable streaming ingestion
    .alter table IoTSensors policy streamingingestion enable

    // Create JSON ingestion mapping
    .create-or-alter table IoTSensors ingestion json mapping 'IoTSensorsJsonMapping'
    ```
    [
        {"column": "Timestamp", "path": "$.timestamp", "datatype": "datetime"},
        {"column": "DeviceId", "path": "$.device_id", "datatype": "string"},
        {"column": "Temperature", "path": "$.temperature", "datatype": "real"},
        {"column": "Humidity", "path": "$.humidity", "datatype": "real"},
        {"column": "Pressure", "path": "$.pressure", "datatype": "real"},
        {"column": "Location", "path": "$.location", "datatype": "string"}
    ]
    ```

    // Create CSV ingestion mapping
    .create-or-alter table IoTSensors ingestion csv mapping 'IoTSensorsCsvMapping'
    ```
    [
        {"column": "Timestamp", "ordinal": 0, "datatype": "datetime"},
        {"column": "DeviceId", "ordinal": 1, "datatype": "string"},
        {"column": "Temperature", "ordinal": 2, "datatype": "real"},
        {"column": "Humidity", "ordinal": 3, "datatype": "real"},
        {"column": "Pressure", "ordinal": 4, "datatype": "real"},
        {"column": "Location", "ordinal": 5, "datatype": "string"}
    ]
    ```

    // ==============================================================================
    // Application Logs Table - Log analytics data
    // ==============================================================================
    .create-merge table AppLogs (
        Timestamp: datetime,
        Level: string,
        Service: string,
        Message: string,
        TraceId: string,
        UserId: string,
        Duration: real
    )

    .alter table AppLogs policy streamingingestion enable

    .create-or-alter table AppLogs ingestion json mapping 'AppLogsJsonMapping'
    ```
    [
        {"column": "Timestamp", "path": "$.timestamp", "datatype": "datetime"},
        {"column": "Level", "path": "$.level", "datatype": "string"},
        {"column": "Service", "path": "$.service", "datatype": "string"},
        {"column": "Message", "path": "$.message", "datatype": "string"},
        {"column": "TraceId", "path": "$.trace_id", "datatype": "string"},
        {"column": "UserId", "path": "$.user_id", "datatype": "string"},
        {"column": "Duration", "path": "$.duration", "datatype": "real"}
    ]
    ```

    // ==============================================================================
    // Metrics Table - Generic metrics data
    // ==============================================================================
    .create-merge table Metrics (
        Timestamp: datetime,
        MetricName: string,
        Value: real,
        Unit: string,
        Dimensions: dynamic
    )

    .alter table Metrics policy streamingingestion enable

    .create-or-alter table Metrics ingestion json mapping 'MetricsJsonMapping'
    ```
    [
        {"column": "Timestamp", "path": "$.timestamp", "datatype": "datetime"},
        {"column": "MetricName", "path": "$.metric_name", "datatype": "string"},
        {"column": "Value", "path": "$.value", "datatype": "real"},
        {"column": "Unit", "path": "$.unit", "datatype": "string"},
        {"column": "Dimensions", "path": "$.dimensions", "datatype": "dynamic"}
    ]
    ```

    // ==============================================================================
    // Stored Functions for Common Queries
    // ==============================================================================

    // Get average sensor readings by device (last hour)
    .create-or-alter function with (docstring = "Average sensor readings by device for the last hour")
    AvgSensorsByDevice() {
        IoTSensors
        | where Timestamp > ago(1h)
        | summarize
            AvgTemperature = round(avg(Temperature), 2),
            AvgHumidity = round(avg(Humidity), 2),
            AvgPressure = round(avg(Pressure), 2),
            ReadingCount = count()
            by DeviceId, Location
        | order by AvgTemperature desc
    }

    // Get error rate by service
    .create-or-alter function with (docstring = "Error rate by service for the last hour")
    ErrorRateByService() {
        AppLogs
        | where Timestamp > ago(1h)
        | summarize
            TotalLogs = count(),
            Errors = countif(Level == "Error"),
            Warnings = countif(Level == "Warning")
            by Service
        | extend
            ErrorRate = round(100.0 * Errors / TotalLogs, 2),
            WarningRate = round(100.0 * Warnings / TotalLogs, 2)
        | order by ErrorRate desc
    }

    // Get sensor readings time series for a device
    .create-or-alter function with (docstring = "Sensor time series for a specific device")
    SensorTimeSeries(deviceId: string, timeRange: timespan) {
        IoTSensors
        | where Timestamp > ago(timeRange) and DeviceId == deviceId
        | summarize
            AvgTemp = avg(Temperature),
            MinTemp = min(Temperature),
            MaxTemp = max(Temperature)
            by bin(Timestamp, 1m)
        | order by Timestamp asc
    }

    // Get metrics summary with percentiles
    .create-or-alter function with (docstring = "Metrics summary with percentiles")
    MetricsSummary(metricName: string, timeRange: timespan) {
        Metrics
        | where Timestamp > ago(timeRange) and MetricName == metricName
        | summarize
            Avg = round(avg(Value), 2),
            Min = min(Value),
            Max = max(Value),
            P50 = percentile(Value, 50),
            P95 = percentile(Value, 95),
            P99 = percentile(Value, 99),
            Count = count()
            by bin(Timestamp, 5m)
        | order by Timestamp asc
    }

    // Get recent logs with filtering
    .create-or-alter function with (docstring = "Recent logs with optional level filter")
    RecentLogs(level: string, limit: int) {
        AppLogs
        | where Timestamp > ago(1h)
        | where isempty(level) or Level == level
        | order by Timestamp desc
        | take limit
    }
  KQL
}
