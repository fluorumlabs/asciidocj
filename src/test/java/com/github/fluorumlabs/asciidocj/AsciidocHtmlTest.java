package com.github.fluorumlabs.asciidocj;

import com.github.fluorumlabs.asciidocj.impl.Utils;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Attribute;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.nodes.Entities;
import org.junit.Assert;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;

import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Created by Artem Godin on 17/11/17.
 */
@RunWith(Parameterized.class)
public class AsciidocHtmlTest {
    @Parameters(name = "{0}")
    public static Collection<Object[]> data() {
        List<Object[]> dataSet = new ArrayList<>();

        File folder = new File(AsciidocHtmlTest.class.getResource("tests").getFile());

        FileUtils.listFiles(folder, new String[]{"adoc"}, true).stream()
                .map(f -> f.toURI().toString())
                .forEach(asciidocFile -> {
                    String asciidocString = null;
                    String htmlString = null;
                    try {
                        URL html = new URL(asciidocFile.replace(".adoc", ".html"));
                        asciidocString = IOUtils.toString(new URL(asciidocFile), "UTF-8");
                        htmlString = IOUtils.toString(html, "UTF-8");
                    } catch (IOException ignore) {
                        // ignore
                    }
                    String fileName = asciidocFile.replace(".adoc", "");
                    String id = Utils.extractAfterStrict(fileName.replace('\\','/'), "tests/");
                    if ( htmlString != null && asciidocString != null && !asciidocString.contains("include::")) {
                        dataSet.add(new Object[]{id, asciidocString, htmlString});
                    }
                });

        return dataSet;
    }

    private String fInput;
    private String fExpected;

    public AsciidocHtmlTest(String id, String input, String expected) {
        fInput = input;
        fExpected = expected;
    }

    @Test
    public void testAsciidocToHtml() {
        Assert.assertEquals(rewrap(fExpected), rewrap(AsciiDocument.from(fInput).getHtml()));
    }

    /**
     * Make html compare-friendly - reorder attributes/classes, remove newlines
     *
     * @param html
     * @return
     */
    private String rewrap(String html) {
        String preProcessedHtml = html
                .replace("\r\n", "\n")
                .replaceAll(">[\\r\\n]+", ">")
                .replaceAll("[\\r\\n]+</", "</");
        Document document = Jsoup.parse(preProcessedHtml);
        document.outputSettings()
                .escapeMode(Entities.EscapeMode.xhtml)
                .charset("US-ASCII");
        for (Element child : document.getAllElements()) {
            // Normalize: reorder attributes and classes
            List<String> classes = child.classNames().stream()
                    .sorted()
                    .collect(Collectors.toList());
            List<Attribute> attributes = child.attributes().asList().stream()
                    .sorted(Comparator.comparing(Attribute::getKey))
                    .collect(Collectors.toList());
            for (Attribute attribute : attributes) {
                child.removeAttr(attribute.getKey());
            }
            for (Attribute attribute : attributes)
                if (!attribute.getKey().equals("class")) {
                    child.attr(attribute.getKey(), attribute.getValue());
                }
            for (String aClass : classes) {
                child.addClass(aClass);
            }
        }
        return document.body().html();
    }
}
