package test;

import static org.testng.Assert.assertNotNull;
import static org.testng.Assert.assertTrue;

import model.LockerSession;
import org.testng.annotations.Test;
import service.RiskScorer;

/**
 * Tests for RiskScorer loading the Weka classifier and scoring normal and abnormal sessions.
 */
public class RiskScorerTest {

    @Test
    public void testRiskScoringWithTrainedModel() {
        RiskScorer scorer = RiskScorer.getInstance();
        assertNotNull(scorer);

        // Normal session
        LockerSession normal = new LockerSession();
        normal.setDoorOpenSec(8.0);
        normal.setWeightDeltaG(0.0);
        normal.setUnlockCount(1);
        normal.setRfidOk(true);
        normal.setStayMin(30.0);

        double normalRisk = scorer.score(normal);
        assertTrue(normalRisk >= 0.0 && normalRisk <= 1.0, "Risk score must be between 0 and 1");

        // Abnormal session (forced open pattern: no RFID, long open door, 0 stay)
        LockerSession abnormal = new LockerSession();
        abnormal.setDoorOpenSec(80.0);
        abnormal.setWeightDeltaG(0.0);
        abnormal.setUnlockCount(0);
        abnormal.setRfidOk(false);
        abnormal.setStayMin(1.0);

        double abnormalRisk = scorer.score(abnormal);
        assertTrue(abnormalRisk >= 0.0 && abnormalRisk <= 1.0, "Risk score must be between 0 and 1");
        assertTrue(abnormalRisk >= normalRisk, "Abnormal session risk should be >= normal session risk");
    }
}
