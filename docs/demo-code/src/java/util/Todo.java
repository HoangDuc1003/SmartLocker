package util;

/**
 * Placeholder used by the skeleton: a method you still have to write throws this.
 * The text appears in the Tomcat log, so you always know what is missing.
 */
public final class Todo {

    private Todo() {
    }

    public static UnsupportedOperationException of(String what) {
        return new UnsupportedOperationException("TODO " + what);
    }
}
