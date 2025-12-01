#!/bin/bash
# Setup script for Flink + MySQL + Paimon + SeaweedFS Stack
# Downloads JARs and generates configuration files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=================================================="
echo "Flink + MySQL + Paimon + SeaweedFS Setup"
echo "=================================================="

# Create directories
echo ""
echo "Creating directories..."
mkdir -p jars mysql-init flink-jobs seaweedfs/master-data seaweedfs/volume-data flink-storage

# Download JARs
download_jars() {
    echo ""
    echo "Downloading Flink connectors and dependencies..."
    echo "  - MySQL Connector/J..."
    cd jars && curl -sO https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/9.4.0/mysql-connector-j-9.4.0.jar
    
    echo "  - Flink MySQL CDC connector..."
    curl -sO https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-mysql-cdc/3.5.0/flink-sql-connector-mysql-cdc-3.5.0.jar
    
    echo "  - Flink JDBC connector..."
    curl -sO https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/3.3.0-1.20/flink-connector-jdbc-3.3.0-1.20.jar
    
    echo "  - Apache Paimon Flink connector..."
    curl -sO https://repo1.maven.org/maven2/org/apache/paimon/paimon-flink-2.1/1.3.1/paimon-flink-2.1-1.3.1.jar
    
    echo "  - Flink CDC Paimon connector..."
    curl -sO https://repo1.maven.org/maven2/org/apache/flink/flink-cdc-pipeline-connector-paimon/3.5.0/flink-cdc-pipeline-connector-paimon-3.5.0.jar
    
    echo "  - Paimon OSS connector..."
    curl -sO https://repo.maven.apache.org/maven2/org/apache/paimon/paimon-oss/1.3.1/paimon-oss-1.3.1.jar
    
    echo "  - Flink OSS FS Hadoop..."
    curl -sO https://repo1.maven.org/maven2/org/apache/flink/flink-oss-fs-hadoop/2.1.1/flink-oss-fs-hadoop-2.1.1.jar
    
    echo "  - Paimon S3 connector..."
    curl -sO https://repo.maven.apache.org/maven2/org/apache/paimon/paimon-s3/1.3.1/paimon-s3-1.3.1.jar
    
    echo "  - Flink S3 FS Hadoop..."
    curl -sO https://repo1.maven.org/maven2/org/apache/flink/flink-s3-fs-hadoop/2.1.1/flink-s3-fs-hadoop-2.1.1.jar
    
    echo "  - Paimon Hadoop Uber..."
    curl -sO https://repository.apache.org/content/groups/snapshots/org/apache/paimon/paimon-hadoop-uber/1.4-SNAPSHOT/paimon-hadoop-uber-1.4-20251201.003816-76.jar

    cd "$SCRIPT_DIR"
    echo "✓ All JARs downloaded to ./jars ($(du -sh jars | awk '{print $1}'))"
}

# Generate MySQL initialization SQL
generate_mysql_sql() {
    echo ""
    echo "Generating MySQL initialization SQL..."
    cat > mysql-init/init.sql << 'EOF'
CREATE DATABASE IF NOT EXISTS testdb;
USE testdb;

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  age INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,
  product_name VARCHAR(200),
  quantity INT,
  price DECIMAL(10,2),
  order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Sample data
INSERT INTO users (name, email, age) VALUES
  ('Alice Johnson', 'alice@example.com', 28),
  ('Bob Smith', 'bob@example.com', 35),
  ('Charlie Brown', 'charlie@example.com', 42),
  ('Diana Prince', 'diana@example.com', 30),
  ('Eve Wilson', 'eve@example.com', 25);

INSERT INTO orders (user_id, product_name, quantity, price) VALUES
  (1, 'Laptop', 1, 999.99),
  (2, 'Mouse', 2, 25.50),
  (1, 'Keyboard', 1, 75.00),
  (3, 'Monitor', 1, 299.99),
  (4, 'Headphones', 1, 150.00),
  (5, 'USB Cable', 3, 10.00);
EOF
    echo "✓ MySQL SQL created at mysql-init/init.sql"
}

# Generate Paimon catalog initialization SQL
generate_paimon_sql() {
    echo ""
    echo "Generating Paimon catalog initialization SQL..."
    cat > flink-jobs/paimon-init.sql << 'EOF'
-- Paimon Catalog Setup for SeaweedFS S3
-- Using SeaweedFS S3 API with IAM credentials

CREATE CATALOG IF NOT EXISTS paimon_catalog WITH (
  'type' = 'paimon',
  'warehouse' = 's3://paimon-data/paimon-warehouse',
  's3.endpoint' = 'http://seaweedfs-s3:8333',
  's3.access-key' = 'paimonAdmin123',
  's3.secret-key' = 'paimonSecretKey456789abcdef',
  's3.path-style-access' = 'true'
);

USE CATALOG paimon_catalog;
CREATE DATABASE IF NOT EXISTS testdb;
USE testdb;

-- Users table in Paimon (stored in SeaweedFS S3)
CREATE TABLE IF NOT EXISTS users (
  id INT,
  name STRING,
  email STRING,
  age INT,
  created_at TIMESTAMP(3),
  updated_at TIMESTAMP(3),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'file.format' = 'parquet',
  'write-mode' = 'append-only'
);

-- Orders table in Paimon (stored in SeaweedFS S3)
CREATE TABLE IF NOT EXISTS orders (
  id INT,
  user_id INT,
  product_name STRING,
  quantity INT,
  price DECIMAL(10, 2),
  order_date TIMESTAMP(3),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'file.format' = 'parquet',
  'write-mode' = 'append-only'
);

-- CDC Source: MySQL users table
CREATE TABLE IF NOT EXISTS mysql_users (
  id INT,
  name STRING,
  email STRING,
  age INT,
  created_at TIMESTAMP(3),
  updated_at TIMESTAMP(3),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'connector' = 'mysql-cdc',
  'hostname' = 'mysql',
  'port' = '3306',
  'username' = 'flink',
  'password' = 'flink123',
  'database-name' = 'testdb',
  'table-name' = 'users'
);

-- CDC Source: MySQL orders table
CREATE TABLE IF NOT EXISTS mysql_orders (
  id INT,
  user_id INT,
  product_name STRING,
  quantity INT,
  price DECIMAL(10, 2),
  order_date TIMESTAMP(3),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'connector' = 'mysql-cdc',
  'hostname' = 'mysql',
  'port' = '3306',
  'username' = 'flink',
  'password' = 'flink123',
  'database-name' = 'testdb',
  'table-name' = 'orders'
);
EOF
    echo "✓ Paimon SQL created at flink-jobs/paimon-init.sql"
}

# Generate SeaweedFS S3 IAM configuration
generate_s3_config() {
    echo ""
    echo "Generating SeaweedFS S3 IAM configuration..."
    cat > seaweedfs/s3-config.json << 'EOF'
{
  "identities": [
    {
      "name": "paimon-admin",
      "credentials": [
        {
          "accessKey": "paimonAdmin123",
          "secretKey": "paimonSecretKey456789abcdef"
        }
      ],
      "actions": [
        "Admin",
        "Read",
        "Write",
        "List",
        "Tagging",
        "Delete"
      ]
    },
    {
      "name": "flink-user",
      "credentials": [
        {
          "accessKey": "flinkUser789",
          "secretKey": "flinkUserSecret123456789xyz"
        }
      ],
      "actions": [
        "Read",
        "Write",
        "List"
      ]
    }
  ]
}
EOF
    echo "✓ S3 config created at seaweedfs/s3-config.json"
}

# Main execution
download_jars
generate_mysql_sql
generate_paimon_sql
generate_s3_config

echo ""
echo "=================================================="
echo "Setup complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. make build   # Build Docker images"
echo "  2. make start   # Start all services"
echo "  3. make status  # Check service status"
echo ""
