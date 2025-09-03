require("dotenv").config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const orderRoutes = require("./routes/orders");
const rateLimiter = require("./middleware/rateLimiter");
const app = express();
const PORT = process.env.PORT || 3001;

// Security middleware
app.use(helmet());
app.use(cors());

// Rate limiting
app.use("/api/", rateLimiter);

// Body parsing
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true }));

// Routes
app.use("/api/orders", orderRoutes);

// Health check
app.get("/health", (req, res) => {
  res.json({
    status: "OK",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
  });
});

// API Health check
app.get("/api/health", (req, res) => {
  res.json({
    status: "API OK",
    timestamp: new Date().toISOString(),
    version: "1.0.0",
  });
});

// Endpoint para simular carga
app.post("/api/stress-test", async (req, res) => {
  const { iterations = 100 } = req.body;
  console.log(`Starting stress test with ${iterations} iterations`);
  for (let i = 0; i < iterations; i++) {
    const data = new Array(10000).fill(Math.random());
    await new Promise((resolve) => setTimeout(resolve, 1));
  }
  res.json({
    message: `Stress test completed: ${iterations} iterations`,
    memoryUsage: process.memoryUsage(),
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error("Error:", err);
  res.status(500).json({
    error: "Internal Server Error",
    message:
      process.env.NODE_ENV === "development"
        ? err.message
        : "Something went wrong",
  });
});

// 404 handler
app.use("*", (req, res) => {
  res.status(404).json({ error: "Route not found" });
});

app.listen(PORT, () => {
  console.log(`FoodFlash Server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
});
module.exports = app;
