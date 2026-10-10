package tool;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Random;
import tool.ModelTrainer.Table;
import weka.classifiers.Classifier;
import weka.classifiers.Evaluation;
import weka.classifiers.trees.RandomForest;
import weka.core.Instances;

/**
 * The "new point" of the assignment: how much does a model trained on the public data lose on a real locker?
 * Trains on PublicSession, tests on the labelled sessions of the device, and prints the two F1 numbers.
 * Both sets are reduced to two labels, NORMAL and ABNORMAL, so they share one header.
 * Needs about 100 labelled device sessions (table LockerSessionLabel). Run with Run File.
 */
public class TransferCheck {

    private static final List<String> LABELS = Arrays.asList("NORMAL", "ABNORMAL");
    private static final String COLUMNS = String.join(", ", ModelTrainer.FEATURES) + ", label";

    public static void main(String[] args) throws Exception {
        // read the two tables, call run(), print the drop
        Table publicSessions = ModelTrainer.readTable("SELECT " + COLUMNS + " FROM PublicSession WHERE label IS NOT NULL");
        Table deviceSessions = ModelTrainer.readTable("SELECT " + COLUMNS + " FROM v_LockerSession_Features");
        double[] f1 = run(publicSessions, deviceSessions);
        System.out.printf("F1 on public data (10-fold cross validation): %.3f%n", f1[0]);
        System.out.printf("F1 on real device data                      : %.3f%n", f1[1]);
        System.out.printf("drop when moving from the lab to the device : %.3f%n", f1[0] - f1[1]);
    }

    /** {F1 on the public data by cross validation, F1 of the model trained on all of it and tested on the device data}. */
    public static double[] run(Table publicSessions, Table deviceSessions) throws Exception {
        // build both with the same two labels; cross validate; train on everything; evaluateModel on the device data
        Instances publicData = ModelTrainer.build(publicSessions.rows, binary(publicSessions.labels), LABELS);
        Instances deviceData = ModelTrainer.build(deviceSessions.rows, binary(deviceSessions.labels), LABELS);

        Classifier model = new RandomForest();
        Evaluation crossValidation = new Evaluation(publicData);
        crossValidation.crossValidateModel(model, publicData, 10, new Random(42));

        model.buildClassifier(publicData);
        Evaluation onDevice = new Evaluation(publicData);
        onDevice.evaluateModel(model, deviceData);
        return new double[]{crossValidation.weightedFMeasure(), onDevice.weightedFMeasure()};
    }

    private static List<String> binary(List<String> labels) {
        List<String> out = new ArrayList<String>();
        for (String label : labels) {
            out.add("NORMAL".equals(label) ? "NORMAL" : "ABNORMAL");
        }
        return out;
    }
}
