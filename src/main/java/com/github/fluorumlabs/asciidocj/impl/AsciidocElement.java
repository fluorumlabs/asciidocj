package com.github.fluorumlabs.asciidocj.impl;

import org.json.JSONObject;
import org.jsoup.nodes.Element;

/**
 * Created by Artem Godin on 11/27/2018.
 */
public class AsciidocElement extends Element {
    private final JSONObject properties;
    private final JSONObject variables;
    private final AsciidocRenderer renderer;

    public AsciidocElement(AsciidocRenderer renderer, JSONObject properties, JSONObject variables) {
        super(renderer.tag());
        this.renderer = renderer;
        this.properties = properties;
        this.variables = variables;
    }

    public JSONObject getProperties() {
        return properties;
    }

    public JSONObject getVariables() {
        return variables;
    }

    public void process() {
        renderer.process(this);
    }
}
