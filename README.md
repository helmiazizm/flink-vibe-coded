# Flink + MySQL + Paimon + SeaweedFS Stack

A Docker Compose-based data processing stack combining Apache Flink, MySQL CDC, Apache Paimon, and SeaweedFS for real-time data streaming and distributed storage.

## 🚀 Quick Start

```bash
make setup    # Initialize directories and build images
make start    # Start all services
make status   # Check service status
```

Access:
- **Flink Web UI**: http://localhost:8081
- **MySQL**: localhost:3306 (user: `flink`, password: `flink123`)

## 📋 Prerequisites

- Docker and Docker Compose
- Make (on Linux/macOS) or compatible build tool

## 🏗️ Architecture

```
MySQL                Flink                 Paimon              SeaweedFS
(CDC Source)      (Stream Processor)    (Lakehouse)        (Storage)
    │
    ├─────────────▶ JobManager ─────────▶ Storage ◀──────── Master
    │                   │                                     Volume
    └─────────────────  TaskManager
```

## 🛠️ Services

| Service | Port | Purpose |
|---------|------|---------|
| **MySQL** | 3306 | Source database with Change Data Capture enabled |
| **Flink JobManager** | 8081 | Stream processing coordinator and web UI |
| **Flink TaskManager** | - | Stream processing workers |
| **SeaweedFS Master** | 9092 | Distributed storage master node |
| **SeaweedFS Volume** | 9093 | Distributed storage volume node |

## 📚 Make Commands

### Service Management
```bash
make help      # Show all available commands
make setup     # Initialize directories and build Docker images
make start     # Start all services
make stop      # Stop all services
make restart   # Restart all services
make status    # Show service status and access points
make logs      # Follow real-time service logs
make clean     # Clean up containers, volumes, and generated files
```

### Access Services
```bash
make mysql     # Connect to MySQL shell
make flink     # Open Flink SQL client
```

## 📂 Project Structure

```
flink_dev/
├── Makefile                    # Build automation
├── docker-compose.yml          # Service orchestration
├── Dockerfile                  # Custom Flink image
├── jars/                       # Flink connectors and libraries
├── mysql-init/                 # MySQL initialization scripts
├── flink-storage/              # Paimon warehouse storage
├── flink-conf.yaml             # Flink configuration
├── hadoop-conf/                # Hadoop configuration
└── seaweedfs/                  # SeaweedFS data directories
    ├── master-data/
    └── volume-data/
```

## 🔧 Configuration

### MySQL
- **Root Password**: root123
- **Database**: testdb
- **User**: flink
- **Password**: flink123
- **CDC Enabled**: Yes (binlog enabled)

### Flink
- **Memory**: 2GB per JM/TM
- **Task Slots**: 2 per TaskManager
- **Checkpoint Dir**: `/tmp/flink-checkpoints`

### Paimon
- **Warehouse**: `/opt/flink/storage/paimon_warehouse`
- **Format**: Parquet
- **Write Mode**: Append-only

## 💾 Data Schema

MySQL source tables are configured in `mysql-init/`. Default schema includes:

- **users**: User profiles with timestamps
- **orders**: Order records linked to users

## 🔍 Example Workflows

### 1. Check Service Status
```bash
make status
```

### 2. Query MySQL
```bash
make mysql
# In MySQL shell:
SELECT * FROM testdb.users;
```

### 3. Access Flink SQL Client
```bash
make flink
# Create Paimon catalogs and tables as needed
```

### 4. Monitor Services
```bash
make logs      # Follow all logs
```

## 🚨 Troubleshooting

### Services won't start
```bash
# Check for port conflicts
docker compose down
# Increase Docker memory/CPU resources
make start
```

### MySQL connection issues
```bash
make mysql
# Should connect; if not, check logs:
docker compose logs mysql
```

### Flink jobs not running
```bash
# Check JobManager logs
docker compose logs jobmanager
# Verify all services are healthy
make status
```

### Clean slate
```bash
make clean     # Remove everything
make setup     # Start fresh
make start
```

## 📖 Documentation

- [Apache Flink](https://flink.apache.org/)
- [Apache Paimon](https://paimon.apache.org/)
- [SeaweedFS](https://github.com/seaweedfs/seaweedfs)
- [Docker Compose](https://docs.docker.com/compose/)

## 🔗 Resource Links

| Service | URL | Purpose |
|---------|-----|---------|
| Flink Web UI | http://localhost:8081 | Job monitoring and management |
| MySQL | localhost:3306 | Data source |
| SeaweedFS Master | localhost:9092 | Distributed storage admin |
| SeaweedFS Volume | localhost:9093 | Storage access |

---

For more information about individual components, refer to their official documentation.
