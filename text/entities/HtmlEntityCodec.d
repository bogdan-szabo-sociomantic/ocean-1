/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    author:         Gavin Norman

	Html entity en/decoder.

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



/*******************************************************************************

	Class to en/decode html entities.

*******************************************************************************/

public class HtmlEntityCodec : MarkupEntityCodec!(HtmlEntitySet)
{
}



/*******************************************************************************

	HtmlDecoding class - provides an opCall method to decode html entities.
	(Designed as a direct replacement for the old HtmlDecoding class. Generally
	it's more convenient to use the normal HtmlEntityCodec, which can do both
	encoding & decoding.)

*******************************************************************************/

public class HtmlDecoding ( Char = char ) : HtmlEntityCodec
{
	/***************************************************************************
	
	    Check the parameter type of this class.
	
	***************************************************************************/
	
	static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
			This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);
	
	
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
	
	static if ( is(Char == char) )
	{
		protected alias StringReplace!(false) StrRep;
	}
	else
	{
		protected alias StringReplace!(true) StrRep;
	}
	
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
			static if ( is(Char == wchar) )
			{
				// TODO: as StringReplace only takes dchar or char, wchars
				// will need to be converted to dchar first, then processed.
				static assert(false, This.stringof ~ ".opCall - sorry, this method can't handle wchars at the moment (TODO)");
			}
			else
			{
				this.string_replace.replacePattern(this.buf, "&amp;", "&");
			}
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

*******************************************************************************/

public class HtmlEncoding ( Char = char ) : HtmlEntityCodec
{
	/***************************************************************************
	
	    Check the parameter type of this class.
	
	***************************************************************************/
	
	static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
			This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);
	
	
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

