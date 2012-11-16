/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    author:         Gavin Norman

	An abstract class template representing an entity de/coder, over a specific
	set of entities.

	The class has various abstract methods, which must be implemented, to decode
	and encode strings.

*******************************************************************************/

module ocean.text.entities.model.IEntityCodec;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.text.entities.model.IEntitySet;

private import Utf = tango.text.convert.Utf;


/*******************************************************************************

	Abstract entity codec template class. Provides 

	Template params:
		E = entity set the codec deals with

*******************************************************************************/

public abstract class IEntityCodec ( E : IEntitySet )
{
	/***************************************************************************

		Abstract methods to encode any unencoded entities in a string.
		
		(Unfortunately template methods can't be abstract.)

	***************************************************************************/

	public abstract char[] encode ( char[] text, ref char[] encoded );
	public abstract wchar[] encode ( wchar[] text, ref wchar[] encoded );
	public abstract dchar[] encode ( dchar[] text, ref dchar[] encoded );


	/***************************************************************************

		Abstract methods to decode any encoded entities in a string.
		
		(Unfortunately template methods can't be abstract.)
	
	***************************************************************************/

	public abstract char[] decode ( char[] text, ref char[] decoded );
	public abstract wchar[] decode ( wchar[] text, ref wchar[] decoded );
	public abstract dchar[] decode ( dchar[] text, ref dchar[] decoded );


	/***************************************************************************

		Abstract methods to tell whether a string contains any unencoded
		entities.
		
		(Unfortunately template methods can't be abstract.)
	
	***************************************************************************/

	public abstract bool containsUnencoded ( char[] text );
	public abstract bool containsUnencoded ( wchar[] text );
	public abstract bool containsUnencoded ( dchar[] text );


	/***************************************************************************

		Abstract methods to tell whether a string contains any encoded entities.
		
		(Unfortunately template methods can't be abstract.)
	
	***************************************************************************/

	public abstract bool containsEncoded ( char[] text );
	public abstract bool containsEncoded ( wchar[] text );
	public abstract bool containsEncoded ( dchar[] text );


	/***************************************************************************

		Internal entity set
	
	***************************************************************************/

	protected E entities;


	/***************************************************************************

		Constructor.
	
	***************************************************************************/

	public this ( )
	{
		this.entities = new E();
	}


	/***************************************************************************

		Tells whether a string is fully encoded (ie contains no unencoded
		entities).
		
		Params:
			text = string to check

		Returns:
			true if there are no unencoded entities in the string
	
	***************************************************************************/

	public bool encoded ( Char ) ( Char[] text )
	{
		return !this.unencoded();
	}


	/***************************************************************************

		Tells whether a string is unencoded (ie contains one or more unencoded
		entities).
		
		Params:
			text = string to check
	
		Returns:
			true if there are unencoded entities in the string
	
	***************************************************************************/

	public bool unencoded ( Char ) ( Char[] text )
	{
		return this.containsUnencoded(text);
	}


	/***************************************************************************

		Static template method to convert from a char to another type.

		Template params:
			Char = type to convert to

		Params:
			c = character to convert

		Returns:
			converted character

	***************************************************************************/

	protected static Char[] charTo ( Char ) ( char c )
	{
		char[1] str;
		str[0] = c;
		return this.charTo!(Char)(str);
	}


	/***************************************************************************

		Static template method to convert from a char[] to another type.
	
		Template params:
			Char = type to convert to
	
		Params:
			text = string to convert
	
		Returns:
			converted string
	
	***************************************************************************/

	protected static Char[] charTo ( Char ) ( char[] text, ref Char[] output )
	{
        output.length = text.length;

		static if ( is(Char == dchar) )
		{
			return Utf.toString32(text, output);
		}
		else static if ( is(Char == wchar) )
		{
			return Utf.toString16(text, output);
		}
		else static if ( is(Char == char) )
		{
			return text;
		}
		else
		{
			static assert(false, This.stringof ~ ".charTo - template parameter must be one of {char, wchar, dchar}");
		}
	}


	/***************************************************************************

		Static template method to convert from a dchar to another type.
	
		Template params:
			Char = type to convert to
	
		Params:
			c = character to convert
	
		Returns:
			converted character
	
	***************************************************************************/

	protected static Char[] dcharTo ( Char ) ( dchar c, ref Char[] output )
	{
		dchar[1] str;
		str[0] = c;
		return this.dcharTo!(Char)(str, output);
	}

	/***************************************************************************

		Static template method to convert from a dchar[] to another type.
	
		Template params:
			Char = type to convert to
	
		Params:
			text = string to convert
	
		Returns:
			converted string
	
	***************************************************************************/

	protected static Char[] dcharTo ( Char ) ( dchar[] text, ref Char[] output )
	{
        output.length = text.length * 4; // Maximum one unicode character -> 4 bytes

        static if ( is(Char == dchar) )
		{
			return text;
		}
		else static if ( is(Char == wchar) )
		{
			return Utf.toString16(text, output);
		}
		else static if ( is(Char == char) )
		{
			return Utf.toString(text, output);
		}
		else
		{
			static assert(false, This.stringof ~ ".charTo - template parameter must be one of {char, wchar, dchar}");
		}
	}
}

