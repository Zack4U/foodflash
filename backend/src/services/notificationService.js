class NotificationService {
  async sendOrderConfirmation(userId, order) {
    try {
      // Simular envío de email
      console.log();
      // Simular delay ocasional
      await new Promise((resolve) => setTimeout(resolve, 100));
      return {
        success: true,
        messageId: "msg_" + Math.random().toString(36).substr(2, 9),
      };
    } catch (error) {
      console.error("Email sending error:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  }
}
module.exports = new NotificationService();
