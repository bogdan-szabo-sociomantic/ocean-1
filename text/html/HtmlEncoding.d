/*******************************************************************************

        D Module for UTF-8/HTML entitiy decoding

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Jan 2009: Initial release

        authors:        Lars Kirchhoff, Thomas Nicolai, David Eckardt,
        				Gavin Norman

        --

        Usage example:

        ---
            
            import ocean.text.Encoding;
            
            dchar[] content;
            
            Encode!(dchar) encode = new Encode!(dchar);
            
            // fill "content" with text
            
            Encode.repairUtf8(content);
            
            // "content" now is cleaned of "Ã£"-like malcoded UTF-8 characters
            
            Encode.decodeHtmlEntities(content);
            
            // all Unicode and ISO8859-1/15 (Latin 1/9) named character entities
            // in "content" are now replaced by their corresponding Unicode
            // characters
        
        ---
        
        Related:
        
        http://www.dsource.org/projects/tango/forums/topic/788#3263

        http://msdn.microsoft.com/workshop/author/dhtml/reference/charsets/charset2.asp
        http://msdn.microsoft.com/workshop/author/dhtml/reference/charsets/charset3.asp
        http://www.unicode.org/Public/MAPPINGS/OBSOLETE/UNI2SGML.TXT
        http://www.w3.org/TR/2002/REC-xhtml1-20020801/dtds.html#h-A2


*******************************************************************************/

module ocean.text.html.HtmlEncoding;

/******************************************************************************
 
    Imports
 
 ******************************************************************************/

private import ocean.text.html.HtmlCharSets;
private import ocean.text.html.HtmlDecoding;

private import tango.core.Array;

private import tango.stdc.stdio:  snprintf;
private import tango.stdc.string: strlen;

private import Utf = tango.text.convert.Utf;

debug
{
	private import tango.util.log.Trace;
}



/******************************************************************************

    HtmlEncoding class

 ******************************************************************************/

class HtmlEncoding ( bool wide_char = false, bool basic_only = false )
{
    /***************************************************************************

	    Entity decoder alias
	
	***************************************************************************/

	alias HtmlDecoding!(wide_char, basic_only) HtmlDecoder;


    /**************************************************************************

        Template instance alias
    
     **************************************************************************/
    
    alias HtmlEntity!(wide_char) HtmlEntity_;


    /**************************************************************************
    
        Character type alias
    
     **************************************************************************/
    
    alias HtmlEntity_.Char Char;


    /***************************************************************************

	    This type alias
	
	***************************************************************************/

    private alias typeof (this) This;


    /**************************************************************************
    
        HTML character entities which can be encoded
    
    ***************************************************************************/
    
    private static char[][Char] html_chars;


    /**************************************************************************
    
        Static constructor; fills the character table
    
    ***************************************************************************/
    
    static this ( )
    {
    	static if ( basic_only )
    	{
    		auto char_set = HtmlCharSets!(wide_char).Basic;
    	}
    	else
    	{
    		auto char_set = HtmlCharSets!(wide_char).ISO8859_1_15;
    	}

    	foreach (html_char; char_set )
        {
            this.html_chars[html_char.code] = html_char.name;
        }
    }


    /**************************************************************************
    
        Params:
            content = content to process
            
        Returns:
            this instance
     
     **************************************************************************/
    /+
    public This opCall ( ref Char[] content )
    {
        
        assert (false, "not implemented yet");
        
        return this;
    }
    +/


    /***************************************************************************

	    Checks whether the passed string contains any unencoded special
	    characters, and creates a new string containing encoded versions of
	    them.
	
		Params:
			content = string to convert
			replacement = output buffer for converted string
		
		Returns:
			converted string
	
	***************************************************************************/
	
	public static Char[] encodeUnencodedSpecialCharacters ( Char[] content, out Char[] replacement )
	{
		size_t last_special_char;
		foreach ( i, c; content )
		{
			if ( typeof(this).isUnencodedSpecialCharacter(content[i..$]) )
			{
				replacement ~= content[last_special_char..i];
				static if ( wide_char )
				{
					replacement ~= Utf.toString32("&" ~ typeof(this).html_chars[c] ~ ";");
				}
				else
				{
					replacement ~= typeof(this).html_chars[c];
				}
				last_special_char = i + 1;
			}
		}
	
		replacement ~= content[last_special_char..$];
		return replacement;
	}


    /***************************************************************************

	    Checks whether the passed string contains any special characters. (This
	    method does not take account of whether the characters are encoded or
	    not, it just does a simple string scan.)

		Params:
			content = string to scan
		
		Returns:
			true if the string contains any special characters, false otherwise
	
	***************************************************************************/

    public static bool containsSpecialCharacters ( Char[] content )
    {
    	foreach ( c; content )
    	{
    		if ( c in this.html_chars )
    		{
    			return true;
    		}
    	}

    	return false;
    }


    /***************************************************************************

	    Checks whether the passed string contains any *unencoded* special
	    characters.
	
		Params:
			content = string to scan
		
		Returns:
			true if the string contains any unencoded special characters, false
			otherwise
	
	***************************************************************************/

    public static bool containsUnencodedSpecialCharacters ( Char[] content )
    {
    	foreach ( i, c; content )
    	{
    		if ( typeof(this).isUnencodedSpecialCharacter(content[i..$]) )
    		{
    			return true;
    		}
    	}

    	return false;
    }


    /***************************************************************************

	    Checks whether the passed string starts with an unencoded special
	    character.
	
		Params:
			content = string to scan
		
		Returns:
			true if the string starts with an unencoded special character, false
			otherwise
	
	***************************************************************************/

    public static bool isUnencodedSpecialCharacter ( Char[] content )
    {
    	if ( content[0] in typeof(this).html_chars )
    	{
        	if ( content[0] == '&' )
        	{
        		// The following characters must form a valid character code
        		auto entity = HtmlDecoder.parseEncodedEntity(content);
        		if ( entity.length )
        		{
        			auto decoded_entity = HtmlDecoder.decodeHtmlEntity(entity);
	        		return decoded_entity == HtmlDecoder.zero_char;
        		}
        		else
        		{
        			return true;
        		}
        	}
        	else
        	{
        		return true;
        	}
    	}

    	return false;
    }


    /**************************************************************************
    
        Returns the HTML character entity name of an UTF ISO-8859-1/-15
        character.
        
        Params:
             c = character
                         
        Returns:
             HTML character entity name
    
     **************************************************************************/
    
    public static char[] encodeCharacter ( Char c )
    {
        char[]* name = c in this.html_chars;
        
        if (name)
        {
            return *name;
        }
        else
        {
            char[0x10] buf;
            
            snprintf(buf.ptr, buf.length - 1, "#x%x", c);
            
            return buf[0 .. strlen(buf.ptr)].dup;
        }
        
    }
}

