/*******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Jan 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        D Module for Html/Xml Encoding methods

        --

        Usage example:

            char[] encoded = html_entity_decode("Ronnie O&#039;Sullivan");
           
        ---
        
        TODO:
        
            1. Implementation of Numeric Replacements (see end of module for example)
            2. Size of interim buffer needs to be smaller
        
        
        ---
        
        Important:
        
        tango.text.Util: substitute (0.99.8) 
        cannot be used because its a memory leak:
        
        foreach (s; patterns (source, match, replacement))
                    output ~= s; --> this produces lots of memory re-allocations
        
        ---
        
        Related:
        
        http://www.dsource.org/projects/tango/forums/topic/788#3263

        http://msdn.microsoft.com/workshop/author/dhtml/reference/charsets/charset2.asp
        http://msdn.microsoft.com/workshop/author/dhtml/reference/charsets/charset3.asp
        http://www.unicode.org/Public/MAPPINGS/OBSOLETE/UNI2SGML.TXT
        http://www.w3.org/TR/2002/REC-xhtml1-20020801/dtds.html#h-A2


********************************************************************************/

module  ocean.text.Encoding;

private import ocean.text.StringReplace;

private import Util = tango.text.Util;

private import Math = tango.math.Math;

private import tango.io.Stdout;
private import tango.io.Console;

private import Integer = tango.text.convert.Integer;

/*******************************************************************************

    Encode class

********************************************************************************/

class Encode ( T )
{
    /**************************************************************************

        Properties

     **************************************************************************/
    
    
    struct entity 
    {
        T[] replacement;
        T[] entity;
    }
    
    public static const T UTF8_MAGIC_CHAR = 0xC3; // 'Ã'
    
    private     entity[]                basic_entities  = 
                                        [
                                             { "\"" , "&quot;"  },
                                             { "<"  , "&lt;"    },
                                             { ">"  , "&gt;"    },
                                             { "&"  , "&amp;"   },
                                             { " "  , "&;nbsp;" },
                                             { " "  , "&nbsp;"  }
                                         ];
    
    public StringReplace!(T) stringReplace;
    
    /**************************************************************************
    
        Constructor

     **************************************************************************/
    
    
    this ( )
    {
        this.stringReplace = new StringReplace!(T);
    }
    
    
    /*******************************************************************************
    
        Public methods

    ********************************************************************************/
    
    
    /**
     * Replace HTML entities in-place
     * 
     * Params:
     *     string = input string
     *     
     * Returns:
     *     string after replacement
     */
    public Encode html_entity_decode ( ref T[] content )
    {
        foreach (basic_entity; basic_entities)
        {
            this.stringReplace.replacePattern(content, basic_entity.entity, basic_entity.replacement);
        }
        
        return this;
    }
    
    

    
    /**
     * Scans "input" for malcoded Unicode characters and replaces them by the
     * correct ones.
     * 
     * Notes:
     * - The character replacement is done in-place and changes the length of
     *   "input": The length is decreased by the number of malcoded characters
     *   found (two malcoded characters form one correct character).
     *   
     * - The search/replace rule is as follows: "input" is scanned for
     *   characters with the value 0xC3 ('Ãƒ'). If that character is followed by
     *   a character with a value of 0x80 or above, the character and its
     *   follower are considered two erroneously Unicode coded raw bytes and the
     *   UTF-8 character that consists of these two bytes is composed.
     * 
     * Example:
     * 
     *   String with malcoded characters:
     *     "AbrahÃ£o, JosÃ© Jorge dos Santos; Instituto AgronÃ´mico do ParanÃ¡"
     * 
     *   Resulting string:
     *      "Abrahão, José Jorge dos Santos; Instituto Agronômico do Paraná"
     * 
     * Params:
     *     content = UTF-8 encoded text content to process
     *     
     * Returns:
     *     the content after processing
     */
    public Encode repairUtf8 ( ref T[] content )
    {
        if (is (T == wchar_t)) // do not do anything on non-wide characters
        {
            this.stringReplace.replaceDecodeChar(content, this.UTF8_MAGIC_CHAR, &this.decodeUtf8);
        }
        
        return this;
    }
    
    
    
    /**************************************************************************
    
        Private methods: Decoder delegates and their subroutines
    
    ***************************************************************************/
    
    
    /**
     * Composes an UTF-8 character from input[source .. source + 1] and puts it
     * to input[destin], if input[source + 1] has a value above 128.  
     * 
     * Params:
     *     content = content string to get the characters from and put the
     *               result to
     *     source  = start index of characters to process
     *     destin  = index to put the resulting character
     *     
     * Returns:
     *     1 if the composition was done or 0 otherwise
     * 
     */
    private uint decodeUtf8 ( ref T[] content, uint source, uint destin )
    {
        if (content[source + 1] & 0x80)
        {
            content[destin] = this.composeUtf8Char(content[source], content[source + 1]);
            
            return 1;
        }
        else
        {
            return 0;
        }
    }
    
    
    /**
     * Scans "input" for HTML entities representing Unicode characters and
     * replaces them by the actual characters.
     * 
     * Example:
     *
     * String with a HTML Unicode entity:
     *     "Doroth&#xE9;e Boccanfuso"
     *     
     * Resulting string:
     *      "DorothÃ©e Boccanfuso"
     * 
     * Params:
     *     content = text content to process
     *     
     * Returns:
     *     the content after processing
     */
    public Encode cleanHtmlUnicode ( ref T[] content )
    {
        this.stringReplace.replaceDecodePattern(content, "&#", &this.decodeHtmlUnicode);
        
        return this;
    }

    
    
    /**
     * Checks if "content[source .. $]" starts with a valid HTML Unicode entity.
     * The trailing "&#" is not checked, only the entity content and terminating
     * ';'. If such an entity is found, the corresponding character is put to
     * "input[destin]".
     * 
     * Params:
     *     content = string which may start with a HTML Unicode entity at
     *               "input[source]"
     *     source  = start index
     *     destin  = index to put the resulting character
     *     
     * Returns:
     *     the number of characters to remove from "content"
     */
    private uint decodeHtmlUnicode ( ref T[] content, uint src_pos, uint dst_pos )
    {
        try
        {
            T[] entity = this.parseHtmlEntity(content[src_pos .. $]);
            
            assert (entity.length);
            
            if (entity[0] == 'x' || entity[0] == 'X')
            {
                assert (entity.length >= 2);
                
                content[dst_pos] = cast (T) Integer.toInt(entity[1 .. $], 0x10);
            }
            else
            {
                content[dst_pos] = cast (T) Integer.toInt(entity, 10);
            }
            
            return entity.length + 2;
        }
        catch
        {
           return 0;
        }
    }
    
    
    
    /**
     * Parses "entity" which is (hopefully) a HTML entity string. If a ';' is
     * found between character 2 and 16, and there is no white space character
     * before the ';', the slice between character 2 and the ';' is returned,
     * otherwise null is returned.
     * Note: The trailing "&#" is not checked by this method; it is assumed that
     * the caller already checked it.
     * 
     * Params:
     *      entity = HTML entity string to parse
     *     
     * Returns:
     *      The content of the entity if parsing was successfull or null on
     *      failure.
     */
    private T[] parseHtmlEntity ( T[] entity )
    {
        uint semicolon = 0;
        
        if (entity.length <= 2)
        {
            return null;
        }
        
        foreach (i, c; entity[2 .. Math.min($, 0x10)])
        {
            bool ko = false;
            
            if (c == ';')
            {
                semicolon = i + 1;
                
                break;
            }
            
            ko |= Util.isSpace(c);
            ko |= (c == '&');
            
            if (ko) break;
        }
        
        if (semicolon <= 2)
        {
            return null;
        }
        
        return entity[2 .. semicolon + 1];
    }
    
    
    
    /**
     * Composes an Unicode character from two Unicode malcoded bytes; taken from
     * tango.text.convert.Utf.toString()
     * 
     * Params:
     *     lb = lower byte
     *     ub = upper byte
     *     
     * Returns:
     *     composed Unicode character
     */
    public static T composeUtf8Char ( T lb, T ub )
    {
        return (((lb & 0x1F) << 6) | (ub & 0x3F));
    }
    
    /+
    
    // Lars' implementation; caused "overlapping array copy" exception
    
    private     T[]                     buffer;  
    
    /**
     * Replace string without heap activity
     * 
     * Params:
     *     input = input string
     *     search = search string  
     *     replacement = replace string
     */    
    public void replace ( inout T[] input, T[] search, T[] replacement )
    {   
        int     in_idx = 0, out_idx = 0, pattern_idx = 0, add_len = 0; 
        int     input_len = input.length,    
                search_len = search.length,
                replacement_len = replacement.length;
        bool    grow = false;
        
        if (this.buffer.length < input_len)
        {
            this.buffer.length = input_len;
        }
       
        // check if the replacement string is larger than the search string
        // get the length difference in order to grow the buffer on each replacement  
        if (search_len < replacement_len)
        {
            add_len = replacement_len - search_len;
            grow = true;        
        }
        
        if ((pattern_idx = Util.locatePattern!(T)(input, search, pattern_idx)) < input_len)
        {                  
            do
            {
                // check if there is something to copy between search strings and 
                // and if yes copy it
                if (in_idx != pattern_idx)
                {
                    this.buffer[out_idx..out_idx+input[in_idx..pattern_idx].length] = input[in_idx..pattern_idx];
                }
                            
                // set new positions
                out_idx = out_idx + (pattern_idx - in_idx);
                in_idx = in_idx + (pattern_idx - in_idx);
                
                // copy the replacement string into buffer            
                this.buffer[out_idx..out_idx+replacement_len] = replacement[0..$];
                
                // set new positions 
                out_idx += replacement_len;
                in_idx += search_len;     
                
                // resize buffer if replacement is larger then search string
                if (grow)
                {
                    this.buffer.length = this.buffer.length + add_len;
                }
            }
            while ((pattern_idx = Util.locatePattern!(T)(input, search, pattern_idx + search_len)) < input_len);
            
            // copy the rest
            this.buffer[out_idx..out_idx+input[in_idx..$].length] = input[in_idx..$];
            out_idx += input[in_idx..$].length;
            
            input.length = out_idx;            
            input[] = this.buffer[0..out_idx];            
        }
    }
    +/
}