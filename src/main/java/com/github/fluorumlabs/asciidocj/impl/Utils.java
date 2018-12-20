package com.github.fluorumlabs.asciidocj.impl;

import org.json.JSONArray;
import org.json.JSONObject;
import org.jsoup.nodes.Attribute;
import org.jsoup.nodes.Document;
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
import java.util.function.Function;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

/**
 * Created by Artem Godin on 12/4/2018.
 */
public class Utils {
    private static Map<String, String> replacements = new ConcurrentHashMap<>();

    static {
        replacements.put("blank", "");
        replacements.put("empty", "");
        replacements.put("sp", " ");
        replacements.put("nbsp", "\u00a0");
        replacements.put("zwsp", "\u200b");
        replacements.put("wj", "\u2060");
        replacements.put("apos", "'");
        replacements.put("quot", "\"");
        replacements.put("lsquo", "\u2018");
        replacements.put("rsquo", "\u2019");
        replacements.put("ldquo", "\u201c");
        replacements.put("rdquo", "\u201d");
        replacements.put("deg", "\u00b0");
        replacements.put("plus", "+");
        replacements.put("brvbar", "\u00a6");
        replacements.put("vbar", "|");
        replacements.put("amp", "&");
        replacements.put("lt", "<");
        replacements.put("gt", ">");
        replacements.put("startsb", "[");
        replacements.put("endsb", "]");
        replacements.put("caret", "^");
        replacements.put("asterisk", "*");
        replacements.put("tilde", "~");
        replacements.put("backslash", "\\");
        replacements.put("backtick", "`");
        replacements.put("two-colons", "::");
        replacements.put("two-semicolons", ";;");
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
        String temp = s.replace("\\" + left, "\1").replace("\\" + right, "\2");
        int iLeft = temp.indexOf(left);
        int iRight = temp.lastIndexOf(right);
        if (iLeft == -1 || iRight == -1) return "";
        int head = temp.indexOf(left) + left.length();
        int tail = temp.length() - temp.lastIndexOf(right);
        return strip(temp, head, tail).replace("\1", "\\" + left).replace("\2", "\\" + right);
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
        return skipLeft(skipRight(s, " \t\n\0"), " \t\n\0");
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
        return new StringReader(zeroTrail ? text + "\0" : text);
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

    public static void copyAttributes(Element from, Element to) {
        for (Attribute attr : from.attributes()) {
            to.attr(attr.getKey(), attr.getValue());
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

    protected static boolean hasOption(Element x, String key) {
        if (!(x instanceof AsciidocElement)) {
            return false;
        }
        JSONObject properties = ((AsciidocElement) x).getProperties();
        if (!properties.has("options")) {
            return false;
        } else {
            return properties.getJSONObject("options").has(key);
        }
    }

    public static Element getTitle(Element x) {
        for (Element child : x.children()) {
            if (child.tagName().equals(AsciidocRenderer.TITLE.tag())) return child;
        }
        return null;
    }

    public static String replaceFunctional(Pattern pattern, String input, Function<String[], String> replacement) {
        Matcher matcher = pattern.matcher(input);
        StringBuffer sb = new StringBuffer();

        while (matcher.find()) {
            int groupCount = matcher.groupCount() + 1;
            String[] groups = new String[groupCount];

            for (int i = 0; i < groupCount; ++i) {
                groups[i] = matcher.group(i);
            }

            String result = (String) replacement.apply(groups);
            if (result != null) {
                matcher.appendReplacement(sb, Matcher.quoteReplacement(result));
            }
        }

        return matcher.appendTail(sb).toString();
    }

    public static String escapeIntermediate(Document document) {
        for (Element element : document.body().getAllElements()) {
            if (element instanceof AsciidocElement) {
                AsciidocElement asciidocElement = (AsciidocElement) element;
                element.attr("properties", asciidocElement.getProperties().toString());
                element.attr("tagName", asciidocElement.tagName().replace("__", ""));
            }
        }

        document.outputSettings().prettyPrint(false);

        return document.body().html();
    }

    public static Document unescapeIntermediate(String html, JSONObject attributes) {
        Document result = Document.createShell("");
        result.body().append(html);

        // Inception
        for (Element element : result.body().select("[tagName]")) {
            String tagName = element.attr("tagName");
            JSONObject newProperties = new JSONObject(element.attr("properties"));
            AsciidocElement newElement = new AsciidocElement(AsciidocRenderer.valueOf(tagName), newProperties, attributes);
            element.removeAttr("properties");
            element.removeAttr("tagName");
            copyChildNodes(element, newElement);
            copyAttributes(element, newElement);

            element.replaceWith(newElement);
        }

        return result;
    }

    public static Element html(Element parent, String html, JSONObject attributes) {
        Document document = unescapeIntermediate(html, attributes);
        moveChildNodes(document.body(), parent);
        return parent;
    }

    public static String trimLeftLines(String text) {
        String[] lines = text.split("\n");
        int ident = Stream.of(lines).mapToInt(line -> unskipLeft(line, " \t").length()).min().orElse(0);
        for (int i = 0; i < lines.length; i++) {
            lines[i] = stripHead(lines[i], ident);
        }
        return String.join("\n", lines);
    }

}
