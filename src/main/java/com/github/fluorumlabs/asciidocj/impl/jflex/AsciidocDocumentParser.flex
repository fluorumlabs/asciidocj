package com.github.fluorumlabs.asciidocj.impl.jflex;

import com.github.fluorumlabs.asciidocj.impl.AsciidocBase;
import com.github.fluorumlabs.asciidocj.impl.AsciidocRenderer;
import com.github.fluorumlabs.asciidocj.impl.ParserException;
import org.apache.commons.lang3.StringUtils;import org.json.JSONObject;
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

PropertiesBare              = "[" ("\\]"|[^\]\r\n\u2028\u2029\u000B\u000C\u0085\0])* "]"
Properties                  = {PropertiesBare} {Whitespace}*
AttributeName               = [A-Za-z0-9_][A-Za-z0-9_-]*

AdmonitionType              = "NOTE"|"TIP"|"IMPORTANT"|"WARNING"|"CAUTION"

%state NEWLINE

%state BLOCK
%state LITERAL_PARAGRAPH
%state LIST_PARAGRAPH

%state OPEN_BLOCK
%state LITERAL_BLOCK
%state PASSTHROUGH_BLOCK
%state SIDEBAR_BLOCK
%state EXAMPLE_BLOCK

%state LISTING_BLOCK
%state LISTING_FENCE_BLOCK
%state LISTING_PARAGRAPH
%state COMMENT_BLOCK
%state QUOTE_BLOCK
%state VERSE_BLOCK
%state VERSE_PARAGRAPH
%state AIR_QUOTE_BLOCK

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

    ":!" {AttributeName} ":" {Whitespace}* {LineFeed} |
    ":" {AttributeName} "!:" {Whitespace}* {LineFeed}
    {
                String[] parts = yytext().replace("!","").split(":", 3);
                String value = trimAll(parts[2]);

                attributes.remove(parts[1]);
                attributes.put(parts[1]+"!","");
            }

    ":" {AttributeName} ":" {NoLineFeed}* {Whitespace}+ / "//"
    {
                String[] parts = yytext().split(":", 3);
                String value = trimAll(parts[2]);

                attributes.put(parts[1], value);
                attributes.remove(parts[1]+"!");
            }

    ":" {AttributeName} ":" ({NoLineFeed}* "\\" {LineFeed})* {NoLineFeed}* {LineFeed}
    {
                String[] parts = yytext().split(":", 3);
                String value = trimAll(parts[2]).replaceAll("\\\\(\\R)","\\1");

                attributes.put(parts[1], value);
                attributes.remove(parts[1]+"!");
            }

    "[[" {NoLineFeed}+ "]]" {LineFeed}
    {
                String[] id = extractBetween(yytext(), "[[", "]]").split(",",2);
                if ( id.length>0 ) properties.put("id", id[0]);
                if ( id.length>1 ) properties.put("reftext", getFormatted(id[1]).body().html());
            }

    "[" {NoLineFeed}+ "'" {NoLineFeed}+ "']" {LineFeed} |
    "[" {NoLineFeed}+ "]" {LineFeed}
    {
                PropertiesParser.parse(strip(yytext(), 1, 2), properties, true);
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
                    openElement(AsciidocRenderer.ADMONITION_BLOCK)
                        .attr("subtype", admonitionType)
                        .attr("text", getFormatted(attributes.optString(admonitionType+"-caption",StringUtils.capitalize(admonitionType))).body().html());

                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                                .html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }
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

    "--" {LineFeed}
    {
                String titleHtml = properties.optString("title:html");
                String caption = properties.optString("caption");

                if ( hasClass("abstract") ) {
                    openElement(AsciidocRenderer.QUOTE_BLOCK);
                }

                if (!titleHtml.isEmpty()) {
                    openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                            .html(titleHtml);
                    closeElement(AsciidocRenderer.TITLE);
                }

                yybegin(OPEN_BLOCK);
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

    [_]{4,128} {LineFeed}
    {
                String titleHtml = properties.optString("title:html");
                String caption = properties.optString("caption");

                if ( getArgument(0).equals("quote") || getArgument(0).equals("verse")) {
                    properties.put("quote:attribution", getFormatted(getArgument(1)).body().html());
                    properties.put("quote:cite", getFormatted(getArgument(2)).body().html());
                }

                boolean isVerse = getArgument(0).equals("verse");
                if ( isVerse ) {
                    properties.put("verse%","");
                }

                openElement(AsciidocRenderer.QUOTE_BLOCK);

                if (!titleHtml.isEmpty()) {
                    openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                            .html(titleHtml);
                    closeElement(AsciidocRenderer.TITLE);
                }

                if ( isVerse ) {
                    yybegin(VERSE_BLOCK);
                } else {
                    yybegin(QUOTE_BLOCK);
                }
            }

    "\"\"" {LineFeed}
    {
                String titleHtml = properties.optString("title:html");
                String caption = properties.optString("caption");

                properties.put("quote:attribution", getFormatted(getArgument(1)).body().html());
                properties.put("quote:cite", getFormatted(getArgument(2)).body().html());

                openElement(AsciidocRenderer.QUOTE_BLOCK);

                if (!titleHtml.isEmpty()) {
                    openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                            .html(titleHtml);
                    closeElement(AsciidocRenderer.TITLE);
                }

                yybegin(AIR_QUOTE_BLOCK);
            }

    "\"" ({NoLineFeed}+ {LineFeed})* {NoLineFeed}+ "\"" {LineFeed} "-- " {NoLineFeed}+ {LineFeed}
    {
        // Quoted paragraph -_-
        String text = stripTail(yytext(),1);
        String cite = extractAfterStrict(text,"-- ");
        text = strip(text, 1, cite.length()+5); // including double quotes, line feed and "-- "
        String[] attribution = cite.split(",",2);

        String titleHtml = properties.optString("title:html");
        String caption = properties.optString("caption");

        if ( attribution.length > 0 ) properties.put("quote:attribution", getFormatted(attribution[0].trim()).body().html());
        if ( attribution.length > 1 ) properties.put("quote:cite", getFormatted(attribution[1].trim()).body().html());

        openElement(AsciidocRenderer.QUOTE_BLOCK);

        if (!titleHtml.isEmpty()) {
            openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                    .html(titleHtml);
            closeElement(AsciidocRenderer.TITLE);
        }

        appendFormatted(text);

        closeElement(AsciidocRenderer.QUOTE_BLOCK);
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
                String formattedReferenceString = getFormatted(properties.optString("reftext",title)).body().html();

                // Process sectnums
                int sectNumDepth = attributes.optInt("sectnumlevels",6)+2;
                boolean sectNums = attributes.has("sectnums") || hasClass("appendix");
                String attribute = hasClass("appendix")?"sectnum-appx":"sectnum";

                StringBuilder num = new StringBuilder();

                attributes.put(attribute+":"+Integer.toString(level), attributes.optInt(attribute+":"+Integer.toString(level), 0)+(sectNums?1:0));
                if ( hasClass("appendix") ) {
                    attributes.put("sectnum-type:"+Integer.toString(level),"Appendix");
                }
                if ( sectNums ) {
                    for ( int i = level+1; i<6; i++) {
                        attributes.remove("sectnum:"+Integer.toString(i));
                        attributes.remove("sectnum-appx:"+Integer.toString(i));
                        attributes.remove("sectnum-type:"+Integer.toString(i));
                    }
                    boolean first = true;
                    if ( level < sectNumDepth ) {
                        for ( int i = 2; i <= level; i++ ) {
                            String key = Integer.toString(i);
                            int n = attributes.optInt(attribute+":"+key, 0);
                            if ( !first ) {
                                num.append(".");
                            }
                            if ( n > 0 && n < 26 && attributes.optString("sectnum-type:"+key).equals("Appendix")) {
                                num.append((char)('A'+n-1));
                                first = false;
                            } else if ( n > 0 ) {
                                num.append(Integer.toString(n));
                                first = false;
                            } else if ( attributes.has(attribute+":"+key)) {
                                first = false;
                            }
                        }
                    }
                }

                if ( id.isEmpty() && level > 1 && !attributes.has("sectids!")) {
                    id = attributes.optString("idprefix","_") + AsciidocRenderer.slugify(formattedTitle.text()).replace("_",attributes.optString("idseparator","_"));
                    properties.put("id", id);
                }

                if (!id.isEmpty()) {
                    attributes.put("anchor:" + id, formattedReferenceString);
                    if ( sectNums && level > 1 && !properties.has("reftext") && !hasClass("appendix")) {
                        attributes.put(attribute+":"+id, "Section " + num.toString());
                    } else if ( hasClass("appendix") && level == 2 && !properties.has("reftext")) {
                        attributes.put(attribute+":"+id, attributes.optString("appendix-caption","Appendix") + " " + num.toString());
                    }
                }

                openElement(AsciidocRenderer.HEADER).attr("level", Integer.toString(level)).attr("sectNum", num.toString());
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
    {Whitespace}* "*" {Whitespace}+ "[[" {PropertiesBare} "]]" |
    {Whitespace}* "-" {Whitespace}+ "[[" {PropertiesBare} "]]"
    {
                String titleHtml = properties.optString("title:html");

                String id = "";
                String text = "";
                String[] data = extractBetween(yytext(), "[[[", "]]]").split(",",2);
                if ( data.length>0 ) id = data[0].trim();
                if ( data.length>1 ) {
                    text = data[1].trim();
                } else {
                    text = id;
                }

                int level = 1;
                closeToElement(AsciidocRenderer.UL, level);
                JSONObject props = properties;
                if (currentElement == null
                        || !currentElement.tagName().equals(AsciidocRenderer.UL.tag())
                        || !currentElement.attr("level").equals(Integer.toString(level))) {
                    properties.put("%bibliography", "true");
                    openElement(AsciidocRenderer.UL).attr("level", Integer.toString(level));
                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }
                }
                properties = props;
                openElement(AsciidocRenderer.LIST_ITEM).attr("level", Integer.toString(level));
                openElement(AsciidocRenderer.P);
                openElement(AsciidocRenderer.LINK).attr("id", id);
                closeElement(AsciidocRenderer.LINK);

                if (!text.isEmpty()) {
                    attributes.put("anchor:" + id, "["+text+"]");
                    appendText("["+text+"] ");
                    appendTextNode();
                }

                yybegin(LIST_PARAGRAPH);
            }

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

                if (!imgUrl.startsWith("http://") && !imgUrl.startsWith("https://")) {
                    String path = attributes.optString("imagesdir", DEFAULT_IMAGESDIR);
                    if (!path.endsWith("/")) path = path.concat("/");
                   imgUrl = path.concat(imgUrl);
                }

                PropertiesParser.parse(extractBetween(yytext(), "[", "]"), properties, false);

                String alt = properties.optString("alt", getArgument(0));
                if (alt.isEmpty()) alt = extractAfterStrict(extractBeforeStrict(imgUrl, "."), "/");
                String titleHtml = properties.optString("title:html");
                String title = properties.optString("title");
                String caption = properties.optString("caption");
                String link = properties.optString("link");

                JSONObject imageProperties = new JSONObject();
                if (properties.has("arguments")) {
                    imageProperties.put("arguments", properties.getJSONArray("arguments"));
                }
                if (properties.has("width")) {
                    imageProperties.put("width", properties.get("width"));
                }
                if (properties.has("height")) {
                    imageProperties.put("height", properties.get("height"));
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

                PropertiesParser.parse(extractBetween(yytext(), "[", "]"), properties, false);

                if (!videoUrl.startsWith("http://") && !videoUrl.startsWith("https://")
                    && !getArgument(0).equals("youtube") && !getArgument(0).equals("vimeo")) {
                    String path = attributes.optString("imagesdir", DEFAULT_IMAGESDIR);
                    if (!path.endsWith("/")) path = path.concat("/");
                   videoUrl = path.concat(videoUrl);
                }

                String titleHtml = properties.optString("title:html");
                String caption = properties.optString("caption");

                openElement(AsciidocRenderer.VIDEO_BLOCK).attr("src", videoUrl);

                if (!titleHtml.isEmpty()) {
                    openElement(AsciidocRenderer.TITLE)
                            .attr("caption", caption)
                            .html(titleHtml);
                }

                closeElement(AsciidocRenderer.VIDEO_BLOCK);
            }

    "audio::" {NoLineFeed}+ {Properties}? {LineFeed}
    {
                String audioUrl = extractBetween(yytext(), "audio::", "[");

                PropertiesParser.parse(extractBetween(yytext(), "[", "]"), properties, false);

                if (!audioUrl.startsWith("http://") && !audioUrl.startsWith("https://")) {
                    String path = attributes.optString("imagesdir", DEFAULT_IMAGESDIR);
                    if (!path.endsWith("/")) path = path.concat("/");
                   audioUrl = path.concat(audioUrl);
                }

                String titleHtml = properties.optString("title:html");
                String caption = properties.optString("caption");

                openElement(AsciidocRenderer.AUDIO_BLOCK).attr("src", audioUrl);

                if (!titleHtml.isEmpty()) {
                    openElement(AsciidocRenderer.TITLE)
                            .attr("caption", caption)
                            .html(titleHtml);
                }

                closeElement(AsciidocRenderer.AUDIO_BLOCK);
            }

    "toc::" {Properties}? {LineFeed}
    {
        openElement(AsciidocRenderer.TOC);
        closeElement(AsciidocRenderer.TOC);
    }

    {AdmonitionType} ":" {NoLineFeed}
    {
                    String subType = extractBefore(yytext(), ":").toLowerCase();
                    openElement(AsciidocRenderer.ADMONITION_BLOCK)
                        .attr("subtype", subType)
                        .attr("text", getFormatted(attributes.optString(subType+"-caption",StringUtils.capitalize(subType))).body().html());
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
                    openElement(AsciidocRenderer.ADMONITION_BLOCK)
                        .attr("subtype", admonitionType)
                        .attr("text", getFormatted(attributes.optString(admonitionType+"-caption",StringUtils.capitalize(admonitionType))).body().html());

                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                                .html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }

                    yypushback(1);
                    yybegin(BLOCK);
                } else if (getArgument(0).equals("source") || getArgument(0).equals("listing")) {
                    yypushback(1);
                    openElement(AsciidocRenderer.LISTING_BLOCK);

                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                                .html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }

                    yybegin(LISTING_PARAGRAPH);
                } else if (getArgument(0).equals("quote") || getArgument(0).equals("verse")) {
                    yypushback(1);
                    properties.put("quote:attribution", getFormatted(getArgument(1)).body().html());
                    properties.put("quote:cite", getFormatted(getArgument(2)).body().html());
                    boolean isVerse = getArgument(0).equals("verse");
                    if ( isVerse ) {
                        properties.put("verse%","");
                    }
                    openElement(AsciidocRenderer.QUOTE_BLOCK);

                    if (!titleHtml.isEmpty()) {
                        openElement(AsciidocRenderer.TITLE).attr("caption", caption)
                                .html(titleHtml);
                        closeElement(AsciidocRenderer.TITLE);
                    }

                    if ( isVerse ) {
                        yybegin(VERSE_PARAGRAPH);
                    } else {
                        yybegin(BLOCK);
                    }
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

<LIST_PARAGRAPH, BLOCK, VERSE_PARAGRAPH> {
    {LineFeed}? {Whitespace}* [*]{1,5} {Whitespace} {NoLineFeed}+ {LineFeed} |
    {LineFeed}? {Whitespace}* [-]{1,5} {Whitespace} {NoLineFeed}+ {LineFeed} |
    {LineFeed}? {Whitespace}* ([1-9][0-9]*)? [.]{1,5} {Whitespace} {NoLineFeed}+ {LineFeed} |
    {LineFeed}? {Whitespace}* {NoLineFeed}+ [:]{2,5} {Whitespace} {NoLineFeed}+ {LineFeed} |
    {LineFeed}? {Whitespace}* {NoLineFeed}+ [:]{2,5} {LineFeed} |
    {LineFeed}? "<" [1-9][0-9]* ">" {Whitespace} {NoLineFeed}+ {LineFeed} |
    {LineFeed}? ":" {AttributeName} ":" |
    {LineFeed}? ":!" {AttributeName} ":" |
    {LineFeed}? ":" {AttributeName} "!:" |
    {LineFeed}? {Properties} {LineFeed}
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

<QUOTE_BLOCK> {
    {Whitespace}* {LineFeed}* [_]{4,128} {LineFeed}
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

<VERSE_BLOCK> {
    {Whitespace}* {LineFeed}* [_]{4,128} {LineFeed}
    {
                closeBlockElement();
                yybegin(NEWLINE);
            }

    "//" {NoLineFeed}+ {LineFeed}
    {
            }

    {NoLineFeed}* {LineFeed}
    {
                appendFormatted(stripTail(yytext(),1));
                appendText(yytext().substring(yytext().length()-1));
                appendTextNode();
            }
}

<VERSE_PARAGRAPH> {
    {LineFeed}
    {
                closeBlockElement();
                yybegin(NEWLINE);
            }

    "//" {NoLineFeed}+ {LineFeed}
    {
            }

    {NoLineFeed}+ {LineFeed}
    {
                appendFormatted(stripTail(yytext(),1));
                appendText(yytext().substring(yytext().length()-1));
                appendTextNode();
            }
}

<AIR_QUOTE_BLOCK> {
    {Whitespace}* {LineFeed}* "\"\"" {LineFeed}
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
    "//" {Whitespace}* "<" [1-9][0-9+]* ">" |
    "#" {Whitespace}* "<" [1-9][0-9+]* ">" |
    ";;" {Whitespace}* "<" [1-9][0-9+]* ">"
    {
                // Asciidoctor 1.5.8+
                appendText(extractBeforeStrict(yytext(), "<"));
                // End of Asciidoctor 1.5.8+
                openElement("b").addClass("conum").text(String.format("(%s)", extractBetween(yytext(), "<", ">")));
                closeElement("b");
            }

    "<" [1-9][0-9+]* ">"
    {
                openElement("b").addClass("conum").text(String.format("(%s)", extractBetween(yytext(), "<", ">")));
                closeElement("b");
            }

    "<!--" [1-9][0-9]* "-->"
    {
                openElement("b").addClass("conum").text(String.format("(%s)", extractBetween(yytext(), "<!--", "-->")));
                closeElement("b");
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

<OPEN_BLOCK> {
    {Whitespace}* {LineFeed}* "--" {LineFeed}
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
