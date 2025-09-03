import React, { useState, useEffect } from "react";
import axios from "axios";
import "./App.css";
function App() {
  const [restaurants, setRestaurants] = useState([
    {
      id: 1,
      name: "Pizza Palace",
      description: "Best pizza in town",
      rating: 4.5,
      delivery_time: 30,
    },
    {
      id: 2,
      name: "Burger Barn",
      description: "Gourmet burgers and fries",
      rating: 4.2,
      delivery_time: 25,
    },
    {
      id: 3,
      name: "Taco Fiesta",
      description: "Authentic Mexican cuisine",
      rating: 4.8,
      delivery_time: 35,
    },
  ]);
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  useEffect(() => {
    loadOrders();
  }, []);
  const loadOrders = async () => {
    try {
      const response = await axios.get("/api/orders/user/1");
      setOrders(response.data);
    } catch (error) {
      console.error("Error loading orders:", error);
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
          paymentMethodId: "pm_test_card",
        },
      };
      console.log("Placing order:", orderData);
      const response = await axios.post("/api/orders", orderData);
      if (response.data.success) {
        alert(`Order placed successfully at ${restaurantName}!`);
        loadOrders();
      }
    } catch (error) {
      const errorMessage = error.response?.data?.error || error.message;
      setError(`Failed to place order: ${errorMessage}`);
      console.error("Order error:", error);
    } finally {
      setLoading(false);
    }
  };
  return (
    <div className="App">
      <header className="App-header">
        <h1>FoodFlash</h1>
        <p>Fast food delivery at your fingertips</p>{" "}
      </header>
      {error && (
        <div
          style={{
            backgroundColor: "#ffebee",
            color: "#c62828",
            padding: "16px",
            margin: "16px",
            borderRadius: "4px",
            border: "1px solid #e57373",
          }}
        >
          {error}
        </div>
      )}
      <main style={{ padding: "20px", maxWidth: "1200px", margin: "0 auto" }}>
        <section>
          <h2>Available Restaurants</h2>
          {loading && <p>Processing order...</p>}
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))",
              gap: "20px",
              marginBottom: "40px",
            }}
          >
            {restaurants.map((restaurant) => (
              <div
                key={restaurant.id}
                style={{
                  border: "1px solid #ddd",
                  borderRadius: "8px",
                  padding: "20px",
                  backgroundColor: "#f9f9f9",
                }}
              >
                <h3>{restaurant.name}</h3>
                <p>{restaurant.description}</p>
                <p>{restaurant.rating}/5</p>
                <p>{restaurant.delivery_time} min delivery</p>{" "}
                <button
                  onClick={() => placeOrder(restaurant.id, restaurant.name)}
                  disabled={loading}
                  style={{
                    backgroundColor: loading ? "#ccc" : "#4CAF50",
                    color: "white",
                    padding: "10px 20px",
                    border: "none",
                    borderRadius: "4px",
                    cursor: loading ? "not-allowed" : "pointer",
                  }}
                >
                  {loading ? "Processing..." : "Order Now - $15.99"}{" "}
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
            <div
              style={{ display: "flex", flexDirection: "column", gap: "10px" }}
            >
              {orders.map((order) => (
                <div
                  key={order.id}
                  style={{
                    border: "1px solid #ddd",
                    borderRadius: "8px",
                    padding: "15px",
                    backgroundColor: "#ffffff",
                  }}
                >
                  <p>
                    <strong>Order #{order.id}</strong>
                  </p>{" "}
                  <p>
                    Status:{" "}
                    <span
                      style={{
                        padding: "4px 8px",
                        borderRadius: "4px",
                        backgroundColor:
                          order.status === "delivered"
                            ? "#4CAF50"
                            : order.status === "preparing"
                            ? "#FF9800"
                            : "#2196F3",
                        color: "white",
                      }}
                    >
                      {order.status}
                    </span>
                  </p>
                  <p>Total: ${order.total}</p>
                  <p>Date: {new Date(order.created_at).toLocaleDateString()}</p>
                  {order.restaurant_name && (
                    <p>Restaurant: {order.restaurant_name}</p>
                  )}
                </div>
              ))}
            </div>
          )}
        </section>
      </main>
      <footer
        style={{
          textAlign: "center",
          padding: "20px",
          marginTop: "40px",
          borderTop: "1px solid #eee",
        }}
      >
        <p>© 2025 FoodFlash - Powered by hunger and code</p>{" "}
        <p>
          Server Status: <span id="server-status">Checking...</span>
        </p>
      </footer>
    </div>
  );
}
export default App;
