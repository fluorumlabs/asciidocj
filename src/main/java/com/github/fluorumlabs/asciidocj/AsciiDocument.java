package com.github.fluorumlabs.asciidocj;

import com.github.fluorumlabs.asciidocj.impl.AsciidocBase;
import com.github.fluorumlabs.asciidocj.impl.ParserException;
import com.github.fluorumlabs.asciidocj.impl.jflex.AsciidocDocumentParser;
import org.json.JSONObject;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;

import java.util.Properties;

/**
 * Created by Artem Godin on 12/4/2018.
 */
public class AsciiDocument {
    private JSONObject attributes;
    private AsciidocDocumentParser parser;
    private Document document;

    private AsciiDocument(String asciidoc, JSONObject attributes) {
        this.attributes = attributes;
        this.parser = new AsciidocDocumentParser();
        try {
            document = parser.parse(asciidoc, attributes);
        } catch (ParserException e) {
            throw new IllegalArgumentException("Cannot parse Asciidoc", e);
        }
    }

    public static AsciiDocument from(String asciidoc) {
        return from(asciidoc, new JSONObject());
    }

    public static AsciiDocument from(String asciidoc, JSONObject attributes) {
        return new AsciiDocument(asciidoc, attributes);
    }

    public Document getDocument() {
        return document;
    }

    public Element getDocumentBody() {
        return document.body();
    }

    public String getHtml() {
        return getDocumentBody().html();
    }

    public JSONObject getAttributesAsJSON() {
        return getAttributesAsJSON(new JSONObject());
    }

    public JSONObject getAttributesAsJSON(JSONObject json) {
        attributes.keySet().forEach(k -> {
            if ( !k.contains(":") ) json.put(k, attributes.get(k));
        });
        return json;
    }

    public Properties getAttributesAsProperties() {
        return getAttributesAsProperties(new Properties());
    }

    public Properties getAttributesAsProperties(Properties properties) {
        attributes.keySet().forEach(k -> {
            if ( !k.contains(":") ) properties.put(k, attributes.get(k));
        });
        return properties;
    }
}
