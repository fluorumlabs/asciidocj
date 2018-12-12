package com.github.fluorumlabs.asciidocj.impl.jflex;

import com.github.fluorumlabs.asciidocj.impl.ParserException;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.IOException;
import java.io.StringReader;

import static com.github.fluorumlabs.asciidocj.impl.Utils.*;

/**
 * Parser for Asciidoc properties
 */
%%

%class ColumnFormatParser
%public
%function parseInput
%apiprivate
%unicode
%scanerror ParserException

%{
    private JSONArray columns = new JSONArray();
    private JSONObject column;

        // We don't need that :)
        protected static class Yytoken {
        }

        /**
        * Parse the PlainText and return a resulting Document
        *
        * @param text Properties block
        * @return Properties JSONObject
        */
        public static JSONArray parse(String text) {
            try(StringReader reader = new StringReader(text)) {
                ColumnFormatParser parser = new ColumnFormatParser(reader);
                parser.column = new JSONObject();
                parser.columns.put(parser.column);
                parser.parseInput();
                return parser.columns;
            } catch (IOException|ParserException e) {
                throw new RuntimeException(e);
            }
        }
%}

Multiply                    = [1-9][0-9]* "*"
Width                       = [1-9][0-9]*
Align                       = "."? [\^<>]
Format                      = [aehlmdsv]

%%

<YYINITIAL> {
    "," {
        column = new JSONObject();
        columns.put(column);
      }

    {Multiply} {
        int count = Integer.parseInt(stripTail(yytext(),1));
        for ( int i = 1; i < count; i++ ) {
            // Add current column count-1 times (same object == same values)
            columns.put(column);
        }
      }

    {Width} {
          column.put("width", Integer.parseInt(yytext()));
      }

    "~" {
          column.put("autowidth", true);
      }

    {Align} {
          boolean isVertical = yytext().startsWith(".");
          String attr = isVertical?"valign":"halign";
          switch (yytext().charAt(yytext().length()-1)) {
              case '^':
                  column.put(attr,isVertical?"middle":"center");
                  break;
              case '<':
                  column.put(attr,isVertical?"top":"left");
                  break;
              case '>':
                  column.put(attr,isVertical?"bottom":"right");
                  break;
          }
      }

    "a" {
          column.put("asciidoc",true);
      }

    "e" {
          column.put("em",true);
      }

    "h" {
          column.put("header",true);
      }

    "l" {
          column.put("literal",true);
      }

    "m" {
          column.put("monospace",true);
      }

    "s" {
          column.put("strong",true);
      }

    "v" {
          column.put("verse",true);
      }

	/* Any other character */
	[^]
    { }
}
