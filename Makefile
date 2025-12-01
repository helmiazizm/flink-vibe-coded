# Makefile for Flink + MySQL + Paimon + SeaweedFS Stack
# Docker Compose orchestration for data pipeline and storage

.PHONY: help setup start stop restart logs mysql flink status clean

# Default target
help:
	@echo "Flink + MySQL + Paimon + SeaweedFS Stack"
	@echo ""
	@echo "Service Management:"
	@echo "  make setup         - Download JARs, create directories, and build images"
	@echo "  make download-jars - Download required Flink connectors and dependencies"
	@echo "  make start         - Start all services"
	@echo "  make stop          - Stop all services"
	@echo "  make restart       - Restart all services"
	@echo "  make logs          - Follow service logs"
	@echo "  make status        - Show service status"
	@echo ""
	@echo "Access Services:"
	@echo "  make mysql         - Connect to MySQL shell"
	@echo "  make flink         - Open Flink SQL client"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean         - Clean all containers and volumes"
	@echo ""
	@echo "Services:"
	@echo "  - MySQL (3306)            - Data source with CDC"
	@echo "  - Flink JobManager (8081) - Stream processor"
	@echo "  - Flink TaskManager       - Worker nodes"
	@echo "  - SeaweedFS Master (9092) - Distributed storage"
	@echo "  - SeaweedFS Volume (9093) - Storage volumes"

# Initialize directories and build images
setup: download-jars
	@echo "Building Docker images..."
	docker compose build
	@echo "Setup complete!"

# Download required JAR files
download-jars:
	@echo "Setting up directories..."
	mkdir -p jars flink-storage mysql-init seaweedfs/master-data seaweedfs/volume-data
	@echo "Downloading MySQL Connector/J..."
	cd jars && curl -O https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/9.4.0/mysql-connector-j-9.4.0.jar 2>/dev/null
	@echo "Downloading Flink MySQL CDC connector..."
	cd jars && curl -O https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-mysql-cdc/3.5.0/flink-sql-connector-mysql-cdc-3.5.0.jar 2>/dev/null
	@echo "Downloading Flink JDBC connector..."
	cd jars && curl -O https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/3.3.0-1.20/flink-connector-jdbc-3.3.0-1.20.jar 2>/dev/null
	@echo "Downloading Apache Paimon Flink connector..."
	cd jars && curl -O https://repo1.maven.org/maven2/org/apache/paimon/paimon-flink-2.1/1.3.1/paimon-flink-2.1-1.3.1.jar 2>/dev/null
	@echo "Downloading Flink CDC Paimon connector..."
	cd jars && curl -O https://repo1.maven.org/maven2/org/apache/flink/flink-cdc-pipeline-connector-paimon/3.5.0/flink-cdc-pipeline-connector-paimon-3.5.0.jar 2>/dev/null
	@echo "Downloading Paimon OSS connector..."
	cd jars && curl -O https://repo.maven.apache.org/maven2/org/apache/paimon/paimon-oss/1.3.1/paimon-oss-1.3.1.jar 2>/dev/null
	@echo "Downloading Flink OSS FS Hadoop..."
	cd jars && curl -O https://repo1.maven.org/maven2/org/apache/flink/flink-oss-fs-hadoop/2.1.1/flink-oss-fs-hadoop-2.1.1.jar 2>/dev/null
	@echo "Downloading Paimon S3 connector..."
	cd jars && curl -O https://repo.maven.apache.org/maven2/org/apache/paimon/paimon-s3/1.3.1/paimon-s3-1.3.1.jar 2>/dev/null
	@echo "Downloading Flink S3 FS Hadoop..."
	cd jars && curl -O https://repo1.maven.org/maven2/org/apache/flink/flink-s3-fs-hadoop/2.1.1/flink-s3-fs-hadoop-2.1.1.jar 2>/dev/null
	@echo "All JARs downloaded to ./jars"

# Start all services
start:
	@echo "Starting all services..."
	docker compose up -d
	@echo "Waiting for services to be ready..."
	sleep 10
	@make status

# Stop all services
stop:
	@echo "Stopping all services..."
	docker compose down

# Restart all services
restart:
	@echo "Restarting all services..."
	docker compose restart
	@echo "Waiting for services to be ready..."
	sleep 10
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
	rm -rf jars/* mysql-init/* flink-storage/* seaweedfs/master-data/* seaweedfs/volume-data/*
	@echo "Environment cleaned."
