/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    author:         Gavin Norman

    Xml entity en/decoder.

    Example usage:

    ---

        import ocean.text.entities.XmlEntityCodec;

        scope entity_codec = new XmlEntityCodec;

        char[] test = "hello & world © &gt;&amp;#x230;'";

        if ( entity_codec.containsUnencoded(test) )
        {
            char[] encoded;
            entity_codec.encode(test, encoded);
        }

    ---

*******************************************************************************/

module ocean.text.entities.XmlEntityCodec;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.text.entities.model.MarkupEntityCodec;

import ocean.text.entities.XmlEntitySet;



/*******************************************************************************

    Class to en/decode xml entities.

*******************************************************************************/

public alias MarkupEntityCodec!(XmlEntitySet) XmlEntityCodec;


/*******************************************************************************

    Unit test

*******************************************************************************/

version ( UnitTest )
{
    void encodeTest ( Char ) ( XmlEntityCodec codec, Char[] str, Char[] expected_result )
    {
        Char[] encoded;

        if ( codec.containsUnencoded(str) )
        {
            codec.encode(str, encoded);
            assert(codec.containsEncoded(encoded));
        }
        else
        {
            encoded = str;
        }

        assert(encoded == expected_result);
    }

    void decodeTest ( Char ) ( XmlEntityCodec codec, Char[] str, Char[] expected_result )
    {
        Char[] decoded;

        if ( codec.containsEncoded(str) )
        {
            codec.decode(str, decoded);
        }
        else
        {
            decoded = str;
        }

        assert(decoded == expected_result);
    }

    // Perform tests for various char types
    void test ( Char ) ( )
    {
        struct Test
        {
            Char[] before;
            Char[] after;
        }

        scope codec = new XmlEntityCodec;

        // Check encoding
        Test[] encode_tests = [
            Test("", "" ), // saftey check
            Test("&", "&amp;"),
            Test("'", "&apos;"),
            Test("\"", "&quot;"),
            Test("<", "&lt;"),
            Test(">", "&gt;"),
            Test("©", "©"), // trick question
            Test("'hello'", "&apos;hello&apos;"),
            Test("&amp;", "&amp;") // already encoded
        ];

        foreach ( t; encode_tests )
        {
            encodeTest!(Char)(codec, t.before, t.after);
        }

        // Check decoding
        Test[] decode_tests = [
           Test("", ""), // saftey check
           Test("&#80;", "P"),
           Test("&#x50;", "P"),
           Test("&amp;", "&"),
           Test("&apos;", "'"),
           Test("&quot;", "\""),
           Test("&lt;", "<"),
           Test("&gt;", ">"),
           Test("©", "©"), // trick question
           Test("&amp;#23;&#80;", "&#23;P") // double encoding
           ];

        foreach ( t; decode_tests )
        {
            decodeTest!(Char)(codec, t.before, t.after);
        }
    }
}

unittest
{
    test!(char)();
    test!(wchar)();
    test!(dchar)();
}
