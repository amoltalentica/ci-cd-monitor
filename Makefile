# CI/CD Dashboard Makefile
# Production-grade operations for development and deployment

.PHONY: help build up down logs clean test lint format deploy

# Default target
help:
	@echo "CI/CD Dashboard - Available Commands"
	@echo "===================================="
	@echo "build    - Build Docker images"
	@echo "up       - Start all services"
	@echo "down     - Stop all services"
	@echo "logs     - View service logs"
	@echo "clean    - Clean up containers and images"
	@echo "test     - Run tests"
	@echo "lint     - Run linting"
	@echo "format   - Format code"
	@echo "deploy   - Deploy to production"
	@echo "status   - Show service status"
	@echo "health   - Check application health"

# Build Docker images
build:
	@echo "Building Docker images..."
	docker-compose build

# Start all services
up:
	@echo "Starting services..."
	docker-compose up -d

# Stop all services
down:
	@echo "Stopping services..."
	docker-compose down

# View service logs
logs:
	@echo "Viewing service logs..."
	docker-compose logs -f

# Clean up containers and images
clean:
	@echo "Cleaning up..."
	docker-compose down -v --rmi all
	docker system prune -f

# Run tests
test:
	@echo "Running tests..."
	docker-compose exec backend python -m pytest

# Run linting
lint:
	@echo "Running linting..."
	docker-compose exec backend flake8 app/
	docker-compose exec backend black --check app/

# Format code
format:
	@echo "Formatting code..."
	docker-compose exec backend black app/
	docker-compose exec backend isort app/

# Deploy to production
deploy:
	@echo "Deploying to production..."
	./deploy.sh

# Show service status
status:
	@echo "Service Status:"
	docker-compose ps

# Check application health
health:
	@echo "Checking application health..."
	@curl -f http://localhost:8000/api/health || echo "Health check failed"

# Backup database
backup:
	@echo "Creating database backup..."
	docker-compose exec db pg_dump -U $(shell grep POSTGRES_USER .env | cut -d '=' -f2) $(shell grep POSTGRES_DB .env | cut -d '=' -f2) > backup_$(shell date +%Y%m%d_%H%M%S).sql

# Restore database
restore:
	@echo "Restoring database from backup..."
	@read -p "Enter backup file name: " backup_file; \
	docker-compose exec -T db psql -U $(shell grep POSTGRES_USER .env | cut -d '=' -f2) $(shell grep POSTGRES_DB .env | cut -d '=' -f2) < $$backup_file

# Update application
update:
	@echo "Updating application..."
	git pull
	docker-compose up -d --build

# Monitor resources
monitor:
	@echo "System Resources:"
	@echo "================="
	@echo "Memory Usage:"
	@free -h
	@echo ""
	@echo "Disk Usage:"
	@df -h
	@echo ""
	@echo "Docker Resources:"
	@docker system df

# Security scan
security:
	@echo "Running security scan..."
	docker-compose exec backend bandit -r app/

# Performance test
perf:
	@echo "Running performance test..."
	@curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8000/api/health

# Development setup
dev-setup:
	@echo "Setting up development environment..."
	python -m venv venv
	. venv/bin/activate && pip install -r backend/requirements.txt
	@echo "Development environment ready!"

# Production setup
prod-setup:
	@echo "Setting up production environment..."
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Please configure .env file with your settings"; \
	fi
	@echo "Production environment ready!"
