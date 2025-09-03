-- FoodFlash Database Setup
-- Drop existing tables if they exist
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS menu_items CASCADE;
DROP TABLE IF EXISTS restaurants CASCADE;
DROP TABLE IF EXISTS users CASCADE;
-- Users table
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255) NOT NULL,
  phone VARCHAR(20),
  address TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Restaurants table
CREATE TABLE restaurants (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  address TEXT NOT NULL,
  phone VARCHAR(20),
  rating DECIMAL(2,1) DEFAULT 0,
  delivery_time INT DEFAULT 30,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Menu items table
CREATE TABLE menu_items (
  id SERIAL PRIMARY KEY,
  restaurant_id INT REFERENCES restaurants(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  category VARCHAR(100),
  is_available BOOLEAN DEFAULT true,
  image_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Inventory table
CREATE TABLE inventory (
  id SERIAL PRIMARY KEY,
  restaurant_id INT REFERENCES restaurants(id) ON DELETE CASCADE,
  item_id INT REFERENCES menu_items(id) ON DELETE CASCADE,
  quantity INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(restaurant_id, item_id)
);
-- Orders table
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id) ON DELETE SET NULL,
  restaurant_id INT REFERENCES restaurants(id) ON DELETE SET NULL,
  total DECIMAL(10,2) NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  payment_id VARCHAR(255),
  items JSONB NOT NULL,
  delivery_address TEXT,
  special_instructions TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Indexes for performance
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_restaurant_id ON orders(restaurant_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_menu_items_restaurant_id ON menu_items(restaurant_id);
CREATE INDEX idx_inventory_restaurant_item ON inventory(restaurant_id, item_id);
-- Sample data for testing
INSERT INTO users (email, password_hash, name, phone, address) VALUES
  ('john@example.com', 'b0', 'John Doe', '+1234567890', '123 Main St, City, State'),
  ('jane@example.com', 'b0', 'Jane Smith', '+1234567891', '456 Oak Ave, City, State'),
  ('bob@example.com', 'b0', 'Bob Johnson', '+1234567892', '789 Pine St, City, State');
INSERT INTO restaurants (name, description, address, phone, rating) VALUES
  ('Pizza Palace', 'Best pizza in town', '100 Pizza St, City, State', '+1111111111', 4.5),
  ('Burger Barn', 'Gourmet burgers and fries', '200 Burger Ave, City, State', '+2222222222', 4.2),
  ('Taco Fiesta', 'Authentic Mexican cuisine', '300 Taco Blvd, City, State', '+3333333333', 4.8);
INSERT INTO menu_items (restaurant_id, name, description, price, category) VALUES
  (1, 'Margherita Pizza', 'Classic tomato, mozzarella, and basil', 18.99, 'Pizza'),
  (1, 'Pepperoni Pizza', 'Tomato sauce, mozzarella, and pepperoni', 21.99, 'Pizza'),
  (2, 'Classic Burger', 'Beef patty with lettuce, tomato, and onion', 15.99, 'Burgers'),
  (2, 'Bacon Cheeseburger', 'Beef patty with bacon and cheese', 18.99, 'Burgers'),
  (3, 'Chicken Tacos', 'Three tacos with grilled chicken', 12.99, 'Tacos'),
  (3, 'Beef Burritos', 'Large burrito with seasoned beef', 14.99, 'Burritos');
-- Stock inicial (INTENCIONALMENTE BAJO para crear problemas)
INSERT INTO inventory (restaurant_id, item_id, quantity) VALUES
  (1, 1, 50), -- Pizza Margherita
  (1, 2, 45), -- Pepperoni Pizza
  (2, 3, 30), -- Classic Burger
  (2, 4, 25), -- Bacon Cheeseburger
  (3, 5, 40), -- Chicken Tacos
  (3, 6, 35); -- Beef Burritos
-- Crear algunos pedidos de prueba
INSERT INTO orders (user_id, restaurant_id, total, status, items) VALUES
  (1, 1, 18.99, 'delivered', '[{"id": 1, "name": "Margherita Pizza", "quantity": 1, "price": 18.99}]'),
  (2, 2, 15.99, 'preparing', '[{"id": 3, "name": "Classic Burger", "quantity": 1, "price": 15.99}]'),
  (3, 3, 12.99, 'confirmed', '[{"id": 5, "name": "Chicken Tacos", "quantity": 1, "price": 12.99}]');
COMMIT;
