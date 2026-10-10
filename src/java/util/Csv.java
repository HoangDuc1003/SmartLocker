package util;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.List;
import javax.servlet.http.HttpServletResponse;

/** Writes a list of rows as a CSV download. Excel opens it correctly because of the BOM. */
public class Csv {

    /** Quotes a value when it holds a comma, a quote or a line break. */
    public static String cell(Object value) {
        throw Todo.of("Csv.cell");
    }

    public static void send(HttpServletResponse res, String filename, String[] header, List<String[]> rows) throws IOException {
        throw Todo.of("Csv.send");
    }

    // TODO helpers (fields, constants, private methods) used by the demos in the guide
}
