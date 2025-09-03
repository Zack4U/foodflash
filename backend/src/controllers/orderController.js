// backend/src/controllers/orderController.js
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

    // Insertar orden
    const orderResult = await client.query(
      'INSERT INTO orders (user_id, restaurant_id, total, items, status, created_at) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [userId, restaurantId, total, JSON.stringify(items), 'pending', new Date()]
    );

    const orderId = orderResult.rows[0].id;

    // Actualizar inventario
    for (let item of items) {
      const result = await client.query(
        'UPDATE inventory SET quantity = quantity - $1 WHERE restaurant_id = $2 AND item_id = $3 AND quantity >= $1',
        [item.quantity || 1, restaurantId, item.id]
      );

      if (result.rowCount === 0) {
        throw new Error(`Insufficient inventory for item ${item.name}`);
      }
    }

    // Procesar pago
    const paymentResult = await paymentService.processPayment(paymentInfo, total);
    if (!paymentResult.success) {
      throw new Error('Payment processing failed');
    }

    // Actualizar orden con info de pago
    await client.query(
      'UPDATE orders SET payment_id = $1, status = $2 WHERE id = $3',
      [paymentResult.paymentId, 'confirmed', orderId]
    );

    await client.query('COMMIT');

    // Enviar notificación fuera del flujo crítico
    notificationService
      .sendOrderConfirmation(userId, orderResult.rows[0])
      .catch(err => console.error('Notification error:', err.message));

    res.json({
      success: true,
      order: orderResult.rows[0],
      paymentId: paymentResult.paymentId
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Order creation failed:', error.message);
    res.status(500).json({
      error: 'Order creation failed',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  } finally {
    client.release(); // 🔥 Siempre liberar el cliente
  }
};

exports.getOrder = async (req, res) => {
  try {
    const { orderId } = req.params;

    const result = await pool.query(
      `SELECT o.*, u.email, u.name, r.name as restaurant_name
       FROM orders o
       JOIN users u ON o.user_id = u.id
       JOIN restaurants r ON o.restaurant_id = r.id
       WHERE o.id = $1`,
      [orderId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching order:', error.message);
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
    console.error('Error updating order:', error.message);
    res.status(500).json({ error: 'Failed to update order' });
  }
};

exports.getOrdersByUser = async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await pool.query(
      `SELECT o.*, r.name as restaurant_name
       FROM orders o
       JOIN restaurants r ON o.restaurant_id = r.id
       WHERE o.user_id = $1
       ORDER BY o.created_at DESC`,
      [userId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching user orders:', error.message);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
};
