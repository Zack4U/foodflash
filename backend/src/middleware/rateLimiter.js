const rateLimit = require("express-rate-limit");
// Rate limiter muy restrictivo (parte del problema)
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW) || 60000, // 1 minuto
  max: parseInt(process.env.RATE_LIMIT_REQUESTS) || 100, // Solo 100 requests por minuto
  message: {
    error: "Too many requests from this IP",
    retryAfter: "1 minute",
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next, options) => {
    console.warn();
    res.status(options.statusCode).json(options.message);
  },
});
module.exports = limiter;
