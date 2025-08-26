#!/bin/bash

# Production CI/CD Dashboard Deployment Script
# Optimized for t2.micro EC2 instances

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration
PROJECT_NAME="cicd-dashboard"
DOCKER_COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# Validation functions
validate_environment() {
    log_step "Validating environment..."
    
    # Check if we're in the right directory
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        log_error "docker-compose.yml not found. Please run this script from the project directory."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check environment file
    if [[ ! -f "$ENV_FILE" ]]; then
        log_warning ".env file not found. Creating from template..."
        if [[ -f "env.production" ]]; then
            cp env.production .env
            log_warning "Created .env file. Please edit it with your configuration:"
            echo "  - GITHUB_TOKEN"
            echo "  - GITHUB_OWNER"
            echo "  - GITHUB_REPO"
            echo "  - SLACK_WEBHOOK_URL (optional)"
            echo ""
            read -p "Press Enter after you've configured the .env file..."
        else
            log_error "env.production file not found!"
            exit 1
        fi
    fi
    
    log_info "Environment validation completed"
}

cleanup_containers() {
    log_step "Cleaning up existing containers..."
    
    # Stop and remove existing containers
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # Remove dangling images
    docker image prune -f 2>/dev/null || true
    
    log_info "Cleanup completed"
}

build_and_start() {
    log_step "Building and starting services..."
    
    # Build images
    log_info "Building Docker images..."
    docker-compose build --no-cache
    
    # Start services
    log_info "Starting services..."
    docker-compose up -d
    
    log_info "Services started successfully"
}

wait_for_services() {
    log_step "Waiting for services to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Checking service health (attempt $attempt/$max_attempts)..."
        
        # Check if all services are running
        if docker-compose ps | grep -q "Up"; then
            # Check database health
            if docker-compose exec -T db pg_isready -U ${POSTGRES_USER:-cicd_user} -d ${POSTGRES_DB:-cicd_dashboard} &>/dev/null; then
                log_info "✅ Database is ready"
                break
            fi
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "❌ Services failed to start within expected time"
            docker-compose logs
            exit 1
        fi
        
        sleep 10
        ((attempt++))
    done
    
    log_info "All services are ready!"
}

test_application() {
    log_step "Testing application endpoints..."
    
    # Test backend health
    log_info "Testing backend health..."
    if curl -s -f http://localhost:8000/api/health > /dev/null; then
        log_info "✅ Backend API is healthy"
    else
        log_warning "⚠️  Backend health check failed"
    fi
    
    # Test frontend
    log_info "Testing frontend..."
    if curl -s -f http://localhost/health > /dev/null; then
        log_info "✅ Frontend is responding"
    else
        log_warning "⚠️  Frontend health check failed"
    fi
    
    # Test main application
    log_info "Testing main application..."
    if curl -s -f http://localhost/ > /dev/null; then
        log_info "✅ Main application is accessible"
    else
        log_warning "⚠️  Main application check failed"
    fi
}

display_status() {
    log_step "Displaying service status..."
    
    echo ""
    echo "🎉 Deployment completed successfully!"
    echo "====================================="
    echo ""
    
    # Get public IP
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
    
    echo "Access your CI/CD Dashboard:"
    echo "  🌐 Frontend: http://$PUBLIC_IP"
    echo "  🔧 API Docs: http://$PUBLIC_IP/docs"
    echo "  💚 Health Check: http://$PUBLIC_IP/api/health"
    echo ""
    
    echo "Service Status:"
    docker-compose ps
    echo ""
    
    echo "Useful commands:"
    echo "  📊 View logs: docker-compose logs -f"
    echo "  🔄 Restart: docker-compose restart"
    echo "  🛑 Stop: docker-compose down"
    echo "  📈 Status: docker-compose ps"
    echo "  🧹 Cleanup: docker-compose down --volumes --remove-orphans"
    echo ""
    
    log_info "Deployment completed! 🚀"
}

# Main execution
main() {
    echo "🚀 Starting Production CI/CD Dashboard Deployment"
    echo "================================================="
    echo ""
    
    validate_environment
    cleanup_containers
    build_and_start
    wait_for_services
    test_application
    display_status
}

# Run main function
main "$@"
