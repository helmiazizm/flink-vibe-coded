# Flink Real-Time Data Platform

A production-ready Apache Flink data platform with MySQL CDC, Apache Paimon lakehouse, and SeaweedFS S3-compatible storage. Features built-in checkpointing, exactly-once semantics, and Python API for interactive development.

**Three Deployment Options:**
- **Development**: Full stack with MySQL CDC, 3 TaskManagers, REST SQL Gateway, Zookeeper HA (Java 17)
- **Production**: External S3, scalable TaskManagers, production-grade configs, Zookeeper HA (Java 17)
- **Hive**: Legacy compatibility with HiveServer2, Hive Metastore, JDBC support, Zookeeper HA (Java 8)

## Quick Start

### Standard Environment (Java 17)
```bash
# Development environment (with MySQL + local S3)
make setup-misc        # Download JARs and generate configs
make build             # Build Docker images (Java 17)
make start-dev         # Start all services
make status            # Check service status
```

### Hive Environment (Java 8)
```bash
# Hive-compatible environment with HiveServer2 & Metastore
make setup-misc        # Download JARs and generate configs
make build-hive        # Build Java 8 images
make start-hive        # Start Hive environment
make status-hive       # Check Hive status
```

**Access Points:**

| Environment | Zookeeper | Flink UI | SQL Gateway | MySQL | SeaweedFS S3 |
|------------|-----------|----------|-------------|-------|--------------|
| **Dev/Prod** | :2181 | :8080 | REST :8081 | :3306 | :9095 |
| **Hive** | :2181 | :8081 | HiveServer2 :10000 | :3306 | :9095 |

## Prerequisites

- Docker and Docker Compose
- Make (Linux/macOS) or compatible build tool
- Python 3.8+ (optional, for Python API)
- DBeaver (recommended, for Hive environment GUI)
- Beeline client (optional, for Hive environment CLI)

## Architecture

### Standard Architecture (Dev/Prod)
```
┌─────────────┐      ┌──────────────────┐      ┌─────────────┐      ┌──────────────┐
│   MySQL     │      │      Flink       │      │   Paimon    │      │  SeaweedFS   │
│ (CDC Source)│─────▶│  JobManager (3)  │─────▶│ (Lakehouse) │◀────▶│  S3 Storage  │
└─────────────┘      │  TaskManager (3) │      └─────────────┘      │   + Filer    │
                     │  SQL Gateway     │                           └──────────────┘
                     └──────────────────┘
                              │                  ┌──────────────┐
                    Checkpoints & Savepoints     │  Zookeeper   │
                    (S3 with RocksDB backend) ◀──│     HA       │
                                                 └──────────────┘
```

### Hive Architecture (Java 8)
```
┌─────────────┐      ┌──────────────────┐      ┌──────────────────┐      ┌──────────────┐
│   MySQL     │      │      Flink       │      │  Hive Metastore  │      │  SeaweedFS   │
│ (CDC Source)│─────▶│  JobManager (1)  │◀────▶│  (PostgreSQL)    │◀────▶│  S3 Storage  │
└─────────────┘      │  TaskManager (1) │      └──────────────────┘      │   + Filer    │
                     │  HiveServer2     │                                 └──────────────┘
                     └──────────────────┘
                              │                  ┌──────────────┐
                    Hive Tables & Metadata       │  Zookeeper   │
                    (Thrift protocol)         ◀──│     HA       │
                                                 └──────────────┘
```

## Services Overview

### Standard Environment (Dev/Prod)
| Service | Port | Purpose |
|---------|------|---------|
| **Zookeeper** | 2181 | High availability coordination |
| **MySQL** | 3306 | CDC-enabled source database (GTID, binlog) |
| **Flink JobManager** | 8080 | Job coordination and Web UI |
| **Flink TaskManager** | - | 3 worker nodes (2GB each) |
| **Flink SQL Gateway** | 8081 | REST API for SQL execution |
| **SeaweedFS Master** | 9092 | Storage cluster coordinator |
| **SeaweedFS Volume** | 9093 | Data volume server |
| **SeaweedFS Filer** | 9094 | File system interface |
| **SeaweedFS S3** | 9095 | S3-compatible API |

### Hive Environment (Java 8)
| Service | Port | Purpose |
|---------|------|---------|
| **Zookeeper** | 2181 | High availability coordination |
| **MySQL** | 3306 | CDC-enabled source database (GTID, binlog) |
| **Flink JobManager** | 8081 | Job coordination and Web UI (Java 8) |
| **Flink TaskManager** | - | 1 worker node (2GB) |
| **HiveServer2 Gateway** | 10000 | Thrift-based SQL endpoint (JDBC) |
| **Hive Metastore** | 9083 | Hive metadata service (Thrift) |
| **PostgreSQL** | - | Metastore backend database |
| **SeaweedFS (all)** | 9092-9095 | S3-compatible storage cluster |

## Make Commands

### Setup
```bash
make help           # Show all commands
make setup-misc     # Download JARs, generate SQL/config files
make setup-venv     # Create Python virtual environment
make setup-all      # Complete setup (misc + venv + build)
make build          # Build Docker images (Java 17)
make build-hive     # Build Docker images (Java 8 for Hive)
```

### Service Management - Standard
```bash
make start-dev      # Start development environment (MySQL + local S3)
make start-prod     # Start production environment (external S3)
make stop-dev       # Stop development services
make stop-prod      # Stop production services
make restart-dev    # Restart development environment
make restart-prod   # Restart production environment
make status         # Show service status and access points
```

### Service Management - Hive
```bash
make start-hive     # Start Hive environment (Java 8 + HiveServer2)
make stop-hive      # Stop Hive services
make restart-hive   # Restart Hive environment
make status-hive    # Show Hive environment status
```

### Monitoring
```bash
make logs           # Show recent logs (last 100 lines)
make logs-follow    # Follow logs in real-time (Ctrl+C to exit)
make logs-service SVC=jobmanager  # Show logs for specific service
```

### Access Services
```bash
make mysql          # MySQL shell (testdb database)
make flink          # Flink SQL client (interactive)
make sql-gateway    # Test SQL Gateway connection (REST API)
make hive-gateway   # Test HiveServer2 Gateway (Hive mode only)
```

### Cleanup
```bash
make clean          # Full cleanup (containers + volumes + files)
make clean-soft     # Remove containers only (keep volumes)
```

## Project Structure

```
flink_dev/
├── docker-compose.yml           # Base service definitions (Java 17)
├── docker-compose-dev.yml       # Development overrides
├── docker-compose-prod.yml      # Production overrides
├── docker-compose-hive.yml      # Hive environment (Java 8)
├── Dockerfile                   # Custom Flink image (Java 17)
├── FlinkHive.Dockerfile         # Custom Flink image (Java 8 + Hive)
├── Makefile                     # Automation commands
├── flink-config/
│   ├── flink-conf-dev.yml      # Dev: S3 checkpoints (SeaweedFS)
│   └── flink-conf-template.yml # Prod: External S3 template
├── hms-config/
│   └── hive-site.xml           # Hive Metastore configuration
├── flink-jobs/
│   └── paimon-init.sql         # Paimon catalog + CDC table setup
├── mysql-init/
│   └── init.sql                # Database schema and sample data
├── scripts/
│   ├── setup.sh                # JAR downloader and config generator
│   ├── flink_sql_gateway_wrapper.py  # Python API for SQL Gateway
│   ├── seaweedfs_bucket.py     # S3 bucket initialization
│   └── requirements.txt        # Python dependencies
├── seaweedfs/
│   ├── s3-config.json          # IAM credentials for S3 API
│   ├── master-data/            # Cluster metadata
│   ├── volume-data/            # Object storage
│   └── filer-data/             # File metadata
└── jars/                       # Auto-downloaded connectors
```

## Configuration

### Environment Comparison

| Feature | Development | Production | Hive |
|---------|-------------|------------|------|
| **Java Version** | 17 | 17 | 8 |
| **Flink Version** | 1.20.3 | 1.20.3 | 1.20.3 |
| **TaskManagers** | 3 | 3 | 1 |
| **SQL Gateway** | REST API | REST API | HiveServer2 |
| **High Availability** | ✅ Zookeeper | ✅ Zookeeper | ✅ Zookeeper |
| **MySQL CDC** | ✅ Included | ❌ External | ✅ Included |
| **Storage** | SeaweedFS S3 | External S3 | SeaweedFS S3 |
| **Metastore** | N/A | N/A | Hive + PostgreSQL |
| **Use Case** | Local testing | Production | Hive compatibility |

**Development** (`make start-dev`):
- MySQL included for CDC testing
- SeaweedFS S3 for local checkpoints/savepoints
- 3 TaskManagers (scalable to test load)
- Checkpoints every 30s with RocksDB backend
- REST-based SQL Gateway on port 8081

**Production** (`make start-prod`):
- External S3 for checkpoints/savepoints
- Configure `flink-config/flink-conf-template.yml` with your S3 credentials
- No MySQL (assumes external CDC sources)
- 3 TaskManagers for production workloads

**Hive** (`make start-hive`):
- Java 8 compatibility for legacy Hive integrations
- HiveServer2 endpoint (JDBC: `jdbc:hive2://localhost:10000`)
- Hive Metastore with PostgreSQL backend
- Compatible with traditional Hive clients (beeline, JDBC drivers)
- Single TaskManager (suitable for Hive query workloads)

### High Availability Configuration

All environments include Zookeeper for high availability:

**Zookeeper Setup:**
- **Version**: 3.9.3
- **Port**: 2181
- **Quorum**: Single node (suitable for dev/test)
- **HA Storage**: S3-compatible filesystem
- **ZNode Path**: `/flink`

**Benefits:**
- **JobManager Failover**: Automatic recovery from JobManager failures
- **Leader Election**: Only one active JobManager at a time
- **Metadata Storage**: Job graphs and completed checkpoints stored in Zookeeper
- **TaskManager Recovery**: TaskManagers reconnect to new JobManager after failover

**Configuration:**
```yaml
high-availability:
  type: "zookeeper"
  storageDir: "s3://flink-state-persistent/ha/"
  zookeeper:
    quorum: "zookeeper:2181"
    path:
      root: "/flink"
```

### Checkpointing Configuration

Both environments use:
- **Interval**: 30 seconds
- **Mode**: EXACTLY_ONCE
- **Backend**: RocksDB (local: `/opt/flink/rocksdb`)
- **Storage**: S3-compatible filesystem
- **Retention**: RETAIN_ON_CANCELLATION

Edit `flink-config/flink-conf-dev.yml` or `flink-conf-template.yml` to customize.

### MySQL CDC Configuration

- **Binlog Format**: ROW
- **GTID Mode**: ON
- **Binlog Row Image**: FULL
- **Server ID**: 1

### Paimon Lakehouse

- **Catalog Type**: paimon
- **Warehouse**: `s3://paimon-data/paimon-warehouse`
- **S3 Endpoint**: SeaweedFS S3 (dev) or external (prod)
- **Table Format**: Parquet with Iceberg metadata compatibility

## Python API Usage

The Python wrapper provides a Jupyter-like interface to Flink SQL Gateway:

```bash
# Setup virtual environment
make setup-venv
source .venv/bin/activate

# Start Python/Jupyter
jupyter notebook flink_python_test.ipynb
```

**Example:**
```python
from scripts.flink_sql_gateway_wrapper import sql, q, tables, describe

# Execute Flink SQL and load results into DuckDB
sql("""
    SELECT name, email, age 
    FROM paimon_catalog.testdb.users 
    WHERE age > 30
""", table="users_over_30")

# Query the cached results with DuckDB
q("SELECT * FROM users_over_30 WHERE name LIKE 'A%'")

# Show all cached tables
tables()

# Describe table schema
describe("users_over_30")
```

**Features:**
- Auto-manages Flink session lifecycle
- Stops SELECT jobs automatically
- Loads results into in-memory DuckDB for fast local queries
- Handles INSERT/UPDATE/MERGE with checkpoint configuration

## Data Schema

Auto-generated by `make setup-misc`:

### MySQL Tables
```sql
-- testdb.users
CREATE TABLE users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100),
  email VARCHAR(100) UNIQUE,
  age INT,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- testdb.orders
CREATE TABLE orders (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT,
  product_name VARCHAR(200),
  quantity INT,
  price DECIMAL(10,2),
  order_date TIMESTAMP
);
```

### Paimon CDC Pipeline
The `flink-jobs/paimon-init.sql` script creates:
1. Paimon catalog pointing to S3
2. Paimon tables mirroring MySQL schema
3. MySQL CDC temporary tables
4. INSERT jobs for continuous replication

## Example Workflows

### Standard Environment Workflows

#### 1. Start and Monitor Services
```bash
make start-dev
make status
make logs-follow    # Watch all services in real-time
```

#### 2. Verify MySQL CDC
```bash
make mysql
# In MySQL shell:
SELECT * FROM testdb.users;
INSERT INTO users (name, email, age) VALUES ('Test User', 'test@example.com', 35);
```

#### 3. Run Paimon CDC Pipeline
```bash
make flink
# In Flink SQL client:
SOURCE '/opt/flink/jobs/paimon-init.sql';
SHOW JOBS;
```

#### 4. Query Paimon Data
```bash
make flink
# In Flink SQL client:
USE CATALOG paimon_catalog;
USE testdb;
SELECT * FROM users;
```

#### 5. Use Python API
```python
from scripts.flink_sql_gateway_wrapper import sql

# Query data from Paimon
sql("SELECT * FROM paimon_catalog.testdb.users", table="users")

# Join tables
sql("""
    SELECT u.name, COUNT(o.id) as order_count, SUM(o.price) as total_spent
    FROM paimon_catalog.testdb.users u
    LEFT JOIN paimon_catalog.testdb.orders o ON u.id = o.user_id
    GROUP BY u.name
""", table="user_summary")
```

#### 6. Test High Availability
```bash
# Check Zookeeper health
make zookeeper

# Start a Flink job
make flink
# In SQL client: CREATE TABLE test AS SELECT 1;

# Simulate JobManager failure
docker stop jobmanager

# Watch automatic recovery
docker logs -f jobmanager

# Verify job continues after restart
docker start jobmanager
# Job should resume from last checkpoint
```

### Hive Environment Workflows

#### 1. Start Hive Environment
```bash
make setup-misc      # Download JARs
make build-hive      # Build Java 8 images
make start-hive      # Start services
make status-hive     # Check status
```

#### 2. Connect with Beeline
```bash
# Using make command (tests connection)
make hive-gateway

# Or connect manually
beeline -u jdbc:hive2://localhost:10000
```

#### 3. Create Hive Catalog in Flink
```sql
-- In beeline or Flink SQL client
CREATE CATALOG hive_catalog WITH (
    'type' = 'hive',
    'hive-conf-dir' = '/opt/hive/conf'
);

USE CATALOG hive_catalog;
SHOW DATABASES;
```

#### 4. Query Hive Tables
```bash
make flink
# In Flink SQL client:
USE CATALOG hive_catalog;
CREATE DATABASE IF NOT EXISTS mydb;
USE mydb;

CREATE TABLE hive_table (
    id INT,
    name STRING,
    age INT
) STORED AS PARQUET;

INSERT INTO hive_table VALUES (1, 'Alice', 30), (2, 'Bob', 25);
SELECT * FROM hive_table;
```

#### 5. Connect with DBeaver (Recommended)

DBeaver provides a user-friendly GUI for HiveServer2 connections:

**Step 1: Install DBeaver**
- Download from https://dbeaver.io/download/
- Community Edition is free and sufficient

**Step 2: Create New Connection**
1. Click "Database" → "New Database Connection"
2. Search for "Apache Hive"
3. Select "Apache Hive" and click "Next"

**Step 3: Configure Connection**
```
Host:          localhost
Port:          10000
Database:      default
Authentication: No Authentication (or Username/Password if configured)
Username:      (leave empty)
Password:      (leave empty)
```

**Step 4: Download Driver**
- DBeaver will prompt to download the Hive JDBC driver
- Click "Download" and wait for completion

**Step 5: Test Connection**
- Click "Test Connection" to verify
- If successful, click "Finish"

**Step 6: Query Data**
```sql
-- In DBeaver SQL Editor
SHOW DATABASES;
USE default;
SHOW TABLES;
SELECT * FROM your_table LIMIT 10;
```

**Troubleshooting DBeaver Connection:**
- Ensure Hive environment is running: `make status-hive`
- Check HiveServer2 logs: `docker compose -f docker-compose-hive.yml logs sql-gateway`
- Verify port 10000 is accessible: `telnet localhost 10000`

## Troubleshooting

### Services won't start
```bash
docker compose down
docker compose ps        # Check for port conflicts (8080, 8081, 3306, 9092-9095)
make start-dev
```

### Checkpoint failures
```bash
docker compose logs jobmanager | grep checkpoint
# Check S3 connectivity:
docker exec -it seaweedfs-s3 wget -O- http://localhost:8333/
```

### CDC not working
```bash
# Verify MySQL binlog:
make mysql
SHOW VARIABLES LIKE 'log_bin';
SHOW MASTER STATUS;

# Check Flink CDC connector:
docker compose logs taskmanager | grep -i cdc
```

### Python API connection issues
```python
# Ensure SQL Gateway is running:
import requests
response = requests.get("http://localhost:8081/v1/info")
print(response.json())
```

### Zookeeper connection issues
```bash
# Check Zookeeper status
docker exec -it zookeeper bash -c "echo ruok | nc localhost 2181"
# Should respond with: imok

# View Zookeeper logs
docker logs zookeeper

# Check Flink HA znodes
docker exec -it zookeeper zkCli.sh ls /flink

# Test from Flink container
docker exec -it jobmanager bash -c "nc -zv zookeeper 2181"
```

### Hive Metastore connection issues
```bash
# Check metastore status
docker compose -f docker-compose-hive.yml logs hive-metastore

# Check PostgreSQL backend
docker compose -f docker-compose-hive.yml logs hive-metastore-db

# Test metastore connectivity
docker exec -it sql-gateway bash -c "telnet hive-metastore 9083"
```

### HiveServer2 not responding
```bash
# Check HiveServer2 logs
docker compose -f docker-compose-hive.yml logs sql-gateway

# Test with beeline
beeline -u jdbc:hive2://localhost:10000 -e "SHOW DATABASES;"
```

### Clean slate
```bash
make clean
make setup-misc
make build          # For dev/prod
make build-hive     # For Hive environment
make start-dev      # Or start-hive
```

## S3 Credentials (Development)

Generated by `make setup-misc` in `seaweedfs/s3-config.json`:

**Admin Account:**
- Access Key: `paimonAdmin123`
- Secret Key: `paimonSecretKey456789abcdef`
- Permissions: Full (Admin, Read, Write, List, Delete)

**Flink User:**
- Access Key: `flinkUser789`
- Secret Key: `flinkUserSecret123456789xyz`
- Permissions: Read, Write, List

## Downloaded JARs

`make setup-misc` downloads (v1.20.x/3.x compatible):
- `mysql-connector-j-9.4.0.jar` - MySQL JDBC driver
- `flink-sql-connector-mysql-cdc-3.5.0.jar` - MySQL CDC connector
- `flink-connector-jdbc-3.3.0-1.20.jar` - Generic JDBC connector
- `paimon-flink-1.20-1.3.1.jar` - Paimon Flink integration
- `flink-cdc-pipeline-connector-paimon-3.5.0.jar` - CDC pipeline connector
- `paimon-s3-1.3.1.jar` - Paimon S3 filesystem
- `flink-s3-fs-hadoop-1.20.3.jar` - Flink S3 filesystem
- `flink-shaded-hadoop-2-uber-2.8.3-10.0.jar` - Hadoop dependencies
- `flink-sql-connector-hive-3.1.3_2.12-1.20.3.jar` - Hive metastore support

## Documentation

- [Apache Flink](https://flink.apache.org/docs/stable/)
- [Apache Paimon](https://paimon.apache.org/docs/master/)
- [Flink CDC Connectors](https://github.com/apache/flink-cdc)
- [SeaweedFS](https://github.com/seaweedfs/seaweedfs/wiki)
- [Docker Compose](https://docs.docker.com/compose/)

## License

This project is a development template. Refer to individual component licenses.
