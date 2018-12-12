package com.github.fluorumlabs.asciidocj.impl;

import com.github.slugify.Slugify;
import org.json.JSONArray;
import org.json.JSONObject;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.nodes.Node;
import org.jsoup.nodes.TextNode;
import org.jsoup.select.Elements;

import java.text.DecimalFormat;
import java.util.Set;
import java.util.function.Consumer;
import java.util.stream.StreamSupport;

import static com.github.fluorumlabs.asciidocj.impl.Utils.*;

/**
 * Created by Artem Godin on 11/27/2018.
 */
public enum AsciidocRenderer {
    PARAGRAPH_BLOCK(x -> {
        x.tagName("div");
        if (x.hasClass("abstract")) {
            x.addClass("quoteblock");
            Element bq = new Element("blockquote");
            moveChildNodes(x, bq);
            x.appendChild(bq);
            Element title = x.select("TITLE__").first();
            if (title != null) bq.before(title);
        } else {
            x.addClass("paragraph");
            Element p = new Element("p");
            moveChildNodes(x, p);
            x.appendChild(p);
            Element title = x.select("TITLE__").first();
            if (title != null) p.before(title);
        }
    }),
    PASSTHROUGH_BLOCK(x -> {
        x.after(x.text());
        x.remove();
    }),
    QUOTE_BLOCK(x -> {
        x.tagName("div").removeClass("quote");
        if (x.getProperties().has("verse%")) {
            x.addClass("verseblock");
            Element pre = new Element("pre").addClass("content");
            moveChildNodes(x, pre);
            x.appendChild(pre);
            Element title = x.select("TITLE__").first();
            if (title != null) pre.before(title);
        } else {
            x.addClass("quoteblock");
            Element bq = new Element("blockquote");
            moveChildNodes(x, bq);
            x.appendChild(bq);
            Element title = x.select("TITLE__").first();
            if (title != null) bq.before(title);
        }

        if (!x.getProperties().optString("quote:attribution").isEmpty()) {
            Element div = new Element("div").addClass("attribution");
            div.appendText("\u2014 ");
            div.append(x.getProperties().optString("quote:attribution"));
            if (!x.getProperties().optString("quote:cite").isEmpty()) {
                div.appendChild(new Element("br"));
                div.appendChild(new Element("cite").html(x.getProperties().optString("quote:cite")));
            }
            x.appendChild(div);
        }
    }),
    LITERAL_BLOCK(x -> {
        if (x.hasClass("listing")) {
            x.tagName("div").addClass("listingblock").removeClass("listing");
        } else {
            x.tagName("div").addClass("literalblock").removeClass("literal");
        }
        Element div = new Element("div").addClass("content");
        Element pre = new Element("pre");
        div.appendChild(pre);

        moveChildNodes(x, pre);
        x.appendChild(div);
    }),
    ADMONITION_BLOCK(x -> {
        String subType = x.attr("subtype");
        x.removeAttr("subtype");
        x.tagName("div").addClass("admonitionblock").addClass(subType);
        Element table = new Element("table");
        Element tbody = new Element("tbody");
        Element tr = new Element("tr");
        Element td1 = new Element("td").addClass("icon");
        Element div1 = new Element("div").addClass("title").html(x.attr("text"));
        Element td2 = new Element("td").addClass("content");
        table.appendChild(tbody);
        tbody.appendChild(tr);
        tr.appendChild(td1).appendChild(td2);
        td1.appendChild(div1);

        moveChildNodes(x, td2);
        x.appendChild(table);
        x.removeAttr("text");
    }),
    SECTION(x -> {
        int level = Integer.parseInt(x.attr("level"));
        x.removeClass("bibliography").removeClass("glossary").removeAttr("level").removeAttr("id");
        if (x.hasClass("discrete")) {
            level = 0;
        }
        switch (level) {
            case 0:
                // Pop content to parent
                moveChildNodesToParent(x);
                x.remove();
                break;
            case 1:
                x.tagName("div").attr("id", "preamble");
                Element sectionBody1 = new Element("div").addClass("sectionbody");
                // Move the first child outside
                Element header = x.children().first();
                if (header != null) {
                    x.before(header);
                }
                moveChildNodes(x, sectionBody1);
                if (sectionBody1.childNodeSize() == 0) {
                    sectionBody1.appendChild(new TextNode("", ""));
                }
                x.appendChild(sectionBody1);
                break;
            case 2:
                x.tagName("div").addClass("sect" + Integer.toString(level - 1));
                if (x.hasClass("abstract")) x.removeClass("abstract");
                if (x.hasClass("appendix")) x.removeClass("appendix");
                Element sectionBody = new Element("div").addClass("sectionbody");
                // Move all but the first child node
                moveChildNodesSkipFirst(x, sectionBody);
                if (sectionBody.childNodeSize() == 0) {
                    sectionBody.appendChild(new TextNode("", ""));
                }
                x.appendChild(sectionBody);
                break;
            default:
                x.tagName("div").addClass("sect" + Integer.toString(level - 1));
                break;
        }
    }),
    HEADER(x -> {
        Document document = x.ownerDocument();
        x.tagName("h" + x.attr("level"));
        x.removeAttr("level");
        x.removeClass("abstract").removeClass("glossary").removeClass("colophon").removeClass("bibliography");

        // override id
        Element last = x.children().last();
        Node beforeLast = last == null ? null : last.previousSibling();
        boolean rewriteId = beforeLast != null && beforeLast instanceof TextNode && ((TextNode) beforeLast).text().endsWith(" ");
        //TODO Fix forward reference to AsciidocRenderer.LINK.tag()
        if (last != null && last.tagName().equals("LINK__") && last.hasAttr("id") && rewriteId) {
            if (x.hasAttr("id")) {
                x.getVariables().put("anchor:" + last.attr("id"), x.getVariables().optString("anchor:" + x.attr("id")));
            }
            x.attr("id", last.attr("id"));
            last.remove();
            // Also remove trailing space(s) from the last textnode
            if (!x.textNodes().isEmpty()) {
                TextNode textNode = x.textNodes().get(x.textNodes().size() - 1);
                textNode.text(trimRight(textNode.text()));
            }
        }

        if (x.hasClass("appendix") && x.tagName().equals("h2") && !x.attr("sectNum").isEmpty()) {
            x.prependText(x.getVariables().optString("appendix-caption", "Appendix") + " " + x.attr("sectNum") + ": ");
        } else if (!x.attr("sectNum").isEmpty()) {
            x.prependText(x.attr("sectNum") + ". ");
        }
        x.removeAttr("sectNum");
        x.removeClass("appendix");

        if (x.getVariables().has("sectanchors") && !x.attr("id").isEmpty()) {
            Element a = new Element("a").addClass("anchor").attr("href", "#" + x.attr("id"));
            x.prependChild(a);
        }
        if (x.getVariables().has("sectlinks") && !x.attr("id").isEmpty()) {
            Element a = new Element("a").addClass("link").attr("href", "#" + x.attr("id"));
            moveChildNodes(x, a);
            x.appendChild(a);
        }

        if (x.parent() != document.body() || document.select("h1").first() != x) {
            if (x.parent() == document.body()) {
                x.addClass("sect0");
            }
        }
    }),
    TOC(x -> {
        x.tagName("div").addClass("toc").attr("id", "toc");
        Element div = new Element("div").attr("id", "toctitle");
        div.text(x.getVariables().optString("toc-title", "Table of Contents"));
        x.prependChild(div);
    }),
    UL(x -> {
        Set<String> classes = x.classNames();
        x.removeAttr("level");
        x.tagName("div").addClass("ulist");
        Element ul = new Element("ul");
        ul.classNames(classes);
        if (x.getProperties().optBoolean("%checklist")) {
            x.addClass("checklist");
            ul.addClass("checklist");
        }
        if (x.getProperties().optBoolean("%bibliography")) {
            x.addClass("bibliography");
            ul.addClass("bibliography");
        }
        moveChildNodes(x, ul);
        x.appendChild(ul);

        Element title = x.select("TITLE__").first();
        if (title != null) ul.before(title);
    }),
    OL(x -> {
        int level = Integer.parseInt(x.attr("level"));
        Set<String> classes = x.classNames();
        x.removeAttr("level");
        x.tagName("div").addClass("olist");
        Element ol = new Element("ol");
        ol.classNames(classes);
        if (x.getProperties().has("start")) {
            ol.attr("start", x.getProperties().getString("start"));
        }
        if (hasOption(x, "reversed")) {
            ol.attr("reversed", true);
        }
        moveChildNodes(x, ol);
        x.appendChild(ol);
        if (ol.hasClass("arabic")) {
            // do nothing
        } else if (ol.hasClass("loweralpha")) {
            ol.attr("type", "a");
        } else if (ol.hasClass("lowerroman")) {
            ol.attr("type", "i");
        } else if (ol.hasClass("upperalpha")) {
            ol.attr("type", "A");
        } else if (ol.hasClass("upperroman")) {
            ol.attr("type", "I");
        } else {
            switch (level) {
                case 1:
                    x.addClass("arabic");
                    ol.addClass("arabic");
                    break;
                case 2:
                    x.addClass("loweralpha");
                    ol.addClass("loweralpha").attr("type", "a");
                    break;
                case 3:
                    x.addClass("lowerroman");
                    ol.addClass("lowerroman").attr("type", "i");
                    break;
                case 4:
                    x.addClass("upperalpha");
                    ol.addClass("upperalpha").attr("type", "A");
                    break;
                case 5:
                default:
                    x.addClass("upperroman");
                    ol.addClass("upperroman").attr("type", "I");
                    break;
            }
        }
        Element title = x.select("TITLE__").first();
        if (title != null) ol.before(title);
    }),
    DL(x -> {
        if (x.hasClass("qanda")) {
            x.tagName("div").addClass("qlist").removeAttr("level");
            Element ol = new Element("ol");
            moveChildNodes(x, ol);
            x.appendChild(ol);
            Element title = x.select("TITLE__").first();
            if (title != null) ol.before(title);
        } else if (x.hasClass("horizontal")) {
            // Oh boy, horizontal dlist -- let's build a table out of <dt>'s and <dd>'s
            x.tagName("div").addClass("hdlist").removeClass("horizontal").removeAttr("level");
            Element table = new Element("table");
            Element tbody = new Element("tbody");
            Element trow = null;
            for (Element child : x.children()) {
                if (child.tagName().equals("DT__")) {
                    if (trow != null) {
                        tbody.appendChild(trow);
                    }
                    trow = new Element("tr");
                }
                if (trow != null) {
                    trow.appendChild(child.addClass("horizontal"));
                } else {
                    child.remove();
                }
            }
            if (trow != null) {
                tbody.appendChild(trow);
            }
            table.appendChild(tbody);
            x.appendChild(table);
        } else {
            x.tagName("div").addClass("dlist").removeAttr("level");
            if (x.hasClass("glossary")) {
                x.select("DT__").addClass("glossary");
            }
            Element dl = new Element("dl");
            moveChildNodes(x, dl);
            x.appendChild(dl);
            Element title = x.select("TITLE__").first();
            if (title != null) dl.before(title);
        }
    }),
    DT(x -> {
        if (getArgument(getParent(x), 0).equals("qanda")) {
            Element li = new Element("li");
            Element p = new Element("p");
            Element em = new Element("em");
            moveChildNodes(x, em);
            p.appendChild(em);

            li.appendChild(p);
            x.before(li);
            x.remove();
        } else if (x.hasClass("glossary")) {
            x.tagName("dt").removeClass("glossary").removeAttr("level");
        } else if (x.hasClass("horizontal")) {
            x.tagName("td").addClass("hdlist1").removeClass("horizontal").removeAttr("level");
        } else {
            x.tagName("dt").addClass("hdlist1").removeAttr("level");
        }

    }),
    DD(x -> {
        if (getArgument(getParent(x), 0).equals("qanda")) {
            // bring answer inside <DT__>
            Element dt = x.previousElementSibling();
            moveChildNodes(x, dt);
            x.remove();
        } else if (x.hasClass("horizontal")) {
            x.tagName("td").addClass("hdlist2").removeClass("horizontal").removeAttr("level");
        } else {
            x.tagName("dd");
        }
    }),
    COL(x -> {
        x.tagName("div").addClass("colist arabic");
        Element col = new Element("ol");
        moveChildNodes(x, col);
        x.appendChild(col);
        Element title = x.select("TITLE__").first();
        if (title != null) col.before(title);
    }),
    LIST_ITEM(x -> {
        x.tagName("li");
        x.removeAttr("level");
        x.removeAttr("class");
    }),
    P(x -> {
        if (!x.hasAttr("keep")) {
            x.remove();
        } else {
            x.tagName("p").removeAttr("keep");
        }
    }),
    LINK(x -> {
        x.tagName("a");
        // Extract inner links - they make no sense
        for (Element sublink : x.select("LINK__")) {
            moveChildNodesToParent(sublink);
            sublink.remove();
        }
        if (x.getProperties().has("to-id")) {
            String id = x.getProperties().getString("to-id");
            x.attr("href", "#" + id);
            if (x.getProperties().has("to-id-contents")) {
                x.html(x.getProperties().getString("to-id-contents"));
            } else {
                String idText = x.getVariables().optString("anchor:" + id, "");

                if (idText.isEmpty()) {
                    Element target = x.ownerDocument().select("#" + id).first();
                    if (target != null) {
                        idText = target.text();
                    }
                }

                if (idText.isEmpty()) {
                    idText = "[" + id + "]";
                }

                x.html(idText);
            }
            if (x.getVariables().optString("xrefstyle").equals("full") && x.getVariables().has("sectnum:" + id)) {
                x.prependText(x.getVariables().getString("sectnum:" + id) + ", \u201c");
                x.appendText("\u201d");
            } else if (x.getVariables().optString("xrefstyle").equals("short") && x.getVariables().has("sectnum:" + id)) {
                x.text(x.getVariables().getString("sectnum:" + id));
            }
        } else {
            if (x.getProperties().has("window")) {
                x.attr("target", x.getProperties().getString("window"));
                x.attr("rel", "noopener");
            }
        }
    }),
    IMAGE_BLOCK(x -> {
        x.tagName("div").addClass("imageblock");
        Element title = x.select("TITLE__").first();
        Element div = new Element("div").addClass("content");

        if (x.getProperties().has("float")) {
            x.addClass(x.getProperties().getString("float"));
        }
        if (x.getProperties().has("align")) {
            x.addClass("text-" + x.getProperties().getString("align"));
        }

        moveChildNodes(x, div);
        x.appendChild(div);

        if (title != null) {
            div.after(title);
        }
    }),
    OPEN_BLOCK(x -> {
        x.tagName("div").addClass("openblock");
        Element div = new Element("div").addClass("content");

        moveChildNodes(x, div);
        x.appendChild(div);
    }),
    VIDEO_BLOCK(x -> {
        String src = x.attr("src");
        x.tagName("div").addClass("videoblock").removeAttr("src");
        Element title = x.select("TITLE__").first();
        Element div = new Element("div").addClass("content");

        Element video;

        String type = getArgument(x, 0);
        switch (type) {
            case "vimeo":
                video = new Element("iframe")
                        .attr("src", "https://player.vimeo.com/video/" + src)
                        .attr("frameborder", "0")
                        .attr("allowfullscreen", "");
                break;
            case "youtube":
                video = new Element("iframe")
                        .attr("src", "https://www.youtube.com/embed/" + src + "?rel=0")
                        .attr("frameborder", "0")
                        .attr("allowfullscreen", "");
                break;
            default:
                video = new Element("video")
                        .attr("src", src)
                        .attr("controls", "");
                video.append("Your browser does not support the video tag.");
                break;
        }

        div.appendChild(video);
        x.appendChild(div);

        if (x.getProperties().has("width")) {
            video.attr("width", x.getProperties().getString("width"));
        }
        if (x.getProperties().has("height")) {
            video.attr("height", x.getProperties().getString("height"));
        }
        if (x.getProperties().has("options")) {
            for (String option : x.getProperties().getJSONObject("options").keySet()) {
                video.attr(option, "");
            }
        }
        if (x.getProperties().has("start") && x.getProperties().has("end")) {
            video.attr("src", String.format("%s#t=%s,%s", src, x.getProperties().getString("start"), x.getProperties().getString("end")));
        }
    }),
    AUDIO_BLOCK(x -> {
        String src = x.attr("src");
        x.tagName("div").addClass("audioblock").removeAttr("src");
        Element div = new Element("div").addClass("content");

        Element audio;

        audio = new Element("audio")
                .attr("src", src)
                .attr("controls", "");
        audio.append("Your browser does not support the audio tag.");

        div.appendChild(audio);
        x.appendChild(div);

        if (x.getProperties().has("options")) {
            for (String option : x.getProperties().getJSONObject("options").keySet()) {
                audio.attr(option, "");
            }
        }
    }),
    IMAGE(x -> {
        String src = x.attr("src");
        if (x.getProperties().optString("opts").equals("interactive") && src.endsWith(".svg")) {
            x.tagName("object").removeAttr("src").attr("data", src).attr("type", "image/svg+xml");
            if (x.hasAttr("alt")) {
                Element span = new Element("span").addClass("alt");
                span.text(x.attr("alt"));
                x.removeAttr("alt");
                x.appendChild(span);
            }
        } else {
            x.tagName("img");
        }
        if (x.getProperties().has("width")) {
            x.attr("width", x.getProperties().getString("width"));
        } else if (!getArgument(x, 1).isEmpty()) {
            x.attr("width", getArgument(x, 1));
        }
        if (x.getProperties().has("height")) {
            x.attr("height", x.getProperties().getString("height"));
        } else if (!getArgument(x, 2).isEmpty()) {
            x.attr("height", getArgument(x, 2));
        }

    }),
    TITLE(x -> {
        String type = x.attr("type");
        x.tagName(type.equals("Table") ? "caption" : "div").addClass("title");
        String caption = x.attr("caption");
        x.removeAttr("type").removeAttr("caption");

        if (!caption.equals("\0")) {
            x.prependText(caption);
        } else if (!type.isEmpty()) {
            caption = x.getVariables().optString(type.toLowerCase() + "-caption!", type);
            if (x.getVariables().has(type.toLowerCase() + "-caption!")) {
                caption = "";
            }
            if (!caption.isEmpty()) {
                int counter = x.getVariables().optInt("counter:" + type, 1);
                x.prependText(String.format("%s %d. ", caption, counter));
                x.getVariables().put("counter:" + type, counter + 1);
            }
        }
    }),
    LISTING_BLOCK(x -> {
        x.tagName("div").addClass("listingblock").removeClass("listing");
        Element div = new Element("div").addClass("content");
        if (getArgument(x, 0).equals("source") || x.hasClass("source")) {
            String language = getArgument(x, 1);
            if (language.isEmpty()) language = x.getVariables().optString("source-language");
            Element pre = new Element("pre")
                    .addClass("highlight");

            if (hasOption(x, "nowrap")) {
                pre.addClass("nowrap");
            }

            Element code = new Element("code");
            if (!language.isEmpty()) {
                code.addClass("language-" + language)
                        .attr("data-lang", language);
            }
            div.appendChild(pre);
            pre.appendChild(code);

            moveChildNodes(x, code);
            x.appendChild(div);
            x.removeClass("source");
        } else {
            Element listingPre = new Element("pre");
            div.appendChild(listingPre);

            moveChildNodes(x, listingPre);
            x.appendChild(div);
        }

        Element title = x.select("TITLE__").first();
        if (title != null) div.before(title);
    }),
    SIDEBAR_BLOCK(x -> {
        x.tagName("div").addClass("sidebarblock").removeClass("sidebar");
        Element div = new Element("div").addClass("content");
        moveChildNodes(x, div);
        x.appendChild(div);
    }),
    EXAMPLE_BLOCK(x -> {
        x.tagName("div").addClass("exampleblock");
        Element div = new Element("div").addClass("content");
        moveChildNodes(x, div);
        x.appendChild(div);

        Element title = x.select("TITLE__").first();
        if (title != null) div.before(title);
    }),
    KEYBOARD(x -> {
        String contents = x.getProperties().optString("shortcut", "");
        if (contents.endsWith("+")) contents = stripTail(contents, 1) + "\1";
        String[] keys = contents.split("\\+");
        if (keys.length == 1) {
            x.tagName("kbd");
            x.text(contents.replace("\1", "+"));
        } else {
            x.tagName("span").addClass("keyseq");
            for (String key : keys) {
                if (x.childNodeSize() > 0) x.appendText("+");
                x.appendChild(new Element("kbd").text(trim(key.replace("\1", "+"))));
            }
        }
    }),
    MENU(x -> {
        String contents = x.getProperties().optString("submenu", "");
        if (x.getProperties().has("menu")) {
            contents = x.getProperties().getString("menu") + ">" + contents;
        }
        String[] keys = contents.split(">");
        if (keys.length == 1) {
            x.tagName("b").addClass("menu");
            x.text(trim(keys[0]));
        } else {
            x.tagName("span").addClass("menuseq");
            for (int i = 0; i < keys.length; i++) {
                String key = trim(keys[i]);
                if (i > 0) {
                    x.appendText("\u00a0"); // nbsp
                    x.appendChild(new Element("b").addClass("caret").text("\u203a"));
                    x.appendText(" ");
                }
                Element item = new Element("b").text(key);
                if (i == 0) {
                    item.addClass("menu");
                } else if (i < keys.length - 1) {
                    item.addClass("submenu");
                } else {
                    item.addClass("menuitem");
                }
                x.appendChild(item);
            }
        }
    }),
    BUTTON(x -> {
        x.tagName("b").addClass("button").text(x.getProperties().optString("button", ""));
    }),
    TABLE_CELL(Node::remove), // Cell contents is handled by TABLE_BLOCK
    TABLE_BLOCK(x -> {
        DecimalFormat widthFormatter = new DecimalFormat("#.####");

        JSONArray columns = x.getProperties().optJSONArray("columns:");
        if (columns == null) {
            columns = new JSONArray();
            for (int i = 0; i < x.getProperties().optInt("firstRowCellCount", x.childNodeSize()); i++) {
                columns.put(new JSONObject());
            }
        }

        x.tagName("table").addClass("frame-" + x.getProperties().optString("frame", "all"))
                .addClass("grid-" + x.getProperties().optString("grid", "all"))
                .addClass("tableblock");

        if (x.getProperties().has("stripes")) {
            x.addClass("stripes-" + x.getProperties().getString("stripes"));
        }

        if (x.getProperties().has("width") ) {
            x.attr("style", "width: " + x.getProperties().getString("width") + ";");
        } else if ( hasOption(x,"autowidth") ) {
            x.addClass("fit-content");
        } else {
            x.addClass("stretch");
        }

        Element colGroup = new Element("colgroup");
        float totalWidth = 0;
        int totalWidthFactor = StreamSupport.stream(columns.spliterator(), false)
                .filter(o -> !((JSONObject) o).optBoolean("autowidth"))
                .mapToInt(o -> ((JSONObject) o).optInt("width", 1)).sum();
        boolean hasAutowidth = hasOption(x,"autowidth") || StreamSupport.stream(columns.spliterator(), false)
                .anyMatch(o -> ((JSONObject) o).optBoolean("autowidth"));

        if (hasAutowidth) {
            for (int i = 0; i < columns.length(); i++) {
                if (columns.getJSONObject(i).has("width")) {
                    colGroup.appendChild(new Element("col").attr("style", String.format("width: %d%%;", columns.getJSONObject(i).getInt("width"))));
                } else {
                    colGroup.appendChild(new Element("col"));
                }
            }
        } else {
            for (int i = 0; i < columns.length() - 1; i++) {
                float width = Math.round(1000000f * columns.getJSONObject(i).optInt("width", 1) / totalWidthFactor) / 10000f;
                totalWidth += width;
                colGroup.appendChild(new Element("col").attr("style", String.format("width: %s%%;", widthFormatter.format(width))));
            }
            colGroup.appendChild(new Element("col").attr("style", String.format("width: %s%%;", widthFormatter.format(100 - totalWidth))));
        }
        Element tbody = new Element("tbody");
        Element thead = null;
        Element trow = null;
        boolean isHead = false;

        JSONObject options = x.getProperties().optJSONObject("options");
        boolean hasHeadRow = (options != null && options.has("header"))
                || (x.getProperties().optInt("firstRowCellCount", 0) == columns.length()
                && x.getProperties().optInt("headerCellCount", 0) == columns.length());

        boolean hasFootRow = options != null && options.has("footer");

        // Lay cells in row/columns
        int rowCounter = 0;
        int columnCounter = 0;
        for (Element cell : x.select(TABLE_CELL.tag())) {
            // overlay local styles
            JSONObject columnFormat = columns.getJSONObject(columnCounter);
            JSONObject cellFormat = ((AsciidocElement) cell).getProperties().getJSONObject("format");
            for (String key : columnFormat.keySet()) {
                if (!cellFormat.has(key)) {
                    cellFormat.put(key, columnFormat.get(key));
                }
            }

            if (trow == null) {
                if (hasHeadRow && rowCounter == 0) {
                    thead = new Element("thead");
                    trow = new Element("tr");
                    isHead = true;
                } else {
                    trow = new Element("tr");
                    isHead = false;
                }
                rowCounter++;
                columnCounter = 0;
            }
            Element tcell = new Element(isHead||cellFormat.optBoolean("header") ? "th" : "td");
            tcell.addClass("tableblock");
            tcell.addClass("halign-" + cellFormat.optString("halign", "left"));
            tcell.addClass("valign-" + cellFormat.optString("valign", "top"));

            Elements content = cell.select(PARAGRAPH_BLOCK.tag());
            if (cellFormat.optBoolean("asciidoc") && !isHead) {
                Element target = new Element("div").addClass("content");
                moveChildNodes(cell, target);
                tcell.appendChild(target);
            } else if (content != null) {
                if (isHead) {
                    for (Element element : content) {
                        moveChildNodes(element, tcell);
                    }
                } else {
                    for (Element element : content) {
                        Element p = new Element("p").addClass("tableblock");
                        Element target = p;
                        if ( cellFormat.optBoolean("verse")) {
                            target.tagName("div").addClass("verse").removeClass("tableblock");
                        }
                        if ( cellFormat.optBoolean("literal")) {
                            target.tagName("div").addClass("literal").removeClass("tableblock");
                            Element n = new Element("pre");
                            target.appendChild(n);
                            target = n;
                        }
                        if ( cellFormat.optBoolean("em")) {
                            Element n = new Element("em");
                            target.appendChild(n);
                            target = n;
                        }
                        if ( cellFormat.optBoolean("monospace")) {
                            Element n = new Element("code");
                            target.appendChild(n);
                            target = n;
                        }
                        if ( cellFormat.optBoolean("strong")) {
                            Element n = new Element("strong");
                            target.appendChild(n);
                            target = n;
                        }
                        moveChildNodes(element, target);
                        if (target != p ) {
                            p.appendChild(target);
                        }
                        tcell.appendChild(p);
                    }
                }
            }
            trow.appendChild(tcell);
            columnCounter++;
            if (columnCounter >= columns.length()) {
                if (isHead) {
                    thead.appendChild(trow);
                } else {
                    tbody.appendChild(trow);
                }
                columnCounter = 0;
                trow = null;
            }
        }

        if (trow != null) {
            if (isHead) {
                thead.appendChild(trow);
            } else {
                tbody.appendChild(trow);
            }
        }

        x.appendChild(colGroup);
        if (thead != null) x.appendChild(thead);
        x.appendChild(tbody);
        if (hasFootRow) {
            trow = tbody.select("tr").last();
            if (trow != null) {
                Element tfoot = new Element("tfoot");
                tfoot.appendChild(trow);
                x.appendChild(tfoot);
            }
        }
    });

    // This entity does not exist :)
    private static final Slugify slugify = new Slugify().withCustomReplacement("ж", "zh");

    private final Consumer<AsciidocElement> processor;

    AsciidocRenderer(Consumer<AsciidocElement> processor) {
        this.processor = processor;
    }

    public String tag() {
        return name().concat("__");
    }

    public void process(AsciidocElement x) {
        processor.accept(x);
    }

    public static String slugify(String s) {
        return slugify.slugify(s).replace("-", "_");
    }

}
