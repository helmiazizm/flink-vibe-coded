# Flink CDC Gateway

A Flask-based REST API service for remote submission of Flink CDC YAML jobs.

## Overview

The CDC Gateway allows you to:
1. Upload Flink CDC YAML files remotely
2. Store them in a shared volume accessible by the Flink JobManager
3. Trigger Flink CDC jobs automatically by executing `./bin/flink-cdc.sh`

## Architecture

```
┌─────────────┐         ┌──────────────────┐         ┌──────────────┐
│  User/Client│────API─→│  CDC Gateway     │─exec──→│  JobManager  │
│             │  (5000) │  (Flask)         │  docker │  (flink-cdc) │
└─────────────┘         └──────────────────┘         └──────────────┘
                               │
                               ├─→ /shared/cdc-yaml/
                               │   (Docker volume)
                               └───────────────────────┐
                                                      │
┌─────────────┐               ┌──────────────────┐    │
│ TaskManager │◄─────────────│  JobManager      │◄───┘
│             │    network   │  (reads YAML)    │
└─────────────┘               └──────────────────┘
```

## API Endpoints

### Health Check
```bash
GET /health
```

Response:
```json
{
  "status": "healthy",
  "service": "flink-cdc-gateway"
}
```

### Submit CDC Job
```bash
POST /submit
Content-Type: multipart/form-data
```

Parameters:
- `file`: YAML file to submit

Response (Success):
```json
{
  "status": "submitted",
  "filename": "cdc_20231227_143052_abc123.yaml",
  "job_id": "1234567890abcdef",
  "message": "CDC job submitted successfully",
  "stdout": "..."
}
```

Response (Error):
```json
{
  "error": "Only YAML files are supported"
}
```

Example:
```bash
curl -X POST http://localhost:5000/submit \
  -F "file=@my-cdc-pipeline.yaml"
```

### List Submitted Jobs
```bash
GET /jobs
```

Response:
```json
{
  "jobs": [
    {
      "filename": "cdc_20231227_143052_abc123.yaml",
      "size": 2048,
      "modified": "2023-12-27T14:30:52"
    }
  ]
}
```

### Delete Job Configuration
```bash
DELETE /jobs/<filename>
```

Response (Success):
```json
{
  "status": "deleted",
  "filename": "cdc_20231227_143052_abc123.yaml"
}
```

Example:
```bash
curl -X DELETE http://localhost:5000/jobs/cdc_20231227_143052_abc123.yaml
```

## Example CDC YAML File

```yaml
source:
  type: mysql
  name: MySQL Source
  hostname: mysql
  port: 3306
  username: flink
  password: flink123
  database: testdb
  table: orders
  server-time-zone: UTC

sink:
  type: paimon
  name: Paimon Sink
  warehouse: s3://flink-state-persistent/warehouse
  database: testdb
  table: orders_cdc
  s3.endpoint: http://seaweedfs-s3:8333
  s3.access-key: minioadmin
  s3.secret-key: minioadmin

pipeline:
  name: MySQL to Paimon CDC Pipeline
  parallelism: 4
```

## Starting the Service

### Development Mode
```bash
make start-dev
```

The CDC Gateway will be available at `http://localhost:5000`

### Production Mode
```bash
make start-prod
```

### Hive Mode
```bash
make start-hive
```

## Testing the Gateway

### 1. Create a sample CDC YAML file
```bash
cat > sample-cdc.yaml <<EOF
source:
  type: mysql
  name: MySQL Source
  hostname: mysql
  port: 3306
  username: flink
  password: flink123
  database: testdb
  table: orders

sink:
  type: paimon
  name: Paimon Sink
  warehouse: s3://flink-state-persistent/warehouse
  database: testdb
  table: orders_cdc
  s3.endpoint: http://seaweedfs-s3:8333
  s3.access-key: minioadmin
  s3.secret-key: minioadmin

pipeline:
  name: Sample CDC Pipeline
  parallelism: 4
EOF
```

### 2. Submit the job
```bash
curl -X POST http://localhost:5000/submit -F "file=@sample-cdc.yaml"
```

### 3. Check the job in Flink Web UI
Visit `http://localhost:8080` to see the running job

### 4. List all submitted jobs
```bash
curl http://localhost:5000/jobs
```

## Volume Structure

The shared volume `cdc-yaml` is mounted at:
- Gateway: `/shared/cdc-yaml`
- JobManager: `/shared/cdc-yaml`
- TaskManager: `/shared/cdc-yaml`

YAML files are stored with the naming convention:
```
cdc_<timestamp>_<hash>.yaml
```

## Docker Access

The CDC Gateway has access to the Docker socket (`/var/run/docker.sock`), allowing it to execute commands inside the JobManager container.

## Logs

View CDC Gateway logs:
```bash
make logs-service SVC=cdc-gateway
```

Or follow all logs:
```bash
make logs-follow
```

## Troubleshooting

### Job submission fails
1. Check if JobManager is running: `docker ps | grep jobmanager`
2. Verify the YAML file is valid YAML syntax
3. Check CDC Gateway logs: `docker logs flink-cdc-gateway`

### Cannot connect to API
1. Verify the service is running: `docker ps | grep cdc-gateway`
2. Check the port is not already in use: `lsof -i :5000`

### Job not visible in Flink Web UI
1. Check the JobManager logs: `docker logs jobmanager`
2. Verify the YAML file exists in the shared volume: `docker exec jobmanager ls /shared/cdc-yaml`
3. Check if `flink-cdc.sh` is available: `docker exec jobmanager ls /opt/flink/bin/flink-cdc.sh`
