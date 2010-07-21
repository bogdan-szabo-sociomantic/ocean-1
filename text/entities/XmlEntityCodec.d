/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    author:         Gavin Norman

	Xml entity en/decoder.

*******************************************************************************/

module ocean.text.entities.XmlEntityCodec;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.text.entities.model.MarkupEntityCodec;

private import ocean.text.entities.XmlEntitySet;



/*******************************************************************************

	Class to en/decode xml entities.

*******************************************************************************/

public class XmlEntityCodec : MarkupEntityCodec!(XmlEntitySet)
{
}


/*******************************************************************************

	Unit test

*******************************************************************************/

debug ( OceanUnitTest )
{
	private import tango.util.log.Trace;

	void encodeTest ( Char ) ( XmlEntityCodec codec, Char[] string, Char[] expected_result )
	{
        char[] encoded;

        if ( codec.containsUnencoded(string) )
        {
            codec.encode(string, encoded);
            assert(codec.containsEncoded(encoded));
        }
        else
        {
        	encoded = string;
        }

        assert(encoded == expected_result);
	}
	
	void decodeTest ( Char ) ( XmlEntityCodec codec, Char[] string, Char[] expected_result )
	{
        char[] decoded;

        if ( codec.containsEncoded(string) )
        {
            codec.decode(string, decoded);
        }
        else
        {
        	decoded = string;
        }

        assert(decoded == expected_result);
	}
	
	// Perform tests for various char types
	void test ( Char ) ( )
	{
        Trace.formatln("Testing {}s", Char.stringof);

        scope codec = new XmlEntityCodec;

        // Check encoding
        encodeTest(codec, "", ""); // saftey check
        encodeTest(codec, "&", "&amp;");
        encodeTest(codec, "'", "&apos;");
        encodeTest(codec, "\"", "&quot;");
        encodeTest(codec, "<", "&lt;");
        encodeTest(codec, ">", "&gt;");
        encodeTest(codec, "©", "©"); // trick question
        encodeTest(codec, "'hello'", "&apos;hello&apos;");
        encodeTest(codec, "&amp;", "&amp;"); // already encoded

        // Check decoding
        decodeTest(codec, "", ""); // saftey check
        decodeTest(codec, "&#80;", "P");
        decodeTest(codec, "&#x50;", "P");
        decodeTest(codec, "&amp;", "&");
        decodeTest(codec, "&apos;", "'");
        decodeTest(codec, "&quot;", "\"");
        decodeTest(codec, "&lt;", "<");
        decodeTest(codec, "&gt;", ">");
        decodeTest(codec, "©", "©"); // trick question
        decodeTest(codec, "&amp;#23;&#80;", "&#23;P"); // double encoding
	}
	
	unittest
	{
        Trace.formatln("Running ocean.text.entities.XmlEntityCodec unittest");

        test!(char)();
        test!(wchar)();
        test!(dchar)();

        Trace.formatln("\nDone unittest\n");
	}
}

