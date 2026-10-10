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
 * SKELETON. Explained in docs/HUONG_DAN_TUNG_FILE.md, section "test/RuleEngineTest.java".
 * One test per rule. No database and no server: RuleEngine only needs a session and a context.
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

    // TODO remoteOpenWithValidCommandIsNotForcedOpen   (case 2: open_source REMOTE + commandValid -> STAFF_OPEN, no alert, not for the model)
    // TODO remoteOpenWithoutCommandIsSpoof             (case 2: REMOTE with an unknown command id -> SUSPECTED_SPOOF)
    // TODO lostCardIsFlagged                           (case 3: card status LOST -> LOST_CARD_USED)
    // TODO impossibleWeightIsSensorFaultNotForcedOpen  (case 5: weight -5000 -> SENSOR_FAULT, not for the model)
    // TODO expiredCalibrationIsSensorFault             (case 5)
    // TODO deviceClockAheadIsSensorFault               (case 5: setUploadDelaySec(-3600))
    // TODO doorOpenedWithoutValidCardIsForcedOpen      (rfid false, door open)
    // TODO cardOfAnotherUserIsWrongUser                (card owner is not the booking owner)
    // TODO weightChangedWithClosedDoorIsSpoof          (door 0 s, weight moved)
    // TODO itemStillInsideIsItemLeft                   (weight 400 g)
    // TODO stayLongerThanPlanIsOverdue                 (stay 200 min, 130 allowed)
}
