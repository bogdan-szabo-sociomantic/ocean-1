/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    author:         Gavin Norman

	An abstract class encapsulating a set of entities for en/decoding. A typical
	example is the various html entities which are required to be encoded, for
	example:

		'&' should be encoded as "&amp;"

	The class should be implemented, and the entities() methods made to return
	the list of entities to be handled.

*******************************************************************************/

module ocean.text.entities.model.IEntitySet;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.text.utf.UtfString : InvalidUnicode;

debug
{
	private import tango.util.log.Trace;
}



/*******************************************************************************

	Abstract entity set class.

*******************************************************************************/

public abstract class IEntitySet
{
	/***************************************************************************

		An entity. Simply a tuple of a name and a unicode value (eg "amp", '&').
	
	***************************************************************************/

	public struct Entity
	{
		char[] name;
		dchar unicode;
	}


	/***************************************************************************

		Abstract method to return the list of entities.
	
	***************************************************************************/

	public abstract Entity[] entities ( );


	/***************************************************************************

		Gets the unicode character associated with the passed name.
		
		Template params:
			Char = character type of name
	
		Params:
			name = name to check
	
		Returns:
			unicode corresponding to name, or InvalidUnicode if name is not in
			the entity list
	
	***************************************************************************/

	public dchar getUnicode ( Char ) ( Char[] name )
	{
		foreach ( check_name, unicode; this )
		{
			if ( this.nameMatch(name, check_name) )
			{
				return unicode;
			}
		}

		return InvalidUnicode;
	}


	/***************************************************************************

		Gets the name associated with the passed unicode character.
		
		Params:
			unicode = unicode value to check
	
		Returns:
			name corresponding to unicode, or "" if unicode is not in the entity
			list
	
	***************************************************************************/

	public char[] getName ( dchar unicode )
	{
		foreach ( name, check_unicode; this )
		{
			if ( check_unicode == unicode )
			{
				return name;
			}
		}

		return "";
	}


	/***************************************************************************

		Checks whether the passed name is in the list of entities.
		
		Params:
			name = name to check
	
		Returns:
			true if name is an entity
	
	***************************************************************************/

	public bool opIn_r ( char[] name )
	{
		foreach ( ref entity; this.entities )
		{
			if ( this.nameMatch(name, entity.name) )
			{
				return true;
			}
		}

		return false;
	}


	/***************************************************************************

		Checks whether the passed name is in the list of entities.
		
		Params:
			name = name to check
	
		Returns:
			true if name is an entity
	
	***************************************************************************/

	public bool opIn_r ( wchar[] name )
	{
		foreach ( ref entity; this.entities )
		{
			if ( this.nameMatch(name, entity.name) )
			{
				return true;
			}
		}

		return false;
	}


	/***************************************************************************

		Checks whether the passed name is in the list of entities.
		
		Params:
			name = name to check
	
		Returns:
			true if name is an entity
	
	***************************************************************************/

	public bool opIn_r ( dchar[] name )
	{
		foreach ( ref entity; this.entities )
		{
			if ( this.nameMatch(name, entity.name) )
			{
				return true;
			}
		}

		return false;
	}


	/***************************************************************************

		Checks whether the passed unicode is in the list of entities.
		
		Params:
			unicode = unicode value to check
	
		Returns:
			true if unicode is an entity
	
	***************************************************************************/

	public bool opIn_r ( dchar unicode )
	{
		foreach ( ref entity; this.entities )
		{
			if ( entity.unicode == unicode )
			{
				return true;
			}
		}

		return false;
	}


	/***************************************************************************

		Checks whether the passed unicode is in the list of entities.
		
		Params:
			unicode = unicode value to check
	
		Returns:
			true if unicode is an entity

	***************************************************************************/

	public bool opIn_r ( wchar unicode )
	{
		return (cast(dchar)unicode) in this;
	}


	/***************************************************************************

		Checks whether the passed unicode is in the list of entities.
		
		Params:
			unicode = unicode value to check
	
		Returns:
			true if unicode is an entity
	
	***************************************************************************/

	public bool opIn_r ( char unicode )
	{
		return (cast(dchar)unicode) in this;
	}


	/***************************************************************************

		foreach iterator over the list of entities.

		foreach arguments exposed:
			char[] name = entity name
			dchar unicode = entity unicode value

	
	***************************************************************************/

	public int opApply ( int delegate ( ref char[], ref dchar ) dg )
	{
		int res;
		foreach ( ref entity; this.entities )
		{
			res = dg(entity.name, entity.unicode);
			if ( res )
			{
				break;
			}
		}

		return res;
	}


	/***************************************************************************

		Do the two passed names match?
		
		Template params:
			Char = character type of name
	
		Params:
			name = name to check
			entity_name = name of an entity
	
		Returns:
			true if the names match
	
	***************************************************************************/
	
	protected bool nameMatch ( Char ) ( Char[] name, char[] entity_name )
	{
		foreach ( i, c; name )
		{
			if ( c != entity_name[i] )
			{
				return false;
			}
		}
		return true;
	}
}

