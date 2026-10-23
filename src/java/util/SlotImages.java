package util;

import javax.servlet.ServletContext;

/**
 * v3: the picture of a slot size, web/img/lockers/size-s|m|l.webp (or .png), added by the owner later.
 * The API names a picture only when the file exists, so the page shows its inline SVG instead of a broken image.
 */
public final class SlotImages {

    private static final String[] EXTENSIONS = {".webp", ".png"};

    private SlotImages() {
    }

    /** "img/lockers/size-m.webp" (relative to the context), or null when there is no picture for the size. */
    public static String find(ServletContext ctx, String sizeCode) {
        if (sizeCode == null || !sizeCode.matches("[SML]")) {
            return null;
        }
        for (String ext : EXTENSIONS) {
            String path = "img/lockers/size-" + sizeCode.toLowerCase() + ext;
            try {
                if (ctx.getResource("/" + path) != null) {
                    return path;
                }
            } catch (java.net.MalformedURLException e) {
                return null;
            }
        }
        return null;
    }
}
