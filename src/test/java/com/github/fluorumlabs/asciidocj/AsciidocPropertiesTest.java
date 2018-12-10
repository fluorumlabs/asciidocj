package com.github.fluorumlabs.asciidocj;

import com.github.fluorumlabs.asciidocj.impl.jflex.PropertiesParser;
import org.junit.Assert;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;

import java.util.Arrays;
import java.util.Collection;

/**
 * Created by Artem Godin on 17/11/17.
 */
@RunWith(Parameterized.class)
public class AsciidocPropertiesTest {
    @Parameters(name = "{index}: {0}")
    public static Collection<Object[]> data() {
        return Arrays.asList(new Object[][]{
                {"%hardbreaks",
                        "{\"options\":{\"hardbreaks\":\"\"}}"},
                {".lead",
                        "{\"class\":{\"lead\":\"\"}}"},
                {"#primitives-nulls",
                        "{\"id\":\"primitives-nulls\"}"},
                {"qanda",
                        "{\"arguments\":[\"qanda\"]}"},
                {"cols=\"2\", options=\"header\"",
                        "{\"options\":{\"header\":\"\"},\"cols\":\"2\"}"},
                {"Asciidoctor",
                        "{\"arguments\":[\"Asciidoctor\"]}"},
                {"Asciidoctor @ *GitHub*",
                        "{\"arguments\":[\"Asciidoctor @ *GitHub*\"]}"},
                {"URL with special characters",
                        "{\"arguments\":[\"URL with special characters\"]}"},
                {"Subscribe, Subscribe me, I want to join!",
                        "{\"arguments\":[\"Subscribe\",\"Subscribe me\",\"I want to join!\"]}"},
                {"Discuss Asciidoctor, role=\"external\", window=\"_blank\"",
                        "{\"arguments\":[\"Discuss Asciidoctor\"],\"window\":\"_blank\",\"class\":{\"external\":\"\"}}"},
                {"Discuss Asciidoctor^, role=\"external\"",
                        "{\"arguments\":[\"Discuss Asciidoctor^\"],\"class\":{\"external\":\"\"}}"},
                {"caption=\"Figure 1: \",link=https://www.flickr.com/photos/javh/5448336655",
                        "{\"link\":\"https://www.flickr.com/photos/javh/5448336655\",\"caption\":\"Figure 1: \"}"},
                {"Play, title=\"Play\"",
                        "{\"arguments\":[\"Play\"],\"title\":\"Play\"}"},
                {"title=\"Pause\"",
                        "{\"title\":\"Pause\"}"},
                {"Sunset,150,150,role=\"right\"",
                        "{\"arguments\":[\"Sunset\",\"150\",\"150\"],\"class\":{\"right\":\"\"}}"},
                {"width=640, start=60, end=140, options=autoplay",
                        "{\"width\":\"640\",\"start\":\"60\",\"options\":{\"autoplay\":\"\"},\"end\":\"140\"}"},
                {"youtube",
                        "{\"arguments\":[\"youtube\"]}"},
                {"source,ruby",
                        "{\"arguments\":[\"source\",\"ruby\"]}"},
                {"quote, Abraham Lincoln, Address delivered at the dedication of the Cemetery at Gettysburg",
                        "{\"arguments\":[\"quote\",\"Abraham Lincoln\",\"Address delivered at the dedication of the Cemetery at Gettysburg\"]}"},
                {"quote, Charles Lutwidge Dodgson, 'Mathematician and author, also known as https://en.wikipedia.org/wiki/Lewis_Carroll[Lewis Carroll]'",
                        "{\"arguments\":[\"quote\",\"Charles Lutwidge Dodgson\",\"Mathematician and author, also known as https://en.wikipedia.org/wiki/Lewis_Carroll[Lewis Carroll]\"]}"},
                {", James Baldwin",
                        "{\"arguments\":[\"\",\"James Baldwin\"]}"},
                {"source,xml,subs=\"verbatim,attributes\"",
                        "{\"subs\":\"verbatim,attributes\",\"arguments\":[\"source\",\"xml\"]}"},
                {"role=\"incremental\"",
                        "{\"class\":{\"incremental\":\"\"}}"},
                {"#goals.incremental",
                        "{\"id\":\"goals\",\"class\":{\"incremental\":\"\"}}"},
                {"#free_the_world.big.goal",
                        "{\"id\":\"free_the_world\",\"class\":{\"big\":\"\",\"goal\":\"\"}}"},
                {"big goal",
                        "{\"arguments\":[\"big goal\"]}"},
                {"role='lead'",
                        "{\"class\":{\"lead\":\"\"}}"},
                {"source, ruby",
                        "{\"arguments\":[\"source\",\"ruby\"]}"},
                {"id='wrapup'",
                        "{\"id\":\"wrapup\"}"},
                {"source%nowrap,java",
                        "{\"options\":{\"nowrap\":\"\"},\"arguments\":[\"source\",\"java\"]}"},
                {"quote, Somebody, Hi there",
                        "{\"arguments\":[\"quote\",\"Somebody\",\"Hi there\"]}"},
                {"quote, Captain James T. Kirk, Star Trek IV: The Voyage Home",
                        "{\"arguments\":[\"quote\",\"Captain James T. Kirk\",\"Star Trek IV: The Voyage Home\"]}"}
        });
    }

    private String fInput;
    private String fExpected;

    public AsciidocPropertiesTest(String input, String expected) {
        fInput = input;
        fExpected = expected;
    }

    @Test
    public void testAsciidocProperties() {
        Assert.assertEquals(fExpected,
                PropertiesParser.parse(fInput, null, true).toString());
    }
}
