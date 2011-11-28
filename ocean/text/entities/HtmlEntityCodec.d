/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    author:         Gavin Norman

	Html entity en/decoder.

    Example usage:
    
    ---

        import ocean.text.entities.HtmlEntityCodec;

        scope entity_codec = new HtmlEntityCodec;

        char[] test = "hello & world © &szlig;&nbsp;&amp;#x230;'";
        
        if ( entity_codec.containsUnencoded(test) )
        {
            char[] encoded;
            entity_codec.encode(test, encoded);
        }
    
    ---

	Note: Also includes the classes HtmlDecoding and HtmlEncoding, which are
	functional replacements for the old classes of the same name (found in
	ocean.text.html.*). These classes provide an opCall method each to decode or
	encode text. Generally, however, it's more convenient to use the normal
	HtmlEntityCodec, which can do both encoding & decoding.

*******************************************************************************/

module ocean.text.entities.HtmlEntityCodec;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.text.entities.model.MarkupEntityCodec;

private import ocean.text.entities.HtmlEntitySet;

private import ocean.text.util.StringReplace;



/*******************************************************************************

	Class to en/decode html entities.

*******************************************************************************/

public alias MarkupEntityCodec!(HtmlEntitySet) HtmlEntityCodec;



/*******************************************************************************

	HtmlDecoding class - provides an opCall method to decode html entities.
	(Designed as a direct replacement for the old HtmlDecoding class. Generally
	it's more convenient to use the normal HtmlEntityCodec, which can do both
	encoding & decoding.)

	Template params:
		wide_char = switches between internal use of char & dchar

*******************************************************************************/

deprecated public class HtmlDecoding ( bool wide_char = false ) : HtmlEntityCodec
{
	/***************************************************************************
	
	    Alias for internal character type.
	
	***************************************************************************/
	
	static if ( wide_char )
	{
		public alias dchar Char;
	}
	else
	{
		public alias char Char;
	}
	
	
	/***************************************************************************
	
	    This alias.
	
	***************************************************************************/
	
	public alias typeof(this) This;
	
	
	/***************************************************************************
	
	    Internal string buffer, used during conversion.
	
	***************************************************************************/
	
	protected Char[] buf;
	
	
	/***************************************************************************
	
	    String replacer.
	
	***************************************************************************/
	
	protected alias StringReplace!(wide_char) StrRep;
	
	protected StrRep string_replace;
	
	
	/***************************************************************************
	
	    Constructor.
	
	***************************************************************************/
	
	this ( )
	{
	    this.string_replace = new StrRep;
	}
	
	
	/***************************************************************************
	
	    opCall. Decodes any html entities in the passed text.
	    
	    Params:
	    	text = text to process
	    	pre_convert_amp = if true, any occurrences of "&amp;" in the text
	    		will be decoded first, then the whole string will be converted.
	
	***************************************************************************/
	
	public This opCall ( ref Char[] text, bool pre_convert_amp = true )
	{
		this.buf = text.dup;
	
		if ( pre_convert_amp )
		{
			this.string_replace.replacePattern(this.buf, "&amp;", "&");
		}
	
		this.decode(text, this.buf);
		text = this.buf.dup;
		return this;
	}
}



/*******************************************************************************

	HtmlEncoding class - provides an opCall method to encode html entities.
	(Designed as a direct replacement for the old HtmlEncoding class. Generally
	it's more convenient to use the normal HtmlEntityCodec, which can do both
	encoding & decoding.)
	
	Template params:
		wide_char = switches between internal use of char & dchar

*******************************************************************************/

deprecated public class HtmlEncoding ( bool wide_char = false ) : HtmlEntityCodec
{
	/***************************************************************************
	
	    Alias for internal character type.
	
	***************************************************************************/

	static if ( wide_char )
	{
		public alias dchar Char;
	}
	else
	{
		public alias char Char;
	}


	/***************************************************************************
	
	    This alias.
	
	***************************************************************************/
	
	public alias typeof(this) This;
	
	
	/***************************************************************************
	
	    Internal string buffer, used during conversion.
	
	***************************************************************************/
	
	protected Char[] buf;
	
	
	/***************************************************************************
	
	    opCall. Encodes any unencoded html entities in the passed text.
	
	    Params:
	    	text = text to process
	
	***************************************************************************/
	
	public This opCall ( ref Char[] text )
	{
		this.buf = text.dup;
		this.encode(text, this.buf);
		text = this.buf.dup;
		return this;
	}
}

