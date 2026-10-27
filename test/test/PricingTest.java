package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertFalse;
import static org.testng.Assert.assertTrue;

import org.testng.annotations.Test;
import util.Pricing;

/** Pure Java, no database: the v3 money rules (docs/spec/smart-locker-v3.md, section 3). */
public class PricingTest {

    private static final int S = 100, M = 130, L = 169;
    private static final long BASE = 5000;      // the shortest plan on sale: 2 hours, 5,000 VND
    private static final int BASE_MIN = 120;
    private static final long T0 = 1_800_000_000_000L;

    // ---- price of a booking: plan -> size, the same for every open method ----

    @Test
    public void sizeFactorRoundsUpTo100() {
        assertEquals(Pricing.sizePrice(5000, S), 5000);
        assertEquals(Pricing.sizePrice(5000, M), 6500);
        assertEquals(Pricing.sizePrice(5000, L), 8500);      // 8,450 -> 8,500
        assertEquals(Pricing.sizePrice(9000, L), 15300);     // 15,210 -> 15,300
        assertEquals(Pricing.sizePrice(25000, L), 42300);    // 42,250 -> 42,300
    }

    @Test
    public void theTableOfSection31() {
        // S, M, L for the 2-hour, 4-hour and whole-day plans (v5: the card is no longer 5% off)
        long[][] expected = {
            {5000, 6500, 8500},
            {9000, 11700, 15300},
            {25000, 32500, 42300}};
        long[] plans = {5000, 9000, 25000};
        int[] sizes = {S, M, L};
        for (int p = 0; p < plans.length; p++) {
            for (int z = 0; z < sizes.length; z++) {
                assertEquals(Pricing.sizePrice(plans[p], sizes[z]), expected[p][z], plans[p] + " " + sizes[z]);
            }
        }
    }

    // ---- hour prices (Q3: one price per size, from the shortest plan) ----

    @Test
    public void hourRateOfEachSize() {
        assertEquals(Pricing.hourRate(BASE, BASE_MIN, S), 2500);
        assertEquals(Pricing.hourRate(BASE, BASE_MIN, M), 3300);   // 3,250 -> 3,300
        assertEquals(Pricing.hourRate(BASE, BASE_MIN, L), 4300);   // 4,250 -> 4,300
    }

    @Test
    public void lateFeeIs150PercentOfTheExactHourRoundedOnce() {
        assertEquals(Pricing.overdueRate(BASE, BASE_MIN, S, 150), 3800);   // 3,750 -> 3,800
        assertEquals(Pricing.overdueRate(BASE, BASE_MIN, M, 150), 4900);   // 4,875 -> 4,900
        assertEquals(Pricing.overdueRate(BASE, BASE_MIN, L, 150), 6400);   // 6,375 -> 6,400
        assertEquals(Pricing.overdueRate(BASE, 0, L, 150), 0);             // no plan on sale
    }

    @Test
    public void lateHoursAreStartedHours() {
        assertEquals(Pricing.overdueHours(-5), 0);
        assertEquals(Pricing.overdueHours(0), 0);
        assertEquals(Pricing.overdueHours(1), 1);
        assertEquals(Pricing.overdueHours(3600), 1);
        assertEquals(Pricing.overdueHours(3601), 2);
        assertEquals(Pricing.overdueHours(2 * 3600 + 600), 3);     // 2 h 10 min late
        assertEquals(Pricing.overdueHours(3 * 3600) * 4900, 14700); // the example of the spec, size M
    }

    @Test
    public void extensionCostsOneHourOfTheSizePerStartedHour() {
        assertEquals(Pricing.extendCharge(15, 3300), 3300);
        assertEquals(Pricing.extendCharge(60, 3300), 3300);
        assertEquals(Pricing.extendCharge(90, 3300), 6600);
        assertEquals(Pricing.extendCharge(240, 4300), 17200);
    }

    // ---- cancel, no-show, booking buffer ----

    @Test
    public void noShowGetsNothingBack() {
        assertEquals(Pricing.noShowRefund(6500), 0);
        assertEquals(Pricing.noShowRefund(6500, 90), 5850);     // the v2 rule, for comparison
    }

    @Test
    public void cancelOnlyInTheFirstFiveMinutes() {
        assertTrue(Pricing.canCancel(T0, 5, T0));
        assertTrue(Pricing.canCancel(T0, 5, T0 + 299_999));      // 4:59.999
        assertFalse(Pricing.canCancel(T0, 5, T0 + 300_000));     // 5:00
        assertFalse(Pricing.canCancel(T0, 5, T0 + 600_000));
    }

    @Test
    public void tenThousandMustStayAfterBooking() {
        assertTrue(Pricing.canBook(16500, 6500, 0, 10000));
        assertFalse(Pricing.canBook(16499, 6500, 0, 10000));
        assertTrue(Pricing.canBook(26500, 6500, 10000, 10000));  // a first card also keeps its 10,000 deposit
        assertFalse(Pricing.canBook(26499, 6500, 10000, 10000));
        assertFalse(Pricing.canBook(-100, 0, 0, 10000));         // a debt blocks every booking
    }

    // ---- time marks: hold 15 minutes, lock after grace, escalate after 48 hours, remind 15 minutes before ----

    @Test
    public void holdIsFifteenMinutes() {
        assertEquals(Pricing.HOLD_MIN, 15);
    }

    @Test
    public void lockStartsStrictlyAfterTheGrace() {
        long due = T0;
        assertFalse(Pricing.isLocked(due, 10, due));
        assertFalse(Pricing.isLocked(due, 10, due + 600_000));   // exactly at the end of grace
        assertTrue(Pricing.isLocked(due, 10, due + 600_001));
    }

    @Test
    public void escalationAfterFortyEightHours() {
        long due = T0;
        assertFalse(Pricing.isEscalated(due, 48, due + 48 * 3_600_000L));
        assertTrue(Pricing.isEscalated(due, 48, due + 48 * 3_600_000L + 1));
    }

    @Test
    public void reminderWindowIsTheLastFifteenMinutes() {
        long now = T0;
        assertTrue(Pricing.reminderDue(now + 15 * 60_000L, 15, now));
        assertTrue(Pricing.reminderDue(now + 1, 15, now));
        assertFalse(Pricing.reminderDue(now + 15 * 60_000L + 1, 15, now));
        assertFalse(Pricing.reminderDue(now, 15, now));            // already due: too late for a reminder
    }
}
