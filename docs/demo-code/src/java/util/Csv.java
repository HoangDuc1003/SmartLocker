package util;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.List;
import javax.servlet.http.HttpServletResponse;

/** Writes a list of rows as a CSV download. Excel opens it correctly because of the BOM. */
public class Csv {

    /** Quotes a value when it holds a comma, a quote or a line break. */
    public static String cell(Object value) {
        if (value == null) {
            return "";
        }
        String s = String.valueOf(value);
        if (s.indexOf(',') < 0 && s.indexOf('"') < 0 && s.indexOf('\n') < 0 && s.indexOf('\r') < 0) {
            return s;
        }
        return "\"" + s.replace("\"", "\"\"") + "\"";
    }

    public static void send(HttpServletResponse res, String filename, String[] header, List<String[]> rows) throws IOException {
        res.setContentType("text/csv;charset=UTF-8");
        res.setHeader("Content-Disposition", "attachment; filename=\"" + filename + "\"");
        PrintWriter out = res.getWriter();
        out.write('﻿');                                  // byte order mark
        out.print(join(header));
        out.print("\r\n");
        for (String[] row : rows) {
            out.print(join(row));
            out.print("\r\n");
        }
        out.flush();
    }

    private static String join(String[] values) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < values.length; i++) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append(cell(values[i]));
        }
        return sb.toString();
    }
}
