package com.github.fluorumlabs.asciidocj.impl.jflex;

import com.github.fluorumlabs.asciidocj.impl.AsciidocBase;
import com.github.fluorumlabs.asciidocj.impl.AsciidocRenderer;
import com.github.fluorumlabs.asciidocj.impl.ParserException;
import org.apache.commons.lang3.StringUtils;import org.json.JSONObject;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Entities;

import java.io.IOException;
import java.util.HashSet;import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;import java.util.stream.Stream;

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

    private enum Pass {
        SPECIAL_CHARACTERS, QUOTES, ATTRIBUTES, REPLACEMENTS, MACROS, POST_REPLACEMENTS;
    }

    private Set<Pass> disabled = new HashSet<AsciidocFormatter.Pass>();


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
                disabled.clear();

                String passString = attributes.optString(":pass","");
                if ( !passString.isEmpty() ) {
                    if ( !passString.contains("c") ) disabled.add(Pass.SPECIAL_CHARACTERS);
                    if ( !passString.contains("q") ) disabled.add(Pass.QUOTES);
                    if ( !passString.contains("a") ) disabled.add(Pass.ATTRIBUTES);
                    if ( !passString.contains("r") ) disabled.add(Pass.REPLACEMENTS);
                    if ( !passString.contains("m") ) disabled.add(Pass.MACROS);
                    if ( !passString.contains("p") ) disabled.add(Pass.POST_REPLACEMENTS);
                }

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

            private Document getFormatted(String text, JSONObject passAttributes) throws ParserException {
                if (formatter == null) formatter = new AsciidocFormatter();
                return formatter.parse(text, properties, passAttributes);
            }

            private String getFormatted(String text, String passMode) throws ParserException {
                if (formatter == null) formatter = new AsciidocFormatter();
                JSONObject passAttributes = new JSONObject(attributes);
                passAttributes.put(":pass",passMode);
                return formatter.parse(text, properties, passAttributes).body().html();
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

            private boolean fallback(Pass passMode) throws ParserException {
                if ( disabled.contains(passMode) ) {
                    appendText(yytext().substring(0,1));
                    yypushback(yytext().length()-1);
                    return true;
                } else {
                    return false;
                }
            }

%}

LineFeed                    = \R | \0
Whitespace					= " "|"\t"
NoWhitespace			    = [^\s]

EmailAddress                = [a-zA-Z0-9.!#$%&'*+/=?\^_`{|}~\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,128}
URLDomainPart               = "www."? [-a-zA-Z0-9@:%._\+~#=]{2,256} "." [a-z]{2,128}
URLDomainPartWithLocalhost  = {URLDomainPart} | "localhost"
URL                         = (("http" [s]?)|"irc") "://" {URLDomainPartWithLocalhost} [-a-zA-Z0-9@:%_\+.,~#?!&//()=*]*

NoLineFeed                  = [^\r\n\u2028\u2029\u000B\u000C\u0085\0]

AttributeName               = [A-Za-z0-9_][A-Za-z0-9_-]*
Properties                  = "[" ("\\]"|[^\]\r\n\u2028\u2029\u000B\u000C\u0085\0])* "]"

%state INSIDE_WORD

%%

/* Escaping */
<YYINITIAL, INSIDE_WORD> {
    "\\\\__" . ~ "__" |
    "\\\\##" . ~ "##" |
    "\\\\**" . ~ "**" |
    "\\\\``" . ~ "``"
    {
                appendText(yytext().substring(2,4));
                appendTextNode();
                appendFormatted(strip(yytext(),4,2));
                appendText(yytext().substring(2,4));
            }

    "\\" [*~&#`_\\\"\'\[{]
    {
                appendText(stripHead(yytext(),1));
            }

    "\\" {URL}
    {
          appendText(stripHead(yytext(),1));
      }
}

<YYINITIAL> {
    "*" [^\s*] .*
    {
                if ( fallback(Pass.QUOTES) ) break;

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
                if ( fallback(Pass.QUOTES) ) break;

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
                if ( fallback(Pass.QUOTES) ) break;

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
                if ( fallback(Pass.QUOTES) ) break;

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

    "`" [^\s`\"\'] .*
    {
                if ( fallback(Pass.QUOTES) ) break;

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

    "pass:" {NoWhitespace}* "[" [^\]]+ "]"
    {
                        if ( fallback(Pass.MACROS) ) break;

                        String params = extractBetween(yytext(), "pass:", "[");
                        String content = extractBetween(yytext(), "[", "]");

                        JSONObject passAttributes = new JSONObject(attributes);
                        passAttributes.put(":pass", Stream.of(params.split(","))
                            .filter(k -> !k.isEmpty())
                            .map(k -> k.substring(0,1))
                            .collect(Collectors.joining()));

                        Document pass = getFormatted(content, passAttributes);
                        appendTextNode();
                        appendDocument(upgradeToHtml(pass));
              }

   "anchor:" [^\[][^\]]+ {Properties}?
    {
                if ( fallback(Pass.MACROS) ) break;

                JSONObject anchorOptions = new JSONObject();
                String id;
                String text;
                id = extractBetween(yytext(), "anchor:", "[");

                PropertiesParser.parse(extractBetween(yytext(), "[", "]"), anchorOptions, false);
                text = getArgument(anchorOptions, 0);
                if (!text.isEmpty()) {
                    attributes.put("anchor:" + id, getFormatted(text).body().html());
                }
                openElement(AsciidocRenderer.LINK).attr("id", id);
                closeElement(AsciidocRenderer.LINK);
                yybegin(YYINITIAL);
            }

    "xref:" [^\s\[]+ {Properties}? |
    "<<" {NoLineFeed}+ ">>"
    {
                if ( fallback(Pass.MACROS) ) break;

                String id;
                String text;

                if ( yytext().startsWith("xref:")) {
                    String content = stripHead(yytext(),5);

                    id = extractBefore(content,"[");
                    text = extractBetween(content,"[","]");
                } else {
                    JSONObject anchorOptions = new JSONObject();
                    PropertiesParser.parse(strip(yytext(), 2, 2), anchorOptions, false);

                    id = getArgument(anchorOptions, 0);
                    text = getArgument(anchorOptions, 1);
                }

                properties.put("to-id", id);
                if (!text.isEmpty()) {
                    properties.put("to-id-contents", getFormatted(text).body().html());
                }
                openElement(AsciidocRenderer.LINK);
                closeElement(AsciidocRenderer.LINK);
                yybegin(YYINITIAL);
            }


    "xref:" [^\s\[]+ {Properties}?
    {
                if ( fallback(Pass.MACROS) ) break;

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

                PropertiesParser.parse(text, properties, false);
                String title = getArgument(0);
                if (title.endsWith("^")) {
                    title = stripTail(title, 1);
                    properties.put("window", "_blank");
                }
                openElement(AsciidocRenderer.LINK).attr("href", href);
                if (!title.isEmpty()) {
                    appendFormatted(title);
                } else {
                    if ( attributes.has("hide-uri-scheme") && href.contains("://")) {
                        href = extractAfter(href,"://");
                    }
                    currentElement.text(href);
                    currentElement.addClass("bare");
                }
                closeElement();
                yybegin(YYINITIAL);
            }


    /* Inline blocks */
    "link:++" {NoLineFeed}* "++" {Properties}?
    {
                if ( fallback(Pass.MACROS) ) break;

                String content = yytext();
                String text = extractBetween(extractAfterStrict(content, "++"), "[", "]");
                String href = extractBetween(content, "++", "++");
                PropertiesParser.parse(text, properties, false);
                String title = getArgument(0);
                if (title.endsWith("^")) {
                    title = stripTail(title, 1);
                    properties.put("window", "_blank");
                }
                openElement(AsciidocRenderer.LINK).attr("href", href);
                if (!title.isEmpty()) {
                    appendFormatted(title);
                } else {
                    if ( attributes.has("hide-uri-scheme") && href.contains("://")) {
                        href = extractAfter(href,"://");
                    }
                    currentElement.text(href);
                    currentElement.addClass("bare");
                }
                closeElement();
                yybegin(YYINITIAL);
            }

    "link:" [^\s\[]+ {Properties}? |
    {URL} {Properties}?
    {
                if ( fallback(Pass.MACROS) ) break;

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

                PropertiesParser.parse(text, properties, false);
                String title = getArgument(0);
                if (title.endsWith("^")) {
                    title = stripTail(title, 1);
                    properties.put("window", "_blank");
                }
                openElement(AsciidocRenderer.LINK).attr("href", href);
                if (!title.isEmpty()) {
                    appendFormatted(title);
                } else {
                    if ( attributes.has("hide-uri-scheme") && href.contains("://")) {
                        href = extractAfter(href,"://");
                    }
                    currentElement.text(href);
                    currentElement.addClass("bare");
                }
                closeElement();
                yybegin(YYINITIAL);
            }

    "mailto:" [^\s\f\t\[\0]+ {Properties}? |
    {EmailAddress} {Properties}?
    {
                if ( fallback(Pass.MACROS) ) break;

                String content = yytext();
                if (content.startsWith("mailto:")) {
                    content = stripHead(content, 7);
                }
                String href = extractBefore(content, "[");
                String text = extractBetween(content, "[", "]");
                PropertiesParser.parse(text, properties, false);
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
                if ( fallback(Pass.MACROS) ) break;

                String imgUrl = extractBetween(yytext(), "image:", "[");

                if (!imgUrl.startsWith("http://") && !imgUrl.startsWith("https://")) {
                    String path = attributes.optString("imagesdir", DEFAULT_IMAGESDIR);
                    if (!path.endsWith("/")) path = path.concat("/");
                   imgUrl = path.concat(imgUrl);
                }

                PropertiesParser.parse(extractBetween(yytext(), "[", "]"), properties, false);

                String alt = getArgument(0);
                if (alt.isEmpty()) alt = extractAfterStrict(extractBeforeStrict(imgUrl, "."), "/");
                String title = properties.optString("title");

                JSONObject imageProperties = new JSONObject();
                if (properties.has("arguments")) {
                    imageProperties.put("arguments", properties.getJSONArray("arguments"));
                }

                JSONObject propertiesCopy = properties;

                openElement("span").addClass("image");

                if ( propertiesCopy.has("float")) {
                    currentElement.addClass(propertiesCopy.getString("float"));
                }
                if ( propertiesCopy.has("align")) {
                    currentElement.addClass("text-"+propertiesCopy.getString("align"));
                }

                properties = imageProperties;
                openElement(AsciidocRenderer.IMAGE).attr("src", imgUrl).attr("alt", alt);
                if (!title.isEmpty()) {
                    currentElement.attr("title", title);
                }
                closeElement("span");
                yybegin(YYINITIAL);
            }

    "kbd:" {Properties}
    {
                if ( fallback(Pass.MACROS) ) break;

                properties.put("shortcut", trim(extractBetween(yytext(), "[", "]")).replace("\\]","]"));
                openElement(AsciidocRenderer.KEYBOARD);
                closeElement(AsciidocRenderer.KEYBOARD);
            }

    "menu:" [^\R\[]+ {Properties} |
    "\"" [^\">\r\n\u2028\u2029\u000B\u000C\u0085\0]+ (">" [^\">\r\n\u2028\u2029\u000B\u000C\u0085\0]+)+ "\""
    {
                if ( fallback(Pass.MACROS) ) break;

                if ( yytext().startsWith("menu:")) {
                    String rootMenu = extractBetween(yytext(), "menu:", "[");

                    properties.put("submenu", getFormatted(trim(extractBetween(yytext(), "[", "]")),"r").replace("&gt;",">"));
                    properties.put("menu", getFormatted(trim(rootMenu),"r"));
                } else {
                    properties.put("menu", getFormatted(trim(strip(yytext(),1,1)),"r").replace("&gt;",">"));
                }
                openElement(AsciidocRenderer.MENU);
                closeElement(AsciidocRenderer.MENU);
            }

    "btn:" {Properties}
    {
                if ( fallback(Pass.MACROS) ) break;

                properties.put("button", getFormatted(trim(extractBetween(yytext(), "[", "]")),"r"));
                openElement(AsciidocRenderer.BUTTON);
                closeElement(AsciidocRenderer.BUTTON);
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
                if ( fallback(Pass.ATTRIBUTES) ) break;

                String id = strip(yytext(), 1, 1);
                if (attributes.has(id)) {
                    appendTextNode();
                    appendFormatted(attributes.getString(id));
                } else {
                    String value = getReplacement(id);
                    appendText(value==null?yytext():value);
                }
            }

    /* Counter reset */
    "{counter:" {AttributeName} ":" ([0-9]+|[a-zA-Z]) "}" |
    "{counter2:" {AttributeName} ":" ([0-9]+|[a-zA-Z]) "}"
    {
                if ( fallback(Pass.ATTRIBUTES) ) break;

                String text = strip(yytext(), 1, 1);
                String attribute = extractBetween(text,":",":");
                String initial = extractAfterStrict(text,":");

                if ( text.startsWith("counter:") ) {
                    appendText(initial);
                }

                attributes.put(attribute,initial);
            }

    /* Counter increment */
    "{counter:" {AttributeName} "}" |
    "{counter2:" {AttributeName} "}"
    {
                    if ( fallback(Pass.ATTRIBUTES) ) break;

                    String text = strip(yytext(), 1, 1);
                    String attribute = extractAfter(text,":");

                    String value = attributes.optString(attribute, "0");

                    if ( StringUtils.isNumeric(value) ) {
                        value = Integer.toString(Integer.parseInt(value)+1);
                    } else if ( value.length() == 1 ){
                        value = Character.toString((char)(value.charAt(0)+1));
                    }

                    if ( text.startsWith("counter:") ) {
                        appendText(value);
                    }

                    attributes.put(attribute,value);
                }

   "[" [^\[][^\]]+ "]"
    {
                if ( fallback(Pass.ATTRIBUTES) ) break;

                String text = strip(yytext(), 1, 1);
                PropertiesParser.parse(text, properties, true);
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

   "[[" ~ "]]"
    {
                if ( fallback(Pass.MACROS) ) break;

                String id = "";
                String text = "";
                String[] data = extractBetween(yytext(), "[[", "]]").split(",",2);
                if ( data.length>0 ) id = data[0];
                if ( data.length>1 ) text = data[1];

                if (!text.isEmpty()) {
                    attributes.put("anchor:" + id, getFormatted(text).body().html());
                }
                openElement(AsciidocRenderer.LINK).attr("id", id);
                closeElement(AsciidocRenderer.LINK);
                yybegin(YYINITIAL);
            }

    /* Formatting */
    "+++" {NoLineFeed}+ "+++"
    {
                if ( fallback(Pass.QUOTES) ) break;

                appendTextNode();
                currentElement.append(strip(yytext(), 3, 3));
            }

    "`+" {NoLineFeed}+ "+`"
    {
                if ( fallback(Pass.QUOTES) ) break;

                openElement("code");
                appendText(strip(yytext(), 2, 2));
                closeElement("code");
            }

    "##" . ~ "##"
    {
                if ( fallback(Pass.MACROS) ) break;

                openElement("mark");
                appendFormatted(trim(yytext(), "#"));
                closeElement("mark");
            }

    "**" . ~ "**"
    {
                if ( fallback(Pass.MACROS) ) break;

                openElement("strong");
                appendFormatted(trim(yytext(), "*"));
                closeElement("strong");
            }

    "__" . ~ "__"
    {
                if ( fallback(Pass.MACROS) ) break;

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
                if ( fallback(Pass.MACROS) ) break;

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

    "^" . ~ "^"
    {
                if ( fallback(Pass.MACROS) ) break;

                openElement("sup");
                appendFormatted(trim(yytext(), "^"));
                closeElement("sup");
            }

    "~" . ~ "~"
    {
                if ( fallback(Pass.MACROS) ) break;

                openElement("sub");
                appendFormatted(trim(yytext(), "~"));
                closeElement("sub");
            }

    /* Character substitutes */
    "..."
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

                appendText("…\u200B");
                yybegin(YYINITIAL);
            }

    /* Smart quotes */
    "\"`"
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

                appendText("\u201c");
                yybegin(INSIDE_WORD);
            }
    "`\""
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

                appendText("\u201d");
                yybegin(INSIDE_WORD);
            }

    "'`"
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

                appendText("\u2018");
                yybegin(INSIDE_WORD);
            }
    "`'"
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

                appendText("\u2019");
                yybegin(INSIDE_WORD);
            }

    "(C)"
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

          appendText("\u00a9");
      }

    "(R)"
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

          appendText("\u00ae");
      }

    "(TM)"
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

          appendText("\u2122");
      }

    "->"
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

          appendText("\u2192");
      }

    "=>"
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

          appendText("\u21d2");
      }

    "<-"
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

          appendText("\u2190");
      }

    "<="
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

          appendText("\u21d0");
      }

    " -- "
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

          appendText("\u2009\u2014\u2009");
          yybegin(YYINITIAL);
      }

    [&][a-z]+[;]
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

                String entity = Entities.getByName(strip(yytext(), 1, 1));
                appendText(entity.isEmpty() ? yytext() : entity);
            }

    [\p{Letter}\p{Digit}]+
    {
                appendText(yytext());
                yybegin(INSIDE_WORD);
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
                if ( fallback(Pass.REPLACEMENTS) ) break;

                appendText("\u2019");
        }

    "--" / [\p{Letter}\p{Digit}]+
    {
                if ( fallback(Pass.REPLACEMENTS) ) break;

                appendText("\u2014\u200b");
            }

}