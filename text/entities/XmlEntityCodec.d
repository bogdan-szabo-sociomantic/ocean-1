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
        Char[] encoded;

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
        Char[] decoded;

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
	
	void decodeTest2Stage ( Char ) ( XmlEntityCodec codec, Char[] original, Char[] intermediate, Char[] expected_result )
	{
        Char[] decoded1, decoded2;

        codec.decodeAmpersands(original, decoded1);
        assert(decoded1 == intermediate);
        
        if ( codec.containsEncoded(decoded1) )
        {
            codec.decode(decoded1, decoded2);
        }
        else
        {
        	decoded2 = decoded1;
        }

        assert(decoded2 == expected_result);
	}

	// Perform tests for various char types
	void test ( Char ) ( )
	{
		struct Test
		{
			Char[] before;
			Char[] after;
		}

		Trace.formatln("Testing {}s", Char.stringof);

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

        // Check 2-stage decoding (ampersands first)
        Char[] original = "&amp;#80;";
        Char[] stage1 = "&#80;";
        Char[] stage2 = "P";
        decodeTest2Stage!(Char)(codec, original, stage1, stage2);
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

