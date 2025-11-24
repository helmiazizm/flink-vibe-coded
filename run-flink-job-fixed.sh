#!/bin/bash

# Execute Flink SQL job
docker exec -i flink_dev-jobmanager-1 /opt/flink/bin/sql-client.sh << EOF
-- Use default catalog first to create MySQL tables
USE CATALOG default_catalog;

-- Create MySQL source table as TEMPORARY
CREATE TEMPORARY TABLE mysql_users (
    id INT,
    name STRING,
    email STRING,
    age INT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:mysql://mysql:3306/testdb',
    'table-name' = 'users',
    'username' = 'flink',
    'password' = 'flink123',
    'scan.fetch-size' = '100',
    'scan.auto-commit' = 'true'
);

-- Create MySQL orders source table as TEMPORARY
CREATE TEMPORARY TABLE mysql_orders (
    id INT,
    user_id INT,
    product_name STRING,
    quantity INT,
    price DECIMAL(10,2),
    order_date TIMESTAMP,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:mysql://mysql:3306/testdb',
    'table-name' = 'orders',
    'username' = 'flink',
    'password' = 'flink123',
    'scan.fetch-size' = '100',
    'scan.auto-commit' = 'true'
);

-- Set up the catalog for Paimon
CREATE CATALOG paimon_catalog WITH (
    'type' = 'paimon',
    'warehouse' = 'file:///opt/flink/storage/paimon_warehouse'
);

USE CATALOG paimon_catalog;

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS testdb;
USE testdb;

-- Create Paimon sink table for users
CREATE TABLE paimon_users (
    id INT,
    name STRING,
    email STRING,
    age INT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'file.format' = 'parquet',
    'write-mode' = 'append-only'
);

-- Create Paimon sink table for orders
CREATE TABLE paimon_orders (
    id INT,
    user_id INT,
    product_name STRING,
    quantity INT,
    price DECIMAL(10,2),
    order_date TIMESTAMP,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'file.format' = 'parquet',
    'write-mode' = 'append-only'
);

-- Create enriched orders table with user information
CREATE TABLE paimon_enriched_orders (
    order_id INT,
    user_id INT,
    user_name STRING,
    user_email STRING,
    user_age INT,
    product_name STRING,
    quantity INT,
    price DECIMAL(10,2),
    order_date TIMESTAMP,
    PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'file.format' = 'parquet',
    'write-mode' = 'append-only'
);

-- Insert data into Paimon tables
-- Insert users data
INSERT INTO paimon_users
SELECT * FROM default_catalog.default_database.mysql_users;

-- Insert orders data
INSERT INTO paimon_orders
SELECT * FROM default_catalog.default_database.mysql_orders;

-- Insert enriched orders data (join with users)
INSERT INTO paimon_enriched_orders
SELECT 
    o.id as order_id,
    o.user_id,
    u.name as user_name,
    u.email as user_email,
    u.age as user_age,
    o.product_name,
    o.quantity,
    o.price,
    o.order_date
FROM default_catalog.default_database.mysql_orders o
LEFT JOIN default_catalog.default_database.mysql_users u ON o.user_id = u.id;

-- Show results
SHOW TABLES;

SELECT 'Users table count:' as info;
SELECT COUNT(*) FROM paimon_users;

SELECT 'Orders table count:' as info;
SELECT COUNT(*) FROM paimon_orders;

SELECT 'Enriched orders table count:' as info;
SELECT COUNT(*) FROM paimon_enriched_orders;

SELECT 'Sample enriched orders:' as info;
SELECT * FROM paimon_enriched_orders LIMIT 5;

QUIT;
EOF