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
            
            encode.repairUtf8(content);
            
            // "content" now is cleaned of "Ã£"-like malcoded UTF-8 characters
            
            encode.decodeHtmlEntities(content);
            
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

module  ocean.text.Encoding;

/******************************************************************************
 
    Imports
 
 ******************************************************************************/

private import ocean.text.StringReplace;
private import ocean.text.HtmlChars;

private import Ctype    = tango.stdc.ctype:             isspace;
private import WCtype   = tango.stdc.wctype:            iswspace;

private import Integer  = tango.text.convert.Integer:   toInt;

private import Math     = tango.math.Math:              min;

/******************************************************************************

    Encode class

 ******************************************************************************/

class Encode ( T )
{
    /**************************************************************************
    
        This alias for chainable methods
     
     **************************************************************************/

    private alias typeof (this) This;
    
    /**************************************************************************
    
        Indicates whether T == char and therefore Unicode is disabled
     
     **************************************************************************/
    
    private const bool UNICODE_DISABLED = is (T == char);
    
    static if (UNICODE_DISABLED)
    {
        pragma (msg, This.stringof ~ ": using type '" ~ T.stringof ~ "'; Unicode disabled");
        
        private alias Ctype.isspace cIsSpace;
    }
    else
    {
        private alias WCtype.iswspace cIsSpace;
    }
    
    /**************************************************************************
    
        Magic character for malcoded UTF8 detection
     
     **************************************************************************/
    
    public static const T UTF8_MAGIC_CHAR = 0xC3; // 'Ã'
    
    /**************************************************************************
    
        StringReplace instance
     
     **************************************************************************/

    private StringReplace!(T) stringReplace;
    
    /**************************************************************************
    
        HTML entities lookup instance
     
     **************************************************************************/

    private Html8859_1_15!(T) html8859_1_15;
    
    /**************************************************************************
    
        Constructor

     **************************************************************************/
    
    this ( )
    {
        this.stringReplace = new StringReplace!(T);
        
        this.html8859_1_15 = new Html8859_1_15!(T);
    }
    
    /**************************************************************************
    
        Scans "input" for HTML entities representing Unicode characters or named
        ISO8859-1/-15 (Latin 1/9) characters and replaces them by the
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
    
    public This decodeHtmlEntities ( ref T[] content )
    {
        this.stringReplace.replacePattern(content, "&amp;", "&");
        
        this.stringReplace.replaceDecodeChar(content, '&', &this.decodeHtmlCharEntity);
        
        return this;
    }
    
    /**************************************************************************
        
        Scans "input" for malcoded Unicode characters and replaces them by the
        correct ones.
        
        Notes:
        - The character replacement is done in-place and changes the length of
          "input": The length is decreased by the number of malcoded characters
          found (two malcoded characters form one correct character).
          
        - The search/replace rule is as follows: "input" is scanned for
          characters with the value 0xC3 ('Ã'). If that character is followed by
          a character with a value of 0x80 or above, the character and its
          follower are considered two erroneously Unicode coded raw bytes and the
          UTF-8 character that consists of these two bytes is composed.
        
        Example:
        
          String with malcoded characters:
            "AbrahÃ£o, JosÃ© Jorge dos Santos; Instituto AgronÃ´mico do ParanÃ¡"
        
          Resulting string:
             "Abrahão, José Jorge dos Santos; Instituto Agronômico do Paraná"
        
        Params:
            content = UTF-8 encoded text content to process
            
        Returns:
            this instance
     
     **************************************************************************/
    
    public This repairUtf8 ( ref T[] content )
    {
        static if (!UNICODE_DISABLED)
        {
            this.stringReplace.replaceDecodeChar(content, this.UTF8_MAGIC_CHAR, &this.decodeUtf8);
        }
        
        return this;
    }
    
    /**************************************************************************
    
        Composes an Unicode character from two Unicode malcoded bytes
        
        (Taken from tango.text.convert.Utf.toString())
        
        Params:
            lb = lower byte
            ub = upper byte
            
        Returns:
            composed Unicode character
        
     **************************************************************************/
    
    public static T composeUtf8Char ( T lb, T ub )
    {
        return (((lb & 0x1F) << 6) | (ub & 0x3F));
    }

    /**************************************************************************
    
        Private methods: Decoder delegates and their subroutines
    
    ***************************************************************************/
    
    
    /**************************************************************************
        
        Composes an UTF-8 character from input[source .. source + 1] and puts it
        to input[destin], if input[source + 1] has a value above 128.  
        
        Params:
            content = content string to get the characters from and put the
                      result to
            source  = start index of characters to process
            destin  = index to put the resulting character
            
        Returns:
            1 if the composition was done or 0 otherwise
        
     **************************************************************************/
    
    private size_t decodeUtf8 ( ref T[] content, size_t src_pos, size_t dst_pos )
    {
        if (content[src_pos + 1] & 0x80)
        {
            content[dst_pos] = this.composeUtf8Char(content[src_pos], content[src_pos + 1]);
            
            return 1;
        }
        else
        {
            return 0;
        }
    }
    
    
    /**************************************************************************
    
        Checks if "content" contains a Unicode or named ISO8859-1/15 HTML
        character entity string starting at "src_pos". If so, the corresponding
        Unicode character is put to "content[dst_pos]".
        
        Params:
            content = content to process
            src_pos = start position (index) of the HTML character entity string
            dst_pos = position (index) to put the resulting character
            
        Returns:
            the number of characters to remove from "content" which is the entity
            length - 1 on success or 0 otherwise 

     **************************************************************************/
    
    private size_t decodeHtmlCharEntity ( ref T[] content, size_t src_pos, size_t dst_pos )
    {
        T[] entity = this.parseHtmlEntity(content[src_pos .. $]);
        
        if (entity) if (entity.length >= 3)
        {
            T chr = 0;
            
            if (entity[1] == '#')
            {
                static if (!UNICODE_DISABLED)
                {
                    chr = this.decodeHtmlUnicodeEntity(entity);
                }
            }
            else
            {
                chr = this.decodeHtml8859_1_15Entity(entity);
            }
            
            if (chr)
            {
                content[dst_pos] = chr;
                
                return entity.length - 1;
            }
        }
        
        return 0;
    }
    
    
    
    /**************************************************************************
    
        Converts a named ISO8859-1/15 (Latin 1/9) HTML character entity string to
        the corresponding Unicode character.
        
        Params:
            entity = entity content to convert; trailing '&' and terminating ';'
                     is not checked
            
        Returns:
            the Unicode character or 0 on failure
        
     **************************************************************************/
    private T decodeHtml8859_1_15Entity ( T[] entity )
    {
        T chr = 0;
        
        if (entity) if (entity.length >= 3)
        {
            T first = entity[1];
            
            if ((first >= 'a' && first <= 'z') ||
                (first >= 'A' && first <= 'Z') ||
                (first >= '0' && first <= '9'))
            {
                return this.html8859_1_15.lookup(entity[1 .. $ - 1]);
            }
        }
        
        return 0;
    }
    
    
    
    /**************************************************************************
    
        Converts the content of a HTML Unicode entity to the corresponding
        Unicode character. A HTML Unicode entity follows one of the schemes
        
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
    
    private T decodeHtmlUnicodeEntity ( T[] entity )
    {
        try
        {
            assert (entity.length >= 4);
            
            if (entity[2] == 'x' || entity[2] == 'X')
            {
                return cast (T) Integer.toInt(entity[3 .. $ - 1], 0x10);
            }
            else
            {
                return cast (T) Integer.toInt(entity[2 .. $ - 1], 10);
            }
        }
        catch
        {
           return 0;
        }
    }
    
    
    
    /**************************************************************************
    
        Parses "entity" which is (hopefully) a HTML entity string. The criteria
        are:
        
         - character 0 is '&',
         - the length of "entity" is at least 3,
         - between characters 1 and 16 one ';' can be found,
         - no white space character or '&' before the first ';'.
         
        If "entity" comlies with all of these, slice until the ';' is returned,
        otherwise null is returned.
        
        Params:
             entity = HTML entity string to parse
            
        Returns:
             The entity if parsing was successfull or null on failure.
             
     **************************************************************************/
    
    private T[] parseHtmlEntity ( T[] entity )
    {
        size_t semicolon = 0;
        
        if (entity.length <= 2)
        {
            return null;
        }
        
        if (entity[0] != '&')
        {
            return null;
        }
        
        foreach (i, c; entity[1 .. Math.min($, 0x10)])
        {
            bool ko = false;
            
            if (c == ';')
            {
                semicolon = i + 1;
                
                break;
            }
            
            ko |= !!cIsSpace(c);
            ko |= (c == '&');
            
            if (ko) break;
        }
        
        if (semicolon <= 2)
        {
            return null;
        }
        
        return entity[0 .. semicolon + 1];
    }
}