// Evidence harness for the paper: re-runs the comparison of test/tool/ModelTrainer.compare (same models, same
// 10-fold CV with new Random(42)) on PublicSession, adds the binary setting, the RF confusion matrix and timings.
// It never calls ModelTrainer.save, so src/java/ml is not touched.
import java.util.*;
import tool.ModelTrainer;
import weka.classifiers.*;
import weka.classifiers.bayes.NaiveBayes;
import weka.classifiers.lazy.IBk;
import weka.classifiers.trees.*;
import weka.core.*;

public class MlEvidence {
    static Map<String, Classifier> models() {
        Map<String, Classifier> m = new LinkedHashMap<String, Classifier>();
        m.put("RandomForest", new RandomForest());
        m.put("J48", new J48());
        m.put("NaiveBayes", new NaiveBayes());
        m.put("IBk", new IBk(5));
        return m;
    }

    static void table(String title, Instances data, boolean cm) throws Exception {
        System.out.println("\n== " + title + " (" + data.numInstances() + " rows, 10-fold CV, new Random(42)) ==");
        System.out.printf("%-14s %9s %10s %8s %8s %12s %14s%n", "model", "accuracy", "precision", "recall", "f1",
                "train_ms", "infer_us/row");
        for (Map.Entry<String, Classifier> e : models().entrySet()) {
            Evaluation eval = new Evaluation(data);
            eval.crossValidateModel(e.getValue(), data, 10, new Random(42));
            // training time on all rows: median of 11 fresh builds (first one also printed)
            long[] t = new long[11];
            Classifier last = null;
            for (int i = 0; i < t.length; i++) {
                Classifier c = AbstractClassifier.makeCopy(models().get(e.getKey()));
                long s = System.nanoTime();
                c.buildClassifier(data);
                t[i] = System.nanoTime() - s;
                last = c;
            }
            long first = t[0];
            Arrays.sort(t);
            // inference: 20 x N predictions after a warm-up pass, averaged
            for (int i = 0; i < data.numInstances(); i++) last.distributionForInstance(data.instance(i));
            long s = System.nanoTime();
            for (int r = 0; r < 20; r++)
                for (int i = 0; i < data.numInstances(); i++) last.distributionForInstance(data.instance(i));
            double us = (System.nanoTime() - s) / 1000.0 / (20.0 * data.numInstances());
            System.out.printf("%-14s %9.4f %10.4f %8.4f %8.4f %5.1f(1st %5.1f) %10.2f%n", e.getKey(), eval.pctCorrect() / 100,
                    eval.weightedPrecision(), eval.weightedRecall(), eval.weightedFMeasure(), t[5] / 1e6, first / 1e6, us);
            if (cm && e.getKey().equals("RandomForest") || cm && e.getKey().equals("IBk")) {
                System.out.println(eval.toMatrixString("-- confusion matrix " + e.getKey() + " --"));
                for (int k = 0; k < data.numClasses(); k++)
                    System.out.printf("   F1[%s] = %.4f%n", data.classAttribute().value(k), eval.fMeasure(k));
            }
            if (!cm && e.getKey().equals("NaiveBayes")) {
                System.out.println(eval.toMatrixString("-- binary confusion matrix NaiveBayes --"));
            }
        }
    }

    public static void main(String[] a) throws Exception {
        String sql = "SELECT " + String.join(", ", ModelTrainer.FEATURES) + ", label FROM PublicSession WHERE label IS NOT NULL";
        System.out.println("query: " + sql);
        ModelTrainer.Table t = ModelTrainer.readTable(sql);
        Map<String, Integer> counts = new TreeMap<String, Integer>();
        for (String l : t.labels) counts.put(l, counts.containsKey(l) ? counts.get(l) + 1 : 1);
        System.out.println("rows=" + t.rows.size() + " class counts=" + counts);
        System.out.println("java=" + System.getProperty("java.version") + " weka=" + weka.core.Version.VERSION);
        table("six classes", ModelTrainer.build(t.rows, t.labels), true);
        List<String> bin = new ArrayList<String>();
        for (String l : t.labels) bin.add("NORMAL".equals(l) ? "NORMAL" : "ABNORMAL");
        table("binary NORMAL vs ABNORMAL, labels in order of appearance", ModelTrainer.build(t.rows, bin), false);
        table("binary NORMAL vs ABNORMAL, label order {NORMAL, ABNORMAL}",
                ModelTrainer.build(t.rows, bin, Arrays.asList("NORMAL", "ABNORMAL")), false);
        table("binary NORMAL vs ABNORMAL, label order {ABNORMAL, NORMAL}",
                ModelTrainer.build(t.rows, bin, Arrays.asList("ABNORMAL", "NORMAL")), false);
    }
}
