package tool;

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
 * Run with Run File in NetBeans (test/tool is a test source root, so it is not packed into the WAR).
 * The working directory is the project folder, so the files land in src/java/ml.
 */
public class ModelTrainer {

    /** The columns of PublicSession used as features, in this order. RiskScorer reads the names from the ARFF header. */
    public static final String[] FEATURES = {"door_open_sec", "weight_delta_g", "unlock_count", "rfid_ok", "stay_min"};

    public static void main(String[] args) throws Exception {
        // load the table, compare, save the winner
        Instances data = loadFromDatabase("SELECT " + String.join(", ", FEATURES)
                + ", label FROM PublicSession WHERE label IS NOT NULL");
        Classifier best = compare(data);
        save(best, data, new File("src/java/ml"));
    }

    /** Prints one line per algorithm and returns the winner (best weighted F1), already trained on all rows. */
    public static Classifier compare(Instances data) throws Exception {
        // crossValidateModel(model, data, 10, new Random(42)), weighted precision, recall and F1
        Map<String, Classifier> models = new LinkedHashMap<String, Classifier>();
        models.put("RandomForest", new RandomForest());
        models.put("J48", new J48());
        models.put("NaiveBayes", new NaiveBayes());
        models.put("IBk", new IBk(5));

        System.out.printf("%-14s %9s %10s %8s %8s%n", "model", "accuracy", "precision", "recall", "f1");
        Classifier best = null;
        double bestF1 = -1;
        for (Map.Entry<String, Classifier> entry : models.entrySet()) {
            Evaluation eval = new Evaluation(data);
            eval.crossValidateModel(entry.getValue(), data, 10, new Random(42));
            System.out.printf("%-14s %9.4f %10.4f %8.4f %8.4f%n", entry.getKey(), eval.pctCorrect() / 100,
                    eval.weightedPrecision(), eval.weightedRecall(), eval.weightedFMeasure());
            if (eval.weightedFMeasure() > bestF1) {
                bestF1 = eval.weightedFMeasure();
                best = entry.getValue();
            }
        }
        best.buildClassifier(data);          // cross validation trained copies; train the winner on every row
        return best;
    }

    /** Writes locker_model.bin (the trained classifier) and locker_header.arff (attribute names, no rows). */
    public static void save(Classifier model, Instances data, File folder) throws Exception {
        // SerializationHelper.write and an empty copy of the data as the header
        folder.mkdirs();
        SerializationHelper.write(new File(folder, "locker_model.bin").getPath(), model);
        try (PrintWriter out = new PrintWriter(new File(folder, "locker_header.arff"), "UTF-8")) {
            out.print(new Instances(data, 0).toString());
        }
        System.out.println("saved the model to " + folder.getAbsolutePath());
    }

    /** Builds a Weka dataset from rows of numbers (the FEATURES) and one text label per row. */
    public static Instances build(List<double[]> rows, List<String> rowLabels) {
        // the class labels are the distinct texts, in the order they appear
        List<String> labels = new ArrayList<String>();
        for (String label : rowLabels) {
            if (!labels.contains(label)) {
                labels.add(label);
            }
        }
        return build(rows, rowLabels, labels);
    }

    /** Same, with the class labels given: two data sets built with the same list have the same header and can be compared. */
    public static Instances build(List<double[]> rows, List<String> rowLabels, List<String> labels) {
        // numeric attributes, one nominal class, the class is the last column
        ArrayList<Attribute> attributes = new ArrayList<Attribute>();
        for (String name : FEATURES) {
            attributes.add(new Attribute(name));
        }
        attributes.add(new Attribute("label", labels));
        Instances data = new Instances("locker", attributes, rows.size());
        data.setClassIndex(attributes.size() - 1);
        for (int i = 0; i < rows.size(); i++) {
            double[] values = new double[FEATURES.length + 1];
            System.arraycopy(rows.get(i), 0, values, 0, FEATURES.length);
            values[FEATURES.length] = labels.indexOf(rowLabels.get(i));
            data.add(new DenseInstance(1.0, values));
        }
        return data;
    }

    /** Rows of numbers and one label per row, as they come out of a query. */
    public static class Table {
        public final List<double[]> rows = new ArrayList<double[]>();
        public final List<String> labels = new ArrayList<String>();
    }

    /** Reads the FEATURES and the label from a query, then calls build(). */
    public static Instances loadFromDatabase(String sql) throws Exception {
        Table t = readTable(sql);
        return build(t.rows, t.labels);
    }

    public static Table readTable(String sql) throws Exception {
        // one double per feature, the label as text
        Table table = new Table();
        try (Connection conn = DbContext.getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) {
                double[] values = new double[FEATURES.length];
                for (int i = 0; i < FEATURES.length; i++) {
                    values[i] = rs.getDouble(FEATURES[i]);
                }
                table.rows.add(values);
                table.labels.add(rs.getString("label"));
            }
        }
        return table;
    }
}
