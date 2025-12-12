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
mkdir -p jars mysql-init flink-jobs seaweedfs/master-data seaweedfs/volume-data seaweedfs/filer-data

# Download JARs
download_jars() {
    echo ""
    echo "Downloading Flink connectors and dependencies..."
    echo "  - MySQL connector..."
    cd jars && curl -sO https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/9.4.0/mysql-connector-j-9.4.0.jar
    
    echo "  - Flink MySQL CDC connector..."
    curl -sO https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-mysql-cdc/3.5.0/flink-sql-connector-mysql-cdc-3.5.0.jar
    
    echo "  - Flink JDBC connector..."
    curl -sO https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/3.3.0-1.20/flink-connector-jdbc-3.3.0-1.20.jar
    
    echo "  - Apache Paimon Flink connector..."
    curl -sO https://repo1.maven.org/maven2/org/apache/paimon/paimon-flink-1.20/1.3.1/paimon-flink-1.20-1.3.1.jar
    
    echo "  - Flink CDC Paimon connector..."
    curl -sO https://repo1.maven.org/maven2/org/apache/flink/flink-cdc-pipeline-connector-paimon/3.5.0/flink-cdc-pipeline-connector-paimon-3.5.0.jar
    
    echo "  - Paimon OSS connector..."
    curl -sO https://repo.maven.apache.org/maven2/org/apache/paimon/paimon-oss/1.3.1/paimon-oss-1.3.1.jar
    
    echo "  - Flink OSS FS Hadoop..."
    curl -sO https://repo1.maven.org/maven2/org/apache/flink/flink-oss-fs-hadoop/1.20.3/flink-oss-fs-hadoop-1.20.3.jar
    
    echo "  - Paimon S3 connector..."
    curl -sO https://repo.maven.apache.org/maven2/org/apache/paimon/paimon-s3/1.3.1/paimon-s3-1.3.1.jar
    
    echo "  - Flink S3 FS Hadoop..."
    curl -sO https://repo1.maven.org/maven2/org/apache/flink/flink-s3-fs-hadoop/1.20.3/flink-s3-fs-hadoop-1.20.3.jar
    
    echo "  - Paimon Hadoop Uber..."
    curl -sO https://repo.maven.apache.org/maven2/org/apache/flink/flink-shaded-hadoop-2-uber/2.8.3-10.0/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar

    echo "  - Flink SQL connector Hive..."
    curl -sO https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-hive-3.1.3_2.12/1.20.3/flink-sql-connector-hive-3.1.3_2.12-1.20.3.jar

    cd "$SCRIPT_DIR"
    echo "✓ All JARs downloaded to ./jars ($(du -sh jars | awk '{print $1}'))"
}

# Main execution
download_jars

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
