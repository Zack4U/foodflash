class PaymentService {
  async processPayment(paymentInfo, amount) {
    try {
      // Simular timeout ocasional para agregar estrés
      if (Math.random() < 0.1) {
        // 10% chance de timeout
        await new Promise((resolve) => setTimeout(resolve, 30000));
      }
      // Simular procesamiento de pago
      const paymentId = "pi_" + Math.random().toString(36).substr(2, 9);
      return {
        success: true,
        paymentId: paymentId,
        status: "succeeded",
      };
    } catch (error) {
      console.error("Payment processing error:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  }
  async refundPayment(paymentId, amount) {
    try {
      const refundId = "re_" + Math.random().toString(36).substr(2, 9);
      return {
        success: true,
        refundId: refundId,
        status: "succeeded",
      };
    } catch (error) {
      console.error("Refund processing error:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  }
}
module.exports = new PaymentService();
