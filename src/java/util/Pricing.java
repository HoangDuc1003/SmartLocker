package util;

/**
 * The v2 price rules, for showing them. The database applies the same rules (dbo.fn_OpenPrice, Deposit_ExpireNoShow).
 */
public final class Pricing {

    public static final long CARD_DEPOSIT = 30000;   // once per card, taken when the card is enrolled at the box
    public static final int HOLD_MIN = 15;           // a reservation waits this long

    private Pricing() {
    }

    /** Price of a plan for an open method: the card is 5% off, rounded up to 100 VND (5,000 -> 4,800). */
    public static long priceFor(long planPrice, String openMethod) {
        if (!"CARD".equals(openMethod)) {
            return planPrice;
        }
        return (planPrice * 95 + 9999) / 10000 * 100;
    }

    /** What a no-show gets back: 90%, the shop keeps CEILING(10%). */
    public static long noShowRefund(long paid) {
        return paid - (paid + 9) / 10;
    }
}
