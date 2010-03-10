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

module ocean.text.html.HtmlEncoding;

/******************************************************************************
 
    Imports
 
 ******************************************************************************/

private import text.html.HtmlCharSets;

private import tango.stdc.stdio:  snprintf;
private import tango.stdc.string: strlen;

/******************************************************************************

    HtmlEncoding class

 ******************************************************************************/

class HtmlEncoding ( bool wide_char = false )
{
    /**************************************************************************

        Template instance alias
    
     **************************************************************************/
    
    alias HtmlEntity!()             HtmlEntity_;
    
    /**************************************************************************
    
        Character type alias
    
     **************************************************************************/
    
    alias HtmlEntity_.Char          Char;
    
    private alias typeof (this) This;
    
    /**************************************************************************
    
        HTML character entities
    
    ***************************************************************************/
    
    private static char[][Char] html_chars;
    
    
    private Char[]        buf;
    
    /**************************************************************************
    
        Static constructor; fills the table
    
    ***************************************************************************/
    
    static this ( )
    {
        foreach (html_char; HtmlCharSets!().ISO8859_1_15)
        {
            this.html_chars[html_char.code] = html_char.name;
        }
    }
    
    this ( )
    {
        this.buf = new Char[0x100];
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
    /**************************************************************************
    
        Returns the HTML character entity name of an UTF ISO-8859-1/-15
        character.
        
        Params:
             c = character
                         
        Returns:
             HTML character entity name
    
     **************************************************************************/
    
    
    static char[] encodeEntity ( Char c )
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