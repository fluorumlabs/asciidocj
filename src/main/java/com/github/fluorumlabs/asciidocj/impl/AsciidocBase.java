package com.github.fluorumlabs.asciidocj.impl;

import org.apache.commons.lang3.StringUtils;
import org.json.JSONArray;
import org.json.JSONObject;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.nodes.Node;
import org.jsoup.nodes.TextNode;
import org.jsoup.parser.Tag;
import org.jsoup.select.Elements;
import org.jsoup.select.NodeTraversor;
import org.jsoup.select.NodeVisitor;

import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.IntStream;
import java.util.stream.Stream;

import static com.github.fluorumlabs.asciidocj.impl.Utils.*;

/**
 * Created by Artem Godin on 11/27/2018.
 */
public abstract class AsciidocBase {
    protected final static String DEFAULT_IMAGESDIR = "images/";

    protected Document document;
    protected StringBuilder textBuilder = new StringBuilder(256);
    protected Element currentElement;
    protected Element lastBlockParent;

    protected JSONObject properties = new JSONObject();
    protected JSONObject currentProperties = new JSONObject();
    protected JSONObject attributes = new JSONObject();

    // We don't need that :)
    protected static class Yytoken {
    }

    private void propagateProperties(Element element) {
        if (!properties.keySet().isEmpty()) {
            if (properties.has("class")) {
                for (String aClass : properties.getJSONObject("class").keySet()) {
                    element.addClass(aClass);
                }
            }
            if (properties.has("id")) {
                element.attr("id", properties.getString("id"));
                if ( properties.has("title:html") ) attributes.put("anchor:"+properties.getString("id"), properties.get("title:html"));
                if ( properties.has("reftext") ) attributes.put("anchor:"+properties.getString("id"), properties.get("reftext"));
            }
        }
        currentProperties = properties;
        properties = new JSONObject();
    }

    protected void promoteArgumentsToClasses() {
    if (properties.has("arguments") && properties.getJSONArray("arguments").length()==1) {
        if ( !properties.has("class") ) {
            properties.put("class", new JSONObject());
        }
        JSONObject classes = properties.getJSONObject("class");

        for (String aClass : properties.getJSONArray("arguments").getString(0).split(" ")) {
            classes.put(aClass,"");
        }
    }
    }

    protected String getArgument(int i) {
        return getArgument(properties,i);
    }

    protected boolean hasClass(String x) {
        if (!properties.has("class")) {
            return false;
        } else {
            return properties.getJSONObject("class").has(x);
        }
    }

    protected String getArgument(JSONObject properties, int i) {
        if (!properties.has("arguments")) {
            return "";
        } else {
            JSONArray arguments = properties.getJSONArray("arguments");
            return arguments.optString(i, "");
        }
    }

    protected String getArguments(JSONObject properties) {
        if (!properties.has("arguments")) {
            return "";
        } else {
            JSONArray arguments = properties.getJSONArray("arguments");
            List<String> results = new ArrayList<>();
            for (Object argument : arguments) {
                if ( argument instanceof String ) {
                    results.add((String)argument);
                }
            }
            return String.join(", ",results);
        }
    }

    protected boolean hasOption(String key) {
        return hasOption(key, properties);
    }

    protected boolean hasOption(String key, JSONObject properties) {
        if (!properties.has("options")) {
            return false;
        } else {
            return properties.getJSONObject("options").has(key);
        }
    }

    protected void appendText(String string) {
        textBuilder.append(string.replace("\0",""));
    }

    protected void clearText() {
        textBuilder.setLength(0);
    }

    protected String getText() {
        return textBuilder.toString();
    }

    protected String getTextAndClear() {
        String result = getText();
        clearText();
        return result;
    }

    protected void appendTextNode() {
        appendTextNode(false);
    }

    protected void appendTextNode(boolean stripNewLines) {
        String text = getText();
        if (stripNewLines) text = skipRight(text, " \t\n\0");
        if (!text.isEmpty()) {
            currentElement.appendChild(new TextNode(text, ""));
            clearText();
        }
    }

    protected void appendDocument(Document document) {
        moveChildNodes(document.body(), currentElement);
    }

    protected Element openElement(String tag) {
        appendTextNode();
        Element newElement = new Element(Tag.valueOf(tag), "");
        currentElement.appendChild(newElement);
        currentElement = newElement;
        propagateProperties(newElement);
        return newElement;
    }

    protected Element openElement(AsciidocRenderer tag) {
        appendTextNode();
        Element newElement = new AsciidocElement(tag, properties, attributes);
        currentElement.appendChild(newElement);
        currentElement = newElement;
        propagateProperties(newElement);
        return newElement;
    }

    protected boolean openOrCloseElement(String tag) {
        Element temp = currentElement;
        closeElement(tag);
        if (currentElement == temp) {
            openElement(tag);
            return true;
        }
        return false;
    }

    protected Element closeElement(String... tag) {
        appendTextNode();
        Set<String> tags = new HashSet<>(Arrays.asList(tag));
        getParents(currentElement).stream()
                .filter(e -> tags.contains(e.tagName()))
                .findFirst()
                .ifPresent(e -> currentElement = e.parent());

        return currentElement;
    }

    protected Element closeElement(AsciidocRenderer... tag) {
        appendTextNode();
        Set<String> tags = Arrays.stream(tag)
                .map(AsciidocRenderer::tag)
                .collect(Collectors.toSet());
        getParents(currentElement).stream()
                .filter(e -> tags.contains(e.tagName()))
                .findFirst()
                .ifPresent(e -> currentElement = e.parent());

        return currentElement;
    }

    protected Element closeElementTop(AsciidocRenderer... tag) {
        appendTextNode();
        Set<String> tags = Arrays.stream(tag)
                .map(AsciidocRenderer::tag)
                .collect(Collectors.toSet());
        getParentsReversed(currentElement).stream()
                .filter(e -> tags.contains(e.tagName()))
                .findFirst()
                .ifPresent(e -> currentElement = e.parent());

        return currentElement;
    }

    protected Element closeToElement(AsciidocRenderer... tag) {
        appendTextNode();
        Set<String> tags = Arrays.stream(tag)
                .map(AsciidocRenderer::tag)
                .collect(Collectors.toSet());
        if ( tags.contains(currentElement.tagName())) {
            return currentElement;
        }
        getParents(currentElement).stream()
                .filter(e -> tags.contains(e.tagName()))
                .findFirst()
                .ifPresent(e -> currentElement = e);

        return currentElement;
    }

    protected Element closeToElement(Element position, AsciidocRenderer... tag) {
        appendTextNode();
        Set<String> tags = Arrays.stream(tag)
                .map(AsciidocRenderer::tag)
                .collect(Collectors.toSet());
        if ( lastBlockParent != null ) {
            currentElement = lastBlockParent;
        }
        if (position == null) {
            position = currentElement;
        }
        if ( tags.contains(position.tagName())) {
            currentElement = position;
        } else {
            getParents(position).stream()
                    .filter(e -> tags.contains(e.tagName()))
                    .findFirst()
                    .ifPresent(e -> currentElement = e);
        }

        return currentElement;
    }

    protected boolean isInside(AsciidocRenderer... tag) {
        appendTextNode();
        Set<String> tags = Arrays.stream(tag)
                .map(AsciidocRenderer::tag)
                .collect(Collectors.toSet());
        return tags.contains(currentElement.tagName()) || getParents(currentElement).stream()
                .anyMatch(e -> tags.contains(e.tagName()));
    }

    protected Element closeElement(AsciidocRenderer tag, int level) {
        appendTextNode();
        String value = Integer.toString(level);
        getParents(currentElement).stream()
                .filter(e -> tag.tag().equals(e.tagName()) && e.attr("level").equals(value))
                .findFirst()
                .ifPresent(e -> currentElement = e.parent());

        return currentElement;
    }


    protected Element closeElement() {
        appendTextNode();
        currentElement = currentElement.parent();
        return currentElement;
    }

    protected Element closeToElement(AsciidocRenderer tag, int level) {
        appendTextNode();
        String value = Integer.toString(level);
        getParents(currentElement).stream()
                .filter(e -> tag.tag().equals(e.tagName()) && e.attr("level").equals(value))
                .findFirst()
                .ifPresent(e -> currentElement = e);

        return currentElement;
    }

    protected Element closeToElement(Element position, AsciidocRenderer tag, int level) {
        appendTextNode();
        String value = Integer.toString(level);
        if ( lastBlockParent != null && position == null ) {
            position = lastBlockParent;
        }
        if (position == null) {
            position = currentElement;
        }
        currentElement = null;
        getParents(position).stream()
                .filter(e -> tag.tag().equals(e.tagName()) && e.attr("level").equals(value))
                .findFirst()
                .ifPresent(e -> currentElement = e);

        if ( currentElement == null ) currentElement = position;
        return currentElement;
    }

    protected boolean isTerminal(Element x) {
        boolean isTerminal = true;
        while ( x != null) {
            isTerminal = isTerminal && (x.nextElementSibling() == null);
            x = x.parent();
        }
        return isTerminal;
    }

    protected Element closeBlockElement() {
        appendTextNode(true);
        getParents(currentElement).stream()
                .filter(e -> e.tagName().endsWith("_BLOCK__"))
                .findFirst()
                .ifPresent(e -> lastBlockParent = e.parent());

        if ( isInside(AsciidocRenderer.SECTION) ) {
            closeToElement(AsciidocRenderer.SECTION);
        } else {
            currentElement = document.body();
        }

        return currentElement;
    }

    protected Element appendElement(String tag) {
        appendTextNode();
        Element appendedElement = new Element(Tag.valueOf(tag), "");
        currentElement.appendChild(appendedElement);
        return appendedElement;
    }

    private static List<Element> getParents(Element element) {
        List<Element> parents = new ArrayList<>();
        Element body = element.ownerDocument().body();
        while (element != null && element != body) {
            parents.add(element);
            element = element.parent();
        }
        return parents;
    }

    private List<Element> getParentsReversed(Element element) {
        List<Element> parents = new ArrayList<>();
        while (element != null && element != element.ownerDocument().body()) {
            parents.add(0, element);
            element = element.parent();
        }
        return parents;
    }


    protected void attachEscaped(String html) {
        appendDocument(unescapeIntermediate(html, attributes));
    }


    protected Document upgradeToHtml(Document document) {
        String html = escapeIntermediate(document)
                .replace("&lt;","<")
                .replace("&gt;", ">")
                .replace("&amp;", "&");

        return unescapeIntermediate(html, attributes);
    }

    /* The working horse */
    protected void enrich() {
        // Autoplacement of TOC
        Element toc = document.select(AsciidocRenderer.TOC.tag()).first();
        if ( toc == null ) {
            toc = new AsciidocElement(AsciidocRenderer.TOC, new JSONObject(), attributes);
        }

        Elements allElements = document.getAllElements();
        for (Element x : allElements) {
            if (x instanceof AsciidocElement) {
                AsciidocElement xx = (AsciidocElement) x;
                xx.process();
                xx.attr("processed",true);
            }
        }
        // second pass for unescaped things added during first pass
        allElements = document.getAllElements();
        for (Element x : allElements) {
            if (x instanceof AsciidocElement) {
                if ( x.hasAttr("processed")) {
                    x.removeAttr("processed");
                } else {
                    AsciidocElement xx = (AsciidocElement) x;
                    xx.process();
                }
            }
        }
        document.select("[properties]").removeAttr("properties");
        document.select("[tagName]").removeAttr("tagName");
        document.select("mark[class], mark[id]").tagName("span");

        // Preamble postprocessing
        for (Element preamble : document.select("div#preamble")) {
            if (preamble.text().isEmpty()) {
                preamble.remove();
            } else if ((document.select("h2,h3,h4,h5,h6").isEmpty() || !preamble.hasAttr("is-document-title"))) {
                Element section = preamble.select("div.sectionbody").first();
                if (section != null) {
                    List<Node> nodes = new ArrayList<>(section.childNodes());
                    for (Node node : nodes) {
                        preamble.before(node);
                    }
                }
                preamble.remove();
            }
            preamble.removeAttr("is-document-title");
        }

        // TOC postprocessing
        String selector = IntStream.rangeClosed(2, attributes.optInt("toclevels", 3))
                .mapToObj(i -> String.format("%s%d[id]", "h", i))
                .collect(Collectors.joining(","));

        int currentLevel = 1;
        boolean emptyToc = true;
        Element currentList = toc;
        for (Element header : document.select(selector)) {
            int level = Integer.parseInt(header.tagName().substring(1));
            emptyToc = false;
            if ( currentLevel < level ) {
                Element newList = new Element("ul").addClass(String.format("sectlevel%d",level-1));
                currentList.appendChild(newList);
                currentList = newList;
                currentLevel = level;
            } else if ( currentLevel > level ) {
                currentList = currentList.parents().get((currentLevel-level)*2-1); // <ul><li><ul><li>... <-- go up 2 times per level
                currentLevel = level;
            } else {
                currentList = currentList.parent(); // go to <ul>
            }
            Element li = new Element("li");
            Element a = new Element("a").attr("href","#"+header.attr("id"));
            a.append(header.html());
            a.select("a.anchor").remove();
            li.appendChild(a);
            currentList.appendChild(li);
            currentList = li;
        }

        if ( toc.parent() == null && attributes.has("toc")) {
            Element firstHeader = document.select("h1").first();
            Element preamble = document.select("div#preamble").first();
            if (preamble != null && attributes.getString("toc").equals("preamble")) {
                preamble.appendChild(toc);
            } else if (firstHeader != null) {
                firstHeader.after(toc);
            } else {
                document.body().prependChild(toc);
            }
        } else {
            // Add "title" class to toc title
            toc.select("div#toctitle").addClass("title");
        }
        if ( toc.tagName().equals(AsciidocRenderer.TOC.tag())) {
            ((AsciidocElement)toc).process();
        }
        if ( emptyToc && toc.parent() != null) {
            toc.remove();
        }

        // Add footnotes
        int footnoteCount = attributes.optInt("footnote:counter",0);
        if ( footnoteCount > 0 ) {
            Element footnotes = new Element("div").attr("id", "footnotes");
            footnotes.appendChild(new Element("hr"));
            for ( int i = 1; i < footnoteCount; i++ ) {
                Element div = new Element("div").addClass("footnote").attr("id", String.format("_footnotedef_%d",i));
                Element a = new Element("a").attr("href", String.format("#_footnoteref_%d",i)).text(Integer.toString(i));
                div.appendChild(a);
                div.appendText(". ");
                div.append(attributes.getString(String.format("footnote:%d",i)));
                footnotes.appendChild(div);
            }
            document.body().appendChild(footnotes);
        }

        // Clean duplicate ids
        Set<String> ids = document.select("[id]").stream().map(e -> e.attr("id")).collect(Collectors.toSet());

        for (String id : ids) {
            Elements sameId = document.getElementsByAttributeValue("id",id);
            if ( sameId.size() > 1 ) {
                for ( int i = 1; i < sameId.size(); i++) {
                    sameId.get(i).removeAttr("id");
                }
            }
        }
    }

    private static boolean isDelimited(String line, char marker) {
        return line.equals(StringUtils.repeat(marker, line.length()));
    }

    public static String processLegacy(String source) {
        List<String> lines = new ArrayList<>(Arrays.asList(source.split("\r\n|\n")));
        int i = 0;
        String currentLine = "";
        String nextLine = "";
        char delimitation = 0;
        while ( i < lines.size()-1 ) {
            currentLine = trimRight(lines.get(i));
            nextLine = trimRight(lines.get(i+1));
            // Check if it's a delimited block and skip whatever we have there
            if ( currentLine.length() > 0 ) {
                if ( delimitation == 0
                        || (currentLine.length()>=4 && isDelimited(currentLine,delimitation))
                        || (currentLine.length()>=4 && currentLine.startsWith("|") && isDelimited(stripHead(currentLine,1), delimitation))) {
                    if ( delimitation == '/' ) {
                        lines.remove(i);
                        delimitation = 0;
                        continue;
                    }
                    char newDelimitation = currentLine.startsWith("|") && currentLine.length() > 1 ? currentLine.charAt(1) : currentLine.charAt(0);
                    if ( delimitation == 0 && ((currentLine.length()>=4 && isDelimited(currentLine, newDelimitation) && "=_-./".indexOf(newDelimitation) >= 0)
                        || (currentLine.startsWith("```") )
                        || (currentLine.length()>=4 && currentLine.startsWith("|") && isDelimited(stripHead(currentLine,1), newDelimitation) && "=".indexOf(newDelimitation) >= 0))) {
                        delimitation = newDelimitation;
                    } else {
                        delimitation = 0;
                        if (nextLine.length() > 0
                                && StringUtils.isAlphanumeric(currentLine.substring(0, 1))) {
                            char marker = nextLine.charAt(0);
                            if ("=-~^+".indexOf(marker) >= 0
                                    && nextLine.equals(StringUtils.repeat(marker, nextLine.length()))
                                    && Math.abs(nextLine.length() - currentLine.length()) <= 1) {
                                int level = 0;
                                switch (marker) {
                                    case '=':
                                        level = 1;
                                        break;
                                    case '-':
                                        level = 2;
                                        break;
                                    case '~':
                                        level = 3;
                                        break;
                                    case '^':
                                        level = 4;
                                        break;
                                    case '+':
                                        level = 5;
                                        break;
                                }
                                lines.remove(i + 1);
                                lines.remove(i);
                                lines.add(i, StringUtils.repeat('=', level) + " " + currentLine);
                            }
                        }
                    }
                }
            }
            if ( delimitation == '/' ) {
                lines.remove(i);
            } else {
                i++;
            }
        }
        return String.join("\n", lines);
    }
}
