# 1. CREAR ESTRUCTURA DE CARPETAS
mkdir foodflash
cd foodflash
# Crear estructura completa
mkdir -p backend/src/{config,controllers,middleware,routes,services,scripts}
mkdir -p frontend/src/{components,services}
mkdir -p frontend/public
mkdir -p crisis-materials/{logs,dashboards}

# 2. INICIALIZAR BACKEND
cd backend
# Crear package.json del backend
npm init -y
# Instalar dependencias del backend
npm install express pg redis bcryptjs jsonwebtoken express-rate-limit cors helmet dotenv stripe nodemailer
# Instalar dependencias de desarrollo
npm install -D nodemon

# 3. CREAR ARCHIVOS DEL BACKEND
# .env
cat > .env << 'EOF'
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=foodflash_dev
DB_USER=postgres
DB_PASSWORD=password
# Redis Cache
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
# Server Configuration
PORT=3001
NODE_ENV=development
# JWT Secret
JWT_SECRET=your-super-secret-jwt-key-here
# Rate Limiting (Muy bajo intencionalmente)
RATE_LIMIT_REQUESTS=100
RATE_LIMIT_WINDOW=60000
# AWS Configuration (Problemático para producción)
AWS_AUTO_SCALING_ENABLED=false
AWS_MAX_INSTANCES=3
AWS_REGION=us-east-1
# Payment
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
# Email
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
EOF

# Actualizar package.json del backend
cat > package.json << 'EOF'
{
  "name": "foodflash-backend",
  "version": "1.0.0",
  "description": "FoodFlash Delivery Platform Backend",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "dev": "nodemon src/app.js",
    "setup-db": "psql -h localhost -U postgres -d foodflash_dev -f scripts/setup_db.sql"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.0",
    "redis": "^4.6.7",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.0",
    "express-rate-limit": "^6.7.0",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "dotenv": "^16.1.4",
    "stripe": "^12.9.0",
    "nodemailer": "^6.9.3"
  },
  "devDependencies": {
    "nodemon": "^2.0.22"
  }
}
EOF

# src/app.js
cat > src/app.js << 'EOF'
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const orderRoutes = require('./routes/orders');
const rateLimiter = require('./middleware/rateLimiter');
const app = express();
const PORT = process.env.PORT || 3001;

// Security middleware
app.use(helmet());
app.use(cors());

// Rate limiting
app.use('/api/', rateLimiter);

// Body parsing
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api/orders', orderRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});

// API Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'API OK',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Endpoint para simular carga
app.post('/api/stress-test', async (req, res) => {
  const { iterations = 100 } = req.body;

  console.log(`Starting stress test with ${iterations} iterations`);
  for (let i = 0; i < iterations; i++) {
    const data = new Array(10000).fill(Math.random());
    await new Promise(resolve => setTimeout(resolve, 1));
  }

  res.json({
    message: `Stress test completed: ${iterations} iterations`,
    memoryUsage: process.memoryUsage()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

app.listen(PORT, () => {
  console.log(`FoodFlash Server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
});

module.exports = app;
EOF

# src/config/database.js (CON BUGS)
cat > src/config/database.js << 'EOF'
const { Pool } = require('pg');
// Database configuration con pool muy pequeño
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'foodflash_dev',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'password',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
};

const pool = new Pool(dbConfig);

// Error handling problemático
pool.on('error', (err) => {
  console.error('Unexpected error on idle client', err);
  process.exit(-1);
});
pool.on('connect', (client) => {
  console.log('New database connection established');
});

// Test connection
pool.query('SELECT NOW()', (err, result) => {
  if (err) {
    console.error('Database connection failed:', err);
  } else {
    console.log('Database connected successfully');
    console.log('Max connections configured:', dbConfig.max);
  }
});

module.exports = pool;
EOF

# src/config/redis.js
cat > src/config/redis.js << 'EOF'
const redis = require('redis');
// Redis client sin retry strategy
const redisClient = redis.createClient({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT) || 6379,
  password: process.env.REDIS_PASSWORD || undefined,
});

redisClient.on('error', (err) => {
  console.error('Redis Client Error:', err);
});
redisClient.on('connect', () => {
  console.log('Redis connected successfully');
});
redisClient.on('ready', () => {
  console.log('Redis client ready');
});

// Connect to Redis
redisClient.connect().catch(console.error);

module.exports = redisClient;
EOF

# src/middleware/rateLimiter.js
cat > src/middleware/rateLimiter.js << 'EOF'
const rateLimit = require('express-rate-limit');
// Rate limiter muy restrictivo (parte del problema)
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW) || 60000, // 1 minuto
  max: parseInt(process.env.RATE_LIMIT_REQUESTS) || 100, // Solo 100 requests por minuto
  message: {
    error: 'Too many requests from this IP',
    retryAfter: '1 minute'
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next, options) => {
    console.warn(`Rate limit exceeded for IP: ${req.ip}`);
    res.status(options.statusCode).json(options.message);
  }
});

module.exports = limiter;
EOF

# src/controllers/orderController.js (CON MEMORY LEAK) cat > src/controllers/orderController.js << 'EOF'
const pool = require('../config/database');
const paymentService = require('../services/paymentService');
const notificationService = require('../services/notificationService');

exports.createOrder = async (req, res) => {
  const client = await pool.connect();

  try {
    const { userId, restaurantId, items, total, paymentInfo } = req.body;

    // Validación básica
    if (!userId || !restaurantId || !items || !total) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    await client.query('BEGIN');

    // Insert order
    const orderResult = await client.query(
      'INSERT INTO orders (user_id, restaurant_id, total, items, status, created_at) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [userId, restaurantId, total, JSON.stringify(items), 'pending', new Date()]
    );

    const orderId = orderResult.rows[0].id;

    // Update restaurant inventory (INEFICIENTE - consulta por cada item)
    for (let item of items) {
      const result = await client.query(
        'UPDATE inventory SET quantity = quantity - $1 WHERE restaurant_id = $2 AND item_id = $3 AND quantity >= $1',
        [item.quantity || 1, restaurantId, item.id]
      );

      if (result.rowCount === 0) {
        throw new Error(`Insufficient inventory for item ${item.name}`);
      }
    }

    // Process payment
    const paymentResult = await paymentService.processPayment(paymentInfo, total);

    if (!paymentResult.success) {
      throw new Error('Payment processing failed');
    }

    // Update order with payment info
    await client.query(
      'UPDATE orders SET payment_id = $1, status = $2 WHERE id = $3',
      [paymentResult.paymentId, 'confirmed', orderId]
    );

    await client.query('COMMIT');

    // client.release();

    // Send confirmation email
    await notificationService.sendOrderConfirmation(userId, orderResult.rows[0]);

    res.json({
      success: true,
      order: orderResult.rows[0],
      paymentId: paymentResult.paymentId
    });

  } catch (error) {
    await client.query('ROLLBACK');
    // client.release();

    console.error('Order creation failed:', error);
    res.status(500).json({
      error: 'Order creation failed',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

exports.getOrder = async (req, res) => {
  try {
    const { orderId } = req.params;

    const result = await pool.query(
      'SELECT o.*, u.email, u.name, r.name as restaurant_name FROM orders o JOIN users u ON o.user_id = u.id JOIN restaurants r ON o.restaurant_id = r.id WHERE o.id = $1',
      [orderId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching order:', error);
    res.status(500).json({ error: 'Failed to fetch order' });
  }
};

exports.updateOrderStatus = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { status } = req.body;

    const validStatuses = ['pending', 'confirmed', 'preparing', 'ready', 'delivered', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    const result = await pool.query(
      'UPDATE orders SET status = $1, updated_at = $2 WHERE id = $3 RETURNING *',
      [status, new Date(), orderId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error updating order:', error);
    res.status(500).json({ error: 'Failed to update order' });
  }
};

exports.getOrdersByUser = async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await pool.query(
      'SELECT o.*, r.name as restaurant_name FROM orders o JOIN restaurants r ON o.restaurant_id = r.id WHERE o.user_id = $1 ORDER BY o.created_at DESC',
      [userId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching user orders:', error);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
};
EOF

# src/routes/orders.js
cat > src/routes/orders.js << 'EOF'
const express = require('express');
const orderController = require('../controllers/orderController');
const router = express.Router();

// Crear orden
router.post('/', orderController.createOrder);

// Obtener orden por ID
router.get('/:orderId', orderController.getOrder);

// Actualizar status de orden
router.put('/:orderId/status', orderController.updateOrderStatus);

// Obtener órdenes de un usuario
router.get('/user/:userId', orderController.getOrdersByUser);

module.exports = router;
EOF

# src/services/paymentService.js
cat > src/services/paymentService.js << 'EOF'
class PaymentService {
  async processPayment(paymentInfo, amount) {
    try {
      // Simular timeout ocasional para agregar estrés
      if (Math.random() < 0.1) { // 10% chance de timeout
        await new Promise(resolve => setTimeout(resolve, 30000));
      }

      // Simular procesamiento de pago
      const paymentId = 'pi_' +
        Math.random().toString(36).substr(2, 9);

      return {
        success: true,
        paymentId: paymentId,
        status: 'succeeded'
      };
    } catch (error) {
      console.error('Payment processing error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  async refundPayment(paymentId, amount) {
    try {
      const refundId = 're_' +
        Math.random().toString(36).substr(2, 9);

      return {
        success: true,
        refundId: refundId,
        status: 'succeeded'
      };
    } catch (error) {
      console.error('Refund processing error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }
}

module.exports = new PaymentService();
EOF

# src/services/notificationService.js
cat > src/services/notificationService.js << 'EOF'
class NotificationService {
  async sendOrderConfirmation(userId, order) {
    try {
      // Simular envío de email
      console.log(`Sending order confirmation to user ${userId} for order ${order.id}`);

      // Simular delay ocasional
      await new Promise(resolve => setTimeout(resolve, 100));
      return {
        success: true,
        messageId: 'msg_' +
          Math.random().toString(36).substr(2, 9)
      };
    } catch (error) {
      console.error('Email sending error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }
}

module.exports = new NotificationService();
EOF

# scripts/setup_db.sql
cat > scripts/setup_db.sql << 'EOF'
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
INSERT INTO users (email, password_hash, name, phone, address) VALUES ('john@example.com', '$2b$10$example_hash', 'John Doe', '+1234567890', '123 Main St, City, State'),
('jane@example.com', '$2b$10$example_hash', 'Jane Smith', '+1234567891', '456 Oak Ave, City, State'),
('bob@example.com', '$2b$10$example_hash', 'Bob Johnson', '+1234567892', '789 Pine St, City, State');

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
INSERT INTO inventory (restaurant_id, item_id, quantity) VALUES (1, 1, 50), -- Pizza Margherita
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
EOF

# 4. VOLVER A LA RAÍZ E INICIALIZAR FRONTEND
cd ..
# Crear React app
npx create-react-app frontend
# Entrar al frontend
cd frontend
# Instalar dependencias adicionales
npm install axios react-router-dom
# Reemplazar src/App.js
cat > src/App.js << 'EOF'
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [restaurants, setRestaurants] = useState([
    { id: 1, name: "Pizza Palace", description: "Best pizza in town", rating: 4.5, delivery_time: 30 },
    { id: 2, name: "Burger Barn", description: "Gourmet burgers and fries", rating: 4.2, delivery_time: 25 },
    { id: 3, name: "Taco Fiesta", description: "Authentic Mexican cuisine", rating: 4.8, delivery_time: 35 }
  ]);
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadOrders();
  }, []);

  const loadOrders = async () => {
    try {
      const response = await axios.get('/api/orders/user/1');
      setOrders(response.data);
    } catch (error) {
      console.error('Error loading orders:', error);
    }
  };

  const placeOrder = async (restaurantId, restaurantName) => {
    try {
      setLoading(true);
      setError(null);

      const orderData = {
        userId: 1,
        restaurantId,
        items: [{ id: 1, name: "Sample Item", quantity: 1, price: 15.99 }],
        total: 15.99,
        paymentInfo: {
          paymentMethodId: 'pm_test_card'
        }
      };
      console.log('Placing order:', orderData);
      const response = await axios.post('/api/orders', orderData);
      if (response.data.success) {
        alert(`Order placed successfully at ${restaurantName}!`);
        loadOrders();
      }
    } catch (error) {
      const errorMessage = error.response?.data?.error || error.message;
      setError(`Failed to place order: ${errorMessage}`);
      console.error('Order error:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>FoodFlash</h1>
        <p>Fast food delivery at your fingertips</p>
      </header>
      {error && (
        <div style={{
          backgroundColor: '#ffebee',
          color: '#c62828',
          padding: '16px',
          margin: '16px',
          borderRadius: '4px',
          border: '1px solid #e57373'
        }}>
          {error}
        </div>
      )}
      <main style={{ padding: '20px', maxWidth: '1200px', margin: '0 auto' }}>
        <section>
          <h2>Available Restaurants</h2>
          {loading && <p>Processing order...</p>}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
            gap: '20px',
            marginBottom: '40px'
          }}>
            {restaurants.map(restaurant => (
              <div key={restaurant.id} style={{
                border: '1px solid #ddd',
                borderRadius: '8px',
                padding: '20px',
                backgroundColor: '#f9f9f9'
              }}>
                <h3>{restaurant.name}</h3>
                <p>{restaurant.description}</p>
                <p>{restaurant.rating}/5</p>
                <p>{restaurant.delivery_time} min delivery</p>
                <button
                  onClick={() => placeOrder(restaurant.id, restaurant.name)}
                  disabled={loading}
                  style={{
                    backgroundColor: loading ? '#ccc' : '#4CAF50',
                    color: 'white',
                    padding: '10px 20px',
                    border: 'none',
                    borderRadius: '4px',
                    cursor: loading ? 'not-allowed' : 'pointer'
                  }}
                >
                  {loading ? 'Processing...' : 'Order Now - $15.99'}
                </button>
              </div>
            ))}
          </div>
        </section>
        <section>
          <h2>Your Orders</h2>
          {orders.length === 0 ? (
            <p>No orders yet. Place your first order above!</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {orders.map(order => (
                <div key={order.id} style={{
                  border: '1px solid #ddd',
                  borderRadius: '8px',
                  padding: '15px',
                  backgroundColor: '#ffffff'
                }}>
                  <p><strong>Order #{order.id}</strong></p>
                  <p>Status: <span style={{
                    padding: '4px 8px',
                    borderRadius: '4px',
                    backgroundColor: order.status === 'delivered' ?
                      '#4CAF50' :
                      order.status === 'preparing' ? '#FF9800' : '#2196F3',
                    color: 'white'
                  }}>{order.status}</span></p>
                  <p>Total: ${order.total}</p>
                  <p>Date: {new Date(order.created_at).toLocaleDateString()}</p>
                  {order.restaurant_name && <p>Restaurant: {order.restaurant_name}</p>}
                </div>
              ))}
            </div>
          )}
        </section>
      </main>
      <footer style={{ textAlign: 'center', padding: '20px', marginTop: '40px', borderTop: '1px solid #eee' }}>
        <p>© 2025 FoodFlash - Powered by hunger and code</p>
        <p>Server Status: <span id="server-status">Checking...</span></p>
      </footer>
    </div>
  );
}

export default App;
EOF

# Actualizar App.css con estilos básicos
cat >> src/App.css << 'EOF'
.App {
  text-align: center;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
}

.App-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 40px;
  margin-bottom: 30px;
}

.App-header h1 {
  margin: 0 0 10px 0;
  font-size: 3rem;
}

.App-header p {
  margin: 0;
  font-size: 1.2rem;
  opacity: 0.9;
}

main {
  text-align: left;
}

h2 {
  color: #333;
  border-bottom: 2px solid #667eea;
  padding-bottom: 10px;
  margin-bottom: 20px;
}

button:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0,0,0,0.2);
  transition: all 0.2s;
}
EOF

# 5. VOLVER A LA RAÍZ Y CREAR DOCKER COMPOSE
cd ..
# docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: foodflash_db
    environment:
      POSTGRES_DB: foodflash_dev
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/scripts/setup_db.sql:/docker-entrypoint-initdb.d/setup_db.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: foodflash_cache
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  postgres_data:
  redis_data:
EOF

# 6. CREAR README PRINCIPAL
cat > README.md << 'EOF'
# FoodFlash - Crisis Simulation Project
## Instalación Rápida
### Opción 1: Con Docker (Recomendado)
```bash
# Levantar base de datos y cache
docker-compose up -d
# Instalar dependencias y ejecutar
cd backend && npm install && npm run dev &
cd frontend && npm start
```
### Opción 2: Manual
```bash
# 1. Instalar PostgreSQL y Redis localmente
# 2. Crear base de datos
createdb foodflash_dev
# 3. Setup backend
cd backend
npm install
npm run setup-db
npm run dev
# 4. Setup frontend (en otra terminal)
cd frontend
npm start
```
## Para Crear Crisis
```bash
# Script de carga masiva (incluir en terminal separada) for i in {1..1000}; do
 curl -X POST http://localhost:3001/api/orders \
 -H "Content-Type: application/json" \
 -d '{"userId":1,"restaurantId":1,"items":[{"id":1,"name":"Pizza","quantity ":1,"price":15.99}],"total":15.99,"paymentInfo":{"paymentMethodId":"tes t"}}' &
done
```
## URLs del Sistema
- **Frontend**: http://localhost:3000
- **Backend Health**: http://localhost:3001/health
- **API Health**: http://localhost:3001/api/health
```
