package service;

import util.Todo;
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
        throw Todo.of("RiskScorer.getInstance: load once, keep it; a missing or broken file gives a scorer that always answers 0");
    }

    /** For tests: a scorer built from streams you control. */
    public static RiskScorer fromStreams(InputStream modelStream, InputStream headerStream) throws Exception {
        throw Todo.of("RiskScorer.fromStreams: SerializationHelper.read for the model, new Instances(reader) for the ARFF header");
    }

    /** 0 = looks normal, 1 = looks abnormal. Never throws. */
    public double score(LockerSession s) {
        throw Todo.of("RiskScorer.score: fill one instance by attribute name, distributionForInstance, 1 - P(NORMAL)");
    }

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: the feature names must match the columns ModelTrainer used
}
