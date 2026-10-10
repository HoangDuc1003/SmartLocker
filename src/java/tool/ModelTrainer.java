package tool;

import util.Todo;
import dao.DbContext;
import java.io.File;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import weka.classifiers.Classifier;
import weka.classifiers.Evaluation;
import weka.classifiers.bayes.NaiveBayes;
import weka.classifiers.lazy.IBk;
import weka.classifiers.trees.J48;
import weka.classifiers.trees.RandomForest;
import weka.core.Attribute;
import weka.core.DenseInstance;
import weka.core.Instances;
import weka.core.SerializationHelper;

/**
 * Compares four algorithms with 10-fold cross validation on the sessions of PublicSession (the TON_IoT data),
 * prints the table that goes into the report, trains the best one on all rows and saves it for RiskScorer.
 * Run with Run File in NetBeans. The working directory is the project folder, so the files land in src/java/ml.
 */
public class ModelTrainer {

    /** The columns of PublicSession used as features, in this order. RiskScorer reads the names from the ARFF header. */
    public static final String[] FEATURES = {"door_open_sec", "weight_delta_g", "unlock_count", "rfid_ok", "stay_min"};

    public static void main(String[] args) throws Exception {
        throw Todo.of("ModelTrainer.main: load the table, compare, save the winner");
    }

    /** Prints one line per algorithm and returns the winner (best weighted F1), already trained on all rows. */
    public static Classifier compare(Instances data) throws Exception {
        throw Todo.of("ModelTrainer.compare: crossValidateModel(model, data, 10, new Random(42)), weighted precision, recall and F1");
    }

    /** Writes locker_model.bin (the trained classifier) and locker_header.arff (attribute names, no rows). */
    public static void save(Classifier model, Instances data, File folder) throws Exception {
        throw Todo.of("ModelTrainer.save: SerializationHelper.write and an empty copy of the data as the header");
    }

    /** Builds a Weka dataset from rows of numbers (the FEATURES) and one text label per row. */
    public static Instances build(List<double[]> rows, List<String> rowLabels) {
        throw Todo.of("ModelTrainer.build: the class labels are the distinct texts, in the order they appear");
    }

    /** Same, with the class labels given: two data sets built with the same list have the same header and can be compared. */
    public static Instances build(List<double[]> rows, List<String> rowLabels, List<String> labels) {
        throw Todo.of("ModelTrainer.build: numeric attributes, one nominal class, the class is the last column");
    }

    /** Rows of numbers and one label per row, as they come out of a query. */
    public static class Table {
        public final List<double[]> rows = new ArrayList<double[]>();
        public final List<String> labels = new ArrayList<String>();
    }

    /** Reads the FEATURES and the label from a query, then calls build(). */
    public static Instances loadFromDatabase(String sql) throws Exception {
        throw Todo.of("ModelTrainer.loadFromDatabase");
    }

    public static Table readTable(String sql) throws Exception {
        throw Todo.of("ModelTrainer.readTable: one double per feature, the label as text");
    }
}
