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

private import Util = tango.text.Util;

private import tango.io.Stdout;



/*******************************************************************************

    Encode class

********************************************************************************/

class Encode
{
    struct entity 
    {
        char[] replacement;
        char[] entity;
    }
                                        
    private     char[]                  buffer;  
    private     entity[]                basic_entities  = 
                                        [
                                             { "\"" , "&quot;"  },
                                             { "'"  , "&#039;"  },
                                             { "'"  , "&#39;"   },
                                             { "'"  , "&#8217;" },
                                             { "<"  , "&lt;"    },
                                             { ">"  , "&gt;"    },
                                             { "&"  , "&amp;"   },
                                             { " "  , "&;nbsp;" },
                                             { " "  , "&nbsp;"  }
                                         ];
    
    
    
    /**
     * Constructor
     *
     */
    public this () 
    {
        this.buffer = new char[2*1024*1024];
    }
    
    
    
    /*******************************************************************************
    
        Public methods
    
    ********************************************************************************/
    
    public char[] html_entity_decode ( char[] string )
    {
        foreach (basic_entity; basic_entities)
        {
            replace(string, basic_entity.entity, basic_entity.replacement);
            // string = Util.substitute(string, basic_entity.entity, basic_entity.replacement);
        }        
        return string;
    }
    
    
    
    /**
     * Replace string without heap activity
     * 
     * Params:
     *     input = input string
     *     search = search string  
     *     replacement = replace string
     */    
    public void replace ( inout char[] input, char[] search, char[] replacement )
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
        
        if ((pattern_idx = Util.locatePattern(input, search, pattern_idx)) < input_len)
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
            while ((pattern_idx = Util.locatePattern(input, search, pattern_idx + search_len)) < input_len);
            
            // copy the rest
            this.buffer[out_idx..out_idx+input[in_idx..$].length] = input[in_idx..$];
            out_idx += input[in_idx..$].length;
            
            input.length = out_idx;            
            input[] = this.buffer[0..out_idx];            
        }
    }
}