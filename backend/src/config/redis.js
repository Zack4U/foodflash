const redis = require("redis");
// Redis client sin retry strategy
const redisClient = redis.createClient({
  host: process.env.REDIS_HOST || "localhost",
  port: parseInt(process.env.REDIS_PORT) || 6379,
  password: process.env.REDIS_PASSWORD || undefined,
});
redisClient.on("error", (err) => {
  console.error("Redis Client Error:", err);
});
redisClient.on("connect", () => {
  console.log("Redis connected successfully");
});
redisClient.on("ready", () => {
  console.log("Redis client ready");
});
// Connect to Redis
redisClient.connect().catch(console.error);
module.exports = redisClient;
