#!/bin/bash

# CI/CD Dashboard Cleanup Script
# This script will remove all containers, images, volumes, and project files for a full cleanup.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

PROJECT_DIR="$(dirname "$0")"
PROJECT_NAME="cicd_dashboard"

log_warning "This will remove ALL containers, images, volumes, and project files for the CI/CD Dashboard!"
read -p "Are you sure you want to continue? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Cleanup cancelled."
    exit 0
fi

cd "$PROJECT_DIR"

log_info "Stopping and removing containers..."
docker-compose down --volumes --remove-orphans || true

log_info "Removing Docker images..."
IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E 'ci-cd-insight-dashboard|cicd_dashboard' || true)
if [[ -n "$IMAGES" ]]; then
    echo "$IMAGES" | xargs -r docker rmi -f
fi

log_info "Removing Docker volumes..."
VOLUMES=$(docker volume ls --format '{{.Name}}' | grep 'cicd_dashboard' || true)
if [[ -n "$VOLUMES" ]]; then
    echo "$VOLUMES" | xargs -r docker volume rm -f
fi

log_info "Removing Docker networks..."
NETWORKS=$(docker network ls --format '{{.Name}}' | grep 'cicd_dashboard' || true)
if [[ -n "$NETWORKS" ]]; then
    echo "$NETWORKS" | xargs -r docker network rm
fi

log_info "Removing project files (except this script)..."
find "$PROJECT_DIR" -mindepth 1 -not -name "cleanup.sh" -exec rm -rf {} +

log_info "Cleanup completed! All CI/CD Dashboard resources have been removed."
