package support;

import org.testng.ITestResult;
import org.testng.TestListenerAdapter;

/** TestNG runs without its default reporters in scripts/test.sh; this prints which test failed or was skipped, and why. */
public class FailurePrinter extends TestListenerAdapter {

    private static void print(String word, ITestResult r) {
        Throwable t = r.getThrowable();
        System.out.println(word + " " + r.getTestClass().getRealClass().getSimpleName() + "." + r.getName()
                + (t == null ? "" : ": " + t));
    }

    @Override public void onTestFailure(ITestResult r) {
        print("FAILED", r);
    }

    @Override public void onTestSkipped(ITestResult r) {
        print("SKIPPED", r);
    }

    @Override public void onConfigurationFailure(ITestResult r) {
        print("FAILED SETUP", r);
    }
}
