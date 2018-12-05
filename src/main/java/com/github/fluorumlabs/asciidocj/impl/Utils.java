package com.github.fluorumlabs.asciidocj.impl;

import org.json.JSONArray;
import org.json.JSONObject;
import org.jsoup.nodes.Element;
import org.jsoup.nodes.Node;

import java.io.Reader;
import java.io.StringReader;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Created by Artem Godin on 12/4/2018.
 */
public class Utils {
    private static Map<String, String> replacements = new ConcurrentHashMap<>();

    static {
        replacements.put("cpp", "C++");
    }

    public static String getReplacement(String s) {
        return replacements.get(s);
    }

    public static String urlEscape(String x) {
        try {
            URI uri = new URI(null, null, null, -1, null, x, null);
            return uri.toString();
        } catch (URISyntaxException e) {
            // Whatever
            return x;
        }
    }

    public static String stripTail(String s, int tail) {
        return tail > 0 ? s.substring(0, s.length() - tail) : s;
    }

    public static String stripHead(String s, int head) {
        return head > 0 ? s.substring(head) : s;
    }

    public static String strip(String s, int head, int tail) {
        return s.substring(head, s.length() - tail);
    }

    public static String extractBetween(String s, String left, String right) {
        int iLeft = s.indexOf(left);
        int iRight = s.lastIndexOf(right);
        if (iLeft == -1 || iRight == -1) return "";
        int head = s.indexOf(left) + left.length();
        int tail = s.length() - s.lastIndexOf(right);
        return strip(s, head, tail);
    }

    public static String extractBefore(String s, String right) {
        int iRight = s.lastIndexOf(right);
        int tail = iRight >= 0 ? s.length() - s.lastIndexOf(right) : 0;
        return stripTail(s, tail);
    }

    public static String extractBeforeStrict(String s, String right) {
        int iRight = s.indexOf(right);
        int tail = iRight >= 0 ? s.length() - s.indexOf(right) : 0;
        return stripTail(s, tail);
    }

    public static String extractAfter(String s, String left) {
        int iLeft = s.indexOf(left);
        int head = iLeft >= 0 ? s.indexOf(left) + left.length() : 0;
        return stripHead(s, head);
    }

    public static String extractAfterStrict(String s, String left) {
        int iLeft = s.lastIndexOf(left);
        int head = iLeft >= 0 ? s.lastIndexOf(left) + left.length() : 0;
        return stripHead(s, head);
    }

    public static String trimLeft(String s) {
        return skipLeft(s, " \t");
    }

    public static String trimRight(String s) {
        return skipRight(s, " \t");
    }

    public static String trim(String s) {
        return skipLeft(skipRight(s, " \t"), " \t");
    }

    public static String trim(String s, String w) {
        return skipLeft(skipRight(s, w), w);
    }

    public static String trimAll(String s) {
        return skipLeft(skipRight(s, " \t\n"), " \t\n");
    }

    public static String trimNewLines(String s) {
        return skipRight(s, "\n");
    }

    public static String skipLeft(String s, String c) {
        int x = 0;
        while (x < s.length() && c.indexOf(s.charAt(x)) >= 0) {
            x++;
        }
        return stripHead(s, x);
    }

    public static String unskipLeft(String s, String c) {
        int x = 0;
        while (x < s.length() && c.indexOf(s.charAt(x)) >= 0) {
            x++;
        }
        return s.substring(0, x);
    }

    public static String skipRight(String s, String c) {
        int x = 0;
        while (x < s.length() && c.indexOf(s.charAt(s.length() - x - 1)) >= 0) {
            x++;
        }
        return stripTail(s, x);
    }

    public static Reader getReader(String text, boolean zeroTrail) {
        return new StringReader(zeroTrail ? trimAll(text) + "\0" : text);
    }

    public static void moveChildNodes(Element from, Element to) {
        List<Node> nodes = new ArrayList<>(from.childNodes());
        for (Node node : nodes) {
            to.appendChild(node);
        }
    }

    public static void moveChildNodesToParent(Element from) {
        List<Node> nodes = new ArrayList<>(from.childNodes());
        for (Node node : nodes) {
            from.before(node);
        }
    }

    public static void copyChildNodes(Element from, Element to) {
        for (Node node : from.childNodes()) {
            to.appendChild(node.clone());
        }
    }

    public static void moveChildNodesSkipFirst(Element from, Element to) {
        List<Node> nodes = new ArrayList<>(from.childNodes());
        if (!nodes.isEmpty()) {
            nodes.remove(0);
        }
        for (Node node : nodes) {
            to.appendChild(node);
        }
    }

    public static AsciidocElement getParent(Element x) {
        return (AsciidocElement) x.parents().stream()
                .filter(e -> e != x && e instanceof AsciidocElement)
                .findFirst()
                .orElse(null);
    }

    public static String getArgument(Element x, int i) {
        if (!(x instanceof AsciidocElement)) {
            return "";
        }
        JSONObject properties = ((AsciidocElement) x).getProperties();
        if (!properties.has("arguments")) {
            return "";
        } else {
            JSONArray arguments = properties.getJSONArray("arguments");
            return arguments.optString(i, "");
        }
    }


}
