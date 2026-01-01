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
    // APM SCHEMA - Azure Data Explorer as Datadog/Coralogix Alternative
    // ==============================================================================

    // ==============================================================================
    // Traces Table - Distributed Tracing (like Datadog APM)
    // ==============================================================================
    .create-merge table Traces (
        Timestamp: datetime,
        TraceId: string,
        SpanId: string,
        ParentSpanId: string,
        Service: string,
        Operation: string,
        Duration: real,
        Status: string,
        HttpMethod: string,
        HttpUrl: string,
        HttpStatusCode: int,
        ErrorMessage: string,
        Tags: dynamic
    )

    .alter table Traces policy streamingingestion enable

    .create-or-alter table Traces ingestion json mapping 'TracesJsonMapping'
    ```
    [
        {"column": "Timestamp", "path": "$.timestamp", "datatype": "datetime"},
        {"column": "TraceId", "path": "$.trace_id", "datatype": "string"},
        {"column": "SpanId", "path": "$.span_id", "datatype": "string"},
        {"column": "ParentSpanId", "path": "$.parent_span_id", "datatype": "string"},
        {"column": "Service", "path": "$.service", "datatype": "string"},
        {"column": "Operation", "path": "$.operation", "datatype": "string"},
        {"column": "Duration", "path": "$.duration", "datatype": "real"},
        {"column": "Status", "path": "$.status", "datatype": "string"},
        {"column": "HttpMethod", "path": "$.http_method", "datatype": "string"},
        {"column": "HttpUrl", "path": "$.http_url", "datatype": "string"},
        {"column": "HttpStatusCode", "path": "$.http_status_code", "datatype": "int"},
        {"column": "ErrorMessage", "path": "$.error_message", "datatype": "string"},
        {"column": "Tags", "path": "$.tags", "datatype": "dynamic"}
    ]
    ```

    // ==============================================================================
    // Logs Table - Centralized Logging (like Datadog Logs)
    // ==============================================================================
    .create-merge table Logs (
        Timestamp: datetime,
        Level: string,
        Service: string,
        Host: string,
        Environment: string,
        Message: string,
        TraceId: string,
        SpanId: string,
        Logger: string,
        Exception: string,
        StackTrace: string,
        Attributes: dynamic
    )

    .alter table Logs policy streamingingestion enable

    .create-or-alter table Logs ingestion json mapping 'LogsJsonMapping'
    ```
    [
        {"column": "Timestamp", "path": "$.timestamp", "datatype": "datetime"},
        {"column": "Level", "path": "$.level", "datatype": "string"},
        {"column": "Service", "path": "$.service", "datatype": "string"},
        {"column": "Host", "path": "$.host", "datatype": "string"},
        {"column": "Environment", "path": "$.environment", "datatype": "string"},
        {"column": "Message", "path": "$.message", "datatype": "string"},
        {"column": "TraceId", "path": "$.trace_id", "datatype": "string"},
        {"column": "SpanId", "path": "$.span_id", "datatype": "string"},
        {"column": "Logger", "path": "$.logger", "datatype": "string"},
        {"column": "Exception", "path": "$.exception", "datatype": "string"},
        {"column": "StackTrace", "path": "$.stack_trace", "datatype": "string"},
        {"column": "Attributes", "path": "$.attributes", "datatype": "dynamic"}
    ]
    ```

    // ==============================================================================
    // Metrics Table - Infrastructure & Custom Metrics (like Datadog Metrics)
    // ==============================================================================
    .create-merge table Metrics (
        Timestamp: datetime,
        MetricName: string,
        Value: real,
        MetricType: string,
        Service: string,
        Host: string,
        Environment: string,
        Unit: string,
        Tags: dynamic
    )

    .alter table Metrics policy streamingingestion enable

    .create-or-alter table Metrics ingestion json mapping 'MetricsJsonMapping'
    ```
    [
        {"column": "Timestamp", "path": "$.timestamp", "datatype": "datetime"},
        {"column": "MetricName", "path": "$.metric_name", "datatype": "string"},
        {"column": "Value", "path": "$.value", "datatype": "real"},
        {"column": "MetricType", "path": "$.metric_type", "datatype": "string"},
        {"column": "Service", "path": "$.service", "datatype": "string"},
        {"column": "Host", "path": "$.host", "datatype": "string"},
        {"column": "Environment", "path": "$.environment", "datatype": "string"},
        {"column": "Unit", "path": "$.unit", "datatype": "string"},
        {"column": "Tags", "path": "$.tags", "datatype": "dynamic"}
    ]
    ```

    // ==============================================================================
    // Errors Table - Error Tracking (like Datadog Error Tracking)
    // ==============================================================================
    .create-merge table Errors (
        Timestamp: datetime,
        ErrorId: string,
        Service: string,
        Host: string,
        Environment: string,
        ErrorType: string,
        ErrorMessage: string,
        StackTrace: string,
        TraceId: string,
        UserId: string,
        RequestUrl: string,
        Fingerprint: string,
        Count: int,
        Attributes: dynamic
    )

    .alter table Errors policy streamingingestion enable

    .create-or-alter table Errors ingestion json mapping 'ErrorsJsonMapping'
    ```
    [
        {"column": "Timestamp", "path": "$.timestamp", "datatype": "datetime"},
        {"column": "ErrorId", "path": "$.error_id", "datatype": "string"},
        {"column": "Service", "path": "$.service", "datatype": "string"},
        {"column": "Host", "path": "$.host", "datatype": "string"},
        {"column": "Environment", "path": "$.environment", "datatype": "string"},
        {"column": "ErrorType", "path": "$.error_type", "datatype": "string"},
        {"column": "ErrorMessage", "path": "$.error_message", "datatype": "string"},
        {"column": "StackTrace", "path": "$.stack_trace", "datatype": "string"},
        {"column": "TraceId", "path": "$.trace_id", "datatype": "string"},
        {"column": "UserId", "path": "$.user_id", "datatype": "string"},
        {"column": "RequestUrl", "path": "$.request_url", "datatype": "string"},
        {"column": "Fingerprint", "path": "$.fingerprint", "datatype": "string"},
        {"column": "Count", "path": "$.count", "datatype": "int"},
        {"column": "Attributes", "path": "$.attributes", "datatype": "dynamic"}
    ]
    ```

    // ==============================================================================
    // ServiceMap Table - Service Dependencies
    // ==============================================================================
    .create-merge table ServiceMap (
        Timestamp: datetime,
        SourceService: string,
        DestinationService: string,
        Protocol: string,
        RequestCount: long,
        ErrorCount: long,
        AvgLatency: real,
        P99Latency: real
    )

    .alter table ServiceMap policy streamingingestion enable

    .create-or-alter table ServiceMap ingestion json mapping 'ServiceMapJsonMapping'
    ```
    [
        {"column": "Timestamp", "path": "$.timestamp", "datatype": "datetime"},
        {"column": "SourceService", "path": "$.source_service", "datatype": "string"},
        {"column": "DestinationService", "path": "$.destination_service", "datatype": "string"},
        {"column": "Protocol", "path": "$.protocol", "datatype": "string"},
        {"column": "RequestCount", "path": "$.request_count", "datatype": "long"},
        {"column": "ErrorCount", "path": "$.error_count", "datatype": "long"},
        {"column": "AvgLatency", "path": "$.avg_latency", "datatype": "real"},
        {"column": "P99Latency", "path": "$.p99_latency", "datatype": "real"}
    ]
    ```

    // ==============================================================================
    // APM Stored Functions - Pre-built Analytics
    // ==============================================================================

    // Service Health Overview
    .create-or-alter function with (docstring = "Service health overview with error rates and latency")
    ServiceHealth(timeRange: timespan) {
        Traces
        | where Timestamp > ago(timeRange)
        | summarize
            RequestCount = count(),
            ErrorCount = countif(Status == "error"),
            AvgLatency = round(avg(Duration), 2),
            P50Latency = round(percentile(Duration, 50), 2),
            P95Latency = round(percentile(Duration, 95), 2),
            P99Latency = round(percentile(Duration, 99), 2)
            by Service
        | extend ErrorRate = round(100.0 * ErrorCount / RequestCount, 2)
        | order by ErrorRate desc
    }

    // Request throughput by service
    .create-or-alter function with (docstring = "Request throughput per minute by service")
    RequestThroughput(timeRange: timespan) {
        Traces
        | where Timestamp > ago(timeRange)
        | summarize Requests = count() by bin(Timestamp, 1m), Service
        | order by Timestamp asc
    }

    // Latency percentiles over time
    .create-or-alter function with (docstring = "Latency percentiles over time")
    LatencyTrend(serviceName: string, timeRange: timespan) {
        Traces
        | where Timestamp > ago(timeRange) and Service == serviceName
        | summarize
            P50 = round(percentile(Duration, 50), 2),
            P95 = round(percentile(Duration, 95), 2),
            P99 = round(percentile(Duration, 99), 2)
            by bin(Timestamp, 1m)
        | order by Timestamp asc
    }

    // Error breakdown by type and service
    .create-or-alter function with (docstring = "Error breakdown by type and service")
    ErrorBreakdown(timeRange: timespan) {
        Errors
        | where Timestamp > ago(timeRange)
        | summarize
            OccurrenceCount = count(),
            AffectedUsers = dcount(UserId)
            by Service, ErrorType, ErrorMessage
        | order by OccurrenceCount desc
    }

    // Log volume by level
    .create-or-alter function with (docstring = "Log volume by level over time")
    LogVolume(timeRange: timespan) {
        Logs
        | where Timestamp > ago(timeRange)
        | summarize Count = count() by bin(Timestamp, 1m), Level
        | order by Timestamp asc
    }

    // Trace search
    .create-or-alter function with (docstring = "Search traces by service and status")
    TraceSearch(serviceName: string, status: string, limit: int) {
        Traces
        | where (isempty(serviceName) or Service == serviceName)
        | where (isempty(status) or Status == status)
        | order by Timestamp desc
        | take limit
        | project Timestamp, TraceId, Service, Operation, Duration, Status, HttpStatusCode
    }

    // Slow requests analysis
    .create-or-alter function with (docstring = "Find slow requests above threshold")
    SlowRequests(thresholdMs: real, timeRange: timespan) {
        Traces
        | where Timestamp > ago(timeRange) and Duration > thresholdMs
        | project Timestamp, TraceId, Service, Operation, Duration, HttpUrl
        | order by Duration desc
        | take 100
    }

    // Service dependency map
    .create-or-alter function with (docstring = "Service dependency map with health")
    DependencyMap(timeRange: timespan) {
        ServiceMap
        | where Timestamp > ago(timeRange)
        | summarize
            TotalRequests = sum(RequestCount),
            TotalErrors = sum(ErrorCount),
            AvgLatency = round(avg(AvgLatency), 2)
            by SourceService, DestinationService
        | extend ErrorRate = round(100.0 * TotalErrors / TotalRequests, 2)
    }

    // Apdex score calculation
    .create-or-alter function with (docstring = "Calculate Apdex score for services")
    ApdexScore(satisfiedThreshold: real, toleratingThreshold: real, timeRange: timespan) {
        Traces
        | where Timestamp > ago(timeRange)
        | summarize
            Satisfied = countif(Duration <= satisfiedThreshold),
            Tolerating = countif(Duration > satisfiedThreshold and Duration <= toleratingThreshold),
            Frustrated = countif(Duration > toleratingThreshold),
            Total = count()
            by Service
        | extend Apdex = round((todouble(Satisfied) + (todouble(Tolerating) / 2.0)) / todouble(Total), 2)
        | project Service, Apdex, Satisfied, Tolerating, Frustrated, Total
    }
  KQL
}
