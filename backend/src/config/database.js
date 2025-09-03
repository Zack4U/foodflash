// backend/src/config/database.js
const { Pool } = require('pg');

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT, 10) || 5432,
  database: process.env.DB_NAME || 'foodflash_dev',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'password',
  max: parseInt(process.env.DB_MAX_POOL, 10) || 50,  // configurable
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
};

const pool = new Pool(dbConfig);

// Mejor manejo de errores
pool.on('error', (err) => {
  console.error('Unexpected idle client error:', err.message);
  // No hacemos process.exit(), dejamos que el servidor siga
});

// Log de conexión
pool.on('connect', () => {
  console.log('✅ Database connection established');
});

// Test connection con try/catch
(async () => {
  try {
    const res = await pool.query('SELECT NOW()');
    console.log(`✅ Database connected at ${res.rows[0].now}`);
    console.log(`Max pool size: ${dbConfig.max}`);
  } catch (err) {
    console.error('❌ Database connection failed:', err.message);
  }
})();

module.exports = pool;
