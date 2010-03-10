/******************************************************************************
    
    HTML named ISO-8859-1/-15 characters database lookup
    
    --
    
    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        November 2009: Initial release

    author:         David Eckardt

    --
    
    Description:

    Database lookup of Unicode characters of named HTML characters.
    
    --
    
 *****************************************************************************/

module ocean.text.html.HtmlTables;

/******************************************************************************

    Imports

 ******************************************************************************/

private import text.html.HtmlCharSets;

/******************************************************************************

    HTML entity character tables

******************************************************************************/

struct HtmlDecodingTables ( bool wide_char = true )
{
    /**************************************************************************

        Template instance alias

     **************************************************************************/

    alias HtmlEntity!(wide_char)    HtmlEntity_;
    
    /**************************************************************************

        Character type alias
    
     **************************************************************************/

    alias HtmlEntity_.Char          Char;
    
    /**************************************************************************

        Indicates whether UTF wide chars are enabled
    
    ***************************************************************************/
    
    static const UtfWide = HtmlEntity_.UtfWide;
    
    /**************************************************************************

        HTML character entities
    
    ***************************************************************************/

    private static HtmlEntity_[] html_chars;
    
    /**************************************************************************

        Static constructor; sorts the table
    
    ***************************************************************************/

    static this ( )
    {
        this.html_chars = HtmlCharSets!(wide_char).ISO8859_1_15.sort;
    }
    
    /**************************************************************************
    
        Returns the UTF value of the named HTML character "name" or 0 if the
        character is unknown.
        
        Params:
             name = HTML character name
            
        Returns:
             UTF character value or 0 on failure
    
     **************************************************************************/
    
    public static Char decode ( S ) ( S[] name )
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

struct HtmlEncodingTables ( bool wide_char = true )
{
    /**************************************************************************

        Template instance alias
    
     **************************************************************************/
    
    alias HtmlEntity!(wide_char)    HtmlEntity_;
    
    /**************************************************************************
    
        Character type alias
    
     **************************************************************************/
    
    alias HtmlEntity_.Char          Char;
    
    /**************************************************************************
    
        Indicates whether Unicode is enabled (when Char is a multi-byte type)
    
    ***************************************************************************/
    
    static const UtfWide = HtmlEntity_.UtfWide;
    
    /**************************************************************************
    
        HTML character entities
    
    ***************************************************************************/
    
    private static char[][Char] html_chars;
    
    /**************************************************************************
    
        Static constructor; fills the table
    
    ***************************************************************************/
    
    static this ( )
    {
        foreach (html_char; HtmlCharSets!(wide_char).ISO8859_1_15)
        {
            this.html_chars[html_char.code] = html_char.name;
        }
    }
    
    /**************************************************************************
    
        Returns the HTML character entity name of an UTF ISO-8859-1/-15
        character.
        
        Params:
             c = character
                         
        Returns:
             HTML character entity name
    
     **************************************************************************/
    
    
    static char[] encode ( Char c )
    {
        char[]* name = c in this.html_chars;
        
        assert (name, "no named ISO-8859-1/-15 HTML entity for character");
        
        return *name;
    }
}