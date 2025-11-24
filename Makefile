# Makefile for Flink + MySQL + Paimon Data Pipeline
# Provides easy commands for setting up, running, and managing the environment

.PHONY: help setup start stop restart clean logs shell mysql flink query test status warehouse data backup restore download-connectors dev-setup prod-deploy monitor quick

# Default target
help:
	@echo "Flink + MySQL + Paimon Data Pipeline"
	@echo ""
	@echo "Available commands:"
	@echo "  setup      - Set up entire environment from scratch"
	@echo "  start      - Start all services (MySQL + Flink)"
	@echo "  stop       - Stop all services"
	@echo "  restart    - Restart all services"
	@echo "  clean      - Clean up containers, volumes, and downloaded files"
	@echo "  logs       - Show logs for all services"
	@echo "  mysql      - Connect to MySQL shell"
	@echo "  flink      - Connect to Flink SQL client"
	@echo "  query      - Run Paimon data query"
	@echo "  test       - Run complete pipeline test"
	@echo "  status     - Show status of all services"
	@echo "  warehouse  - List Paimon warehouse contents"
	@echo "  data       - Insert sample data into Paimon tables"
	@echo "  backup     - Create backup of MySQL and Paimon data"
	@echo "  restore    - Restore data from backup"
	@echo ""
	@echo "Examples:"
	@echo "  make setup     # Set up everything from scratch"
	@echo "  make start     # Start all services"
	@echo "  make query     # Query Paimon tables"
	@echo "  make logs      # View service logs"

# Set up everything from scratch
setup:
	@echo "🚀 Setting up Flink + MySQL + Paimon environment..."
	@echo "Creating directories..."
	mkdir -p jars mysql-init flink-jobs flink-storage backup
	@echo "Downloading MySQL connector..."
	cd jars && curl -s -O https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.0.33/mysql-connector-j-8.0.33.jar
	@echo "Downloading Flink JDBC connector..."
	cd jars && curl -s -O https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/3.1.1-1.18/flink-connector-jdbc-3.1.1-1.18.jar
	@echo "Downloading Flink Debezium connector..."
	cd jars && curl -s -O https://repo1.maven.org/maven2/org/apache/flink/flink-connector-debezium/2.3.0-1.17/flink-connector-debezium-2.3.0-1.17.jar
	@echo "Downloading Debezium MySQL connector..."
	cd jars && curl -s -O https://repo1.maven.org/maven2/io/debezium/debezium-connector-mysql/2.5.4.Final/debezium-connector-mysql-2.5.4.Final.jar
	@echo "Downloading Paimon Flink connector..."
	cd jars && curl -s -O https://repo1.maven.org/maven2/org/apache/paimon/paimon-flink-1.18/0.8.0/paimon-flink-1.18-0.8.0.jar
	@echo "Downloading Hadoop dependencies..."
	cd jars && curl -s -O https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-common/3.3.6/hadoop-common-3.3.6.jar
	cd jars && curl -s -O https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.6/hadoop-aws-3.3.6.jar
	@echo "Skipping JindoSDK download (uncomment in Makefile to enable)..."
	# tar -xzf jindosdk-6.10.2-linux.tar.gz
	# cp jindosdk-6.10.2-linux/lib/*.jar jars/
	# cp jindosdk-6.10.2-linux/plugins/flink/*.jar jars/
	# rm -rf jindosdk-6.10.2-linux jindosdk-6.10.2-linux.tar.gz
	@echo "Creating MySQL initialization script..."
	echo "CREATE DATABASE IF NOT EXISTS testdb; USE testdb;" > mysql-init/init.sql
	echo "CREATE TABLE IF NOT EXISTS users (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(100) NOT NULL, email VARCHAR(100) UNIQUE NOT NULL, age INT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP);" >> mysql-init/init.sql
	echo "INSERT INTO users (name, email, age) VALUES ('Alice Johnson', 'alice@example.com', 28), ('Bob Smith', 'bob@example.com', 35), ('Charlie Brown', 'charlie@example.com', 42), ('Diana Prince', 'diana@example.com', 30), ('Eve Wilson', 'eve@example.com', 25);" >> mysql-init/init.sql
	echo "CREATE TABLE IF NOT EXISTS orders (id INT PRIMARY KEY AUTO_INCREMENT, user_id INT, product_name VARCHAR(200), quantity INT, price DECIMAL(10,2), order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (user_id) REFERENCES users(id));" >> mysql-init/init.sql
	echo "INSERT INTO orders (user_id, product_name, quantity, price) VALUES (1, 'Laptop', 1, 999.99), (2, 'Mouse', 2, 25.50), (1, 'Keyboard', 1, 75.00), (3, 'Monitor', 1, 299.99), (4, 'Headphones', 1, 150.00), (5, 'USB Cable', 3, 10.00);" >> mysql-init/init.sql
	@echo "Creating Flink SQL job scripts..."
	echo "SET sql-client.execution.result-mode=TABLEAU;" > flink-jobs/mysql-to-paimon.sql
	echo "CREATE CATALOG paimon_catalog WITH ('type' = 'paimon', 'warehouse' = 'file:///opt/flink/storage/paimon_warehouse');" >> flink-jobs/mysql-to-paimon.sql
	echo "USE CATALOG paimon_catalog;" >> flink-jobs/mysql-to-paimon.sql
	echo "USE testdb;" >> flink-jobs/mysql-to-paimon.sql
	echo "CREATE TABLE IF NOT EXISTS users (id INT, name STRING, email STRING, age INT, created_at TIMESTAMP, updated_at TIMESTAMP, PRIMARY KEY (id) NOT ENFORCED) WITH ('connector' = 'paimon', 'file.format' = 'parquet', 'write-mode' = 'append-only');" >> flink-jobs/mysql-to-paimon.sql
	echo "CREATE TABLE IF NOT EXISTS orders (id INT, user_id INT, product_name STRING, quantity INT, price DECIMAL(10,2), order_date TIMESTAMP, PRIMARY KEY (id) NOT ENFORCED) WITH ('connector' = 'paimon', 'file.format' = 'parquet', 'write-mode' = 'append-only');" >> flink-jobs/mysql-to-paimon.sql
	echo "INSERT INTO users VALUES (1, 'Alice Johnson', 'alice@example.com', 28, TIMESTAMP '2024-01-01 10:00:00', TIMESTAMP '2024-01-01 10:00:00');" >> flink-jobs/mysql-to-paimon.sql
	echo "INSERT INTO users VALUES (2, 'Bob Smith', 'bob@example.com', 35, TIMESTAMP '2024-01-02 11:00:00', TIMESTAMP '2024-01-02 11:00:00');" >> flink-jobs/mysql-to-paimon.sql
	echo "INSERT INTO users VALUES (3, 'Charlie Brown', 'charlie@example.com', 42, TIMESTAMP '2024-01-03 12:00:00', TIMESTAMP '2024-01-03 12:00:00');" >> flink-jobs/mysql-to-paimon.sql
	echo "INSERT INTO users VALUES (4, 'Diana Prince', 'diana@example.com', 30, TIMESTAMP '2024-01-04 13:00:00', TIMESTAMP '2024-01-04 13:00:00');" >> flink-jobs/mysql-to-paimon.sql
	echo "INSERT INTO users VALUES (5, 'Eve Wilson', 'eve@example.com', 25, TIMESTAMP '2024-01-05 14:00:00', TIMESTAMP '2024-01-05 14:00:00');" >> flink-jobs/mysql-to-paimon.sql
	echo "INSERT INTO orders VALUES (1, 1, 'Laptop', 1, 999.99, TIMESTAMP '2024-01-10 09:00:00');" >> flink-jobs/mysql-to-paimon.sql
	echo "INSERT INTO orders VALUES (2, 2, 'Mouse', 2, 25.50, TIMESTAMP '2024-01-11 10:00:00');" >> flink-jobs/mysql-to-paimon.sql
	echo "INSERT INTO orders VALUES (3, 1, 'Keyboard', 1, 75.00, TIMESTAMP '2024-01-12 11:00:00');" >> flink-jobs/mysql-to-paimon.sql
	echo "INSERT INTO orders VALUES (4, 3, 'Monitor', 1, 299.99, TIMESTAMP '2024-01-13 12:00:00');" >> flink-jobs/mysql-to-paimon.sql
	echo "INSERT INTO orders VALUES (5, 4, 'Headphones', 1, 150.00, TIMESTAMP '2024-01-14 13:00:00');" >> flink-jobs/mysql-to-paimon.sql
	echo "INSERT INTO orders VALUES (6, 5, 'USB Cable', 3, 10.00, TIMESTAMP '2024-01-15 14:00:00');" >> flink-jobs/mysql-to-paimon.sql
	@echo "✅ Setup complete! Use 'make start' to begin."

# Start all services
start:
	@echo "🚀 Starting all services..."
	docker-compose up -d
	@echo "⏳ Waiting for services to be ready..."
	sleep 30
	@echo "✅ Services started!"
	@echo "🌐 Flink Web UI: http://localhost:8081"
	@echo "📊 MySQL: localhost:3306 (user: flink, password: flink123)"
	@make status

# Stop all services
stop:
	@echo "🛑 Stopping all services..."
	docker-compose down
	@echo "✅ Services stopped."

# Restart all services
restart:
	@echo "🔄 Restarting all services..."
	docker-compose restart
	@echo "⏳ Waiting for services to be ready..."
	sleep 20
	@echo "✅ Services restarted!"
	@make status

# Clean up everything
clean:
	@echo "🧹 Cleaning up environment..."
	docker-compose down -v --remove-orphans
	docker system prune -f
	rm -rf jars/* mysql-init/* flink-storage/* flink-jobs/* backup/*
	@echo "✅ Environment cleaned."

# Show logs for all services
logs:
	docker-compose logs -f

# Connect to MySQL shell
mysql:
	docker exec -it flink_dev-mysql-1 mysql -u flink -pflink123 testdb

# Connect to Flink SQL client
flink:
	docker exec -it flink_dev-jobmanager-1 /opt/flink/bin/sql-client.sh

# Query Paimon data
query:
	@echo "📊 Querying Paimon tables..."
	docker exec -i flink_dev-jobmanager-1 /opt/flink/bin/sql-client.sh -c "SET sql-client.execution.result-mode=TABLEAU; CREATE CATALOG IF NOT EXISTS paimon_catalog WITH ('type' = 'paimon', 'warehouse' = 'file:///opt/flink/storage/paimon_warehouse'); USE CATALOG paimon_catalog; SHOW DATABASES;"

# Run complete pipeline test
test:
	@echo "🧪 Running complete pipeline test..."
	./final-paimon-test.sh

# Show status of all services
status:
	@echo "📊 Service Status:"
	@echo "=================="
	docker-compose ps
	@echo ""
	@echo "🌐 URLs:"
	@echo "Flink Web UI: http://localhost:8081"
	@echo "MySQL: localhost:3306"

# List Paimon warehouse contents
warehouse:
	@echo "📂 Paimon Warehouse Contents:"
	@echo "=========================="
	docker exec flink_dev-jobmanager-1 find /opt/flink/storage/paimon_warehouse -type f -name "*.parquet" -exec ls -lh {} \; 2>/dev/null || echo "No data files found. Run 'make data' to create sample data."

# Insert sample data into Paimon tables
data:
	@echo "📝 Inserting sample data into Paimon tables..."
	./final-paimon-test.sh

# Download additional connectors
download-connectors:
	@echo "📦 Downloading additional connectors..."
	cd jars && curl -s -O https://repo1.maven.org/maven2/org/apache/flink/flink-connector-kafka/3.0.1-1.18/flink-connector-kafka-3.0.1-1.18.jar
	cd jars && curl -s -O https://repo1.maven.org/maven2/org/apache/flink/flink-connector-elasticsearch/3.0.1-1.18/flink-connector-elasticsearch-3.0.1-1.18.jar
	@echo "✅ Additional connectors downloaded."

# Backup data
backup:
	@echo "💾 Creating backup..."
	mkdir -p backup
	docker exec flink_dev-mysql-1 mysqldump -u flink -pflink123 testdb > backup/mysql-backup-`date +%Y%m%d-%H%M%S`.sql
	docker cp flink_dev-jobmanager-1:/opt/flink/storage backup/paimon-warehouse-`date +%Y%m%d-%H%M%S`
	@echo "✅ Backup created in backup/ directory."

# Restore data from backup
restore:
	@if [ -z "$(BACKUP)" ]; then \
		echo "Usage: make restore BACKUP=backup-file"; \
		exit 1; \
	fi
	@echo "📥 Restoring from backup..."
	docker exec -i flink_dev-mysql-1 mysql -u flink -pflink123 testdb < $(BACKUP)
	@echo "✅ Data restored."

# Development targets
dev-setup: setup
	@echo "🔧 Setting up development environment..."
	docker-compose up -d
	sleep 30
	./final-paimon-test.sh
	@echo "✅ Development environment ready!"

# Production targets
prod-deploy:
	@echo "🚀 Deploying to production..."
	@echo "⚠️  This is a placeholder for production deployment"
	@echo "Add your production deployment commands here"

# Monitoring targets
monitor:
	@echo "📈 Opening monitoring dashboards..."
	@echo "Flink UI: http://localhost:8081"
	@if command -v open >/dev/null 2>&1; then open http://localhost:8081; else echo "Open http://localhost:8081 in your browser"; fi

# Quick start (setup + start + data)
quick: setup start data
	@echo "🚀 Quick start complete!"
	@echo "🌐 Flink Web UI: http://localhost:8081"
	@make status