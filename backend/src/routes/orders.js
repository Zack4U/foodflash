const express = require("express");
const orderController = require("../controllers/orderController");
const router = express.Router();
// Crear orden
router.post("/", orderController.createOrder);
// Obtener orden por ID
router.get("/:orderId", orderController.getOrder);
// Actualizar status de orden
router.put("/:orderId/status", orderController.updateOrderStatus);
// Obtener órdenes de un usuario
router.get("/user/:userId", orderController.getOrdersByUser);
module.exports = router;
