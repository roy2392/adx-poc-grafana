#!/usr/bin/env python3
"""
Generate realistic sample data for ADX POC demo.
Creates IoT sensor readings, application logs, and metrics.
"""

import json
import random
from datetime import datetime, timedelta
from pathlib import Path

# Configuration
NUM_DEVICES = 10
NUM_SERVICES = 8
DURATION_HOURS = 24
INTERVAL_SECONDS = 60

LOCATIONS = [
    "Building-A-Floor-1", "Building-A-Floor-2", "Building-A-Floor-3",
    "Building-B-Floor-1", "Building-B-Floor-2",
    "Warehouse-1", "Warehouse-2",
    "Outdoor-North", "Outdoor-South", "Outdoor-East"
]

SERVICES = [
    "api-gateway", "user-service", "order-service", "payment-service",
    "inventory-service", "notification-service", "auth-service", "search-service"
]

LOG_LEVELS = ["Info", "Warning", "Error", "Debug"]
LOG_LEVEL_WEIGHTS = [70, 15, 10, 5]  # Percentages

LOG_MESSAGES = {
    "Info": [
        "Request received: GET /api/v1/{}",
        "Response sent: 200 OK",
        "Cache hit for key: {}",
        "Database query executed successfully",
        "User session created",
        "Background job completed",
        "Health check passed",
        "Configuration reloaded"
    ],
    "Warning": [
        "High latency detected: {}ms",
        "Cache miss rate above threshold",
        "Connection pool running low",
        "Token expiring soon for user",
        "Rate limit approaching for client",
        "Memory usage above 80%"
    ],
    "Error": [
        "Failed to connect to database",
        "Timeout waiting for response",
        "Invalid authentication token",
        "Service unavailable: {}",
        "Failed to process request: {}",
        "Connection refused"
    ],
    "Debug": [
        "Entering function: {}",
        "Variable state: {}",
        "Query plan: {}",
        "Cache key generated: {}"
    ]
}


def generate_iot_sensors(output_path: Path, start_time: datetime):
    """Generate IoT sensor data."""
    devices = [f"sensor-{i:03d}" for i in range(1, NUM_DEVICES + 1)]
    device_locations = {d: random.choice(LOCATIONS) for d in devices}

    # Base values for each device (to simulate realistic patterns)
    device_base_temp = {d: random.uniform(18, 28) for d in devices}
    device_base_humidity = {d: random.uniform(40, 60) for d in devices}
    device_base_pressure = {d: random.uniform(1010, 1020) for d in devices}

    records = []
    current_time = start_time
    num_intervals = (DURATION_HOURS * 3600) // INTERVAL_SECONDS

    for _ in range(num_intervals):
        for device in devices:
            # Add some variation and drift
            temp = device_base_temp[device] + random.gauss(0, 0.5)
            humidity = device_base_humidity[device] + random.gauss(0, 2)
            pressure = device_base_pressure[device] + random.gauss(0, 0.5)

            # Simulate daily temperature pattern
            hour = current_time.hour
            if 10 <= hour <= 16:
                temp += 2  # Warmer during day
            elif hour >= 22 or hour <= 6:
                temp -= 2  # Cooler at night

            record = {
                "timestamp": current_time.isoformat() + "Z",
                "device_id": device,
                "temperature": round(temp, 1),
                "humidity": round(max(0, min(100, humidity)), 1),
                "pressure": round(pressure, 2),
                "location": device_locations[device]
            }
            records.append(record)

        current_time += timedelta(seconds=INTERVAL_SECONDS)

    with open(output_path, 'w') as f:
        for record in records:
            f.write(json.dumps(record) + '\n')

    print(f"Generated {len(records)} IoT sensor records -> {output_path}")


def generate_app_logs(output_path: Path, start_time: datetime):
    """Generate application log data."""
    records = []
    current_time = start_time
    trace_counter = 1

    # Generate logs with varying frequency
    while current_time < start_time + timedelta(hours=DURATION_HOURS):
        # More logs during business hours
        hour = current_time.hour
        if 9 <= hour <= 18:
            logs_per_minute = random.randint(10, 50)
        else:
            logs_per_minute = random.randint(2, 15)

        for _ in range(logs_per_minute):
            level = random.choices(LOG_LEVELS, weights=LOG_LEVEL_WEIGHTS)[0]
            service = random.choice(SERVICES)
            message_template = random.choice(LOG_MESSAGES[level])

            # Fill in message placeholders
            if "{}" in message_template:
                placeholders = ["users", "orders", "products", "cache_key_123",
                              str(random.randint(100, 5000)), "process_data"]
                message = message_template.format(random.choice(placeholders))
            else:
                message = message_template

            # Generate realistic durations
            if level == "Error":
                duration = random.uniform(1000, 30000)  # Errors take longer
            elif level == "Warning":
                duration = random.uniform(100, 1000)
            else:
                duration = random.uniform(1, 200)

            trace_id = f"trace-{trace_counter:08d}"
            trace_counter += 1

            user_id = f"user-{random.randint(1, 1000):04d}" if random.random() > 0.2 else ""

            log_time = current_time + timedelta(seconds=random.uniform(0, 60))

            record = {
                "timestamp": log_time.isoformat() + "Z",
                "level": level,
                "service": service,
                "message": message,
                "trace_id": trace_id,
                "user_id": user_id,
                "duration": round(duration, 1)
            }
            records.append(record)

        current_time += timedelta(minutes=1)

    # Sort by timestamp
    records.sort(key=lambda x: x["timestamp"])

    with open(output_path, 'w') as f:
        for record in records:
            f.write(json.dumps(record) + '\n')

    print(f"Generated {len(records)} app log records -> {output_path}")


def generate_metrics(output_path: Path, start_time: datetime):
    """Generate metrics data."""
    metric_definitions = [
        ("cpu_usage", "percent", 20, 80),
        ("memory_usage", "percent", 30, 70),
        ("request_rate", "requests/sec", 100, 1000),
        ("response_time", "ms", 10, 500),
        ("error_rate", "percent", 0, 5),
        ("active_connections", "count", 50, 500),
        ("queue_depth", "count", 0, 100),
        ("cache_hit_rate", "percent", 80, 99)
    ]

    records = []
    current_time = start_time
    num_intervals = (DURATION_HOURS * 3600) // (INTERVAL_SECONDS * 5)  # Every 5 minutes

    for _ in range(num_intervals):
        for metric_name, unit, min_val, max_val in metric_definitions:
            # Add time-based patterns
            hour = current_time.hour
            if metric_name in ["cpu_usage", "request_rate", "active_connections"]:
                if 9 <= hour <= 18:
                    value = random.uniform(min_val + (max_val - min_val) * 0.5, max_val)
                else:
                    value = random.uniform(min_val, min_val + (max_val - min_val) * 0.3)
            else:
                value = random.uniform(min_val, max_val)

            dimensions = {
                "environment": random.choice(["production", "staging"]),
                "region": random.choice(["eastus", "westus", "westeurope"]),
                "service": random.choice(SERVICES)
            }

            record = {
                "timestamp": current_time.isoformat() + "Z",
                "metric_name": metric_name,
                "value": round(value, 2),
                "unit": unit,
                "dimensions": dimensions
            }
            records.append(record)

        current_time += timedelta(minutes=5)

    with open(output_path, 'w') as f:
        for record in records:
            f.write(json.dumps(record) + '\n')

    print(f"Generated {len(records)} metric records -> {output_path}")


def main():
    script_dir = Path(__file__).parent
    sample_data_dir = script_dir.parent / "sample-data"
    sample_data_dir.mkdir(exist_ok=True)

    # Use yesterday as start time for demo purposes
    start_time = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=1)

    print(f"Generating sample data starting from {start_time.isoformat()}Z")
    print(f"Duration: {DURATION_HOURS} hours")
    print()

    generate_iot_sensors(sample_data_dir / "iot-sensors-full.json", start_time)
    generate_app_logs(sample_data_dir / "app-logs-full.json", start_time)
    generate_metrics(sample_data_dir / "metrics-full.json", start_time)

    print()
    print("Sample data generation complete!")


if __name__ == "__main__":
    main()
