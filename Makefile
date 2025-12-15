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
        mysql flink sql-gateway hive-gateway zookeeper \
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
	@echo "  make zookeeper         Check Zookeeper status and HA nodes"
	@echo ""
	@echo "🧹 CLEANUP"
	@echo "  make clean             Full cleanup (containers + volumes + files)"
	@echo "  make clean-soft        Remove containers only (keep volumes)"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Services:"
	@echo "    • Zookeeper:         localhost:2181 (HA coordination)"
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
	@. .venv/bin/activate && pip install --quiet uv && uv pip install -r scripts/requirements.txt
	@echo "✓ Virtual environment ready at .venv/"
	@echo "  Activate with: source .venv/bin/activate || . .venv/bin/activate"

setup-all: setup-misc setup-venv build
	@echo ""
	@echo "✓ Complete setup finished!"
	@echo "  Next: make start-dev"

build:
	@echo "🔨 Building Docker images (Flink 1.20 + Java 17)..."
	@docker compose -f docker/docker-compose.yml build
	@echo "✓ Build complete!"

build-hive:
	@echo "🐝 Building Docker images (Flink 1.20 + Java 8 for Hive)..."
	@docker compose -f docker/docker-compose-hive.yml build
	@echo "✓ Hive-compatible build complete!"

# ============================================================================
# SERVICE MANAGEMENT - Development
# ============================================================================

ZOOKEEPER_DEV_FLAG_FILE := .zookeeper_enabled
FLINK_DEV_CONFIG_FILE_TEMPLATE := ./flink-config/flink-conf-dev.yml
FLINK_DEV_CONFIG_FILE_STARTUP := ./flink-config/flink-conf-dev-startup.yml

start-dev:
	@echo "🚀 Starting development environment..."
	@cp $(FLINK_DEV_CONFIG_FILE_TEMPLATE) $(FLINK_DEV_CONFIG_FILE_STARTUP);
	@read -p "Use Zookeeper? (y/n): " use_zookeeper && \
	if [ "$$use_zookeeper" = "y" ] || [ "$$use_zookeeper" = "Y" ]; then \
		echo "true" > $(ZOOKEEPER_DEV_FLAG_FILE); \
		echo "📝 Zookeeper enabled"; \
		echo "" >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		echo "high-availability:" >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		echo '  type: "zookeeper"' >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		echo '  storageDir: "s3://flink-state-persistent/ha/"' >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		echo "  zookeeper:" >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		echo '    quorum: "zookeeper:2181"' >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		echo "    path:" >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		echo '      root: "/flink"' >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		echo "    client:" >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		echo '      session-timeout: "60s"' >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		echo '      connection-timeout: "15s"' >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		echo '      retry-wait: "5s"' >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		echo "      max-retry-attempts: 3" >> $(FLINK_DEV_CONFIG_FILE_STARTUP); \
		docker compose -f docker/docker-compose.yml -f docker/docker-compose-dev.yml -f docker/docker-compose-zookeeper.yml up -d; \
	else \
		echo "false" > $(ZOOKEEPER_DEV_FLAG_FILE); \
		echo "📝 Zookeeper disabled"; \
		docker compose -f docker/docker-compose.yml -f docker/docker-compose-dev.yml up -d; \
	fi
	@echo "⏳ Waiting for services to initialize..."
	@sleep 3
	@echo ""
	@make status-dev

stop-dev:
	@echo "🛑 Stopping development environment..."
	@if [ -f $(ZOOKEEPER_DEV_FLAG_FILE) ] && [ "$$(cat $(ZOOKEEPER_DEV_FLAG_FILE))" = "true" ]; then \
		echo "📝 Stopping with Zookeeper..."; \
		docker compose -f docker/docker-compose.yml -f docker/docker-compose-dev.yml -f docker/docker-compose-zookeeper.yml down; \
	else \
		echo "📝 Stopping without Zookeeper..."; \
		docker compose -f docker/docker-compose.yml -f docker/docker-compose-dev.yml down; \
	fi
	@rm -f $(ZOOKEEPER_DEV_FLAG_FILE) $(FLINK_DEV_CONFIG_FILE_STARTUP)
	@echo "✓ Development environment stopped"

restart-dev: stop-dev start-dev
	@echo "✓ Development environment restarted"

# ============================================================================
# SERVICE MANAGEMENT - Production
# ============================================================================

start-prod:
	@echo "🏭 Starting production environment..."
	@docker compose -f docker/docker-compose.yml -f docker/docker-compose-prod.yml -f docker/docker-compose-zookeeper.yml up -d
	@echo "⏳ Waiting for services to initialize..."
	@sleep 3
	@echo ""
	@make status-prod

stop-prod:
	@echo "🛑 Stopping production environment..."
	@docker compose -f docker/docker-compose.yml -f docker/docker-compose-prod.yml -f docker/docker-compose-zookeeper.yml down
	@echo "✓ Production environment stopped"

restart-prod: stop-prod start-prod
	@echo "✓ Production environment restarted"

# ============================================================================
# SERVICE MANAGEMENT - Hive (Java 8)
# ============================================================================

# File to store zookeeper usage choice for Hive
ZOOKEEPER_HIVE_FLAG_FILE := .zookeeper_hive_enabled
FLINK_HIVE_CONFIG_FILE_TEMPLATE := ./flink-config/flink-conf-hive.yml
FLINK_HIVE_CONFIG_FILE_STARTUP := ./flink-config/flink-conf-hive-startup.yml

start-hive:
	@echo "🐝 Starting Hive environment (Flink 1.20 + Java 8)..."
	@echo "   Includes: HiveServer2, Hive Metastore, PostgreSQL"
	@cp $(FLINK_HIVE_CONFIG_FILE_TEMPLATE) $(FLINK_HIVE_CONFIG_FILE_STARTUP);
	@read -p "Use Zookeeper for high availability? (y/n): " use_zookeeper && \ 
	if [ "$$use_zookeeper" = "y" ] || [ "$$use_zookeeper" = "Y" ]; then \
		echo "true" > $(ZOOKEEPER_HIVE_FLAG_FILE); \
		echo "📝 Zookeeper enabled for Hive environment"; \
		echo "" >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		echo "high-availability:" >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		echo '  type: "zookeeper"' >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		echo '  storageDir: "s3://flink-state-persistent/ha/"' >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		echo "  zookeeper:" >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		echo '    quorum: "zookeeper:2181"' >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		echo "    path:" >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		echo '      root: "/flink"' >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		echo "    client:" >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		echo '      session-timeout: "60s"' >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		echo '      connection-timeout: "15s"' >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		echo '      retry-wait: "5s"' >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		echo "      max-retry-attempts: 3" >> $(FLINK_HIVE_CONFIG_FILE_STARTUP); \
		docker compose -f docker/docker-compose-hive.yml -f docker/docker-compose-dev.yml -f docker/docker-compose-zookeeper.yml up -d; \
	else \
		echo "false" > $(ZOOKEEPER_HIVE_FLAG_FILE); \
		echo "📝 Zookeeper disabled for Hive environment"; \
		docker compose -f docker/docker-compose-hive.yml -f docker/docker-compose-dev.yml up -d; \
	fi
	@echo "⏳ Waiting for services to initialize..."
	@sleep 3
	@echo ""
	@make status-hive

stop-hive:
	@echo "🛑 Stopping Hive environment..."
	@if [ -f $(ZOOKEEPER_HIVE_FLAG_FILE) ] && [ "$$(cat $(ZOOKEEPER_HIVE_FLAG_FILE))" = "true" ]; then \
		echo "📝 Stopping Hive environment with Zookeeper..."; \
		docker compose -f docker/docker-compose-hive.yml -f docker/docker-compose-dev.yml -f docker/docker-compose-zookeeper.yml down; \
	else \
		echo "📝 Stopping Hive environment without Zookeeper..."; \
		docker compose -f docker/docker-compose-hive.yml -f docker/docker-compose-dev.yml down; \
	fi
	@rm -f $(ZOOKEEPER_HIVE_FLAG_FILE) $(FLINK_HIVE_CONFIG_FILE_STARTUP)
	@echo "✓ Hive environment stopped"

restart-hive: stop-hive start-hive
	@echo "✓ Hive environment restarted"

status-hive:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Hive Environment Status (Java 8)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@if [ -f $(ZOOKEEPER_HIVE_FLAG_FILE) ] && [ "$$(cat $(ZOOKEEPER_HIVE_FLAG_FILE))" = "true" ]; then \
		docker compose -f docker/docker-compose-hive.yml -f docker/docker-compose-dev.yml -f docker/docker-compose-zookeeper.yml ps; \
	else \
		docker compose -f docker/docker-compose-hive.yml -f docker/docker-compose-dev.yml ps; \
	fi
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Hive Access Points"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@if [ -f $(ZOOKEEPER_HIVE_FLAG_FILE) ] && [ "$$(cat $(ZOOKEEPER_HIVE_FLAG_FILE))" = "true" ]; then \
		echo "  🔷 Zookeeper:          localhost:2181 (HA coordination)"; \
	fi
	@echo "  🌐 Flink Web UI:       http://localhost:8080"
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

status-dev:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Service Status"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@if [ -f $(ZOOKEEPER_DEV_FLAG_FILE) ] && [ "$$(cat $(ZOOKEEPER_DEV_FLAG_FILE))" = "true" ]; then \
		docker compose -f docker/docker-compose.yml -f docker/docker-compose-dev.yml -f docker/docker-compose-zookeeper.yml ps; \
	else \
		docker compose -f docker/docker-compose.yml -f docker/docker-compose-dev.yml ps; \
	fi
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

status-prod:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Service Status"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@docker compose -f docker/docker-compose.yml -f docker/docker-compose-prod.yml -f docker/docker-compose-zookeeper.yml ps
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Access Points"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  🌐 Flink Web UI:      http://localhost:8080"
	@echo "  🔌 Flink SQL Gateway: http://localhost:8081"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

logs:
	@if [ -f $(ZOOKEEPER_DEV_FLAG_FILE) ] && [ "$$(cat $(ZOOKEEPER_DEV_FLAG_FILE))" = "true" ]; then \
		docker compose -f docker/docker-compose.yml -f docker/docker-compose-dev.yml -f docker/docker-compose-zookeeper.yml logs --tail=100; \
	else \
		docker compose -f docker/docker-compose.yml -f docker/docker-compose-dev.yml logs --tail=100; \
	fi

logs-follow:
	@echo "📋 Following logs (Ctrl+C to exit)..."
	@if [ -f $(ZOOKEEPER_DEV_FLAG_FILE) ] && [ "$$(cat $(ZOOKEEPER_DEV_FLAG_FILE))" = "true" ]; then \
		docker compose -f docker/docker-compose.yml -f docker/docker-compose-dev.yml -f docker/docker-compose-zookeeper.yml logs -f; \
	else \
		docker compose -f docker/docker-compose.yml -f docker/docker-compose-dev.yml logs -f; \
	fi

logs-service:
	@if [ -z "$(SVC)" ]; then \
		echo "❌ Error: Please specify service name"; \
		echo "   Example: make logs-service SVC=jobmanager"; \
		echo "   Available: jobmanager, taskmanager, sql-gateway, mysql, master, volume, filer, s3"; \
		exit 1; \
	fi
	@docker compose -f docker/docker-compose.yml logs -f $(SVC)

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

zookeeper:
	@echo "🔷 Checking Zookeeper status..."
	@docker exec -it zookeeper bash -c "echo ruok | nc localhost 2181" 2>/dev/null && \
		echo "✓ Zookeeper is healthy" || \
		echo "❌ Zookeeper is not responding"
	@echo ""
	@echo "📋 Flink HA nodes in Zookeeper:"
	@docker exec -it zookeeper zkCli.sh ls /flink 2>/dev/null | grep -v "Connecting\|WATCHER\|WatchedEvent" || \
		echo "❌ Cannot connect to Zookeeper or /flink path doesn't exist"

# ============================================================================
# CLEANUP
# ============================================================================

clean:
	@echo "🧹 Performing full cleanup..."
	@echo "  • Stopping all environments..."
	@docker compose -f docker/docker-compose.yml -f docker/docker-compose-dev.yml -f docker/docker-compose-zookeeper.yml down -v --remove-orphans 2>/dev/null || true
	@docker compose -f docker/docker-compose.yml -f docker/docker-compose-prod.yml -f docker/docker-compose-zookeeper.yml down -v --remove-orphans 2>/dev/null || true
	@docker compose -f docker/docker-compose-hive.yml -f docker/docker-compose-dev.yml -f docker/docker-compose-zookeeper.yml down -v --remove-orphans 2>/dev/null || true
	@echo "  • Removing generated files..."
	@rm -rf jars/*
	@rm -f $(ZOOKEEPER_DEV_FLAG_FILE) $(ZOOKEEPER_HIVE_FLAG_FILE)
	@rm -f $(FLINK_DEV_CONFIG_FILE_BACKUP) $(FLINK_HIVE_CONFIG_FILE_BACKUP)
	@if [ -d seaweedfs/master-data ] || [ -d seaweedfs/filer-data ] || [ -d seaweedfs/volume-data ]; then \
		echo "  • Removing SeaweedFS data (requires sudo)..."; \
		sudo rm -rf seaweedfs/master-data/* seaweedfs/filer-data/* seaweedfs/volume-data/*; \
	fi
	@echo "✓ Environment cleaned"
	@echo "  Next: make setup-all && make start-dev"

clean-soft:
	@echo "🧹 Soft cleanup (keeping volumes)..."
	@docker compose -f docker/docker-compose.yml down --remove-orphans
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
	@docker compose -f docker/docker-compose.yml ps | grep $(SVC) | grep -q "Up" || \
		(echo "❌ Service $(SVC) is not running"; exit 1)
