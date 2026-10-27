package util;

/**
 * The v3 money rules, for showing them and for the unit tests. The database applies the same formulas
 * (dbo.fn_SizePrice, fn_HourRate, fn_OverdueRate, Deposit_* procedures, sql/03_v2_v3.sql);
 * PricingDatabaseIntegrationTest compares the two. The numbers themselves (5 minutes, 10,000 VND...) live in
 * the AppConfig table; the constants below are only the defaults the tests use.
 *
 * Price of a booking: plan price x size factor, rounded up to 100 VND. Every open method (PIN, card, finger)
 * costs the same; a first card only adds the one-time deposit, taken at the box.
 */
public final class Pricing {

    public static final long CARD_DEPOSIT = 10000;     // once per card, taken when the card is enrolled at the box
    public static final int HOLD_MIN = 15;             // a reservation waits this long after booking
    public static final int CANCEL_FREE_MIN = 5;       // cancel with a full refund only this soon after booking
    public static final int NO_SHOW_REFUND_PCT = 0;    // a no-show loses everything
    public static final long BOOKING_BUFFER = 10000;   // left in the wallet after booking, for a late fee
    public static final int OVERDUE_FEE_PCT = 150;     // one late hour costs 150% of one hour
    public static final int ESCALATE_HOURS = 48;       // overdue this long: handed to the staff
    public static final int DUE_REMINDER_MIN = 15;     // the due reminder e-mail goes out this long before

    private Pricing() {
    }

    private static long ceilDiv(long a, long b) {
        return (a + b - 1) / b;
    }

    /** Plan price times the size factor in percent, rounded up to 100 VND (5,000 x 169% = 8,450 -> 8,500). */
    public static long sizePrice(long planPrice, int sizePct) {
        return ceilDiv(planPrice * sizePct, 10000) * 100;
    }

    /** One hour of a size, from the shortest plan on sale: CEILING(sized x 60 / minutes / 100) x 100. */
    public static long hourRate(long basePrice, int baseMinutes, int sizePct) {
        if (baseMinutes <= 0) {
            return 0;
        }
        return ceilDiv(sizePrice(basePrice, sizePct) * 60, baseMinutes * 100L) * 100;
    }

    /** Late fee of one hour: feePct of the exact hour, rounded up once to 100 VND (S 3,800, M 4,900, L 6,400). */
    public static long overdueRate(long basePrice, int baseMinutes, int sizePct, int feePct) {
        if (baseMinutes <= 0) {
            return 0;
        }
        return ceilDiv(sizePrice(basePrice, sizePct) * 60 * feePct, baseMinutes * 10000L) * 100;
    }

    /** Late hours to pay: every started hour after due_at (0 when not late). */
    public static long overdueHours(long secondsLate) {
        return secondsLate <= 0 ? 0 : ceilDiv(secondsLate, 3600);
    }

    /** The slot locks once the grace time after due_at is over (strictly after). */
    public static boolean isLocked(long dueAtMs, int graceMin, long nowMs) {
        return dueAtMs + graceMin * 60_000L < nowMs;
    }

    /** A reservation can be cancelled for a full refund while less than cancelMin minutes have passed. */
    public static boolean canCancel(long reservedAtMs, int cancelMin, long nowMs) {
        return nowMs < reservedAtMs + cancelMin * 60_000L;
    }

    /** Handed to the staff when more than escalateHours have passed since due_at. */
    public static boolean isEscalated(long dueAtMs, int escalateHours, long nowMs) {
        return dueAtMs + escalateHours * 3_600_000L < nowMs;
    }

    /** The due reminder is due when due_at is in the future and at most reminderMin minutes away. */
    public static boolean reminderDue(long dueAtMs, int reminderMin, long nowMs) {
        return dueAtMs > nowMs && dueAtMs <= nowMs + reminderMin * 60_000L;
    }

    /** What an extension costs: one hour of the size for every started hour. */
    public static long extendCharge(int minutes, long hourRate) {
        return ceilDiv(minutes, 60) * hourRate;
    }

    /** What a no-show gets back (v3: refundPct is 0, nothing comes back). */
    public static long noShowRefund(long paid, int refundPct) {
        return paid * refundPct / 100;
    }

    public static long noShowRefund(long paid) {
        return noShowRefund(paid, NO_SHOW_REFUND_PCT);
    }

    /** Booking is allowed when, after paying (and keeping a first card deposit), the buffer is left. */
    public static boolean canBook(long balance, long price, long cardDeposit, long buffer) {
        return balance - price - cardDeposit >= buffer;
    }
}
