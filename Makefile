# Makefile for Flink + MySQL + Paimon + SeaweedFS Stack
# Docker Compose orchestration for data pipeline and storage

.PHONY: help setup start stop restart logs mysql flink status clean build

# Default target
help:
	@echo "Flink + MySQL + Paimon + SeaweedFS Stack"
	@echo ""
	@echo "Setup & Build:"
	@echo "  make setup       - Download JARs and generate configuration files"
	@echo "  make build       - Build Docker images"
	@echo ""
	@echo "Service Management:"
	@echo "  make start       - Start all services"
	@echo "  make stop        - Stop all services"
	@echo "  make restart     - Restart all services"
	@echo "  make status      - Show service status"
	@echo "  make logs        - Follow service logs"
	@echo ""
	@echo "Access Services:"
	@echo "  make mysql       - Connect to MySQL shell"
	@echo "  make flink       - Open Flink SQL client"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean       - Clean all containers and volumes"
	@echo ""
	@echo "Services:"
	@echo "  - MySQL (3306)            - Data source with CDC"
	@echo "  - Flink JobManager (8081) - Stream processor"
	@echo "  - Flink TaskManager       - Worker nodes"
	@echo "  - SeaweedFS Master (9092) - Distributed storage"
	@echo "  - SeaweedFS Volume (9093) - Storage volumes"

# Run setup script
setup-misc:
	@bash scripts/setup.sh

setup-venv:
	@python -m virtualenv .venv
	@source .venv/bin/activate && \
		pip install uv && \
		uv pip install -r scripts/requirements.txt


# Build Docker images
build:
	@echo "Building Docker images..."
	docker compose build
	@echo "Build complete!"

# Start all services
start-dev:
	@echo "Starting all services..."
	docker compose -f docker-compose.yml -f docker-compose-dev.yml --profile dev up -d
	@echo "Waiting for services to be ready..."
	@echo "Services started. Paimon catalog will be initialized automatically."
	@make status

start-prod:
	@echo "Starting all services in production mode..."
	docker compose -f docker-compose.yml -f docker-compose-prod.yml up -d
	@echo "Waiting for services to be ready..."
	@echo "Services started. Paimon catalog will be initialized automatically."
	@make status

# Stop all services
stop-dev:
	@echo "Stopping all services..."
	docker compose -f docker-compose.yml -f docker-compose-dev.yml --profile dev down

stop-prod:
	@echo "Stopping all services..."
	docker compose -f docker-compose.yml -f docker-compose-prod.yml down

# Restart all services
restart:
	@echo "Restarting all services..."
	docker compose restart
	@echo "Waiting for services to be ready..."
	sleep 20
	@echo "Services restarted. Paimon catalog initialization may be in progress."
	@make status

# Show service status
status:
	@echo "Service Status:"
	@echo "==============="
	docker compose ps
	@echo ""
	@echo "Access Points:"
	@echo "  Flink Web UI: http://localhost:8081"
	@echo "  MySQL: localhost:3306 (user: flink, password: flink123)"
	@echo "  SeaweedFS Master: localhost:9092"
	@echo "  SeaweedFS Volume: localhost:9093"

# Follow service logs
logs:
	docker compose logs -f

# Connect to MySQL shell
mysql:
	docker exec -it mysql mysql -u flink -pflink123 testdb

# Open Flink SQL client
flink:
	docker exec -it jobmanager /opt/flink/bin/sql-client.sh

# Clean up all containers and volumes
clean:
	@echo "Cleaning up environment..."
	docker compose down -v --remove-orphans
	@echo "Removing generated files..."
	rm -rf jars/* mysql-init/* flink-jobs/*
	sudo rm -rf seaweedfs/master-data/* seaweedfs/filer-data/* seaweedfs/volume-data/*
	@echo "Environment cleaned."
	rm -rf jars/* mysql-init/* flink-jobs/*
	sudo rm -rf seaweedfs/master-data/* seaweedfs/filer-data/* seaweedfs/volume-data/*
	@echo "Environment cleaned."
