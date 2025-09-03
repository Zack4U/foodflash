const pool = require("../config/database");
const paymentService = require("../services/paymentService");
const notificationService = require("../services/notificationService");
exports.createOrder = async (req, res) => {
  const client = await pool.connect();
  try {
    const { userId, restaurantId, items, total, paymentInfo } = req.body;
    // Validación básica
    if (!userId || !restaurantId || !items || !total) {
      return res.status(400).json({ error: "Missing required fields" });
    }
    await client.query("BEGIN");
    // Insert order
    const orderResult = await client.query(
      "INSERT INTO orders (user_id, restaurant_id, total, items, status, created_at) VALUES (, , , , , ) RETURNING *",
      [
        userId,
        restaurantId,
        total,
        JSON.stringify(items),
        "pending",
        new Date(),
      ]
    );
    const orderId = orderResult.rows[0].id;
    // Update restaurant inventory (INEFICIENTE - consulta por cada item)
    for (let item of items) {
      const result = await client.query(
        "UPDATE inventory SET quantity = quantity -  WHERE restaurant_id =  AND item_id =  AND quantity >= ",
        [item.quantity || 1, restaurantId, item.id]
      );
      if (result.rowCount === 0) {
        throw new Error();
      }
    }
    // Process payment
    const paymentResult = await paymentService.processPayment(
      paymentInfo,
      total
    );
    if (!paymentResult.success) {
      throw new Error("Payment processing failed");
    }
    // Update order with payment info
    await client.query(
      "UPDATE orders SET payment_id = , status =  WHERE id = ",
      [paymentResult.paymentId, "confirmed", orderId]
    );
    await client.query("COMMIT");
    // client.release();
    // Send confirmation email
    await notificationService.sendOrderConfirmation(
      userId,
      orderResult.rows[0]
    );
    res.json({
      success: true,
      order: orderResult.rows[0],
      paymentId: paymentResult.paymentId,
    });
  } catch (error) {
    await client.query("ROLLBACK");
    // client.release();
    console.error("Order creation failed:", error);
    res.status(500).json({
      error: "Order creation failed",
      details:
        process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};
exports.getOrder = async (req, res) => {
  try {
    const { orderId } = req.params;
    const result = await pool.query(
      "SELECT o.*, u.email, u.name, r.name as restaurant_name FROM orders o JOIN users u ON o.user_id = u.id JOIN restaurants r ON o.restaurant_id = r.id WHERE o.id = ",
      [orderId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Order not found" });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error("Error fetching order:", error);
    res.status(500).json({ error: "Failed to fetch order" });
  }
};
exports.updateOrderStatus = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { status } = req.body;
    const validStatuses = [
      "pending",
      "confirmed",
      "preparing",
      "ready",
      "delivered",
      "cancelled",
    ];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: "Invalid status" });
    }
    const result = await pool.query(
      "UPDATE orders SET status = , updated_at =  WHERE id =  RETURNING *",
      [status, new Date(), orderId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Order not found" });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error("Error updating order:", error);
    res.status(500).json({ error: "Failed to update order" });
  }
};
exports.getOrdersByUser = async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await pool.query(
      "SELECT o.*, r.name as restaurant_name FROM orders o JOIN restaurants r ON o.restaurant_id = r.id WHERE o.user_id =  ORDER BY o.created_at DESC",
      [userId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error("Error fetching user orders:", error);
    res.status(500).json({ error: "Failed to fetch orders" });
  }
};
