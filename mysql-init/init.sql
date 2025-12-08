CREATE DATABASE IF NOT EXISTS testdb;
USE testdb;

CREATE USER IF NOT EXISTS 'flink'@'%' IDENTIFIED BY 'flink123';

GRANT SELECT, REPLICATION SLAVE, REPLICATION CLIENT, SHOW VIEW ON *.* TO 'flink'@'%';
FLUSH PRIVILEGES;

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  age INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,
  product_name VARCHAR(200),
  quantity INT,
  price DECIMAL(10,2),
  order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Sample data
INSERT INTO users (name, email, age) VALUES
  ('Alice Johnson', 'alice@example.com', 28),
  ('Bob Smith', 'bob@example.com', 35),
  ('Charlie Brown', 'charlie@example.com', 42),
  ('Diana Prince', 'diana@example.com', 30),
  ('Eve Wilson', 'eve@example.com', 25);

INSERT INTO orders (user_id, product_name, quantity, price) VALUES
  (1, 'Laptop', 1, 999.99),
  (2, 'Mouse', 2, 25.50),
  (1, 'Keyboard', 1, 75.00),
  (3, 'Monitor', 1, 299.99),
  (4, 'Headphones', 1, 150.00),
  (5, 'USB Cable', 3, 10.00);

