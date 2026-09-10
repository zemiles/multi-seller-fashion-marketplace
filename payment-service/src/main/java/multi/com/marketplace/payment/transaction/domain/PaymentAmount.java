package multi.com.marketplace.payment.transaction.domain;

/** Integer minor units, matching the database bigint amount columns. */
public record PaymentAmount(String currency, long amount) {
    public PaymentAmount {
        if (currency == null || !currency.matches("[A-Z]{3}")) {
            throw new IllegalArgumentException("Currency must contain three uppercase letters");
        }
        if (amount <= 0) {
            throw new IllegalArgumentException("Payment amount must be positive");
        }
    }
}
