package com.github.fluorumlabs.asciidocj.impl.jflex;

import com.github.fluorumlabs.asciidocj.impl.ParserException;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.IOException;
import java.io.StringReader;

/**
 * Parser for Asciidoc properties
 */
%%

%class PropertiesParser
%public
%function parseInput
%apiprivate
%unicode
%scanerror ParserException

%{
    private JSONObject properties = new JSONObject();
        private StringBuilder currentString = new StringBuilder();
        private StringBuilder currentName = new StringBuilder();
        private StringBuilder currentValue = new StringBuilder();
        private boolean isClass = false;
        private boolean isId = false;
        private boolean isOption = false;
        private boolean isProperty = false;
        private boolean canShorthands = false;

        // We don't need that :)
        protected static class Yytoken {
        }

        /**
        * Parse the PlainText and return a resulting Document
        *
        * @param text Properties block
        * @param p Properties JSONObject that will receive parsed output
        * @return Properties JSONObject
        */
        public static JSONObject parse(String text, JSONObject p, boolean withShorthands) {
            try(StringReader reader = new StringReader(text)) {
                PropertiesParser parser = new PropertiesParser(reader);
                if ( p != null ) {
                    parser.properties = p;
                }
                parser.canShorthands = withShorthands;
                parser.parseInput();
                parser.addValue(false);
                return parser.properties;
            } catch (IOException|ParserException e) {
                throw new RuntimeException(e);
            }
        }

        private void addValue(boolean force) {
            if ( currentString.length() == 0 && !force ) return;

            if ( !(isProperty || isId || isOption || isClass)) {
                if ( !properties.has("arguments") ) {
                    properties.put("arguments", new JSONArray());
                }
                properties.getJSONArray("arguments").put(currentString.toString());
            }

            if ( isClass ) {
                if ( !properties.has("class") ) {
                    properties.put("class", new JSONObject());
                }
                JSONObject classes = properties.getJSONObject("class");
                for (String className: currentName.toString().split(" ")) {
                    classes.put(className, "");
                }
            } else if ( isId ) {
                properties.put("id",currentName.toString());
            } else if ( isOption ) {
               if ( !properties.has("options") ) {
                   properties.put("options", new JSONObject());
               }
               properties.getJSONObject("options").put(currentName.toString(),"");
            } else if ( isProperty ) {
                if ( currentName.toString().equals("role") ) {
                    if ( !properties.has("class") ) {
                       properties.put("class", new JSONObject());
                    }

                    properties.getJSONObject("class").put(currentValue.toString(),"");
                } else if ( currentName.toString().equals("options") || currentName.toString().equals("opts") ) {
                   if ( !properties.has("options") ) {
                      properties.put("options", new JSONObject());
                   }
                   for (String v : currentValue.toString().split(",")) {
                       properties.getJSONObject("options").put(v.trim(),"");
                   }
               } else {
                    properties.put(currentName.toString(),currentValue.toString());
                }
            }

            currentString.setLength(0);
            currentName.setLength(0);
            currentValue.setLength(0);

            isClass = false;
            isId = false;
            isOption = false;
            isProperty = false;
        }
%}

%state QUOTED
%state QUOTED_S
%state VALUE
%state VALUE_QUOTED
%state VALUE_QUOTED_S

%%

<YYINITIAL> {
    "." / \s* [a-zA-Z0-9]
    {
        if (canShorthands) {
            addValue(false);
            isClass = true;
        } else {
            currentString.append(yytext());
            currentName.append(yytext());
        }
    }

    "%" / \s* [a-zA-Z0-9]
    {
        if (canShorthands) {
            addValue(false);
            isOption = true;
        } else {
            currentString.append(yytext());
            currentName.append(yytext());
        }
    }

    "#" / \s* [a-zA-Z0-9]
    {
        if (canShorthands) {
            addValue(false);
            isId = true;
        } else {
            currentString.append(yytext());
            currentName.append(yytext());
        }
    }

    "\""
    {
        if ( currentString.length() == 0 ) {
            yybegin(QUOTED);
        } else {
            currentString.append(yytext());
            currentName.append(yytext());
        }
    }

    "'"
    {
        if ( currentString.length() == 0 ) {
            yybegin(QUOTED_S);
        } else {
            currentString.append(yytext());
            currentName.append(yytext());
        }
    }

    "="
    {
        currentString.append(yytext());
        isProperty = true;
        yybegin(VALUE);
    }

    "," " "*
    {
        addValue(true);
        canShorthands = false;
    }

	/* Any other character */
	[^]
    {
        currentString.append(yytext());
        currentName.append(yytext());
    }
}

<QUOTED> {
    "\""
    {
        yybegin(YYINITIAL);
    }

    [^]
    {
        currentString.append(yytext());
        currentName.append(yytext());
    }
}

<QUOTED_S> {
    "'"
    {
        yybegin(YYINITIAL);
    }

    [^]
    {
        currentString.append(yytext());
        currentName.append(yytext());
    }
}

<VALUE> {
    ","
    {
        yypushback(1);
        yybegin(YYINITIAL);
    }

    "\""
    {
        yybegin(VALUE_QUOTED);
    }

    "'"
    {
        yybegin(VALUE_QUOTED_S);
    }

    [^]
    {
        currentString.append(yytext());
        currentValue.append(yytext());
    }
}

<VALUE_QUOTED> {
    "\""
    {
        yybegin(YYINITIAL);
    }

    [^]
    {
        currentString.append(yytext());
        currentValue.append(yytext());
    }
}


<VALUE_QUOTED_S> {
    "'"
    {
        yybegin(YYINITIAL);
    }

    [^]
    {
        currentString.append(yytext());
        currentValue.append(yytext());
    }
}
