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
  created_at TIMESTAMP(4),
  updated_at TIMESTAMP(4),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'metadata.iceberg.storage' = 'table-location',
  'data-file.path-directory' = 'data'
);

-- Orders table in Paimon (stored in SeaweedFS S3)
CREATE TABLE IF NOT EXISTS orders (
  id INT,
  user_id INT,
  product_name STRING,
  quantity INT,
  price DECIMAL(10, 2),
  order_date TIMESTAMP(4),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'metadata.iceberg.storage' = 'table-location',
  'data-file.path-directory' = 'data'
);

-- CDC Source: MySQL users table
CREATE TEMPORARY TABLE IF NOT EXISTS mysql_users (
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
  'table-name' = 'users',
  'scan.startup.mode' = 'initial'
);

-- CDC Source: MySQL orders table
CREATE TEMPORARY TABLE IF NOT EXISTS mysql_orders (
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
  'table-name' = 'orders',
  'scan.startup.mode' = 'initial'
);

INSERT INTO users SELECT * FROM mysql_users;
INSERT INTO orders SELECT * FROM mysql_orders;