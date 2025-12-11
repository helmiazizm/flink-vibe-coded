# ============================================================================
# Flink Real-Time Data Platform - Makefile
# ============================================================================
# Docker Compose orchestration for Flink + MySQL CDC + Paimon + SeaweedFS
#
# Quick Start:
#   make setup-all    - Complete setup (JARs + venv + build)
#   make start-dev    - Start development environment
#   make status       - Check service status
# ============================================================================

# Declare all targets as phony (not files)
.PHONY: help setup-misc setup-venv setup-all build build-hive \
        start-dev start-prod start-hive stop-dev stop-prod stop-hive \
        restart-dev restart-prod restart-hive \
        status status-hive logs logs-follow logs-service \
        mysql flink sql-gateway hive-gateway \
        clean clean-soft

# Default target - show help
.DEFAULT_GOAL := help

# ============================================================================
# HELP
# ============================================================================

help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Flink Real-Time Data Platform"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "📦 SETUP & BUILD"
	@echo "  make setup-misc        Download JARs and generate configs"
	@echo "  make setup-venv        Create Python virtual environment"
	@echo "  make setup-all         Complete setup (misc + venv + build)"
	@echo "  make build             Build Docker images (Flink 1.20 + Java 17)"
	@echo "  make build-hive        Build Docker images (Flink 1.20 + Java 8 for Hive)"
	@echo ""
	@echo "🚀 SERVICE MANAGEMENT - Development"
	@echo "  make start-dev         Start development env (MySQL + local S3)"
	@echo "  make stop-dev          Stop development environment"
	@echo "  make restart-dev       Restart development environment"
	@echo ""
	@echo "🏭 SERVICE MANAGEMENT - Production"
	@echo "  make start-prod        Start production env (external S3)"
	@echo "  make stop-prod         Stop production environment"
	@echo "  make restart-prod      Restart production environment"
	@echo ""
	@echo "🐝 SERVICE MANAGEMENT - Hive (Java 8)"
	@echo "  make start-hive        Start Flink with Hive Metastore & HiveServer2"
	@echo "  make stop-hive         Stop Hive environment"
	@echo "  make restart-hive      Restart Hive environment"
	@echo "  make status-hive       Show Hive environment status"
	@echo ""
	@echo "📊 MONITORING"
	@echo "  make status            Show service status and access points"
	@echo "  make logs              Show recent logs from all services"
	@echo "  make logs-follow       Follow logs in real-time (Ctrl+C to exit)"
	@echo "  make logs-service SVC=<name>  Show logs for specific service"
	@echo ""
	@echo "🔌 ACCESS SERVICES"
	@echo "  make mysql             Connect to MySQL shell (testdb)"
	@echo "  make flink             Open Flink SQL client (interactive)"
	@echo "  make sql-gateway       Test SQL Gateway connection (REST API)"
	@echo "  make hive-gateway      Test HiveServer2 Gateway (Hive mode only)"
	@echo ""
	@echo "🧹 CLEANUP"
	@echo "  make clean             Full cleanup (containers + volumes + files)"
	@echo "  make clean-soft        Remove containers only (keep volumes)"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Services:"
	@echo "    • Flink Web UI:      http://localhost:8080"
	@echo "    • Flink SQL Gateway: http://localhost:8081"
	@echo "    • MySQL:             localhost:3306 (user: flink / flink123)"
	@echo "    • SeaweedFS Master:  localhost:9092"
	@echo "    • SeaweedFS Volume:  localhost:9093"
	@echo "    • SeaweedFS Filer:   localhost:9094"
	@echo "    • SeaweedFS S3:      localhost:9095"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ============================================================================
# SETUP & BUILD
# ============================================================================

setup-misc:
	@echo "📦 Downloading JARs and generating configuration files..."
	@bash scripts/setup.sh

setup-venv:
	@echo "🐍 Creating Python virtual environment..."
	@python -m virtualenv .venv
	@echo "📥 Installing Python dependencies..."
	@source .venv/bin/activate && \
		pip install --quiet uv && \
		uv pip install -r scripts/requirements.txt
	@echo "✓ Virtual environment ready at .venv/"
	@echo "  Activate with: source .venv/bin/activate"

setup-all: setup-misc setup-venv build
	@echo ""
	@echo "✓ Complete setup finished!"
	@echo "  Next: make start-dev"

build:
	@echo "🔨 Building Docker images (Flink 1.20 + Java 17)..."
	@docker compose build
	@echo "✓ Build complete!"

build-hive:
	@echo "🐝 Building Docker images (Flink 1.20 + Java 8 for Hive)..."
	@docker compose -f docker-compose-hive.yml build
	@echo "✓ Hive-compatible build complete!"

# ============================================================================
# SERVICE MANAGEMENT - Development
# ============================================================================

start-dev:
	@echo "🚀 Starting development environment..."
	@docker compose -f docker-compose.yml -f docker-compose-dev.yml --profile dev up -d
	@echo "⏳ Waiting for services to initialize..."
	@sleep 3
	@echo ""
	@make status

stop-dev:
	@echo "🛑 Stopping development environment..."
	@docker compose -f docker-compose.yml -f docker-compose-dev.yml --profile dev down
	@echo "✓ Development environment stopped"

restart-dev: stop-dev start-dev
	@echo "✓ Development environment restarted"

# ============================================================================
# SERVICE MANAGEMENT - Production
# ============================================================================

start-prod:
	@echo "🏭 Starting production environment..."
	@docker compose -f docker-compose.yml -f docker-compose-prod.yml up -d
	@echo "⏳ Waiting for services to initialize..."
	@sleep 3
	@echo ""
	@make status

stop-prod:
	@echo "🛑 Stopping production environment..."
	@docker compose -f docker-compose.yml -f docker-compose-prod.yml down
	@echo "✓ Production environment stopped"

restart-prod: stop-prod start-prod
	@echo "✓ Production environment restarted"

# ============================================================================
# SERVICE MANAGEMENT - Hive (Java 8)
# ============================================================================

start-hive:
	@echo "🐝 Starting Hive environment (Flink 1.20 + Java 8)..."
	@echo "   Includes: HiveServer2, Hive Metastore, PostgreSQL"
	@docker compose -f docker-compose-hive.yml up -d
	@echo "⏳ Waiting for services to initialize..."
	@sleep 3
	@echo ""
	@make status-hive

stop-hive:
	@echo "🛑 Stopping Hive environment..."
	@docker compose -f docker-compose-hive.yml down
	@echo "✓ Hive environment stopped"

restart-hive: stop-hive start-hive
	@echo "✓ Hive environment restarted"

status-hive:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Hive Environment Status (Java 8)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@docker compose -f docker-compose-hive.yml ps
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Hive Access Points"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  🌐 Flink Web UI:       http://localhost:8081"
	@echo "  🐝 HiveServer2:        jdbc:hive2://localhost:10000"
	@echo "  🗄️  Hive Metastore:     thrift://localhost:9083"
	@echo "  🗄️  MySQL:              mysql -h localhost -P 3306 -u flink -pflink123 testdb"
	@echo "  📦 SeaweedFS Master:   http://localhost:9092"
	@echo "  💾 SeaweedFS Volume:   http://localhost:9093"
	@echo "  📁 SeaweedFS Filer:    http://localhost:9094"
	@echo "  🪣 SeaweedFS S3:       http://localhost:9095"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ============================================================================
# MONITORING
# ============================================================================

status:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Service Status"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@docker compose ps
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Access Points"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  🌐 Flink Web UI:      http://localhost:8080"
	@echo "  🔌 Flink SQL Gateway: http://localhost:8081"
	@echo "  🗄️  MySQL:             mysql -h localhost -P 3306 -u flink -pflink123 testdb"
	@echo "  📦 SeaweedFS Master:  http://localhost:9092"
	@echo "  💾 SeaweedFS Volume:  http://localhost:9093"
	@echo "  📁 SeaweedFS Filer:   http://localhost:9094"
	@echo "  🪣 SeaweedFS S3:      http://localhost:9095"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

logs:
	@docker compose logs --tail=100

logs-follow:
	@echo "📋 Following logs (Ctrl+C to exit)..."
	@docker compose logs -f

logs-service:
	@if [ -z "$(SVC)" ]; then \
		echo "❌ Error: Please specify service name"; \
		echo "   Example: make logs-service SVC=jobmanager"; \
		echo "   Available: jobmanager, taskmanager, sql-gateway, mysql, master, volume, filer, s3"; \
		exit 1; \
	fi
	@docker compose logs -f $(SVC)

# ============================================================================
# ACCESS SERVICES
# ============================================================================

mysql:
	@echo "🗄️  Connecting to MySQL (testdb)..."
	@echo "   Credentials: user=flink, password=flink123"
	@docker exec -it mysql mysql -u flink -pflink123 testdb

flink:
	@echo "🔧 Opening Flink SQL Client..."
	@echo "   Tip: Use 'SHOW CATALOGS;' to see available catalogs"
	@docker exec -it jobmanager /opt/flink/bin/sql-client.sh

sql-gateway:
	@echo "🔌 Testing SQL Gateway connection (REST API)..."
	@curl -s http://localhost:8081/v1/info | python3 -m json.tool || \
		echo "❌ SQL Gateway not responding at http://localhost:8081"

hive-gateway:
	@echo "🐝 Testing HiveServer2 Gateway connection..."
	@echo "   Note: Requires beeline client installed locally"
	@echo "   Command: beeline -u jdbc:hive2://localhost:10000"
	@which beeline > /dev/null 2>&1 && \
		beeline -u jdbc:hive2://localhost:10000 -e "SHOW DATABASES;" || \
		echo "❌ beeline not found. Install with: brew install hive (macOS) or apt install hive (Linux)"

# ============================================================================
# CLEANUP
# ============================================================================

clean:
	@echo "🧹 Performing full cleanup..."
	@echo "  • Stopping and removing containers..."
	@docker compose down -v --remove-orphans
	@echo "  • Removing generated files..."
	@rm -rf jars/* mysql-init/* flink-jobs/*
	@if [ -d seaweedfs/master-data ] || [ -d seaweedfs/filer-data ] || [ -d seaweedfs/volume-data ]; then \
		echo "  • Removing SeaweedFS data (requires sudo)..."; \
		sudo rm -rf seaweedfs/master-data/* seaweedfs/filer-data/* seaweedfs/volume-data/*; \
	fi
	@echo "✓ Environment cleaned"
	@echo "  Next: make setup-all && make start-dev"

clean-soft:
	@echo "🧹 Soft cleanup (keeping volumes)..."
	@docker compose down --remove-orphans
	@echo "✓ Containers removed (volumes preserved)"

# ============================================================================
# HELPER TARGETS
# ============================================================================

# Check if a service is running
check-service:
	@if [ -z "$(SVC)" ]; then \
		echo "❌ Error: SVC variable not set"; \
		exit 1; \
	fi
	@docker compose ps | grep $(SVC) | grep -q "Up" || \
		(echo "❌ Service $(SVC) is not running"; exit 1)
