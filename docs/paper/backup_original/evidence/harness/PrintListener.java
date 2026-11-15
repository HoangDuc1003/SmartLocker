// Evidence harness: prints every TestNG result with its status and skip reason.
import org.testng.ITestResult;
import org.testng.TestListenerAdapter;

public class PrintListener extends TestListenerAdapter {
    private static void line(String s, ITestResult r) {
        Throwable t = r.getThrowable();
        System.out.println(s + " " + r.getTestClass().getRealClass().getSimpleName() + "." + r.getMethod().getMethodName()
                + (t != null ? "  -- " + t.getClass().getSimpleName() + ": " + t.getMessage() : ""));
    }
    @Override public void onTestSuccess(ITestResult r) { line("PASS", r); }
    @Override public void onTestFailure(ITestResult r) { line("FAIL", r); }
    @Override public void onTestSkipped(ITestResult r) { line("SKIP", r); }
}
