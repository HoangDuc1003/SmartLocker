// ExtendedEvidence - extended evaluation for the paper (repeated CV, significance, unsupervised baselines, ablation).
//
// The 480 sessions are regenerated from the formulas of sql/02_data_v1.sql (section 9, PublicSession), row n = 1..480,
// so no database is read. Part 1 checks that the regenerated data gives the published 10-fold results (MlEvidence).
// The rules are the real service.RuleEngine of the application, compiled from src/java.
//
// compile: "C:/Program Files/Java/jdk1.8.0_202/bin/javac" -nowarn -encoding UTF-8 -cp "web/WEB-INF/lib/weka.jar"
//            -d docs/paper/evidence/harness/classes-ext src/java/model/LockerSession.java src/java/service/Verdict.java
//            src/java/service/SessionContext.java src/java/service/RuleEngine.java docs/paper/evidence/harness/ExtendedEvidence.java
// run:     "C:/Program Files/Java/jdk1.8.0_202/bin/java" -cp "docs/paper/evidence/harness/classes-ext;web/WEB-INF/lib/weka.jar" ExtendedEvidence

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

import model.LockerSession;
import service.RuleEngine;
import service.SessionContext;
import service.Verdict;
import weka.classifiers.AbstractClassifier;
import weka.classifiers.Classifier;
import weka.classifiers.Evaluation;
import weka.classifiers.bayes.NaiveBayes;
import weka.classifiers.lazy.IBk;
import weka.classifiers.trees.J48;
import weka.classifiers.trees.RandomForest;
import weka.core.Attribute;
import weka.core.DenseInstance;
import weka.core.Instance;
import weka.core.Instances;

public class ExtendedEvidence {

    static final String[] FEATURES = {"door_open_sec", "weight_delta_g", "unlock_count", "rfid_ok", "stay_min"};
    static final String[] LABEL_BY_MOD = {"NORMAL", "FORCED_OPEN", "WRONG_USER", "OVERDUE", "ITEM_LEFT", "SUSPECTED_SPOOF"};
    static final int N = 480, SEEDS = 10, FOLDS = 10;
    static final double ALLOWED_MIN = 130;   // 2-hour plan + 10 min grace (StoragePlan.grace_min default)
    static final double TAU = 0.80;          // AlertService ML_ANOMALY threshold

    static double[][] X = new double[N][];
    static String[] Y = new String[N];

    public static void main(String[] args) throws Exception {
        System.out.println("# extended.log - " + java.time.Instant.now() + " UTC");
        System.out.println("java=" + System.getProperty("java.version") + " weka=" + weka.core.Version.VERSION);
        generate();
        part1Reproduce();
        part2RepeatedCv();
        part3Detection();
        part4Ablation();
        part5RuleTiming();
    }

    // ---------------------------------------------------------------- data

    /** Row n of sql/02_data_v1.sql section 9 (same CASE expressions). */
    static void generate() {
        for (int n = 1; n <= N; n++) {
            int c = n % 6;
            double door = c == 1 ? 25.0 + (n % 9) : c == 5 ? 0.0 : 3.0 + (n % 7);
            double weight = c == 4 ? 150.0 + (n % 300) : c == 5 ? 100.0 + (n % 200) : -10.0 - (n % 80);
            double unlocks = c == 1 ? 4 : 1;
            double rfid = c == 1 ? 0 : 1;
            double stay = c == 3 ? 180.0 + (n % 90) : 10.0 + (n % 90);
            X[n - 1] = new double[]{door, weight, unlocks, rfid, stay};
            Y[n - 1] = LABEL_BY_MOD[c];
        }
    }

    /** Same header as tool.ModelTrainer.build: numeric features, nominal class in the given order. */
    static Instances build(int[] idx, String[] labels, List<String> order) {
        ArrayList<Attribute> atts = new ArrayList<Attribute>();
        for (String f : FEATURES) atts.add(new Attribute(f));
        atts.add(new Attribute("label", order));
        Instances d = new Instances("locker", atts, idx.length);
        d.setClassIndex(FEATURES.length);
        for (int i : idx) {
            double[] v = Arrays.copyOf(X[i], FEATURES.length + 1);
            v[FEATURES.length] = order.indexOf(labels[i]);
            d.add(new DenseInstance(1.0, v));
        }
        return d;
    }

    static List<String> appearanceOrder(String[] labels) {
        List<String> order = new ArrayList<String>();
        for (String l : labels) if (!order.contains(l)) order.add(l);
        return order;
    }

    static int[] all() {
        int[] a = new int[N];
        for (int i = 0; i < N; i++) a[i] = i;
        return a;
    }

    static Map<String, Classifier> models() {
        Map<String, Classifier> m = new LinkedHashMap<String, Classifier>();
        m.put("RandomForest", new RandomForest());
        m.put("J48", new J48());
        m.put("NaiveBayes", new NaiveBayes());
        m.put("IBk(k=5)", new IBk(5));
        return m;
    }

    // ---------------------------------------------------------------- part 1

    static void part1Reproduce() throws Exception {
        System.out.println("\n== part 1: regenerated data, 10-fold CV with new Random(42) (must equal ml.log) ==");
        Instances data = build(all(), Y, appearanceOrder(Y));
        int[] counts = new int[6];
        for (String y : Y) counts[Arrays.asList(LABEL_BY_MOD).indexOf(y)]++;
        System.out.println("rows=" + N + " per class (NORMAL..SUSPECTED_SPOOF)=" + Arrays.toString(counts));
        System.out.printf("%-14s %9s %9s%n", "model", "accuracy", "wF1");
        for (Map.Entry<String, Classifier> e : models().entrySet()) {
            Evaluation ev = new Evaluation(data);
            ev.crossValidateModel(e.getValue(), data, 10, new Random(42));
            System.out.printf("%-14s %9.4f %9.4f%n", e.getKey(), ev.pctCorrect() / 100, ev.weightedFMeasure());
        }
    }

    // ---------------------------------------------------------------- part 2

    static void part2RepeatedCv() throws Exception {
        System.out.println("\n== part 2: 10 x 10-fold stratified CV (seeds 1..10), six classes, per-fold weighted F1 ==");
        Instances data = build(all(), Y, appearanceOrder(Y));
        Map<String, double[]> f1 = new LinkedHashMap<String, double[]>();
        Map<String, double[]> acc = new LinkedHashMap<String, double[]>();
        for (Map.Entry<String, Classifier> e : models().entrySet()) {
            double[] fs = new double[SEEDS * FOLDS], as = new double[SEEDS * FOLDS];
            int k = 0;
            for (int seed = 1; seed <= SEEDS; seed++) {
                Random r = new Random(seed);
                Instances d = new Instances(data);
                d.randomize(r);
                d.stratify(FOLDS);
                for (int f = 0; f < FOLDS; f++) {
                    Instances train = d.trainCV(FOLDS, f, r);
                    Instances test = d.testCV(FOLDS, f);
                    Classifier c = AbstractClassifier.makeCopy(e.getValue());
                    c.buildClassifier(train);
                    Evaluation ev = new Evaluation(train);
                    ev.evaluateModel(c, test);
                    fs[k] = weightedF1(ev.confusionMatrix());   // Weka gives NaN when a class is never predicted
                    as[k] = ev.pctCorrect() / 100;
                    k++;
                }
            }
            f1.put(e.getKey(), fs);
            acc.put(e.getKey(), as);
            System.out.printf("%-14s accuracy %.4f +- %.4f   wF1 %.4f +- %.4f%n", e.getKey(),
                    mean(as), sd(as), mean(fs), sd(fs));
        }
        System.out.println("-- corrected resampled t-test (Nadeau & Bengio), wF1, k=100, n_test/n_train=1/9, df=99 --");
        double[] ibk = f1.get("IBk(k=5)");
        for (String other : new String[]{"RandomForest", "J48", "NaiveBayes"}) {
            double[] d = new double[ibk.length];
            for (int i = 0; i < d.length; i++) d[i] = ibk[i] - f1.get(other)[i];
            double m = mean(d), v = sd(d) * sd(d);
            double t = v == 0 ? Double.POSITIVE_INFINITY : m / Math.sqrt((1.0 / d.length + 1.0 / 9.0) * v);
            double p = v == 0 ? 0 : betai(0.5 * 99, 0.5, 99 / (99 + t * t));
            System.out.printf("IBk - %-12s mean diff %+.4f  t=%.3f  p=%.2e%n", other, m, t, p);
        }
    }

    // ---------------------------------------------------------------- part 3

    /** Stratified fold assignment on the six labels, shuffled with the seed. fold[i] in 0..FOLDS-1. */
    static int[] folds(int seed) {
        Random r = new Random(seed);
        int[] fold = new int[N];
        for (String lab : LABEL_BY_MOD) {
            List<Integer> idx = new ArrayList<Integer>();
            for (int i = 0; i < N; i++) if (Y[i].equals(lab)) idx.add(i);
            Collections.shuffle(idx, r);
            for (int j = 0; j < idx.size(); j++) fold[idx.get(j)] = j % FOLDS;
        }
        return fold;
    }

    interface Detector {
        /** Scores the test rows (higher = more abnormal) and returns {scores..., threshold} after fitting on train rows. */
        double[] fitScore(int[] train, int[] test, int seed) throws Exception;
    }

    static void part3Detection() throws Exception {
        System.out.println("\n== part 3: abnormal-session detection, positive = any label other than NORMAL ==");
        System.out.println("protocol: 10 x 10-fold stratified CV (seeds 1..10). Unsupervised detectors are fitted on the NORMAL");
        System.out.println("rows of the training folds only (z-scored with their mean/sd) and alarm above the 95th percentile of");
        System.out.println("their training-normal scores. Rules use the real RuleEngine; two-tier = rules + IBk risk >= 0.80.");
        Map<String, Detector> det = new LinkedHashMap<String, Detector>();
        det.put("kNN distance (k=5)", (tr, te, s) -> knnDetector(tr, te, 5));
        det.put("LOF (MinPts=10)", (tr, te, s) -> lofDetector(tr, te, 10));
        det.put("Isolation Forest (t=100)", (tr, te, s) -> iforestDetector(tr, te, 100, 64, s));
        det.put("IBk binary, supervised", ExtendedEvidence::ibkBinary);
        det.put("Rules, telemetry only", (tr, te, s) -> rulesDetector(te, false, null, tr));
        det.put("Rules + identity context", (tr, te, s) -> rulesDetector(te, true, null, tr));
        det.put("Two-tier (rules + IBk)", (tr, te, s) -> rulesDetector(te, true, new IBk(5), tr));
        det.put("Two-tier, no identity", (tr, te, s) -> rulesDetector(te, false, new IBk(5), tr));

        System.out.printf("%-26s %15s %15s %15s %15s %15s %8s%n", "method", "precision", "recall", "F1", "false alarm",
                "AUC", "WU rec");
        for (Map.Entry<String, Detector> e : det.entrySet()) {
            List<Double> P = new ArrayList<Double>(), R = new ArrayList<Double>(), F = new ArrayList<Double>(),
                    FA = new ArrayList<Double>(), AUC = new ArrayList<Double>();
            int wuHit = 0, wuAll = 0;
            int[] perClassHit = new int[6], perClassAll = new int[6];
            for (int seed = 1; seed <= SEEDS; seed++) {
                int[] fold = folds(seed);
                for (int f = 0; f < FOLDS; f++) {
                    int[] train = select(fold, f, false), test = select(fold, f, true);
                    double[] out = e.getValue().fitScore(train, test, seed * 100 + f);
                    double thr = out[test.length];
                    int tp = 0, fp = 0, fn = 0, tn = 0;
                    double[] sc = Arrays.copyOf(out, test.length);
                    boolean[] pos = new boolean[test.length];
                    for (int i = 0; i < test.length; i++) {
                        pos[i] = !Y[test[i]].equals("NORMAL");
                        boolean alarm = sc[i] >= thr;
                        if (pos[i] && alarm) tp++;
                        else if (pos[i]) fn++;
                        else if (alarm) fp++;
                        else tn++;
                        int c = Arrays.asList(LABEL_BY_MOD).indexOf(Y[test[i]]);
                        perClassAll[c]++;
                        if (alarm) perClassHit[c]++;
                        if (Y[test[i]].equals("WRONG_USER")) { wuAll++; if (alarm) wuHit++; }
                    }
                    double p = tp + fp == 0 ? 0 : tp / (double) (tp + fp), r = tp / (double) (tp + fn);
                    P.add(p); R.add(r); F.add(p + r == 0 ? 0 : 2 * p * r / (p + r)); FA.add(fp / (double) (fp + tn));
                    AUC.add(auc(sc, pos));
                }
            }
            System.out.printf("%-26s %15s %15s %15s %15s %15s %8.3f%n", e.getKey(), ms(P), ms(R), ms(F), ms(FA), ms(AUC),
                    wuHit / (double) wuAll);
            StringBuilder sb = new StringBuilder("    alarm rate per class:");
            for (int c = 0; c < 6; c++) sb.append(String.format(" %s=%.3f", LABEL_BY_MOD[c], perClassHit[c] / (double) perClassAll[c]));
            System.out.println(sb);
        }
    }

    static int[] select(int[] fold, int f, boolean test) {
        List<Integer> l = new ArrayList<Integer>();
        for (int i = 0; i < N; i++) if ((fold[i] == f) == test) l.add(i);
        int[] a = new int[l.size()];
        for (int i = 0; i < a.length; i++) a[i] = l.get(i);
        return a;
    }

    static int[] normalsOf(int[] rows) {
        List<Integer> l = new ArrayList<Integer>();
        for (int i : rows) if (Y[i].equals("NORMAL")) l.add(i);
        int[] a = new int[l.size()];
        for (int i = 0; i < a.length; i++) a[i] = l.get(i);
        return a;
    }

    /** z-scores of all rows with the mean and sd of the reference rows (sd 0 -> 1). */
    static double[][] zscore(int[] ref) {
        int d = FEATURES.length;
        double[] mu = new double[d], sdv = new double[d];
        for (int j = 0; j < d; j++) {
            double[] col = new double[ref.length];
            for (int i = 0; i < ref.length; i++) col[i] = X[ref[i]][j];
            mu[j] = mean(col);
            double s = sd(col);
            sdv[j] = s == 0 ? 1 : s;
        }
        double[][] z = new double[N][d];
        for (int i = 0; i < N; i++) for (int j = 0; j < d; j++) z[i][j] = (X[i][j] - mu[j]) / sdv[j];
        return z;
    }

    static double dist(double[] a, double[] b) {
        double s = 0;
        for (int j = 0; j < a.length; j++) s += (a[j] - b[j]) * (a[j] - b[j]);
        return Math.sqrt(s);
    }

    /** Distances from row p to the reference rows, sorted, excluding p itself. */
    static double[] sortedDist(double[][] z, int p, int[] ref) {
        double[] d = new double[ref.length];
        int m = 0;
        for (int r : ref) if (r != p) d[m++] = dist(z[p], z[r]);
        d = Arrays.copyOf(d, m);
        Arrays.sort(d);
        return d;
    }

    static double percentile95(double[] v) {
        double[] s = v.clone();
        Arrays.sort(s);
        return s[(int) Math.ceil(0.95 * s.length) - 1];
    }

    static double[] withThreshold(double[] scores, double thr) {
        double[] out = Arrays.copyOf(scores, scores.length + 1);
        out[scores.length] = thr;
        return out;
    }

    static double[] knnDetector(int[] train, int[] test, int k) {
        int[] ref = normalsOf(train);
        double[][] z = zscore(ref);
        double[] trainScores = new double[ref.length];
        for (int i = 0; i < ref.length; i++) trainScores[i] = meanFirst(sortedDist(z, ref[i], ref), k);
        double[] s = new double[test.length];
        for (int i = 0; i < test.length; i++) s[i] = meanFirst(sortedDist(z, test[i], ref), k);
        return withThreshold(s, percentile95(trainScores));
    }

    static double meanFirst(double[] d, int k) {
        double s = 0;
        for (int i = 0; i < k; i++) s += d[i];
        return s / k;
    }

    /** Local outlier factor (Breunig et al. 2000), reference set = training NORMAL rows. */
    static double[] lofDetector(int[] train, int[] test, int k) {
        int[] ref = normalsOf(train);
        double[][] z = zscore(ref);
        Map<Integer, Double> kdist = new LinkedHashMap<Integer, Double>();
        for (int r : ref) kdist.put(r, sortedDist(z, r, ref)[k - 1]);
        Map<Integer, Double> lrdRef = new LinkedHashMap<Integer, Double>();
        for (int r : ref) lrdRef.put(r, lrd(z, r, ref, kdist, k));
        double[] trainScores = new double[ref.length];
        for (int i = 0; i < ref.length; i++) trainScores[i] = lof(z, ref[i], ref, kdist, lrdRef, k);
        double[] s = new double[test.length];
        for (int i = 0; i < test.length; i++) s[i] = lof(z, test[i], ref, kdist, lrdRef, k);
        return withThreshold(s, percentile95(trainScores));
    }

    static int[] kNearest(double[][] z, int p, int[] ref, int k) {
        Integer[] o = new Integer[ref.length];
        int m = 0;
        for (int r : ref) if (r != p) o[m++] = r;
        Integer[] c = Arrays.copyOf(o, m);
        Arrays.sort(c, (a, b) -> Double.compare(dist(z[p], z[a]), dist(z[p], z[b])));
        int[] nn = new int[k];
        for (int i = 0; i < k; i++) nn[i] = c[i];
        return nn;
    }

    static double lrd(double[][] z, int p, int[] ref, Map<Integer, Double> kdist, int k) {
        double s = 0;
        for (int o : kNearest(z, p, ref, k)) s += Math.max(kdist.get(o), dist(z[p], z[o]));
        return 1.0 / (s / k + 1e-12);
    }

    static double lof(double[][] z, int p, int[] ref, Map<Integer, Double> kdist, Map<Integer, Double> lrdRef, int k) {
        double lp = lrd(z, p, ref, kdist, k), s = 0;
        for (int o : kNearest(z, p, ref, k)) s += lrdRef.get(o) / lp;
        return s / k;
    }

    /** Isolation Forest (Liu et al. 2008): t trees on subsamples of psi training NORMAL rows. */
    static double[] iforestDetector(int[] train, int[] test, int t, int psi, int seed) {
        int[] ref = normalsOf(train);
        Random r = new Random(seed);
        int sub = Math.min(psi, ref.length);
        int limit = (int) Math.ceil(Math.log(sub) / Math.log(2));
        List<Node> forest = new ArrayList<Node>();
        for (int i = 0; i < t; i++) {
            List<Integer> pool = new ArrayList<Integer>();
            for (int x : ref) pool.add(x);
            Collections.shuffle(pool, r);
            forest.add(grow(pool.subList(0, sub), 0, limit, r));
        }
        double cn = c(sub);
        double[] trainScores = new double[ref.length];
        for (int i = 0; i < ref.length; i++) trainScores[i] = iscore(forest, X[ref[i]], cn);
        double[] s = new double[test.length];
        for (int i = 0; i < test.length; i++) s[i] = iscore(forest, X[test[i]], cn);
        return withThreshold(s, percentile95(trainScores));
    }

    static class Node {
        int att = -1, size;
        double split;
        Node left, right;
    }

    static Node grow(List<Integer> rows, int depth, int limit, Random r) {
        Node n = new Node();
        n.size = rows.size();
        if (depth >= limit || rows.size() <= 1) return n;
        List<Integer> usable = new ArrayList<Integer>();
        for (int j = 0; j < FEATURES.length; j++) {
            double lo = Double.MAX_VALUE, hi = -Double.MAX_VALUE;
            for (int i : rows) { lo = Math.min(lo, X[i][j]); hi = Math.max(hi, X[i][j]); }
            if (hi > lo) usable.add(j);
        }
        if (usable.isEmpty()) return n;
        int j = usable.get(r.nextInt(usable.size()));
        double lo = Double.MAX_VALUE, hi = -Double.MAX_VALUE;
        for (int i : rows) { lo = Math.min(lo, X[i][j]); hi = Math.max(hi, X[i][j]); }
        n.att = j;
        n.split = lo + r.nextDouble() * (hi - lo);
        List<Integer> a = new ArrayList<Integer>(), b = new ArrayList<Integer>();
        for (int i : rows) (X[i][j] < n.split ? a : b).add(i);
        n.left = grow(a, depth + 1, limit, r);
        n.right = grow(b, depth + 1, limit, r);
        return n;
    }

    static double pathLength(Node n, double[] x, int depth) {
        if (n.att < 0) return depth + c(n.size);
        return pathLength(x[n.att] < n.split ? n.left : n.right, x, depth + 1);
    }

    static double c(int n) {
        if (n <= 1) return 0;
        if (n == 2) return 1;
        return 2 * (Math.log(n - 1) + 0.5772156649) - 2.0 * (n - 1) / n;
    }

    static double iscore(List<Node> forest, double[] x, double cn) {
        double h = 0;
        for (Node t : forest) h += pathLength(t, x, 0);
        return Math.pow(2, -(h / forest.size()) / cn);
    }

    /** Supervised IBk on NORMAL vs ABNORMAL: score = P(ABNORMAL), alarm at 0.5 (the predicted class). */
    static double[] ibkBinary(int[] train, int[] test, int seed) throws Exception {
        String[] bin = new String[N];
        for (int i = 0; i < N; i++) bin[i] = Y[i].equals("NORMAL") ? "NORMAL" : "ABNORMAL";
        List<String> order = Arrays.asList("NORMAL", "ABNORMAL");
        Instances tr = build(train, bin, order), te = build(test, bin, order);
        IBk m = new IBk(5);
        m.buildClassifier(tr);
        double[] s = new double[test.length];
        for (int i = 0; i < test.length; i++) s[i] = m.distributionForInstance(te.instance(i))[1];
        return withThreshold(s, 0.5);
    }

    static SessionContext context(int i, boolean identity) {
        SessionContext ctx = new SessionContext();
        ctx.setRange("DOOR", 0, 3600);
        ctx.setRange("WEIGHT", -200, 20000);
        ctx.setRange("STAY", 0, 10080);
        ctx.setCardStatus("ACTIVE");
        ctx.setAllowedMin(ALLOWED_MIN);
        if (identity) {   // the server knows both owners; a wrong-user session is a card of another user
            ctx.setCardOwnerId(1);
            ctx.setDepositOwnerId(Y[i].equals("WRONG_USER") ? 2 : 1);
        }
        return ctx;
    }

    static LockerSession session(int i) {
        LockerSession s = new LockerSession();
        s.setDoorOpenSec(X[i][0]);
        s.setWeightDeltaG(X[i][1]);
        s.setUnlockCount((int) X[i][2]);
        s.setRfidOk(X[i][3] == 1);
        s.setStayMin(X[i][4]);
        s.setOpenSource("LOCAL");
        return s;
    }

    static final RuleEngine ENGINE = new RuleEngine();

    /** 1 when the rules raise an alert; with a model, also 1 when the rules say NORMAL and the risk is >= TAU. */
    static double[] rulesDetector(int[] test, boolean identity, Classifier model, int[] train) throws Exception {
        Instances te = null;
        int normalIdx = -1;
        if (model != null) {
            List<String> order = appearanceOrder(Y);
            Instances tr = build(train, Y, order);
            te = build(test, Y, order);
            model.buildClassifier(tr);
            normalIdx = order.indexOf("NORMAL");
        }
        double[] s = new double[test.length];
        for (int i = 0; i < test.length; i++) {
            Verdict v = ENGINE.evaluate(session(test[i]), context(test[i], identity));
            if (v.isAlert()) s[i] = 1;
            else if (model != null && v.isMlEligible()) {
                double risk = 1 - model.distributionForInstance(te.instance(i))[normalIdx];
                s[i] = risk >= TAU ? 1 : 0;
            }
        }
        return withThreshold(s, 0.5);
    }

    // ---------------------------------------------------------------- part 4

    static void part4Ablation() throws Exception {
        System.out.println("\n== part 4: six-class labels on all 480 sessions ==");
        List<String> order = Arrays.asList(LABEL_BY_MOD);
        for (boolean identity : new boolean[]{false, true}) {
            int[][] cm = new int[6][6];
            for (int i = 0; i < N; i++) {
                String got = ENGINE.evaluate(session(i), context(i, identity)).getLabel();
                cm[order.indexOf(Y[i])][order.indexOf(got)]++;
            }
            report(identity ? "RuleEngine + identity context" : "RuleEngine, telemetry only", cm);
        }
        Instances data = build(all(), Y, appearanceOrder(Y));
        Evaluation ev = new Evaluation(data);
        ev.crossValidateModel(new IBk(5), data, 10, new Random(42));
        double[][] m = ev.confusionMatrix();
        List<String> ap = appearanceOrder(Y);
        int[][] cm = new int[6][6];
        for (int a = 0; a < 6; a++) for (int b = 0; b < 6; b++)
            cm[order.indexOf(ap.get(a))][order.indexOf(ap.get(b))] = (int) m[a][b];
        report("IBk(k=5) only, 10-fold CV seed 42", cm);
    }

    static void report(String name, int[][] cm) {
        int correct = 0;
        double macro = 0;
        StringBuilder per = new StringBuilder();
        for (int c = 0; c < 6; c++) {
            correct += cm[c][c];
            int row = 0, col = 0;
            for (int j = 0; j < 6; j++) { row += cm[c][j]; col += cm[j][c]; }
            double p = col == 0 ? 0 : cm[c][c] / (double) col, r = row == 0 ? 0 : cm[c][c] / (double) row;
            double f = p + r == 0 ? 0 : 2 * p * r / (p + r);
            macro += f / 6;
            per.append(String.format(" %s=%.3f", LABEL_BY_MOD[c], f));
        }
        System.out.printf("%-36s accuracy %.4f  macro-F1 %.4f%n    per-class F1:%s%n", name, correct / (double) N, macro, per);
        System.out.println("    confusion (rows = actual " + Arrays.toString(LABEL_BY_MOD) + "):");
        for (int[] r : cm) System.out.println("    " + Arrays.toString(r));
    }

    // ---------------------------------------------------------------- part 5

    static void part5RuleTiming() {
        System.out.println("\n== part 5: RuleEngine.evaluate time per session (context prebuilt) ==");
        LockerSession[] ss = new LockerSession[N];
        SessionContext[] cs = new SessionContext[N];
        for (int i = 0; i < N; i++) { ss[i] = session(i); cs[i] = context(i, true); }
        int sink = 0;
        for (int w = 0; w < 2000; w++) for (int i = 0; i < N; i++) sink += ENGINE.evaluate(ss[i], cs[i]).getLabel().length();
        double[] runs = new double[11];
        for (int k = 0; k < runs.length; k++) {
            long t0 = System.nanoTime();
            for (int rep = 0; rep < 200; rep++) for (int i = 0; i < N; i++) sink += ENGINE.evaluate(ss[i], cs[i]).getLabel().length();
            runs[k] = (System.nanoTime() - t0) / (200.0 * N);
        }
        Arrays.sort(runs);
        System.out.printf("median of 11 runs: %.1f ns per session (min %.1f, max %.1f) [sink %d]%n", runs[5], runs[0], runs[10], sink % 7);
    }

    // ---------------------------------------------------------------- statistics

    /** Support-weighted F1 from a confusion matrix; a class never predicted has precision 0 (so F1 0), never NaN. */
    static double weightedF1(double[][] cm) {
        double total = 0, sum = 0;
        for (int c = 0; c < cm.length; c++) {
            double row = 0, col = 0;
            for (int j = 0; j < cm.length; j++) { row += cm[c][j]; col += cm[j][c]; }
            double p = col == 0 ? 0 : cm[c][c] / col, r = row == 0 ? 0 : cm[c][c] / row;
            sum += row * (p + r == 0 ? 0 : 2 * p * r / (p + r));
            total += row;
        }
        return sum / total;
    }

    static double mean(double[] v) {
        double s = 0;
        for (double x : v) s += x;
        return s / v.length;
    }

    static double sd(double[] v) {
        double m = mean(v), s = 0;
        for (double x : v) s += (x - m) * (x - m);
        return Math.sqrt(s / (v.length - 1));
    }

    static String ms(List<Double> l) {
        double[] v = new double[l.size()];
        for (int i = 0; i < v.length; i++) v[i] = l.get(i);
        return String.format("%.3f+-%.3f", mean(v), sd(v));
    }

    /** Area under the ROC curve (Mann-Whitney), ties count one half; NaN when one class is missing. */
    static double auc(double[] s, boolean[] pos) {
        double num = 0;
        int np = 0, nn = 0;
        for (int i = 0; i < s.length; i++) {
            if (!pos[i]) continue;
            np++;
            for (int j = 0; j < s.length; j++) {
                if (pos[j]) continue;
                num += s[i] > s[j] ? 1 : s[i] == s[j] ? 0.5 : 0;
            }
        }
        for (boolean b : pos) if (!b) nn++;
        return np == 0 || nn == 0 ? Double.NaN : num / (np * (double) nn);
    }

    /** Regularised incomplete beta I_x(a, b) (Numerical Recipes betai); two-sided t p-value = I_{df/(df+t^2)}(df/2, 1/2). */
    static double betai(double a, double b, double x) {
        if (x <= 0) return 0;
        if (x >= 1) return 1;
        double bt = Math.exp(lgamma(a + b) - lgamma(a) - lgamma(b) + a * Math.log(x) + b * Math.log(1 - x));
        return x < (a + 1) / (a + b + 2) ? bt * betacf(a, b, x) / a : 1 - bt * betacf(b, a, 1 - x) / b;
    }

    static double betacf(double a, double b, double x) {
        double qab = a + b, qap = a + 1, qam = a - 1, c = 1, d = 1 - qab * x / qap;
        if (Math.abs(d) < 1e-300) d = 1e-300;
        d = 1 / d;
        double h = d;
        for (int m = 1; m <= 300; m++) {
            int m2 = 2 * m;
            double aa = m * (b - m) * x / ((qam + m2) * (a + m2));
            d = 1 + aa * d; if (Math.abs(d) < 1e-300) d = 1e-300;
            c = 1 + aa / c; if (Math.abs(c) < 1e-300) c = 1e-300;
            d = 1 / d; h *= d * c;
            aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
            d = 1 + aa * d; if (Math.abs(d) < 1e-300) d = 1e-300;
            c = 1 + aa / c; if (Math.abs(c) < 1e-300) c = 1e-300;
            d = 1 / d;
            double del = d * c;
            h *= del;
            if (Math.abs(del - 1) < 3e-14) break;
        }
        return h;
    }

    static double lgamma(double x) {
        double[] cof = {76.18009172947146, -86.50532032941677, 24.01409824083091, -1.231739572450155,
                0.1208650973866179e-2, -0.5395239384953e-5};
        double y = x, tmp = x + 5.5;
        tmp -= (x + 0.5) * Math.log(tmp);
        double ser = 1.000000000190015;
        for (double cf : cof) ser += cf / ++y;
        return -tmp + Math.log(2.5066282746310005 * ser / x);
    }
}
