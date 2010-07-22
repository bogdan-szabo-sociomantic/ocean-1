/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    author:         Gavin Norman

	Struct template to iterate over strings in variable encoding format (utf8,
	utf16, utf32), extracting one unicode character at a time. Each unicode
	character may be represented by one or more character in the input string,
	depending on the encoding format.

	The struct takes a template parameter (pull_dchars) which determines
	whether its methods return unicode characters (utf32 - dchars) or characters
	in the same format as the source string.

	The template also has an index operator, to extract the nth unicode
	character in the string, and static methods for extracting single characters
	from a string of variable encoding.

	Example usage:
	
	---
	
		import ocean.text.utf.UtfString;
		
		char[] test = "test string";
		UtfString!(char) utfstr = { test };
		
		foreach ( width, i, c; utfstr )
		{
			Trace.formatln("Character {} is {} and it's {} wide", i, c, width);
		}
	
	---

*******************************************************************************/

module ocean.text.utf.UtfString;



/*******************************************************************************

	Imports

*******************************************************************************/

private import Utf = tango.text.convert.Utf;

debug
{
	private import tango.util.log.Trace;
}



/***************************************************************************

	Invalid unicode.

***************************************************************************/

public static const dchar InvalidUnicode = cast(dchar)0xffffffff;



/*******************************************************************************

	UtfString template struct

	Template params:
		Char = type of strings to process
		pull_dchars = determines the output type of the struct's methods. If
			true they will all output dchars (ie unicode / utf32 characters),
			otherwise they output slices of the input string, containing the
			characters representing a single unicode character.

*******************************************************************************/

public struct UtfString ( Char = char, bool pull_dchars = false )
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
	
	    String to iterate over.
	
	***************************************************************************/
	
	Char[] string;
	
	
	/***************************************************************************
	
	    Output type alias.
	
	***************************************************************************/
	
	static if ( pull_dchars )
	{
		public alias dchar OutType;
	}
	else
	{
		public alias Char[] OutType;
	}
	
	
	/***************************************************************************
	
	    foreach iterator.
	    
	    Exposes the following foreach parameters:
	    	size_t width = number of input characters for this unicode character
	    	size_t i = current index into the input string
	    	OutType c = the next unicode character in the string
	
	***************************************************************************/
	
	public int opApply ( int delegate ( ref size_t, ref size_t, ref OutType ) dg )
	{
		int res;
		size_t i;
	
		while ( i < this.string.length )
		{
			Char[] process = this.string[i..$];
	
			size_t width;
			auto c = This.extract(process, width);
	
			res = dg(width, i, c);
			if ( res )
			{
				break;
			}
	
			i += width;
		}
	
		return res;
	}
	
	
	/***************************************************************************
	
	    foreach iterator.
	    
	    Exposes the following foreach parameters:
	    	size_t i = current index into the input string
	    	OutType c = the next unicode character in the string
	
	***************************************************************************/
	
	public int opApply ( int delegate ( ref size_t, ref OutType ) dg )
	{
		int res;
		size_t i;
	
		while ( i < this.string.length )
		{
			Char[] process = this.string[i..$];
	
			size_t width;
			auto c = This.extract(process, width);
	
			res = dg(i, c);
			if ( res )
			{
				break;
			}
	
			i += width;
		}
	
		return res;
	}
	
	
	/***************************************************************************
	
	    foreach iterator.
	    
	    Exposes the following foreach parameters:
	    	OutType c = the next unicode character in the string
	
	***************************************************************************/
	
	public int opApply ( int delegate ( ref OutType ) dg )
	{
		int res;
		size_t i;
	
		while ( i < this.string.length )
		{
			Char[] process = this.string[i..$];
	
			size_t width;
			auto c = This.extract(process, width);
	
			res = dg(c);
			if ( res )
			{
				break;
			}
	
			i += width;
		}
	
		return res;
	}


	/***************************************************************************
	
	    opIndex. Extracts the nth unicode character from the input string.
	
	    Params:
	    	index = index of character to extract
	    	
		Returns:
			the extracted character, either as a dchar or a slice into the input
			string (depending on the pull_dchars template parameter).
	
	***************************************************************************/
	
	public OutType opIndex ( size_t index )
	in
	{
		assert(this.string.length, This.stringof ~ ".opIndex - attempted to index into an empty string");
	}
	body
	{
		size_t i;
		size_t count;
		OutType c;
		do
		{
			size_t width;
			c = This.extract(this.string[i..$], width);
			i += width;
		} while ( count++ < index );
	
		return c;
	}
	
	
	/***************************************************************************
	
	    Static method to extract the next character from the passed string.
	
	    Params:
	    	text = string to extract from
	
		Returns:
			the extracted character, either as a dchar or a slice into the input
			string (depending on the pull_dchars template parameter).

	***************************************************************************/
	
	public static OutType extract ( Char[] text )
	{
		size_t width;
		return This.extract(text, width);
	}
	
	
	/***************************************************************************
	
	    Static method to extract the next character from the passed string.
	
	    Params:
	    	text = string to extract from
	    	width = outputs the width (in terms of the number of characters in
	    		the input string) of the extracted character
	
		Returns:
			the extracted character, either as a dchar or a slice into the input
			string (depending on the pull_dchars template parameter).

	***************************************************************************/
	
	static if ( pull_dchars )
	{
		public static OutType extract ( Char[] text, out size_t width )
		{
			if ( !text.length )
			{
				return InvalidUnicode;
			}
	
			static if ( is(Char == dchar) )
			{
				width = 1;
				return text[0];
			}
			else
			{
				dchar unicode = Utf.decode(text, width);
				return unicode;
			}
		}
	}
	else
	{
		public static OutType extract ( Char[] text, out size_t width )
		{
			if ( !text.length )
			{
				return "";
			}
	
			static if ( is(Char == dchar) )
			{
				width = 1;
				return [text[0]];
			}
			else
			{
				dchar unicode = Utf.decode(text, width);
				return text[0..width];
			}
		}
	}
}

