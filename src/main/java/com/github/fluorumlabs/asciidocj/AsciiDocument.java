package com.github.fluorumlabs.asciidocj;

import com.github.fluorumlabs.asciidocj.impl.ParserException;
import com.github.fluorumlabs.asciidocj.impl.jflex.AsciidocDocumentParser;
import org.json.JSONObject;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;

import java.util.Map;
import java.util.Properties;

/**
 * Created by Artem Godin on 12/4/2018.
 */
public class AsciiDocument {
    private JSONObject attributes;
    private AsciidocDocumentParser parser;
    private String asciidoc;
    private Document document;

    private AsciiDocument(String asciidoc, JSONObject attributes) {
        this.attributes = attributes;
        this.parser = new AsciidocDocumentParser();
        this.asciidoc = asciidoc;
    }

    public static AsciiDocument from(String asciidoc) {
        return from(asciidoc, new JSONObject());
    }

    public static AsciiDocument from(String asciidoc, JSONObject attributes) {
        return new AsciiDocument(asciidoc, attributes);
    }

    public AsciiDocument with(JSONObject attributes) {
        attributes.keySet().forEach(k -> {
            if (!k.contains(":") && !k.contains("%")) this.attributes.put(k, attributes.get(k));
        });

        return this;
    }

    public AsciiDocument with(Map<String, String> attributes) {
        attributes.keySet().forEach(k -> {
            if (!k.contains(":") && !k.contains("%")) this.attributes.put(k, attributes.get(k));
        });

        return this;
    }

    public Document getDocument() {
        return parseAndGetDocument();
    }

    public Element getDocumentBody() {
        return parseAndGetDocument().body();
    }

    public String getHtml() {
        return getDocumentBody().html();
    }

    public JSONObject getAttributesAsJSON() {
        return getAttributesAsJSON(new JSONObject());
    }

    public JSONObject getAttributesAsJSON(JSONObject json) {
        attributes.keySet().forEach(k -> {
            if (!k.contains(":") && !k.contains("%")) json.put(k, attributes.get(k));
        });
        return json;
    }

    public Properties getAttributesAsProperties() {
        return getAttributesAsProperties(new Properties());
    }

    public Properties getAttributesAsProperties(Properties properties) {
        attributes.keySet().forEach(k -> {
            if (!k.contains(":") && !k.contains("%")) properties.put(k, attributes.get(k));
        });
        return properties;
    }

    private Document parseAndGetDocument() {
        if (document == null) {
            try {
                document = parser.parse(asciidoc, attributes);
            } catch (ParserException e) {
                throw new IllegalArgumentException("Cannot parse Asciidoc", e);
            }
        }
        return document;
    }
}
