# Asciidoc to HTML renderer


[![Maven metadata URL](https://img.shields.io/maven-metadata/v/http/oss.sonatype.org/content/groups/public/com/github/fluorumlabs/asciidocj/maven-metadata.xml.svg)](https://oss.sonatype.org/content/groups/public/com/github/fluorumlabs/asciidocj/) 
[![GitHub](https://img.shields.io/github/license/fluorumlabs/asciidocj.svg)](https://github.com/fluorumlabs/asciidocj/blob/master/LICENSE)
 [![Build Status](https://travis-ci.com/fluorumlabs/asciidocj.svg?branch=master)](https://travis-ci.com/fluorumlabs/asciidocj) 

## What?

`asciidocj` is a _faster_ lightweight lexer-based Asciidoc processor
outputting Jsoup DOM or plain HTML for Java

## Why?

In our project we faced the need to transform Asciidoc files to HTML on-the-fly. Obviously our go-to solution was to use
awesome [AsciidoctorJ](https://github.com/asciidoctor/asciidoctorj) java library, but, unfortunately we found it's performance
a bit dissatisfying: the very basic conversion was measured to run for more than 500 ms (yes, half a second), and the most of this 
was caused by the inner workings of JRuby.

As a solution for our use-case I started this project. It's doing only one thing: converts your Asciidoc formatted text to 
HTML (or JSoup Document, if you need). Output of `asciidocj` is verified against `AsciidoctorJ`, so it is producing exactly the
same DOM tree with exactly same classes, meaning that you can use it right away without changing of your existing styles.

## How?

1: Add maven dependency

```xml
<dependency>
   <groupId>com.github.fluorumlabs</groupId>
   <artifactId>asciidocj</artifactId>
   <version>1.0.1</version>
</dependency>
```

2: Convert your asciidoc text to `AsciiDocument`: 

```java
AsciiDocument parsedAsciidoc = AsciiDocument.from(asciidoc);
``` 

3: Get the results:
   - Get plain HTML in string: `parsedAsciidoc.getHtml()`
   - Get JSoup Document: `parsedAsciidoc.getDocument()`
   - Get `<body>` element of JSoup Document: `parsedAsciidoc.getDocumentBody()`
   - Get asciidoc attributes: `parsedAsciidoc.getAttributesAsJSON()` and `parsedAsciidoc.getAttributesAsProperties()`

## Supported features

See [asciidocj test suite](https://github.com/fluorumlabs/asciidocj/tree/master/src/test/resources/com/github/fluorumlabs/asciidocj/tests) 
for the list of verified supported features. The verification is performed by comparing output of `asciidocj` with the output of
`AsciidoctorJ`. The following AsciidoctorJ settings are used: 
```
backend = html5
headerFooter = false

showtitle = true
experimental = true
skip-front-matter = true
```

## Limitations

- Boundaries of delimited blocks can be unbalanced (see https://asciidoctor.org/docs/user-manual/#delimiter-lines)
- Support for block nesting is limited
- Pass-through blocks (`++++`) are considered as blocks: all non closed html tags are closed automatically. This means that they
  can't be used to create complex HTML layouts.
- Table cells are always treated as asciidoc fragments, but only paragraphs are outputted if no `a` is specified
- Nested tables are not supported
- List continuation (attaching to parent) actually attaches to parent instead of some arbitrary level as in Asciidoctor

## Internals

`asciidocj` is a two-stage converter. First stage is based on [JFlex lexical analyzer generator](http://www.jflex.de/), but instead of producing fully-featured
AST, it creates a "semi-AST" right inside Jsoup DOM tree. The resulting DOM is then processed in a second stage to a normal HTML.

Jsoup guarantees that the resulting HTML will always be 100% syntactically correct and safe.   
