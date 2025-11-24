CREATE CATALOG paimon_catalog WITH ('type' = 'paimon', 'warehouse' = 'file:///opt/flink/storage/paimon_warehouse');
USE CATALOG paimon_catalog;
CREATE DATABASE IF NOT EXISTS testdb;
USE testdb;
CREATE TABLE users (
    id INT,
    name STRING,
    email STRING,
    age INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'file.format' = 'parquet'
);
INSERT INTO users VALUES (1, 'Alice', 'alice@test.com', 28);
SELECT * FROM users;