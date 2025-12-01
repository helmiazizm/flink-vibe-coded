CREATE CATALOG paimon_catalog WITH ('type' = 'paimon', 'warehouse' = 's3://paimon-data/paimon_warehouse', 's3.endpoint' = 'http://seaweedfs-s3:8333/', 's3.access-key' = 'admin', 's3.secret-key' = 'supersecret', 's3.path.style.access' = 'true');

CREATE TABLE my_table (user_id BIGINT, item_id BIGINT, behavior STRING, dt STRING, hh STRING, PRIMARY KEY (dt, hh, user_id) NOT ENFORCED);
