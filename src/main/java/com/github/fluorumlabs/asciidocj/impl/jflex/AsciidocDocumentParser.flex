package com.github.fluorumlabs.asciidocj.impl.jflex;

import com.github.fluorumlabs.asciidocj.impl.AsciidocBase;
import com.github.fluorumlabs.asciidocj.impl.AsciidocRenderer;
import com.github.fluorumlabs.asciidocj.impl.ParserException;
import org.json.JSONObject;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;

import java.io.IOException;

import static com.github.fluorumlabs.asciidocj.impl.Utils.*;


/**
 * Asciidoc specification
 * - https://asciidoctor.org/docs/user-manual/
 * - https://asciidoctor.org/docs/asciidoc-syntax-quick-reference/
 * <p>
 * Parser produces Jsoup Document
 */
%%

%class AsciidocDocumentParser
%public
%extends AsciidocBase
%function parseInput
%apiprivate
%unicode
%scanerror ParserException

%{
    private AsciidocFormatter formatter = null;

    /**
     * Construct a new parser.
     */
    public AsciidocDocumentParser() {
    }

    /**
     * Convert asciidoc to JSoup Document.
     *
     * @param text Asciidoc
     * @return JSoup Document
     * @throws ParserException if there was an unrecoverable error
     */
    public Document parse(String text) throws ParserException {
        parse(text, null, null);
        enrich();
        return document;
    }

    /**
     * Convert asciidoc to JSoup Document with attributes.
     *
     * @param text       Asciidoc
     * @param attributes JSONObject holding Asciidoc attributes
     * @return JSoup Document
     * @throws ParserException if there was an unrecoverable error
     */
    public Document parse(String text, JSONObject attributes) throws ParserException {
        parse(text, null, attributes);
        enrich();
        return document;
    }

    /**
     * Convert asciidoc to JSoup Document with attributes and properties.
     *
     * @param text       Asciidoc
     * @param properties Properties
     * @param attributes Attributes
     * @return JSoup Document
     * @throws ParserException if there was an unrecoverable error
     */
    private Document parse(String text, JSONObject properties, JSONObject attributes) throws ParserException {
        if (properties != null) {
            this.properties = properties;
        }
        if (attributes != null) {
            this.attributes = attributes;
        }
        document = Document.createShell("");
        document.outputSettings().prettyPrint(false);
        currentElement = document.body();
        textBuilder.setLength(0);

        try {
            yyreset(getReader(text.replace("\r\n", "\n"), true));
            parseInput();
            appendTextNode(); // If needed
            return document;
        } catch (IOException e) {
            throw new ParserException(e);
        }
    }

    /**
     * Format collected text and append to current element
     *
     * @throws ParserException if there was an unrecoverable error
     */
    private void appendFormatted() throws ParserException {
        if (formatter == null) formatter = new AsciidocFormatter();
        appendDocument(formatter.parse(trimAll(getTextAndClear()), new JSONObject(), attributes));
    }

    /**
     * Format text
     * @param text text to format
     * @return Document containing resulting DOM tree
     * @throws ParserException if there was an unrecoverable error
     */
    private Document getFormatted(String text) throws ParserException {
        if (formatter == null) formatter = new AsciidocFormatter();
        return formatter.parse(trimAll(text), new JSONObject(), attributes);
    }

    /**
     * Format text and append to current element
     * @param text text to format
     * @throws ParserException if there was an unrecoverable error
     */
    private void appendFormatted(String text) throws ParserException {
        if (formatter == null) formatter = new AsciidocFormatter();
        appendDocument(formatter.parse(trimAll(text), new JSONObject(), attributes));
    }

    /**
     * Parse sub-document and append to current element
     * @param text asciidoc of sub-document
     * @throws ParserException if there was an unrecoverable error
     */
    private void appendSubdocument(String text) throws ParserException {
        AsciidocDocumentParser parser = new AsciidocDocumentParser();
        appendDocument(parser.parse(trimAll(text), new JSONObject(), attributes));
    }

    private JSONObject tableProperties;
    private int tableCellCounter;
%}

LineFeed                    = \R | \0
Whitespace					= " "|"\t"
NoLineFeed                  = [^\r\n\u2028\u2029\u000B\u000C\u0085\0]

Properties                  = "[" [\]]* "]" {Whitespace}*
AttributeName               = [A-Za-z0-9_][A-Za-z0-9_-]*

AdmonitionType              = "NOTE"|"TIP"|"IMPORTANT"|"WARNING"|"CAUTION"

%state NEWLINE

%state BLOCK
%state LITERAL_PARAGRAPH
%state LIST_PARAGRAPH

%state LITERAL_BLOCK
%state PASSTHROUGH_BLOCK
%state SIDEBAR_BLOCK
%state EXAMPLE_BLOCK

%state LISTING_BLOCK
%state LISTING_FENCE_BLOCK
%state LISTING_PARAGRAPH
%state COMMENT_BLOCK

%state TABLE_BLOCK
%state TABLE_CELL

%state SKIP

%%

<YYINITIAL> {
    "---" {LineFeed} [^]* {LineFeed} "---" {LineFeed} {LineFeed}
    {
                // Skip front matter
            }

    \0
    {
            }

    [^]
    {
                yypushback(1);
                yybegin(NEWLINE);
            }
}

<NEWLINE> {
    {Whitespace}* {LineFeed}
    {
            }

    ":" {AttributeName} ":" {NoLineFeed}* {Whitespace}+ / "//"
    {
                String[] parts = yytext().split(":", 3);
                String value = trimAll(parts[2]);

                attributes.put(parts[1], value);
            }

    ":" {AttributeName} ":" ({NoLineFeed}* "\\" {LineFeed})* {NoLineFeed}* {LineFeed}
    {
                String[] parts = yytext().split(":", 3);
                String value = trimAll(parts[2]).replaceAll("\\\\(\\R)","\\1");

                attributes.put(parts[1], value);
            }

    "[[" {NoLineFeed}+ "]]" {LineFeed}
    {
                String id = extractBetween(yytext(), "[[", "]]");
                properties.put("id", id);
            }

    "[" {NoLineFeed}+ "'" {NoLineFeed}+ "']" {LineFeed} |
    "[" {NoLineFeed}+ "]" {LineFeed}
    {
                PropertiesParser.parse(strip(yytext(), 1, 2), properties);
                promoteArgumentsToClasses();
            }

    /* Blocks */
    "|" [=]{3,128} {Whitespace}* {LineFeed}
    {
                String titleHtml = properties.optString("title:html");
                String caption = properties.optString("caption");

                tableProperties = properties;
                openElement(AsciidocRenderer.TABLE_BLOCK);

                if (!titleHtml.isEmpty()) {
                    openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                            .attr("type", "Table")
                            .html(titleHtml);
                    closeElement(AsciidocRenderer.TITLE);
                }

                tableCellCounter = 0;
                yybegin(TABLE_BLOCK);
            }

    [/]{4,128} {LineFeed}
    {
                yybegin(COMMENT_BLOCK);
            }

    "//" .* {LineFeed}
    {
            }


    [*]{4,128} {LineFeed}
    {
                String titleHtml = properties.optString("title:html");
                String caption = properties.optString("caption");

                openElement(AsciidocRenderer.SIDEBAR_BLOCK);

                if (!titleHtml.isEmpty()) {
                    openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                            .html(titleHtml);
                    closeElement(AsciidocRenderer.TITLE);
                }
                yybegin(SIDEBAR_BLOCK);
            }

    [=]{4,128} {LineFeed}
    {
                String titleHtml = properties.optString("title:html");
                String caption = properties.optString("caption");

                String admonitionType = null;
                if (hasClass("NOTE")) admonitionType = "note";
                if (hasClass("TIP")) admonitionType = "tip";
                if (hasClass("IMPORTANT")) admonitionType = "important";
                if (hasClass("WARNING")) admonitionType = "warning";
                if (hasClass("CAUTION")) admonitionType = "caution";

                if (admonitionType != null) {
                    properties.getJSONObject("class").remove(admonitionType.toUpperCase());
                    openElement(AsciidocRenderer.ADMONITION_BLOCK).attr("subtype", admonitionType);
                } else {
                    openElement(AsciidocRenderer.EXAMPLE_BLOCK);

                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).attr("caption", caption).attr("type", "Example")
                                .html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }
                }

                yybegin(EXAMPLE_BLOCK);
            }

    [.]{4,128} {LineFeed}
    {
                openElement(AsciidocRenderer.LITERAL_BLOCK);
                yybegin(LITERAL_BLOCK);
            }

    [-]{4,128} {LineFeed}
    {
                String titleHtml = properties.optString("title:html");
                String caption = properties.optString("caption");

                openElement(AsciidocRenderer.LISTING_BLOCK);

                if (!titleHtml.isEmpty()) {
                    openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                            .html(titleHtml);
                    closeElement(AsciidocRenderer.TITLE);
                }

                yybegin(LISTING_BLOCK);
            }

    [`]{3,128} {LineFeed}
    {
                String titleHtml = properties.optString("title:html");
                String caption = properties.optString("caption");

                openElement(AsciidocRenderer.LISTING_BLOCK);

                if (!titleHtml.isEmpty()) {
                    openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                            .html(titleHtml);
                    closeElement(AsciidocRenderer.TITLE);
                }

                yybegin(LISTING_FENCE_BLOCK);
            }

    [+]{4,128} {LineFeed}
    {
                yybegin(PASSTHROUGH_BLOCK);
            }

    /* Headers */
    "." [^\s\t\f\n.] {NoLineFeed}* {LineFeed}
    {
                String title = trimAll(stripHead(yytext(), 1));
                String format = getFormatted(title).body().html();
                properties.put("title:html", format);
            }

    [=]{1,6} [^\f\n=] {Whitespace}* {NoLineFeed}+ {LineFeed}
    {
                yypushback(1);

                String id = properties.optString("id");

                String text = yytext();
                int level = 0;
                while (text.charAt(level) == '=') {
                    level++;
                }
                String title = trimAll(skipLeft(text, "= \t"));
                if (level > 0) {
                    closeElement(AsciidocRenderer.SECTION, level + 1);
                    closeElement(AsciidocRenderer.SECTION, level);
                    if (level > 1) {
                        closeElement(AsciidocRenderer.SECTION, 1);
                    }
                    JSONObject props = properties;
                    openElement(AsciidocRenderer.SECTION).attr("level", Integer.toString(level));
                    properties = props;
                }
                Document formattedTitle = getFormatted(title);
                String formattedTitleString = formattedTitle.body().html();

                if (!id.isEmpty()) {
                    attributes.put("anchor:" + id, formattedTitle.body().html());
                }

                openElement(AsciidocRenderer.HEADER).attr("level", Integer.toString(level));
                appendDocument(formattedTitle);
                closeElement(AsciidocRenderer.HEADER);

                if (level == 1) {
                    if ( !attributes.has("doctitle") ) {
                        attributes.put("doctitle", formattedTitleString);
                    }
                    yybegin(SKIP);
                }
            }

    /* Lists */
    {Whitespace}* [*]{1,5} {Whitespace} "[" [\sx*] "]" |
    {Whitespace}* [-]{1,5} {Whitespace} "[" [\sx*] "]"
    {
                String titleHtml = properties.optString("title:html");

                String text = trim(stripTail(yytext(), 3));
                int level = text.length();
                closeToElement(AsciidocRenderer.UL, level);
                JSONObject props = properties;
                if (currentElement == null
                        || !currentElement.tagName().equals(AsciidocRenderer.UL.tag())
                        || !currentElement.attr("level").equals(Integer.toString(level))) {
                    properties.put("%checklist", "true");
                    openElement(AsciidocRenderer.UL).attr("level", Integer.toString(level));
                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }
                }
                properties = props;
                openElement(AsciidocRenderer.LIST_ITEM).attr("level", Integer.toString(level));
                openElement(AsciidocRenderer.P);
                if (yytext().endsWith("[ ]")) {
                    appendText("\u274f");
                } else {
                    appendText("\u2713");
                }
                yybegin(LIST_PARAGRAPH);
            }

    {Whitespace}* [*]{1,5} {Whitespace} |
    {Whitespace}* [-]{1,5} {Whitespace}
    {
                String titleHtml = properties.optString("title:html");

                String text = trim(yytext());
                int level = text.length();
                closeToElement(AsciidocRenderer.UL, level);
                JSONObject props = properties;
                if (currentElement == null
                        || !currentElement.tagName().equals(AsciidocRenderer.UL.tag())
                        || !currentElement.attr("level").equals(Integer.toString(level))) {
                    openElement(AsciidocRenderer.UL).attr("level", Integer.toString(level));
                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }
                }
                properties = props;
                openElement(AsciidocRenderer.LIST_ITEM).attr("level", Integer.toString(level));
                openElement(AsciidocRenderer.P);
                yybegin(LIST_PARAGRAPH);
            }

    {Whitespace}* ([1-9][0-9]*)? [.]{1,5} {Whitespace}
    {
                String titleHtml = properties.optString("title:html");

                String text = trim(yytext());
                int level = text.replaceAll("[^.]", "").length();
                closeToElement(AsciidocRenderer.OL, level);
                JSONObject props = properties;
                if (currentElement == null
                        || !currentElement.tagName().equals(AsciidocRenderer.OL.tag())
                        || !currentElement.attr("level").equals(Integer.toString(level))) {
                    openElement(AsciidocRenderer.OL).attr("level", Integer.toString(level));
                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }
                }
                properties = props;
                openElement(AsciidocRenderer.LIST_ITEM).attr("level", Integer.toString(level));
                openElement(AsciidocRenderer.P);
                yybegin(LIST_PARAGRAPH);
            }

    {Whitespace}* [^\r\n\u2028\u2029\u000B\u000C\u0085\0:] {NoLineFeed}* [:]{2,5} {Whitespace} |
    {Whitespace}* [^\r\n\u2028\u2029\u000B\u000C\u0085\0:] {NoLineFeed}* [:]{2,5} {LineFeed}
    {
                String titleHtml = properties.optString("title:html");

                String text = trimAll(yytext());
                String term = extractBeforeStrict(text, "::");
                int level = text.length() - text.indexOf(':') - 1;
                closeToElement(AsciidocRenderer.DL, level);
                JSONObject props = properties;
                if (currentElement == null
                        || !currentElement.tagName().equals(AsciidocRenderer.DL.tag())
                        || !currentElement.attr("level").equals(Integer.toString(level))) {
                    openElement(AsciidocRenderer.DL).attr("level", Integer.toString(level));
                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }
                }
                properties = props;
                openElement(AsciidocRenderer.DT).attr("level", Integer.toString(level));
                appendFormatted(term);
                closeElement(AsciidocRenderer.DT);
                openElement(AsciidocRenderer.DD);
                openElement(AsciidocRenderer.P);
                yybegin(LIST_PARAGRAPH);

            }

    "<" [1-9][0-9]* ">" {Whitespace}
    {
                String titleHtml = properties.optString("title:html");

                closeToElement(AsciidocRenderer.COL);
                JSONObject props = properties;
                if (currentElement == null || !currentElement.tagName().equals(AsciidocRenderer.COL.tag())) {
                    openElement(AsciidocRenderer.COL);
                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }
                }
                properties = props;
                openElement(AsciidocRenderer.LIST_ITEM);
                openElement(AsciidocRenderer.P);
                yybegin(LIST_PARAGRAPH);
            }

    /* Misc formatting */
    [']{3,128} {LineFeed}
    {
                appendTextNode();
                appendElement("hr");
            }

    [<]{3,128} {LineFeed}
    {
                appendTextNode();
                appendElement("div").attr("style", "page-break-after: always;");
            }

    /* Special blocks */
    "image::" {NoLineFeed}+ {Properties}? {LineFeed}
    {
                String imgUrl = extractBetween(yytext(), "image::", "[");
                PropertiesParser.parse(extractBetween(yytext(), "[", "]"), properties);

                String alt = getArgument(0);
                if (alt.isEmpty()) alt = extractAfterStrict(extractBeforeStrict(imgUrl, "."), "/");
                String titleHtml = properties.optString("title:html");
                String title = properties.optString("title");
                String caption = properties.optString("caption");
                String link = properties.optString("link");

                JSONObject imageProperties = new JSONObject();
                if (properties.has("arguments")) {
                    imageProperties.put("arguments", properties.getJSONArray("arguments"));
                }

                openElement(AsciidocRenderer.IMAGE_BLOCK);
                Element root = currentElement;
                if (!link.isEmpty()) {
                    openElement("a").addClass("image").attr("href", link);
                }
                properties = imageProperties;
                openElement(AsciidocRenderer.IMAGE).attr("src", imgUrl).attr("alt", alt);
                if (!title.isEmpty()) {
                    currentElement.attr("title", title);
                }

                currentElement = root;
                if (!titleHtml.isEmpty()) {
                    openElement(AsciidocRenderer.TITLE).attr("type", "Figure")
                            .attr("caption", caption)
                            .html(titleHtml);
                }
                closeElement(AsciidocRenderer.IMAGE_BLOCK);
            }

    "video::" {NoLineFeed}+ {Properties}? {LineFeed}
    {
                String videoUrl = extractBetween(yytext(), "video::", "[");
                PropertiesParser.parse(extractBetween(yytext(), "[", "]"), properties);

                String titleHtml = properties.optString("title:html");
                String caption = properties.optString("caption");

                openElement(AsciidocRenderer.VIDEO_BLOCK).attr("src", videoUrl);

                if (!titleHtml.isEmpty()) {
                    openElement(AsciidocRenderer.TITLE).attr("type", "Video")
                            .attr("caption", caption)
                            .html(titleHtml);
                }

                closeElement(AsciidocRenderer.VIDEO_BLOCK);
            }

    {AdmonitionType} ":" {NoLineFeed}
    {
                String subType = extractBefore(yytext(), ":").toLowerCase();
                openElement(AsciidocRenderer.ADMONITION_BLOCK).attr("subtype", subType);
                yypushback(1);
                yybegin(BLOCK);
            }


    {Whitespace}+ {NoLineFeed}
    {
                openElement(AsciidocRenderer.LITERAL_BLOCK);
                yypushback(yytext().length());
                yybegin(LITERAL_PARAGRAPH);
            }

    [^]
    {
                String titleHtml = properties.optString("title:html");
                String caption = properties.optString("caption");

                String admonitionType = null;
                if (hasClass("NOTE")) admonitionType = "note";
                if (hasClass("TIP")) admonitionType = "tip";
                if (hasClass("IMPORTANT")) admonitionType = "important";
                if (hasClass("WARNING")) admonitionType = "warning";
                if (hasClass("CAUTION")) admonitionType = "caution";

                if (admonitionType != null) {
                    properties.getJSONObject("class").remove(admonitionType.toUpperCase());
                    openElement(AsciidocRenderer.ADMONITION_BLOCK).attr("subtype", admonitionType);
                    yypushback(1);
                    yybegin(BLOCK);
                } else if (getArgument(0).equals("source")) {
                    yypushback(1);
                    openElement(AsciidocRenderer.LISTING_BLOCK);

                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                                .html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }

                    yybegin(LISTING_PARAGRAPH);
                } else {
                    openElement(AsciidocRenderer.PARAGRAPH_BLOCK);

                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                                .html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }

                    yypushback(1);
                    yybegin(BLOCK);
                }
            }
}

<BLOCK> {
    {Whitespace}* {LineFeed}
    {
                appendFormatted();
                closeBlockElement();
                yybegin(NEWLINE);
            }

    "//" {NoLineFeed}+ {LineFeed}
    {
            }

    {NoLineFeed}+ {LineFeed}
    {
                appendText(yytext());
            }

    <<EOF>>
    {
                appendFormatted();
                return null;
            }
}

<LITERAL_PARAGRAPH> {
    {LineFeed}
    {
                if (!getText().isEmpty()) {
                    appendTextNode();
                    closeBlockElement();
                } else {
                    Element block = currentElement;
                    currentElement = currentElement.parent();
                    block.remove();
                }
                yybegin(NEWLINE);
            }

    {NoLineFeed}+ {LineFeed}
    {
                if (!getText().isEmpty()) {
                    appendText("\n");
                }
                appendText(trimLeft(stripTail(yytext(), 1)));
            }
}

<LIST_PARAGRAPH> {
    {LineFeed}? {Whitespace}* [*]{1,5} {Whitespace} {NoLineFeed}+ {LineFeed} |
    {LineFeed}? {Whitespace}* [-]{1,5} {Whitespace} {NoLineFeed}+ {LineFeed} |
    {LineFeed}? {Whitespace}* ([1-9][0-9]*)? [.]{1,5} {Whitespace} {NoLineFeed}+ {LineFeed} |
    {LineFeed}? {Whitespace}* {NoLineFeed}+ [:]{2,5} {Whitespace} {NoLineFeed}+ {LineFeed} |
    {LineFeed}? {Whitespace}* {NoLineFeed}+ [:]{2,5} {LineFeed} |
    {LineFeed}? "<" [1-9][0-9]* ">" {Whitespace} {NoLineFeed}+ {LineFeed} |
    {LineFeed}? ":" {AttributeName} ":"
    {
                yypushback(yytext().length());
                appendFormatted();
                Element parent = currentElement.parent();
                if (currentElement.tagName().equals(AsciidocRenderer.P.tag()) && currentElement.text().isEmpty()) {
                    currentElement.remove();
                }
                currentElement = parent;
                yybegin(NEWLINE);
            }

    {LineFeed}
    {
                appendFormatted();
                closeElementTop(AsciidocRenderer.UL, AsciidocRenderer.OL, AsciidocRenderer.COL);
                yybegin(NEWLINE);
            }

    "//" {NoLineFeed}+ {LineFeed}
    {
            }

    {NoLineFeed}+ {LineFeed}
    {
                if (!getText().isEmpty()) {
                    appendText("\n");
                }
                appendText(trimLeft(stripTail(yytext(), 1)));
            }

    <<EOF>>
    {
                appendFormatted();
                return null;
            }
}

<SKIP> {
    {LineFeed} ":"
    {
                yypushback(1);
                yybegin(NEWLINE);
            }

    {LineFeed} {LineFeed}
    {
                yybegin(NEWLINE);
            }

    [^]
    {
            }
}

<LITERAL_BLOCK> {
    {Whitespace}* {LineFeed}* [.]{4,128} {LineFeed}
    {
                appendTextNode();
                closeBlockElement();
                yybegin(NEWLINE);
            }

    {NoLineFeed}* {LineFeed}
    {
                if (!getText().isEmpty()) {
                    appendText("\n");
                }
                appendText(stripTail(yytext(), 1));
            }
}

<LISTING_BLOCK> {
    {Whitespace}* {LineFeed}* [-]{4,128} {Whitespace}* {LineFeed}
    {
                appendTextNode();
                closeBlockElement();
                yybegin(NEWLINE);
            }
}

<LISTING_FENCE_BLOCK> {
    {Whitespace}* {LineFeed}* [`]{3,128} {Whitespace}* {LineFeed}
    {
                appendTextNode();
                closeBlockElement();
                yybegin(NEWLINE);
            }
}

<LISTING_PARAGRAPH> {
    {Whitespace}* {LineFeed} {LineFeed}
        {
                appendTextNode();
                closeBlockElement();
                yybegin(NEWLINE);
            }
}

<LISTING_BLOCK, LISTING_PARAGRAPH, LISTING_FENCE_BLOCK> {
    "//" {Whitespace}* "<" [1-9][0-9+]* ">" {Whitespace}* {LineFeed} |
    "#" {Whitespace}* "<" [1-9][0-9+]* ">" {Whitespace}* {LineFeed} |
    ";;" {Whitespace}* "<" [1-9][0-9+]* ">" {Whitespace}* {LineFeed}
    {
                // Asciidoctor 1.5.8+
                appendText(extractBeforeStrict(yytext(), "<"));
                // End of Asciidoctor 1.5.8+
                openElement("b").addClass("conum").text(String.format("(%s)", extractBetween(yytext(), "<", ">")));
                closeElement("b");
                yypushback(1);
            }

    "<" [1-9][0-9+]* ">" {Whitespace}* {LineFeed}
    {
                openElement("b").addClass("conum").text(String.format("(%s)", extractBetween(yytext(), "<", ">")));
                closeElement("b");
                yypushback(1);
            }

    "<!--" [1-9][0-9]* "-->" {Whitespace}* {LineFeed}
    {
                openElement("b").addClass("conum").text(String.format("(%s)", extractBetween(yytext(), "<!--", "-->")));
                closeElement("b");
                yypushback(1);
            }

    {Whitespace}* {LineFeed}
    {
                appendText("\n");
            }

    [^]
    {
                appendText(yytext());
            }
}

<PASSTHROUGH_BLOCK> {
    {Whitespace}* {LineFeed}* [+]{4,128} {LineFeed}
    {
                currentElement.append(getTextAndClear());
                yybegin(NEWLINE);
            }

    {NoLineFeed}* {LineFeed}
    {
                appendText(yytext());
            }
}

<SIDEBAR_BLOCK> {
    {Whitespace}* {LineFeed}* [*]{4,128} {LineFeed}
    {
                appendSubdocument(getTextAndClear());
                closeBlockElement();
                yybegin(NEWLINE);
            }

    {NoLineFeed}* {LineFeed}
    {
                appendText(yytext());
            }
}

<EXAMPLE_BLOCK> {
    {Whitespace}* {LineFeed}* [=]{4,128} {LineFeed}
    {
                appendSubdocument(getTextAndClear());
                closeBlockElement();
                yybegin(NEWLINE);
            }

    {NoLineFeed}* {LineFeed}
    {
                appendText(yytext());
            }
}

<COMMENT_BLOCK> {
    {Whitespace}* {LineFeed}* [/]{4,128} {LineFeed}
    {
                yybegin(NEWLINE);
            }

    .* {LineFeed}
    {
            }
}

<TABLE_BLOCK> {
    "|" [=]{3,128} {Whitespace}* {LineFeed}
    {
                closeElement(AsciidocRenderer.TABLE_BLOCK);
                yybegin(NEWLINE);
            }

    {LineFeed} {Whitespace}* {LineFeed}
    {
                if (!tableProperties.has("firstRowCellCount") && tableCellCounter > 0) {
                    tableProperties.put("firstRowCellCount", tableCellCounter);
                }

                if (!tableProperties.has("headerCellCount") && tableCellCounter > 0) {
                    tableProperties.put("headerCellCount", tableCellCounter);
                }
            }

    "|" [=]{0,2}[^=|] |
    "|"
    {
                tableCellCounter++;
                openElement(AsciidocRenderer.TABLE_CELL);
                yypushback(yytext().length() - 1);
                yybegin(TABLE_CELL);
            }

    {LineFeed}
    {
                if (!tableProperties.has("firstRowCellCount") && tableCellCounter > 0) {
                    tableProperties.put("firstRowCellCount", tableCellCounter);
                }
            }

    [^]
    {
            }
}

<TABLE_CELL> {
    "|" |
    {LineFeed} "|" |
    {LineFeed} {Whitespace}* {LineFeed} "|"
    {
                appendSubdocument(getTextAndClear());
                closeElement(AsciidocRenderer.TABLE_CELL);
                yypushback(yytext().length());
                yybegin(TABLE_BLOCK);
            }

    [^]
    {
                appendText(yytext());
            }
}