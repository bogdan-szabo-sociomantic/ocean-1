/******************************************************************************

        D Module for UTF-8/HTML entitiy decoding

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Jan 2009: Initial release

        authors:        Lars Kirchhoff, Thomas Nicolai & David Eckardt

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


 ******************************************************************************/

module ocean.text.html.HtmlDecoding;

/******************************************************************************
 
    Imports
 
 ******************************************************************************/

private import ocean.text.html.HtmlCharSets;

private import ocean.text.utf.GlibUnicode;

private import ocean.text.util.StringSearch;
private import ocean.text.util.StringReplace;

private import Integer  = tango.text.convert.Integer:   toInt;

private import Math     = tango.math.Math:              min;

private import tango.io.Stdout;

private import tango.core.Array;



/******************************************************************************

    HtmlEncoding class

 ******************************************************************************/

deprecated class HtmlDecoding ( bool wide_char = false, bool basic_only = false )
{
    /**************************************************************************

        Template instance alias
    
     **************************************************************************/
    
    alias HtmlEntity!(wide_char)             HtmlEntity_;
    
    /**************************************************************************
    
        Template instance aliases
     
     **************************************************************************/

    alias StringSearch!(wide_char)  StringSearch_;
    
    /**************************************************************************
    
        Content character type alias
     
     **************************************************************************/

    alias StringSearch_.Char        Char;

    /**************************************************************************
    
        Character type alias for HTML entities; always wide character
     
     **************************************************************************/

    alias HtmlEntity_.Char          HtChar;
    
    /**************************************************************************
    
        This alias for chainable methods
     
     **************************************************************************/

    private alias typeof (this) This;
    
    /**************************************************************************
    
        HTML character entities
    
    ***************************************************************************/
    
    private static HtmlEntity_[] html_chars;

    /**************************************************************************
    
        StringReplace instance
     
     **************************************************************************/

    private StringReplace!(wide_char) stringReplace;
    
    /**************************************************************************
    
        Static constructor; sorts the table of entities
    
    ***************************************************************************/
    
    static this ( )
    {
        static if ( basic_only )
        {
        	this.html_chars = HtmlCharSets!(wide_char).Basic.sort;
        }
        else
        {
        	this.html_chars = HtmlCharSets!(wide_char).ISO8859_1_15.sort;
        }
    }

    /**************************************************************************
    
        Constructor

     **************************************************************************/
    
    this ( )
    {
        this.stringReplace = new StringReplace!(wide_char);
    }
    
    /**************************************************************************
    
        Scans content for HTML entities representing Unicode characters or named
        ISO8859-1/-15 (Latin 1/9) characters and replaces them in-place by the
        corresponding Unicode letters.
        Note: Since the character entity escape literal '&' itself may be
        represented as the "&amp;" entity, first all occurrences of "&amp;" are
        replaced by '&'.
        
        Examples:
             Result for all of the example input strings: 
                 Diego Mauricio Riaño-Pachón
        
             Input example 1 -- named ISO8859-1 entities:
                 Diego Mauricio Ria&ntilde;o-Pach&oacute;n
                 
             Input example 2 -- Unicode entities:
                 Diego Mauricio Ria&#xf1;o-Pach&#xf3;n
             
             Input example 3 -- both with "&amp;" instead of '&':
                 Diego Mauricio Ria&amp;#xf1;o-Pach&amp;oacute;n
        
        Params:
            content = content to process
            
        Returns:
            this instance
     
     **************************************************************************/
    
    public This opCall ( ref Char[] content )
    {
        this.stringReplace.replacePattern(content, "&amp;", "&");
        
        this.stringReplace.replaceDecodeChar(content, '&', &this.decodeReplaceHtmlEntity);
        
        return this;
    }


    /***************************************************************************

		Checks whether the passed string contains any encoded entities.

	    Params:
	        content = content to process
	        
	    Returns:
	        true if any encoded entities are found, false otherwise
	 
	***************************************************************************/

    public static bool containsEncodedEntities ( Char[] content )
    {
    	Char[] to_check = content;
    	while ( to_check.length )
    	{
    		// Find an '&' which might be the start of an entity
    		const Char[] ampersand = "&";
    		auto StartNotFound = to_check.length;

    		auto start_pos = to_check.find(ampersand);
    		if ( start_pos != StartNotFound )
    		{
    			// See if a matching ';' exists
    			auto entity = typeof(this).parseEncodedEntity(to_check[start_pos..$]);
    			if ( entity.length )
    			{
    				// See if it is a valid entity
    				return typeof(this).decodeHtmlEntity_(entity) != 0;
    			}
    		}
    		else
    		{
    			return false;
    		}

    		to_check = to_check[start_pos + 1..$];
    	}

    	return false;
    }


    /**************************************************************************
    
	    Parses "entity" which is (hopefully) a HTML entity string. The criteria
	    are:
	    
	     a) length of "entity" is at least 3,
	     b) character 0 is '&',
	     c) a ';' between characters 1 and 16,
	     d) no white space character or '&' before the first ';'.
	     e) first ';' is behind character 2
	     
	    If "entity" complies with all of these, slice until the ';' is returned,
	    otherwise null.
	    
	    Params:
	         entity = HTML entity string to parse
	        
	    Returns:
	         The entity if parsing was successfull or null on failure.
	         
	 **************************************************************************/
	
	public static Char[] parseEncodedEntity ( Char[] entity )
	{
	    size_t semicolon = 0;
	    
	    if (entity.length <= 2)                         // a) criterium
	    {
	        return "";
	    }
	    
	    if (entity[0] != '&')                           // b) criterium
	    {
	        return "";
	    }
	    
	    foreach (i, c; entity[1 .. Math.min($, 0x10)])  // c) criterium
	    {
	        bool ko = false;
	        
	        if (c == ';')
	        {
	            semicolon = i + 1;
	            
	            break;
	        }
	        
	        ko |= !!StringSearch_.isSpace(c);                 // d) criterium
	        ko |= (c == '&');                           // d) criterium
	        
	        if (ko) break;
	    }
	    
	    if (semicolon <= 2)                             // e) criterium
	    {
	        return "";
	    }
	    
	    return entity[0 .. semicolon + 1];
	}


    static if (wide_char)
    {
        /**********************************************************************
        
            Converts a HTML character entity string to an Unicode multi-byte
            character. The entity may be either
                - a Unicode entity (like "&#xE1;" for 'á') or
                - a named ISO8859-1/15 (Latin 1/9) entity (like "&szlig;" for 'ß').
            
            Params:
                entity = entity content to convert; trailing '&' and terminating ';'
                         is not checked
                
            Returns:
                the Unicode character or 0 on failure
            
         **********************************************************************/

        public static Char decodeHtmlEntity ( Char[] entity )
        {
            return decodeHtmlEntity_(entity);
        }

        public static const Char zero_char = 0;
    }
    else
    {
        /**********************************************************************
        
            Converts a HTML character entity string to an UTF-8 string holding
            the Unicode character. The entity may be either
                - a Unicode entity (like "&#xE1;" for 'á') or
                - a named ISO8859-1/15 (Latin 1/9) entity (like "&szlig;" for 'ß').
            
            Params:
                entity = entity content to convert; trailing '&' and terminating ';'
                         is not checked
                
            Returns:
                the Unicode character or 0 on failure
            
         **********************************************************************/

        public static Char[] decodeHtmlEntity ( Char[] entity )
        {
            return GlibUnicode.toUtf8(decodeHtmlEntity_(entity));
        }

        public static const Char[] zero_char = "\0";
    }


    /**************************************************************************
    
	    Checks if content contains a Unicode or named ISO8859-1/-15 HTML
	    character entity string starting at src_pos. If so, the corresponding
	    Unicode character is put to content[dst_pos].
	    
	    Params:
	        content = content to process
	        src_pos = start position (index) of the HTML character entity string
	        dst_pos = position (index) to put the resulting character
	        length  = number of characters put to content
	        
	    Returns:
	        number of characters replaced in content, which is the
	        entity length on success or 0 otherwise 
	
	 **************************************************************************/
	
	private size_t decodeReplaceHtmlEntity ( Char[] content, out Char[] replacement )
	{
	    Char[] entity = this.parseEncodedEntity(content);
	    
	    size_t replaced = 0;
	    
	    if (entity.length >= 4)
	    {
	        replaced = entity.length;
	        
	        static if (wide_char)
	        {
	            Char chr = this.decodeHtmlEntity(entity);
	                
	            if (chr)
	            {
	                replacement = [chr];
	            }
	        }
	        else
	        {
	            Char[] chr = this.decodeHtmlEntity(entity);
	            
	            if (chr.length && chr.length <= entity.length)
	            {
	                replacement = chr;
	            }
	        }
	    }
	    
	    return replaced;
	}


    /**************************************************************************
    
        Converts a HTML character entity string to an Unicode character. The
        entity may be either
            - a Unicode entity (like "&#xE1;" for 'á') or
            - a named ISO8859-1/15 (Latin 1/9) entity (like "&szlig;" for 'ß').
        
        Params:
            entity = entity content to convert; trailing '&' and terminating ';'
                     is not checked
            
        Returns:
            the Unicode character or 0 on failure
        
     **************************************************************************/

    private static HtChar decodeHtmlEntity_ ( Char[] entity )
    {
        HtChar chr =  0;
        
        assert (entity.length >= 2, "HTML character entity too short");
        assert (entity[0] == '&' && entity[$ - 1] == ';', "invalid HTML character entity");
        
        if (entity.length)
        {
            if (entity[1] == '#')
            {
                chr = decodeHtmlUnicodeEntity(entity);
            }
            else
            {
                chr = decodeHtml8859_1_15Entity(entity);
            }
        }
        
        return chr;
    }
    
    /**************************************************************************
    
        Converts a named ISO8859-1/15 (Latin 1/9) HTML character entity to a
        Unicode character.
        
        Params:
            entity = entity content to convert; trailing '&' and terminating ';'
                     is not checked
            
        Returns:
            the Unicode character or 0 on failure
        
     **************************************************************************/

    private static HtChar decodeHtml8859_1_15Entity ( Char[] entity )
    {
        HtChar chr = 0;
        
        if (entity) if (entity.length >= 3)
        {
            if (StringSearch_.isAlNum(entity[1]))
            {
                chr = decodeEntity(entity[1 .. $ - 1]);
            }
        }
        
        return chr;
    }

    /**************************************************************************
    
        Converts a HTML Unicode entity to a Unicode character. A HTML Unicode
        entity follows one of the schemes
        
             &#<decimal Unicode>; 
        or
             &#x<hexadecimal Unicode>;
             
        in a case insensitive way.
        
        Examples:
        
             Entity      Character       Unicode hex (dec)
             "&#65;"     'A'             0x41 (65)
             "&#xE1;"    'á'             0xE1 (225)
             "&#Xf1;"    'ñ'             0xF1 (241)
        
        Params:
            entity = entity content to convert; trailing "&#" and terminating ';'
                     is not checked
            
        Returns:
            the Unicode character or 0 on failure
     
     **************************************************************************/
    
    private static HtChar decodeHtmlUnicodeEntity ( Char[] entity )
    {
        HtChar chr = 0;
        
        if (entity) if (entity.length >= 4) try
        {
            if (entity[2] == 'x' || entity[2] == 'X')
            {
                chr = cast (HtChar) Integer.toInt(entity[3 .. $ - 1], 0x10);
            }
            else
            {
                chr = cast (HtChar) Integer.toInt(entity[2 .. $ - 1], 10);
            }
        }
        catch {}
        
        return chr;
    }


    /**************************************************************************
    
        Returns the UTF value of the named HTML character "name" or 0 if the
        character is unknown.
        
        Params:
             name = HTML character name
            
        Returns:
             UTF character value or 0 on failure
    
     **************************************************************************/
    
    private static HtChar decodeEntity ( S ) ( S[] name )
    {
        uint start;
        uint index;
        
        uint c = 0;
        
        bool match = false;
        
        foreach (i, item; this.html_chars) // seek to first html_char element of same length as "name"
        {
            match = (item.name.length == name.length);
            
            if (match)
            {
                start = i;
                break;
            }
        }
        
        if (match)
        {
            match = false;
            
            foreach (i, item; this.html_chars[start .. $]) // iterate over elements of html_char
            {
                bool ok = true;
                
                ok &= (item.name[c] <= name[c]);
                ok &= (item.name.length == name.length);
                
                if (ok) 
                {
                    match = (item.name[c] == name[c]);
                    
                    while ((c < name.length) && match)  // iterate over matching name characters
                    {
                        match = (item.name[c] == name[c]);
                        
                        c += match;
                    }
                    
                    if (c == name.length) // end of name reached and match => found
                    {
                        if (match)
                        {
                            index = i;
                            break;
                        }
                        else                // end of name reached and no match => not found
                        {
                            return 0;
                        }
                    }
                }
                else
                {
                    return 0;
                }
            }
            
            return this.html_chars[start + index].code;
        }
        
        return 0;
    } // lookup

    
}