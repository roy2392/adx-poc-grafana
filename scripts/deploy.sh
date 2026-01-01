#!/bin/bash
set -e

# ==============================================================================
# ADX POC Deployment Helper Script
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$ROOT_DIR/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform >= 1.5.0"
        exit 1
    fi

    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install Azure CLI"
        exit 1
    fi

    # Check Azure login
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login'"
        exit 1
    fi

    print_info "All prerequisites met!"
}

# Initialize Terraform
init() {
    print_info "Initializing Terraform..."
    cd "$TERRAFORM_DIR"
    terraform init
    print_info "Terraform initialized successfully!"
}

# Plan deployment
plan() {
    print_info "Planning deployment..."
    cd "$TERRAFORM_DIR"
    terraform plan -out=tfplan
    print_info "Plan saved to tfplan"
}

# Apply deployment
apply() {
    print_info "Applying deployment..."
    cd "$TERRAFORM_DIR"

    if [ -f "tfplan" ]; then
        terraform apply tfplan
    else
        terraform apply
    fi

    print_info "Deployment complete!"
    print_info ""
    terraform output connection_info
}

# Destroy resources
destroy() {
    print_warn "This will destroy all resources!"
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        cd "$TERRAFORM_DIR"
        terraform destroy
        print_info "Resources destroyed!"
    else
        print_info "Destroy cancelled"
    fi
}

# Ingest sample data
ingest_sample_data() {
    print_info "Ingesting sample data..."

    cd "$TERRAFORM_DIR"

    # Get outputs
    CLUSTER_NAME=$(terraform output -raw adx_cluster_name 2>/dev/null)
    DATABASE_NAME=$(terraform output -raw adx_database_name 2>/dev/null)
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null)
    STORAGE_ACCOUNT=$(terraform output -raw storage_account_name 2>/dev/null)

    if [ -z "$CLUSTER_NAME" ]; then
        print_error "Could not get ADX cluster name. Is the infrastructure deployed?"
        exit 1
    fi

    print_info "Uploading sample data to storage..."

    # Upload IoT sensor data
    az storage blob upload \
        --account-name "$STORAGE_ACCOUNT" \
        --container-name "sample-data" \
        --name "iot-sensors.json" \
        --file "$ROOT_DIR/sample-data/iot-sensors.json" \
        --overwrite

    # Upload app logs
    az storage blob upload \
        --account-name "$STORAGE_ACCOUNT" \
        --container-name "sample-data" \
        --name "app-logs.json" \
        --file "$ROOT_DIR/sample-data/app-logs.json" \
        --overwrite

    print_info "Sample data uploaded!"
    print_info ""
    print_info "To ingest data into ADX, run the following KQL commands in the ADX Web UI:"
    print_info ""
    echo ".ingest into table IoTSensors ("
    echo "  h'https://${STORAGE_ACCOUNT}.blob.core.windows.net/sample-data/iot-sensors.json'"
    echo ") with (format='multijson', ingestionMappingReference='IoTSensorsJsonMapping')"
    echo ""
    echo ".ingest into table AppLogs ("
    echo "  h'https://${STORAGE_ACCOUNT}.blob.core.windows.net/sample-data/app-logs.json'"
    echo ") with (format='multijson', ingestionMappingReference='AppLogsJsonMapping')"
}

# Show outputs
outputs() {
    cd "$TERRAFORM_DIR"
    terraform output
}

# Show help
show_help() {
    echo "ADX POC Deployment Helper"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  check       Check prerequisites"
    echo "  init        Initialize Terraform"
    echo "  plan        Plan deployment"
    echo "  apply       Apply deployment"
    echo "  destroy     Destroy all resources"
    echo "  ingest      Ingest sample data"
    echo "  outputs     Show Terraform outputs"
    echo "  help        Show this help message"
    echo ""
    echo "Quick start:"
    echo "  $0 check"
    echo "  $0 init"
    echo "  $0 apply"
    echo "  $0 ingest"
}

# Main
case "${1:-help}" in
    check)
        check_prerequisites
        ;;
    init)
        check_prerequisites
        init
        ;;
    plan)
        plan
        ;;
    apply)
        apply
        ;;
    destroy)
        destroy
        ;;
    ingest|ingest-sample-data)
        ingest_sample_data
        ;;
    outputs)
        outputs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
