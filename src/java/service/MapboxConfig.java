package service;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.servlet.ServletContext;

/**
 * The Mapbox settings of the users' map. Looked up like the mail settings: MAPBOX_TOKEN in the environment (hosted server),
 * -Dsmartlocker.mapboxConfig=FILE, config/mapbox.local.properties of the project (git ignores it, see the .example file),
 * then CATALINA_BASE/conf/smartlocker-mapbox.properties. Without a public token (pk.*) the map stays on Leaflet.
 */
public final class MapboxConfig {

    private static final Logger LOG = Logger.getLogger(MapboxConfig.class.getName());
    private static final String ATTRIBUTE = "smartlocker.mapbox";
    private static final String LIGHT = "mapbox://styles/mapbox/streets-v12";
    private static final String DARK = "mapbox://styles/mapbox/dark-v11";

    private final String token;
    private final String styleLight;
    private final String styleDark;

    private MapboxConfig(String token, String styleLight, String styleDark) {
        this.token = token;
        this.styleLight = styleLight;
        this.styleDark = styleDark;
    }

    /** Empty when Mapbox is off. */
    public String getToken() {
        return token;
    }

    public String getStyleLight() {
        return styleLight;
    }

    public String getStyleDark() {
        return styleDark;
    }

    /** Read once, then kept in the servlet context. */
    public static MapboxConfig of(ServletContext ctx) {
        Object o = ctx.getAttribute(ATTRIBUTE);
        if (o instanceof MapboxConfig) {
            return (MapboxConfig) o;
        }
        MapboxConfig c = read(ctx);
        ctx.setAttribute(ATTRIBUTE, c);
        return c;
    }

    private static MapboxConfig read(ServletContext ctx) {
        Properties p = new Properties();
        for (File f : candidates(ctx)) {
            if (f != null && f.isFile()) {
                try (InputStream in = new FileInputStream(f)) {
                    p.load(in);
                    break;
                } catch (IOException e) {
                    LOG.log(Level.WARNING, "Cannot read Mapbox settings " + f + ": " + e.getMessage());
                }
            }
        }
        String env = System.getenv("MAPBOX_TOKEN");
        String token = env != null && !env.trim().isEmpty() ? env.trim() : p.getProperty("mapbox.token", "").trim();
        if (!token.startsWith("pk.")) {
            if (!token.isEmpty()) {
                // this value goes into the page, so a secret token (sk.*) must never be used; it is not logged either
                LOG.warning("mapbox.token is not a public token (pk.*): the map stays on Leaflet");
            }
            token = "";
        }
        return new MapboxConfig(token, p.getProperty("mapbox.style.light", LIGHT).trim(), p.getProperty("mapbox.style.dark", DARK).trim());
    }

    private static File[] candidates(ServletContext ctx) {
        String explicit = System.getProperty("smartlocker.mapboxConfig");
        String root = ctx == null ? null : ctx.getRealPath("/");
        File project = root == null ? null : new File(root).getAbsoluteFile().getParentFile();
        project = project == null ? null : project.getParentFile();
        String catalina = System.getProperty("catalina.base");
        return new File[] {
            explicit == null ? null : new File(explicit),
            project == null ? null : new File(project, "config/mapbox.local.properties"),
            catalina == null ? null : new File(catalina, "conf/smartlocker-mapbox.properties")
        };
    }
}
