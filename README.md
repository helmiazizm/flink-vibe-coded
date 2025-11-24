# Flink + MySQL + Paimon Data Pipeline

A complete data pipeline solution using Apache Flink, MySQL, and Apache Paimon for real-time data processing and lakehouse storage.

## 🚀 Quick Start

```bash
# Set up everything from scratch and start the pipeline
make quick

# Or step by step:
make setup    # Download dependencies and create configuration
make start    # Start all services
make data     # Insert sample data into Paimon tables
make query    # Query the Paimon tables
```

## 📋 Prerequisites

- Docker and Docker Compose
- Make
- Git (optional, for version control)

## 🏗️ Architecture

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   MySQL    │───▶│   Flink     │───▶│   Paimon   │
│  (Source)  │    │ (Processing) │    │ (Lakehouse) │
└─────────────┘    └──────────────┘    └─────────────┘
```

- **MySQL**: Source database with CDC (Change Data Capture) enabled
- **Flink**: Stream processing engine for data transformation
- **Paimon**: Lakehouse storage format for analytics

## 🛠️ Available Commands

### Setup & Management
```bash
make setup      # Set up entire environment from scratch
make start      # Start all services (MySQL + Flink)
make stop       # Stop all services
make restart    # Restart all services
make clean      # Clean up containers, volumes, and files
make status     # Show status of all services
```

### Data Operations
```bash
make data       # Insert sample data into Paimon tables
make query      # Query Paimon tables and show results
make test       # Run complete pipeline test
make warehouse  # List Paimon warehouse contents
```

### Development & Debugging
```bash
make mysql      # Connect to MySQL shell
make flink      # Connect to Flink SQL client
make logs       # Show logs for all services
```

### Backup & Recovery
```bash
make backup     # Create backup of MySQL and Paimon data
make restore    # Restore from backup (BACKUP=file)
```

### Advanced
```bash
make download-connectors  # Download additional Flink connectors
make dev-setup           # Set up development environment
make monitor             # Open monitoring dashboards
```

## 📂 Project Structure

```
flink_dev/
├── Makefile                 # Build automation
├── docker-compose.yml       # Service orchestration
├── jars/                   # Flink connectors and dependencies
├── mysql-init/            # MySQL initialization scripts
├── flink-jobs/           # Flink SQL job definitions
├── flink-storage/        # Paimon warehouse storage
└── backup/               # Data backups
```

## 🔧 Configuration

### MySQL Configuration
- **Database**: `testdb`
- **User**: `flink`
- **Password**: `flink123`
- **Port**: `3306`
- **CDC**: Enabled with binlog

### Flink Configuration
- **JobManager**: `http://localhost:8081`
- **TaskManager**: Auto-scaling
- **SQL Client**: Interactive shell available

### Paimon Configuration
- **Warehouse**: `file:///opt/flink/storage/paimon_warehouse`
- **Format**: Parquet
- **Mode**: Append-only for time-series data

## 📊 Data Schema

### Users Table
```sql
CREATE TABLE users (
    id INT PRIMARY KEY,
    name STRING,
    email STRING UNIQUE,
    age INT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

### Orders Table
```sql
CREATE TABLE orders (
    id INT PRIMARY KEY,
    user_id INT FOREIGN KEY REFERENCES users(id),
    product_name STRING,
    quantity INT,
    price DECIMAL(10,2),
    order_date TIMESTAMP
);
```

## 🌐 Access Points

- **Flink Web UI**: http://localhost:8081
- **MySQL Database**: `localhost:3306`
- **Paimon Warehouse**: `/opt/flink/storage/paimon_warehouse`

## 📝 Example Queries

```sql
-- Set up Paimon catalog
CREATE CATALOG paimon_catalog WITH (
    'type' = 'paimon',
    'warehouse' = 'file:///opt/flink/storage/paimon_warehouse'
);

USE CATALOG paimon_catalog;
USE testdb;

-- Query users
SELECT * FROM users ORDER BY created_at DESC;

-- Query orders with user information
SELECT 
    u.name as user_name,
    u.email as user_email,
    o.product_name,
    o.quantity,
    o.price,
    o.order_date
FROM orders o
JOIN users u ON o.user_id = u.id
ORDER BY o.order_date DESC;

-- Analytics queries
SELECT 
    COUNT(*) as total_orders,
    SUM(price * quantity) as total_revenue,
    AVG(price) as avg_order_value
FROM orders;
```

## 🔍 Monitoring & Debugging

### Check Service Status
```bash
make status     # Show all running services
docker ps       # Docker container status
```

### View Logs
```bash
make logs       # Follow all service logs
docker-compose logs mysql    # MySQL logs only
docker-compose logs jobmanager # Flink JobManager logs
```

### Check Data Files
```bash
make warehouse  # List Paimon data files
docker exec flink_dev-jobmanager-1 find /opt/flink/storage/paimon_warehouse -name "*.parquet"
```

## 🚨 Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # Check if ports are in use
   lsof -i :8081  # Flink UI
   lsof -i :3306  # MySQL
   ```

2. **Memory Issues**
   ```bash
   # Increase Docker memory limits
   docker-compose down
   # Edit docker-compose.yml to add memory limits
   docker-compose up -d
   ```

3. **Connector Issues**
   ```bash
   # Check available connectors
   make flink
   # In SQL client: SHOW CONNECTORS;
   ```

4. **Data Not Appearing**
   ```bash
   # Check Flink job status
   make logs
   # Look for job submission errors
   ```

### Reset Environment
```bash
make clean     # Complete reset
make setup     # Fresh setup
make start     # Start services
```

## 🔗 Connectors & Extensions

### Available Connectors
- **MySQL CDC**: For real-time change data capture
- **JDBC**: For batch data access
- **Kafka**: For streaming data integration
- **Elasticsearch**: For search indexing

### Adding New Connectors
```bash
make download-connectors
# Or manually:
cd jars
curl -O <connector-url>
docker-compose restart
```

## 📈 Performance Tuning

### Flink Configuration
- **Parallelism**: Adjust based on data volume
- **Memory**: Configure heap and off-heap memory
- **Checkpointing**: Tune for exactly-once semantics

### Paimon Optimization
- **File Size**: Configure target file sizes
- **Compaction**: Set up background compaction
- **Partitioning**: Use appropriate partition keys

## 🧪 Testing

### Run Test Suite
```bash
make test       # Run complete pipeline test
```

### Test Data Generation
```bash
# Generate test data
make mysql
# In MySQL shell:
INSERT INTO users (name, email, age) VALUES 
('Test User', 'test@example.com', 30);
```

## 📚 Documentation

- [Apache Flink Documentation](https://flink.apache.org/docs/)
- [Apache Paimon Documentation](https://paimon.apache.org/docs/)
- [MySQL CDC Documentation](https://debezium.io/documentation/connectors/mysql/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `make test`
5. Submit a pull request

## 📄 License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review service logs with `make logs`
3. Create an issue with detailed information
4. Include environment details and error messages