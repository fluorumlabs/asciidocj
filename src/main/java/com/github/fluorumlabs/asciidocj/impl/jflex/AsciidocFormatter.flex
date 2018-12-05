package com.github.fluorumlabs.asciidocj.impl.jflex;

import com.github.fluorumlabs.asciidocj.impl.AsciidocBase;
import com.github.fluorumlabs.asciidocj.impl.AsciidocRenderer;
import com.github.fluorumlabs.asciidocj.impl.ParserException;
import org.json.JSONObject;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Entities;

import java.io.IOException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static com.github.fluorumlabs.asciidocj.impl.Utils.*;

/**
 * Asciidoc specification
 * - https://asciidoctor.org/docs/asciidoc-syntax-quick-reference/
 * <p>
 * Parser produces Jsoup Document
 */
%%

%class AsciidocFormatter
%public
%extends AsciidocBase
%function parseInput
%apiprivate
%unicode
%scanerror ParserException

%{
    public AsciidocFormatter() {
    }

    /**
     * Parse the Asciidoc paragraph/block and return a resulting Document
     *
     * @param text       Asciidoc
     * @param properties Properties
     * @param attributes Attributes
     * @return JSoup Document
     * @throws ParserException if there was an unrecoverable error
     */
    public Document parse(String text, JSONObject properties, JSONObject attributes) throws ParserException {
        this.properties = properties;
        this.attributes = attributes;
        document = Document.createShell("");
        document.outputSettings().prettyPrint(false);
        currentElement = document.body();
        textBuilder.setLength(0);

        try {
            yyreset(getReader(text, false));
            parseInput();
            appendTextNode(); // If needed
            return document;
        } catch (IOException e) {
            throw new ParserException(e);
        }
    }

    private AsciidocFormatter formatter;

    private Document getFormatted(String text) throws ParserException {
        if (formatter == null) formatter = new AsciidocFormatter();
        return formatter.parse(text, properties, attributes);
    }

    private void appendFormatted(String text) throws ParserException {
        if (formatter == null) formatter = new AsciidocFormatter();
        appendDocument(formatter.parse(text, properties, attributes));
    }

    private static final String QUOTED_EXTRACT_REGEXP = "^[\1](.*?[\\S\1])[\1]([^\1\\w]|$)";

    private String extractQuoted(String x, char marker) {
        String pattern = QUOTED_EXTRACT_REGEXP.replace('\1', marker);
        Matcher matcher = Pattern.compile(pattern).matcher(x);
        if (!matcher.find()) {
            return "";
        } else {
            return matcher.group(1);
        }
    }

    private static final String QUOTED_UNCONSTRAINED_CODE_EXTRACT_REGEXP = "^``(.+?)``(`\"|`'|[^`]|$)";

    private String extractUnconstrainedCode(String x) {
        Matcher matcher = Pattern.compile(QUOTED_UNCONSTRAINED_CODE_EXTRACT_REGEXP).matcher(x);
        if (!matcher.find()) {
            return "";
        } else {
            return matcher.group(1);
        }
    }
%}

LineFeed                    = \R | \0
Whitespace					= " "|"\t"
NoWhitespace			    = [^\s]

EmailAddress                = [a-zA-Z0-9.!#$%&'*+/=?\^_`{|}~\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,128}
URLDomainPart               = "www."? [-a-zA-Z0-9@:%._\+~#=]{2,256} "." [a-z]{2,128}
URLDomainPartWithLocalhost  = {URLDomainPart} | "localhost"
URL                         = "http" [s]? "://" {URLDomainPartWithLocalhost} [-a-zA-Z0-9@:%_\+.,~#?!&//()=*]*

NoLineFeed                  = [^\r\n\u2028\u2029\u000B\u000C\u0085\0]

AttributeName               = [A-Za-z0-9_][A-Za-z0-9_-]*
Properties                  = "[" ~ "]"

%state INSIDE_WORD

%%

<YYINITIAL> {
    "*" [^\s*] .*
    {
                String text = yytext();
                String toFormat = extractQuoted(text, '*');
                if (toFormat.isEmpty()) {
                    appendText("*");
                    yypushback(yytext().length() - 1);
                } else {
                    openElement("strong");
                    appendFormatted(toFormat);
                    closeElement("strong");
                    yypushback(text.length() - toFormat.length() - 2);
                    yybegin(INSIDE_WORD);
                }
            }

    "_" [^\s_] .*
    {
                String text = yytext();
                String toFormat = extractQuoted(text, '_');
                if (toFormat.isEmpty()) {
                    appendText("_");
                    yypushback(yytext().length() - 1);
                } else {
                    openElement("em");
                    appendFormatted(toFormat);
                    closeElement("em");
                    yypushback(text.length() - toFormat.length() - 2);
                    yybegin(INSIDE_WORD);
                }
            }

    "#" [^\s#] .*
    {
                String text = yytext();
                String toFormat = extractQuoted(text, '#');
                if (toFormat.isEmpty()) {
                    appendText("#");
                    yypushback(yytext().length() - 1);
                } else {
                    openElement("mark");
                    appendFormatted(toFormat);
                    closeElement("mark");
                    yypushback(text.length() - toFormat.length() - 2);
                    yybegin(INSIDE_WORD);
                }
            }

    "+" [^\s+] .*
    {
                String text = yytext();
                String toFormat = extractQuoted(text, '+');
                if (toFormat.isEmpty()) {
                    appendText("+");
                    yypushback(yytext().length() - 1);
                } else {
                    appendText(toFormat);
                    yypushback(text.length() - toFormat.length() - 2);
                    yybegin(INSIDE_WORD);
                }
            }

    "`" [^\s`] .*
    {
                String text = yytext();
                String toFormat = extractQuoted(text, '`');
                if (toFormat.isEmpty()) {
                    appendText("`");
                    yypushback(yytext().length() - 1);
                } else {
                    openElement("code");
                    appendFormatted(toFormat);
                    closeElement("code");
                    yypushback(text.length() - toFormat.length() - 2);
                    yybegin(INSIDE_WORD);
                }
            }

}

<YYINITIAL, INSIDE_WORD> {
    /* Newlines */
    {Whitespace} "+" {Whitespace}* {LineFeed}
    {
                appendElement("br");
                appendText("\n");
                yybegin(YYINITIAL);
            }

    {LineFeed}
    {
                if (hasOption("hardbreaks") && !yytext().equals("\0")) {
                    appendElement("br");
                }
                appendText("\n");
                yybegin(YYINITIAL);
            }

    /* Vars */
    "{" {AttributeName} "}"
    {
                String id = strip(yytext(), 1, 1);
                if (attributes.has(id)) {
                    appendText(attributes.getString(id));
                } else {
                    String value = getReplacement(id);
                    appendText(value==null?yytext():value);
                }
            }

   "[" [^\[][^\]]+ "]"
    {
                String text = strip(yytext(), 1, 1);
                PropertiesParser.parse(text, properties);
                if (!properties.has("class")) {
                    properties.put("class", new JSONObject());
                }
                JSONObject classes = properties.getJSONObject("class");
                if (!getArgument(0).isEmpty()) {
                    for (String className : getArgument(0).split(" ")) {
                        classes.put(className, "");
                    }
                }
            }

    "pass:c[" [^\]]+ "]"
    {
          appendText(extractBetween(yytext(), "[", "]"));
      }

   "[[" {NoLineFeed}+ "]]" |
   "anchor:" [^\[][^\]]+ {Properties}?
    {
                JSONObject anchorOptions = new JSONObject();
                String id;
                String text;
                if (yytext().startsWith("anchor:")) {
                    id = extractBetween(yytext(), "anchor:", "[");
                    PropertiesParser.parse(extractBetween(yytext(), "[", "]"), anchorOptions);
                    text = getArgument(anchorOptions, 0);
                } else {
                    PropertiesParser.parse(strip(yytext(), 2, 2), anchorOptions);

                    id = getArgument(anchorOptions, 0);
                    text = getArgument(anchorOptions, 1);
                }
                if (!text.isEmpty()) {
                    attributes.put("anchor:" + id, getFormatted(text).body().html());
                }
                openElement(AsciidocRenderer.LINK).attr("id", id);
                closeElement(AsciidocRenderer.LINK);
                yybegin(YYINITIAL);
            }

    "<<" {NoLineFeed}+ ">>"
    {
                JSONObject anchorOptions = new JSONObject();
                PropertiesParser.parse(strip(yytext(), 2, 2), anchorOptions);

                String id = getArgument(anchorOptions, 0);
                String text = getArgument(anchorOptions, 1);

                properties.put("to-id", id);
                if (!text.isEmpty()) {
                    properties.put("to-id-contents", getFormatted(text).body().html());
                }
                openElement(AsciidocRenderer.LINK);
                closeElement(AsciidocRenderer.LINK);
                yybegin(YYINITIAL);
            }

    /* Inline blocks */
    "link:++" {NoLineFeed}* "++" {Properties}?
    {
                String content = yytext();
                String text = extractBetween(extractAfterStrict(content, "++"), "[", "]");
                String href = extractBetween(content, "++", "++");
                PropertiesParser.parse(text, properties);
                String title = getArgument(0);
                if (title.endsWith("^")) {
                    title = stripTail(title, 1);
                    properties.put("window", "_blank");
                }
                openElement(AsciidocRenderer.LINK).attr("href", href);
                if (!title.isEmpty()) {
                    appendFormatted(title);
                } else {
                    currentElement.text(href);
                    currentElement.addClass("bare");
                }
                closeElement();
                yybegin(YYINITIAL);
            }

    "link:" [^\s\[]+ {Properties}? |
    {URL} {Properties}?
    {
                String content = yytext();
                if (content.startsWith("link:")) {
                    content = stripHead(content, 5);
                }
                String href = extractBefore(content, "[");
                String text = extractBetween(content, "[", "]");

                if (text.isEmpty() && (href.endsWith("!") || href.endsWith(",") || href.endsWith(".") || href.endsWith(":") || href.endsWith("~"))) {
                    href = stripTail(href, 1);
                    yypushback(1);
                }

                PropertiesParser.parse(text, properties);
                String title = getArgument(0);
                if (title.endsWith("^")) {
                    title = stripTail(title, 1);
                    properties.put("window", "_blank");
                }
                openElement(AsciidocRenderer.LINK).attr("href", href);
                if (!title.isEmpty()) {
                    appendFormatted(title);
                } else {
                    currentElement.text(href);
                    currentElement.addClass("bare");
                }
                closeElement();
                yybegin(YYINITIAL);
            }

    "mailto:" [^\s\f\t\[\0]+ {Properties}? |
    {EmailAddress} {Properties}?
    {
                String content = yytext();
                if (content.startsWith("mailto:")) {
                    content = stripHead(content, 7);
                }
                String href = extractBefore(content, "[");
                String text = extractBetween(content, "[", "]");
                PropertiesParser.parse(text, properties);
                String title = getArgument(0);

                if (!getArgument(1).isEmpty()) {
                    StringBuilder hrefSb = new StringBuilder();
                    hrefSb.append("subject=");
                    hrefSb.append(getArgument(1));
                    if (!getArgument(2).isEmpty()) {
                        hrefSb.append("&body=");
                        hrefSb.append(getArgument(2));
                    }
                    href = href + urlEscape(hrefSb.toString());
                }

                openElement(AsciidocRenderer.LINK).attr("href", "mailto:" + href);
                if (!title.isEmpty()) {
                    appendFormatted(title);
                } else {
                    currentElement.text(href);
                }
                closeElement();
                yybegin(YYINITIAL);
            }

    "image:" {NoWhitespace}+ {Properties}?
    {
                String imgUrl = extractBetween(yytext(), "image:", "[");
                PropertiesParser.parse(extractBetween(yytext(), "[", "]"), properties);

                String alt = getArgument(0);
                if (alt.isEmpty()) alt = extractAfterStrict(extractBeforeStrict(imgUrl, "."), "/");
                String title = properties.optString("title");

                JSONObject imageProperties = new JSONObject();
                if (properties.has("arguments")) {
                    imageProperties.put("arguments", properties.getJSONArray("arguments"));
                }

                openElement("span").addClass("image");
                properties = imageProperties;
                openElement(AsciidocRenderer.IMAGE).attr("src", imgUrl).attr("alt", alt);
                if (!title.isEmpty()) {
                    currentElement.attr("title", title);
                }
                closeElement("span");
                yybegin(YYINITIAL);
            }


    /* Formatting */
    "+++" {NoLineFeed}+ "+++"
    {
                appendTextNode();
                currentElement.append(strip(yytext(), 3, 3));
            }

    "`+" {NoLineFeed}+ "+`"
    {
                openElement("code");
                appendText(strip(yytext(), 2, 2));
                closeElement("code");
            }

    /* Skipping stray constrained formatting characters
    {WhitespaceOrLineFeed} "*" {WhitespaceOrLineFeed} |
    {WhitespaceOrLineFeed} "_" {WhitespaceOrLineFeed} |
    {WhitespaceOrLineFeed} "`" {WhitespaceOrLineFeed} |
    {WhitespaceOrLineFeed} "#" {WhitespaceOrLineFeed} |
    {Character} "*" {Character} |
    {Character} "_" {Character} |
    {Character} "`" {Character} |
    {Character} "#" {Character}
    {
        appendText(stripTail(yytext(),1));
        yypushback(1);
    }*/

    "##" . ~ "##"
    {
                openElement("mark");
                appendFormatted(trim(yytext(), "#"));
                closeElement("mark");
            }
    /*"##" | "#"
    {
        openOrCloseElement("mark");
    }*/

    "**" . ~ "**"
    {
                openElement("strong");
                appendFormatted(trim(yytext(), "*"));
                closeElement("strong");
            }
    /*"**" | "*"
    {
        openOrCloseElement("strong");
    }*/

    "__" . ~ "__"
    {
                openElement("em");
                appendFormatted(trim(yytext(), "_"));
                closeElement("em");
            }
    /*"__" | "_"
    {
        openOrCloseElement("em");
    }*/

    "``" .+
    {
                String text = yytext();
                String toFormat = extractUnconstrainedCode(text);
                if (toFormat.isEmpty()) {
                    appendText("`");
                    yypushback(yytext().length() - 1);
                } else {
                    openElement("code");
                    appendFormatted(toFormat);
                    closeElement("code");
                    yypushback(text.length() - toFormat.length() - 4);
                    yybegin(INSIDE_WORD);
                }
            }

    /*
    "``" | "`"
    {
        openOrCloseElement("code");
    }*/

    "^" . ~ "^"
    {
                openElement("sup");
                appendFormatted(trim(yytext(), "^"));
                closeElement("sup");
            }
    /*"^"
    {
        openOrCloseElement("sup");
    }*/

    "~" . ~ "~"
    {
                openElement("sub");
                appendFormatted(trim(yytext(), "~"));
                closeElement("sub");
            }
    /*"~"
    {
        openOrCloseElement("sub");
    }*/

    /* Character substitutes */
    "..."
    {
                appendText("…\u200B");
                yybegin(YYINITIAL);
            }

    /* Smart quotes */
    "\"`"
    {
                appendText("\u201c");
                yybegin(INSIDE_WORD);
            }
    "`\""
    {
                appendText("\u201d");
                yybegin(INSIDE_WORD);
            }

    "'`"
    {
                appendText("\u2018");
                yybegin(INSIDE_WORD);
            }
    "`'"
    {
                appendText("\u2019");
                yybegin(INSIDE_WORD);
            }

    [&][a-z]+[;]
    {
                String entity = Entities.getByName(strip(yytext(), 1, 1));
                appendText(entity.isEmpty() ? yytext() : entity);
            }

    [\p{Letter}\p{Digit}]+
    {
                appendText(yytext());
                yybegin(INSIDE_WORD);
            }

    /* Escape */
    "\\" [*~`_\"\']
    {
                appendText(stripHead(yytext(), 1));
            }

    [^]
    {
                appendText(yytext());
                yybegin(YYINITIAL);
            }
}

<INSIDE_WORD> {
    "'" / [\p{Letter}\p{Digit}]+
    {
                appendText("\u2019");
            }
}