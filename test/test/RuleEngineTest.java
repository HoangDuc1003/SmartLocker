package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertFalse;
import static org.testng.Assert.assertTrue;

import model.LockerSession;
import org.testng.annotations.Test;
import service.RuleEngine;
import service.SessionContext;
import service.Verdict;

/**
 * One test per rule. No database and no server: RuleEngine only needs a session and a context.
 * Add one test for every new rule you write.
 */
public class RuleEngineTest {

    private final RuleEngine engine = new RuleEngine();

    private LockerSession session(double doorSec, double weightG, boolean rfidOk, double stayMin) {
        LockerSession s = new LockerSession();
        s.setDeviceId(1);
        s.setDoorOpenSec(doorSec);
        s.setWeightDeltaG(weightG);
        s.setRfidOk(rfidOk);
        s.setStayMin(stayMin);
        s.setUnlockCount(2);
        s.setSlotCode("A01");
        s.setCardUid("04A1B2C3");
        s.setOpenSource("RFID");
        return s;
    }

    /** A context in which nothing is wrong: valid ranges, the card of the booking owner, 130 minutes allowed. */
    private SessionContext healthy() {
        SessionContext c = new SessionContext();
        c.setRange("DOOR", 0, 3600);
        c.setRange("WEIGHT", -200, 20000);
        c.setRange("STAY", 0, 10080);
        c.setCardStatus("ACTIVE");
        c.setCardOwnerId(7);
        c.setDepositOwnerId(7);
        c.setAllowedMin(130);
        return c;
    }

    @Test
    public void normalSessionRaisesNothing() {
        Verdict v = engine.evaluate(session(6, 2, true, 40), healthy());
        assertEquals(v.getLabel(), "NORMAL");
        assertFalse(v.isAlert());
        assertTrue(v.isMlEligible());
    }

    @Test
    public void remoteOpenWithValidCommandIsNotForcedOpen() {
        LockerSession s = session(8, 0, false, 40);
        s.setOpenSource("REMOTE");
        s.setCommandId(15L);
        SessionContext ctx = healthy();
        ctx.setCommandValid(true);
        Verdict v = engine.evaluate(s, ctx);
        assertEquals(v.getLabel(), "STAFF_OPEN");
        assertFalse(v.isAlert());
        assertFalse(v.isMlEligible());
    }

    @Test
    public void openDuringRentalIsNotSpoof() {
        // v6: an ACCESS at the keypad opens the door and moves weight; a phone ACCESS comes with its SENT command
        LockerSession box = session(10, -80, true, 40);   // rfid_ok: the box accepted the credential
        box.setOpenSource("PIN");
        assertEquals(engine.evaluate(box, healthy()).getLabel(), "NORMAL");
        LockerSession phone = session(10, -80, false, 40);
        phone.setOpenSource("PHONE");
        phone.setCommandId(14L);
        SessionContext ctx = healthy();
        ctx.setCommandValid(true);
        assertEquals(engine.evaluate(phone, ctx).getLabel(), "STAFF_OPEN");
    }

    @Test
    public void remoteOpenWithoutCommandIsSpoof() {
        LockerSession s = session(8, 0, false, 40);
        s.setOpenSource("REMOTE");
        s.setCommandId(999999L);
        assertEquals(engine.evaluate(s, healthy()).getLabel(), "SUSPECTED_SPOOF");
    }

    @Test
    public void lostCardIsFlagged() {
        SessionContext ctx = healthy();
        ctx.setCardStatus("LOST");
        assertEquals(engine.evaluate(session(6, 2, true, 30), ctx).getLabel(), "LOST_CARD_USED");
    }

    @Test
    public void impossibleWeightIsSensorFaultNotForcedOpen() {
        Verdict v = engine.evaluate(session(6, -5000, false, 30), healthy());
        assertEquals(v.getLabel(), "SENSOR_FAULT");
        assertFalse(v.isMlEligible());
    }

    @Test
    public void expiredCalibrationIsSensorFault() {
        SessionContext ctx = healthy();
        ctx.setCalibrationValid(false);
        assertEquals(engine.evaluate(session(6, 2, true, 30), ctx).getLabel(), "SENSOR_FAULT");
    }

    @Test
    public void deviceClockAheadIsSensorFault() {
        SessionContext ctx = healthy();
        ctx.setUploadDelaySec(-3600);
        assertEquals(engine.evaluate(session(6, 2, true, 30), ctx).getLabel(), "SENSOR_FAULT");
    }

    @Test
    public void doorOpenedWithoutValidCardIsForcedOpen() {
        assertEquals(engine.evaluate(session(6, 2, false, 40), healthy()).getLabel(), "FORCED_OPEN");
    }

    @Test
    public void cardOfAnotherUserIsWrongUser() {
        SessionContext ctx = healthy();
        ctx.setCardOwnerId(9);
        assertEquals(engine.evaluate(session(6, 2, true, 40), ctx).getLabel(), "WRONG_USER");
    }

    @Test
    public void weightChangedWithClosedDoorIsSpoof() {
        assertEquals(engine.evaluate(session(0, -150, true, 40), healthy()).getLabel(), "SUSPECTED_SPOOF");
    }

    @Test
    public void itemStillInsideIsItemLeft() {
        assertEquals(engine.evaluate(session(6, 400, true, 40), healthy()).getLabel(), "ITEM_LEFT");
    }

    @Test
    public void stayLongerThanPlanIsOverdue() {
        assertEquals(engine.evaluate(session(6, 2, true, 200), healthy()).getLabel(), "OVERDUE");
    }
}
