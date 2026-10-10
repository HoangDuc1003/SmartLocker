package tool;

import util.Todo;
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
        throw Todo.of("TransferCheck.main: read the two tables, call run(), print the drop");
    }

    /** {F1 on the public data by cross validation, F1 of the model trained on all of it and tested on the device data}. */
    public static double[] run(Table publicSessions, Table deviceSessions) throws Exception {
        throw Todo.of("TransferCheck.run: build both with the same two labels; cross validate; train on everything; evaluateModel on the device data");
    }

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: every label that is not NORMAL becomes ABNORMAL
}
