package com.github.fluorumlabs.asciidocj.impl;

import com.github.slugify.Slugify;
import org.apache.commons.lang3.StringUtils;
import org.json.JSONObject;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.nodes.Node;
import org.jsoup.nodes.TextNode;

import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.function.Consumer;
import java.util.stream.Collectors;

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
    QUOTE_BLOCK(x -> {
        x.tagName("div");
        x.addClass("quoteblock");
        Element bq = new Element("blockquote");
        moveChildNodes(x, bq);
        x.appendChild(bq);
        Element title = x.select("TITLE__").first();
        if (title != null) bq.before(title);
    }),
    LITERAL_BLOCK(x -> {
        if (x.hasClass("listing")) {
            x.tagName("div").addClass("listingblock").removeClass("listing");
        } else {
            x.tagName("div").addClass("literalblock");
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
        x.removeClass("bibliography").removeAttr("level").removeAttr("id");
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
        x.removeClass("abstract").removeClass("colophon").removeClass("bibliography");

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
            moveChildNodes(x,a);
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
        x.removeAttr("level");
        x.tagName("div").addClass("ulist");
        Element ul = new Element("ul");
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
        x.removeAttr("level");
        x.tagName("div").addClass("olist");
        Element ol = new Element("ol");
        moveChildNodes(x, ol);
        x.appendChild(ol);
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
        } else {
            x.tagName("div").addClass("dlist").removeAttr("level");
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
    }),
    P(x -> {
        x.tagName("p");
    }),
    LINK(x -> {
        x.tagName("a");
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

        moveChildNodes(x, div);
        x.appendChild(div);

        if (title != null) {
            div.after(title);
        }
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
        x.tagName("img");

        String src = x.attr("src");

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
        if (x.getProperties().has("title")) {
            x.attr("title", x.getProperties().getString("title"));
        }
    }),
    TITLE(x -> {
        String type = x.attr("type");
        x.tagName(type.equals("Table") ? "caption" : "div").addClass("title");
        String caption = x.attr("caption");
        x.removeAttr("type").removeAttr("caption");

        if (!caption.isEmpty()) {
            x.prependText(caption);
        } else if (!type.isEmpty()) {
            int counter = x.getVariables().optInt("counter:" + type, 1);
            x.prependText(String.format("%s %d. ", type, counter));
            x.getVariables().put("counter:" + type, counter + 1);
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
        x.tagName("div").addClass("sidebarblock");
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

        List<Set<Character>> columnFormat = new ArrayList<>();
        List<Integer> columnWidths = new ArrayList<>();

        if (x.getProperties().has("cols")) {
            for (String format : x.getProperties().getString("cols").split(",")) {
                int count = 1;
                String[] split = format.split("\\*", 2);
                if (format.contains("*") && StringUtils.isNumeric(split[0])) {
                    count = Integer.valueOf(split[0]);
                    format = split.length == 2 ? split[1] : "";
                }

                String width = unskipLeft(format, "0123456789");
                int witdhFactor = 1;
                if (StringUtils.isNumeric(width)) {
                    witdhFactor = Integer.valueOf(width);
                }

                for (int i = 0; i < count; i++) {
                    // Collect formatting characters to a set
                    columnFormat.add(format.codePoints().mapToObj(c -> (char) c).collect(Collectors.toSet()));
                    columnWidths.add(witdhFactor);
                }
            }
        } else {
            for (int i = 0; i < x.getProperties().optInt("firstRowCellCount", x.childNodeSize()); i++) {
                columnFormat.add(Collections.emptySet());
                columnWidths.add(1);
            }
        }

        x.tagName("table").addClass("frame-all")
                .addClass("grid-all")
                .addClass("tableblock");

        if (x.getProperties().has("width")) {
            x.attr("style", "width: " + x.getProperties().getString("width") + ";");
        } else {
            x.addClass("stretch");
        }

        Element colGroup = new Element("colgroup");
        float totalWidth = 0;
        int totalWidthFactor = columnWidths.stream().mapToInt(Integer::intValue).sum();
        for (int i = 0; i < columnFormat.size() - 1; i++) {
            float width = Math.round(1000000f * columnWidths.get(i) / totalWidthFactor) / 10000f;
            totalWidth += width;
            colGroup.appendChild(new Element("col").attr("style", String.format("width: %s%%;", widthFormatter.format(width))));
        }
        colGroup.appendChild(new Element("col").attr("style", String.format("width: %s%%;", widthFormatter.format(100 - totalWidth))));
        Element tbody = new Element("tbody");
        Element thead = null;
        Element trow = null;
        boolean isHead = false;

        JSONObject options = x.getProperties().optJSONObject("options");

        // Lay cells in row/columns
        int rowCounter = 0;
        int columnCounter = 0;
        for (Element cell : x.select(TABLE_CELL.tag())) {
            if (trow == null) {

                if ((x.getProperties().optInt("headerCellCount", 0) > 0 || (options != null && options.has("header")))
                        && rowCounter == 0) {
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
            Element tcell = new Element(isHead ? "th" : "td");
            tcell.addClass("halign-left").addClass("tableblock").addClass("valign-top");

            Element content = cell.select(PARAGRAPH_BLOCK.tag()).first();
            if (columnFormat.get(columnCounter).contains('a') && !isHead) {
                Element target = new Element("div").addClass("content");
                moveChildNodes(cell, target);
                tcell.appendChild(target);
            } else if (content != null) {
                if (isHead) {
                    moveChildNodes(content, tcell);
                } else {
                    Element target = new Element("p").addClass("tableblock");
                    moveChildNodes(content, target);
                    tcell.appendChild(target);
                }
            }
            trow.appendChild(tcell);
            columnCounter++;
            if (columnCounter >= columnFormat.size()) {
                if (isHead) {
                    thead.appendChild(trow);
                } else {
                    tbody.appendChild(trow);
                }
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
