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

%class CellFormatParser
%public
%function parseInput
%apiprivate
%unicode
%scanerror ParserException

%{
    private JSONObject format = new JSONObject();

        // We don't need that :)
        protected static class Yytoken {
        }

        /**
        * Parse the PlainText and return a resulting Document
        *
        * @param text Properties block
        * @return Properties JSONObject
        */
        public static JSONObject parse(String text) {
            try(StringReader reader = new StringReader(text)) {
                CellFormatParser parser = new CellFormatParser(reader);
                parser.parseInput();
                return parser.format;
            } catch (IOException|ParserException e) {
                throw new RuntimeException(e);
            }
        }
%}

TCDuplicate                 = [1-9][0-9]* "*"
TCAlign                     = "."? [\^<>]

%%

<YYINITIAL> {
    {TCDuplicate} {
        format.put("duplicate", Integer.parseInt(stripTail(yytext(),1)));
      }

    [1-9][0-9]* "+"
    {
        format.put("spanColumn", Integer.parseInt(stripTail(yytext(),1)));
      }

    [1-9][0-9]* / "."
    {
        format.put("spanColumn", Integer.parseInt(yytext()));
      }

    "." [1-9][0-9]* "+"
     {
        format.put("spanRow", Integer.parseInt(strip(yytext(),1,1)));
      }

    {TCAlign} {
          boolean isVertical = yytext().startsWith(".");
          String attr = isVertical?"valign":"halign";
          switch (yytext().charAt(yytext().length()-1)) {
              case '^':
                  format.put(attr,isVertical?"middle":"center");
                  break;
              case '<':
                  format.put(attr,isVertical?"top":"left");
                  break;
              case '>':
                  format.put(attr,isVertical?"bottom":"right");
                  break;
          }
      }

    "d" {
          format.put("default",true);
      }

    "a" {
          format.put("asciidoc",true);
      }

    "e" {
          format.put("em",true);
      }

    "h" {
          format.put("header",true);
      }

    "l" {
          format.put("literal",true);
      }

    "m" {
          format.put("monospace",true);
      }

    "s" {
          format.put("strong",true);
      }

    "v" {
          format.put("verse",true);
      }

	/* Any other character */
	[^]
    { }
}
