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
        x.tagName("div").addClass("paragraph");
        Element p = new Element("p");
        moveChildNodes(x, p);
        x.appendChild(p);
        Element title = x.select("TITLE__").first();
        if (title != null) p.before(title);
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
        Element div1 = new Element("div").addClass("title").text(StringUtils.capitalize(subType));
        Element td2 = new Element("td").addClass("content");
        table.appendChild(tbody);
        tbody.appendChild(tr);
        tr.appendChild(td1).appendChild(td2);
        td1.appendChild(div1);

        moveChildNodes(x, td2);
        x.appendChild(table);
    }),
    SECTION(x -> {
        int level = Integer.parseInt(x.attr("level"));
        x.removeAttr("level");
        x.removeAttr("id");
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
        if (x.parent() != document.body() || document.select("h1").first() != x) {
            if (!x.hasAttr("id")) {
                x.attr("id", "_" + slugify(x.text()));
            }
            if (x.parent() == document.body()) {
                x.addClass("sect0");
            }
        }
    }),
    UL(x -> {
        x.removeAttr("level");
        x.tagName("div").addClass("ulist");
        Element ul = new Element("ul");
        if (x.getProperties().optBoolean("%checklist")) {
            x.addClass("checklist");
            ul.addClass("checklist");
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
            x.tagName("dt").addClass("hdlist" + x.attr("level")).removeAttr("level");
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
                x.html(x.getVariables().optString("anchor:" + id, ""));
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

        if (title != null) {
            div.after(title);
        }
    }),
    IMAGE(x -> {
        x.tagName("img");

        String src = x.attr("src");
        if (!src.startsWith("http://") && !src.startsWith("https://") && x.getVariables().has("imagesdir")) {
            String path = x.getVariables().getString("imagesdir");
            if (!path.endsWith("/")) path = path.concat("/");
            x.attr("src", path.concat(src));
        }

        if (StringUtils.isNumeric(getArgument(x, 1))) {
            x.attr("width", getArgument(x, 1));
        }
        if (StringUtils.isNumeric(getArgument(x, 2))) {
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
        x.tagName("div").addClass("listingblock");
        Element div = new Element("div").addClass("content");
        if (getArgument(x, 0).equals("source")) {
            String language = getArgument(x, 1);
            Element pre = new Element("pre")
                    .addClass("highlight");
            Element code = new Element("code");
            if (!language.isEmpty()) {
                code.addClass("language-" + language)
                        .attr("data-lang", language);
            }
            div.appendChild(pre);
            pre.appendChild(code);

            moveChildNodes(x, code);
            x.appendChild(div);
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

    private static String slugify(String s) {
        return slugify.slugify(s).replace("-", "_");
    }

}
