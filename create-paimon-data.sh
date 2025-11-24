#!/bin/bash

# Simple script to create Paimon tables and insert data
echo "🚀 Creating Paimon tables and inserting data..."

docker exec -i flink_dev-jobmanager-1 /opt/flink/bin/sql-client.sh << 'EOF'
SET sql-client.execution.result-mode=TABLEAU;

-- Create Paimon catalog
CREATE CATALOG paimon_catalog WITH ('type' = 'paimon', 'warehouse' = 'file:///opt/flink/storage/paimon_warehouse');

-- Create database
USE CATALOG paimon_catalog;
CREATE DATABASE IF NOT EXISTS testdb;
USE testdb;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
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

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
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

-- Insert users data
INSERT INTO users VALUES
    (1, 'Alice Johnson', 'alice@example.com', 28, TIMESTAMP '2024-01-01 10:00:00', TIMESTAMP '2024-01-01 10:00:00'),
    (2, 'Bob Smith', 'bob@example.com', 35, TIMESTAMP '2024-01-02 11:00:00', TIMESTAMP '2024-01-02 11:00:00'),
    (3, 'Charlie Brown', 'charlie@example.com', 42, TIMESTAMP '2024-01-03 12:00:00', TIMESTAMP '2024-01-03 12:00:00'),
    (4, 'Diana Prince', 'diana@example.com', 30, TIMESTAMP '2024-01-04 13:00:00', TIMESTAMP '2024-01-04 13:00:00'),
    (5, 'Eve Wilson', 'eve@example.com', 25, TIMESTAMP '2024-01-05 14:00:00', TIMESTAMP '2024-01-05 14:00:00');

-- Insert orders data
INSERT INTO orders VALUES
    (1, 1, 'Laptop', 1, 999.99, TIMESTAMP '2024-01-10 09:00:00'),
    (2, 2, 'Mouse', 2, 25.50, TIMESTAMP '2024-01-11 10:00:00'),
    (3, 1, 'Keyboard', 1, 75.00, TIMESTAMP '2024-01-12 11:00:00'),
    (4, 3, 'Monitor', 1, 299.99, TIMESTAMP '2024-01-13 12:00:00'),
    (5, 4, 'Headphones', 1, 150.00, TIMESTAMP '2024-01-14 13:00:00'),
    (6, 5, 'USB Cable', 3, 10.00, TIMESTAMP '2024-01-15 14:00:00');

-- Query results
SELECT '=== Paimon Users Table ===' as info;
SELECT COUNT(*) as user_count FROM users;

SELECT '=== Paimon Orders Table ===' as info;
SELECT COUNT(*) as order_count FROM orders;

SELECT '=== Sample Users ===' as info;
SELECT id, name, email, age FROM users ORDER BY id LIMIT 3;

SELECT '=== Sample Orders ===' as info;
SELECT id, user_id, product_name, quantity, price FROM orders ORDER BY id LIMIT 3;
EOF

echo ""
echo "✅ Paimon tables created and populated!"