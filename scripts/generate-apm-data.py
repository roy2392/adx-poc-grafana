#!/usr/bin/env python3
"""
APM Sample Data Generator for Azure Data Explorer
Generates realistic APM data similar to Datadog/Coralogix
"""

import json
import random
import uuid
from datetime import datetime, timedelta
from typing import List, Dict, Any

# Configuration
SERVICES = [
    {"name": "api-gateway", "host": "api-gw-01", "endpoints": ["/api/v1/users", "/api/v1/orders", "/api/v1/products", "/api/v1/auth"]},
    {"name": "user-service", "host": "user-svc-01", "endpoints": ["/users/create", "/users/get", "/users/update", "/users/delete"]},
    {"name": "order-service", "host": "order-svc-01", "endpoints": ["/orders/create", "/orders/list", "/orders/status", "/orders/cancel"]},
    {"name": "payment-service", "host": "payment-svc-01", "endpoints": ["/payments/process", "/payments/refund", "/payments/status"]},
    {"name": "inventory-service", "host": "inventory-svc-01", "endpoints": ["/inventory/check", "/inventory/reserve", "/inventory/release"]},
    {"name": "notification-service", "host": "notif-svc-01", "endpoints": ["/notify/email", "/notify/sms", "/notify/push"]},
    {"name": "analytics-service", "host": "analytics-01", "endpoints": ["/analytics/track", "/analytics/aggregate", "/analytics/report"]},
]

ENVIRONMENTS = ["production", "staging"]
LOG_LEVELS = ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]
LOG_LEVEL_WEIGHTS = [10, 50, 20, 15, 5]

HTTP_METHODS = ["GET", "POST", "PUT", "DELETE"]
HTTP_STATUS_CODES = {
    "success": [200, 201, 204],
    "client_error": [400, 401, 403, 404, 422],
    "server_error": [500, 502, 503, 504],
}

ERROR_TYPES = [
    "NullPointerException",
    "ConnectionTimeoutException",
    "ValidationException",
    "AuthenticationException",
    "DatabaseException",
    "RateLimitException",
    "SerializationException",
]

STACK_TRACES = {
    "NullPointerException": """java.lang.NullPointerException: Cannot invoke method on null object
    at com.example.service.UserService.getUser(UserService.java:45)
    at com.example.controller.UserController.handleRequest(UserController.java:78)
    at org.springframework.web.servlet.FrameworkServlet.service(FrameworkServlet.java:897)""",
    "ConnectionTimeoutException": """java.net.ConnectException: Connection timed out after 30000ms
    at com.example.client.HttpClient.connect(HttpClient.java:112)
    at com.example.service.ExternalApiService.call(ExternalApiService.java:56)
    at com.example.handler.RequestHandler.process(RequestHandler.java:89)""",
    "DatabaseException": """org.postgresql.util.PSQLException: Connection pool exhausted
    at org.postgresql.jdbc.PgConnection.createStatement(PgConnection.java:234)
    at com.example.repository.OrderRepository.findById(OrderRepository.java:67)
    at com.example.service.OrderService.getOrder(OrderService.java:123)""",
}

LOG_MESSAGES = {
    "DEBUG": [
        "Processing request with correlation ID: {trace_id}",
        "Cache hit for key: user_{user_id}",
        "Database query executed in {duration}ms",
    ],
    "INFO": [
        "Request completed successfully",
        "User {user_id} authenticated successfully",
        "Order {order_id} created for user {user_id}",
        "Payment processed: amount=${amount}",
        "Notification sent to {email}",
    ],
    "WARN": [
        "Slow query detected: {duration}ms exceeds threshold",
        "Retry attempt 2/3 for external API call",
        "Cache miss rate exceeds 20%",
        "Connection pool utilization at 85%",
    ],
    "ERROR": [
        "Failed to process payment: {error}",
        "Database connection failed after 3 retries",
        "External API returned error: {status_code}",
        "Authentication failed for user {user_id}",
    ],
    "FATAL": [
        "Service unable to start: configuration error",
        "Out of memory: heap space exhausted",
        "Critical database failure: all connections lost",
    ],
}


def generate_trace_id() -> str:
    return uuid.uuid4().hex[:32]

def generate_span_id() -> str:
    return uuid.uuid4().hex[:16]

def generate_user_id() -> str:
    return f"user_{random.randint(1000, 9999)}"

def generate_traces(start_time: datetime, count: int) -> List[Dict[str, Any]]:
    """Generate distributed traces with spans."""
    traces = []

    for i in range(count):
        timestamp = start_time + timedelta(seconds=random.randint(0, 3600))
        trace_id = generate_trace_id()
        service = random.choice(SERVICES)
        endpoint = random.choice(service["endpoints"])

        # Determine if this request will be successful, slow, or errored
        outcome = random.choices(
            ["success", "slow", "error"],
            weights=[80, 15, 5]
        )[0]

        if outcome == "success":
            duration = random.uniform(10, 200)
            status = "ok"
            status_code = random.choice(HTTP_STATUS_CODES["success"])
            error_msg = ""
        elif outcome == "slow":
            duration = random.uniform(500, 3000)
            status = "ok"
            status_code = random.choice(HTTP_STATUS_CODES["success"])
            error_msg = ""
        else:
            duration = random.uniform(50, 500)
            status = "error"
            status_code = random.choice(
                HTTP_STATUS_CODES["client_error"] + HTTP_STATUS_CODES["server_error"]
            )
            error_msg = random.choice(ERROR_TYPES)

        trace = {
            "timestamp": timestamp.isoformat() + "Z",
            "trace_id": trace_id,
            "span_id": generate_span_id(),
            "parent_span_id": "",
            "service": service["name"],
            "operation": endpoint.split("/")[-1],
            "duration": round(duration, 2),
            "status": status,
            "http_method": random.choice(HTTP_METHODS),
            "http_url": endpoint,
            "http_status_code": status_code,
            "error_message": error_msg,
            "tags": {
                "env": random.choice(ENVIRONMENTS),
                "version": f"1.{random.randint(0, 5)}.{random.randint(0, 20)}",
            }
        }
        traces.append(trace)

    return traces


def generate_logs(start_time: datetime, count: int) -> List[Dict[str, Any]]:
    """Generate application logs."""
    logs = []

    for i in range(count):
        timestamp = start_time + timedelta(seconds=random.randint(0, 3600))
        level = random.choices(LOG_LEVELS, weights=LOG_LEVEL_WEIGHTS)[0]
        service = random.choice(SERVICES)

        message_template = random.choice(LOG_MESSAGES[level])
        message = message_template.format(
            trace_id=generate_trace_id(),
            user_id=generate_user_id(),
            order_id=f"ORD-{random.randint(10000, 99999)}",
            amount=random.randint(10, 500),
            email=f"user{random.randint(100, 999)}@example.com",
            duration=random.randint(100, 5000),
            error=random.choice(ERROR_TYPES),
            status_code=random.choice([500, 502, 503]),
        )

        log = {
            "timestamp": timestamp.isoformat() + "Z",
            "level": level,
            "service": service["name"],
            "host": service["host"],
            "environment": random.choice(ENVIRONMENTS),
            "message": message,
            "trace_id": generate_trace_id() if random.random() > 0.3 else "",
            "span_id": generate_span_id() if random.random() > 0.3 else "",
            "logger": f"com.example.{service['name'].replace('-', '.')}.Application",
            "exception": "",
            "stack_trace": "",
            "attributes": {
                "thread": f"http-nio-8080-exec-{random.randint(1, 50)}",
                "request_id": uuid.uuid4().hex[:8],
            }
        }

        # Add exception details for error logs
        if level in ["ERROR", "FATAL"]:
            error_type = random.choice(ERROR_TYPES)
            log["exception"] = error_type
            log["stack_trace"] = STACK_TRACES.get(error_type, f"{error_type}: An error occurred")

        logs.append(log)

    return logs


def generate_metrics(start_time: datetime, count: int) -> List[Dict[str, Any]]:
    """Generate infrastructure and application metrics."""
    metrics = []
    metric_definitions = [
        {"name": "http.request.duration", "unit": "ms", "type": "histogram", "base": 100, "variance": 50},
        {"name": "http.request.count", "unit": "count", "type": "counter", "base": 500, "variance": 200},
        {"name": "http.error.count", "unit": "count", "type": "counter", "base": 10, "variance": 15},
        {"name": "cpu.usage", "unit": "percent", "type": "gauge", "base": 45, "variance": 30},
        {"name": "memory.usage", "unit": "percent", "type": "gauge", "base": 60, "variance": 20},
        {"name": "db.connections.active", "unit": "count", "type": "gauge", "base": 25, "variance": 15},
        {"name": "db.query.duration", "unit": "ms", "type": "histogram", "base": 50, "variance": 100},
        {"name": "cache.hit.rate", "unit": "percent", "type": "gauge", "base": 85, "variance": 10},
        {"name": "queue.size", "unit": "count", "type": "gauge", "base": 100, "variance": 80},
        {"name": "gc.pause.duration", "unit": "ms", "type": "histogram", "base": 20, "variance": 30},
    ]

    for i in range(count):
        timestamp = start_time + timedelta(seconds=random.randint(0, 3600))
        service = random.choice(SERVICES)
        metric_def = random.choice(metric_definitions)

        value = max(0, metric_def["base"] + random.uniform(-metric_def["variance"], metric_def["variance"]))

        metric = {
            "timestamp": timestamp.isoformat() + "Z",
            "metric_name": metric_def["name"],
            "value": round(value, 2),
            "metric_type": metric_def["type"],
            "service": service["name"],
            "host": service["host"],
            "environment": random.choice(ENVIRONMENTS),
            "unit": metric_def["unit"],
            "tags": {
                "region": random.choice(["us-east-1", "us-west-2", "eu-west-1"]),
                "instance": f"i-{uuid.uuid4().hex[:8]}",
            }
        }
        metrics.append(metric)

    return metrics


def generate_errors(start_time: datetime, count: int) -> List[Dict[str, Any]]:
    """Generate error tracking data."""
    errors = []

    for i in range(count):
        timestamp = start_time + timedelta(seconds=random.randint(0, 3600))
        service = random.choice(SERVICES)
        error_type = random.choice(ERROR_TYPES)

        error = {
            "timestamp": timestamp.isoformat() + "Z",
            "error_id": uuid.uuid4().hex[:16],
            "service": service["name"],
            "host": service["host"],
            "environment": random.choice(ENVIRONMENTS),
            "error_type": error_type,
            "error_message": f"{error_type}: Operation failed",
            "stack_trace": STACK_TRACES.get(error_type, f"{error_type}: An error occurred\n    at unknown location"),
            "trace_id": generate_trace_id(),
            "user_id": generate_user_id() if random.random() > 0.3 else "",
            "request_url": random.choice(service["endpoints"]),
            "fingerprint": uuid.uuid4().hex[:8],
            "count": random.randint(1, 50),
            "attributes": {
                "browser": random.choice(["Chrome", "Firefox", "Safari", "Edge"]),
                "os": random.choice(["Windows", "macOS", "Linux", "iOS", "Android"]),
            }
        }
        errors.append(error)

    return errors


def generate_service_map(start_time: datetime) -> List[Dict[str, Any]]:
    """Generate service dependency data."""
    dependencies = [
        ("api-gateway", "user-service", "http"),
        ("api-gateway", "order-service", "http"),
        ("api-gateway", "analytics-service", "http"),
        ("user-service", "notification-service", "http"),
        ("order-service", "payment-service", "http"),
        ("order-service", "inventory-service", "http"),
        ("order-service", "notification-service", "http"),
        ("payment-service", "notification-service", "http"),
    ]

    service_map = []
    for source, dest, protocol in dependencies:
        timestamp = start_time + timedelta(minutes=random.randint(0, 60))

        request_count = random.randint(1000, 10000)
        error_rate = random.uniform(0, 5)
        error_count = int(request_count * error_rate / 100)

        entry = {
            "timestamp": timestamp.isoformat() + "Z",
            "source_service": source,
            "destination_service": dest,
            "protocol": protocol,
            "request_count": request_count,
            "error_count": error_count,
            "avg_latency": round(random.uniform(10, 150), 2),
            "p99_latency": round(random.uniform(200, 1000), 2),
        }
        service_map.append(entry)

    return service_map


def main():
    # Generate data for the last hour
    now = datetime.utcnow()
    start_time = now - timedelta(hours=1)

    print("Generating APM sample data...")

    # Generate all data types
    traces = generate_traces(start_time, 500)
    logs = generate_logs(start_time, 1000)
    metrics = generate_metrics(start_time, 800)
    errors = generate_errors(start_time, 50)
    service_map = generate_service_map(start_time)

    # Save to files
    data_dir = "sample-data"

    with open(f"{data_dir}/traces.json", "w") as f:
        json.dump(traces, f, indent=2)
    print(f"Generated {len(traces)} traces")

    with open(f"{data_dir}/logs.json", "w") as f:
        json.dump(logs, f, indent=2)
    print(f"Generated {len(logs)} logs")

    with open(f"{data_dir}/metrics.json", "w") as f:
        json.dump(metrics, f, indent=2)
    print(f"Generated {len(metrics)} metrics")

    with open(f"{data_dir}/errors.json", "w") as f:
        json.dump(errors, f, indent=2)
    print(f"Generated {len(errors)} errors")

    with open(f"{data_dir}/service-map.json", "w") as f:
        json.dump(service_map, f, indent=2)
    print(f"Generated {len(service_map)} service map entries")

    print("\nAPM sample data generated successfully!")
    print(f"Files saved to {data_dir}/")


if __name__ == "__main__":
    main()
