package service;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.logging.Logger;
import model.LockerSession;
import weka.classifiers.Classifier;
import weka.core.DenseInstance;
import weka.core.Instance;
import weka.core.Instances;
import weka.core.SerializationHelper;

/**
 * Scores a session with the Weka model trained by tool.ModelTrainer.
 * risk = 1 - P(NORMAL), a number from 0 to 1. The model is read once and kept.
 * The two files live in src/java/ml, NetBeans copies them to WEB-INF/classes/ml.
 * Without a model the score is 0, so the system works with rules alone until you have trained one.
 */
public class RiskScorer {

    private static final Logger LOG = Logger.getLogger(RiskScorer.class.getName());
    private static RiskScorer instance;

    private final Classifier model;     // null = no model found
    private final Instances header;     // attribute names and the class labels, no rows
    private final int normalIndex;      // position of NORMAL among the class labels

    private RiskScorer(Classifier model, Instances header) {
        this.model = model;
        this.header = header;
        this.normalIndex = header == null ? -1 : header.classAttribute().indexOfValue("NORMAL");
    }

    public static synchronized RiskScorer getInstance() {
        // load once, keep it; a missing or broken file gives a scorer that always answers 0
        if (instance == null) {
            instance = load();
        }
        return instance;
    }

    /** For tests: a scorer built from streams you control. */
    public static RiskScorer fromStreams(InputStream modelStream, InputStream headerStream) throws Exception {
        Classifier model = (Classifier) SerializationHelper.read(modelStream);
        Instances header = new Instances(new BufferedReader(new InputStreamReader(headerStream, StandardCharsets.UTF_8)));
        header.setClassIndex(header.numAttributes() - 1);
        return new RiskScorer(model, header);
    }

    /** 0 = looks normal, 1 = looks abnormal. Never throws. */
    public double score(LockerSession s) {
        // fill one instance by attribute name, distributionForInstance, 1 - P(NORMAL)
        if (model == null || normalIndex < 0) {
            return 0.0;
        }
        try {
            double[] values = new double[header.numAttributes()];
            for (int i = 0; i < header.numAttributes(); i++) {
                if (i != header.classIndex()) {
                    values[i] = featureValue(header.attribute(i).name(), s);
                }
            }
            Instance row = new DenseInstance(1.0, values);
            row.setDataset(header);
            double[] distribution = model.distributionForInstance(row);
            return Math.min(1.0, Math.max(0.0, 1.0 - distribution[normalIndex]));
        } catch (Exception e) {
            LOG.warning("Scoring failed, answering 0: " + e.getMessage());
            return 0.0;
        }
    }

    private static RiskScorer load() {
        try (InputStream modelStream = RiskScorer.class.getResourceAsStream("/ml/locker_model.bin");
             InputStream headerStream = RiskScorer.class.getResourceAsStream("/ml/locker_header.arff")) {
            if (modelStream == null || headerStream == null) {
                LOG.warning("No model in /ml (locker_model.bin, locker_header.arff): scores will be 0. Run tool.ModelTrainer.");
                return new RiskScorer(null, null);
            }
            return fromStreams(modelStream, headerStream);
        } catch (Exception e) {
            LOG.warning("Could not load the model: " + e.getMessage());
            return new RiskScorer(null, null);
        }
    }

    private static double featureValue(String name, LockerSession s) {
        switch (name) {
            case "door_open_sec":  return s.getDoorOpenSec();
            case "weight_delta_g": return s.getWeightDeltaG();
            case "unlock_count":   return s.getUnlockCount();
            case "rfid_ok":        return s.isRfidOk() ? 1 : 0;
            case "stay_min":       return s.getStayMin();
            default: throw new IllegalArgumentException("Unknown feature " + name);
        }
    }
}
