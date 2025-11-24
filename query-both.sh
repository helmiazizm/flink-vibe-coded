#!/bin/bash

# Query both MySQL and Paimon tables for comparison
echo "🔍 Querying MySQL and Paimon tables..."

# Query MySQL
echo "=== MySQL Source Tables ==="
echo "Users table:"
docker exec flink_dev-mysql-1 mysql -u flink -pflink123 testdb -e "SELECT COUNT(*) as user_count FROM users;"

echo "Orders table:"
docker exec flink_dev-mysql-1 mysql -u flink -pflink123 testdb -e "SELECT COUNT(*) as order_count FROM orders;"

echo ""
echo "=== Paimon Target Tables ==="

# Query Paimon
docker exec -i flink_dev-jobmanager-1 /opt/flink/bin/sql-client.sh << 'EOF'
SET sql-client.execution.result-mode=TABLEAU;
CREATE CATALOG IF NOT EXISTS paimon_catalog WITH ('type' = 'paimon', 'warehouse' = 'file:///opt/flink/storage/paimon_warehouse');
USE CATALOG paimon_catalog;
USE testdb;

SELECT 'Paimon Users Count:' as info;
SELECT COUNT(*) as count FROM users;

SELECT 'Paimon Orders Count:' as info;
SELECT COUNT(*) as count FROM orders;

SELECT 'Sample Paimon Users:' as info;
SELECT id, name, email, age FROM users ORDER BY id LIMIT 3;

SELECT 'Sample Paimon Orders:' as info;
SELECT id, user_id, product_name, quantity, price FROM orders ORDER BY id LIMIT 3;
EOF

echo ""
echo "✅ Query complete!"