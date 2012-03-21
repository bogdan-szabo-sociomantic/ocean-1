/******************************************************************************

    UTF-8 URL decoder
    
    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved
    
    version:        January 2012: Initial release
    
    authors:        Gavin Norman, David Eckardt
    
    Uses the glib 2.0, use
    
        -Lglib-2.0
        
    as linking parameter.
    
 ******************************************************************************/

module ocean.net.util.UrlDecoder;

/******************************************************************************

    Imports and library function declarations
    
 ******************************************************************************/

private import ocean.text.util.SplitIterator: ChrSplitIterator;

extern (C) private
{
    /**************************************************************************
    
        Determines the numeric value of a character as a hexidecimal digit.
        
        @see http://developer.gnome.org/glib/stable/glib-String-Utility-Functions.html#g-ascii-xdigit-value
        
        Params:
            c = an ASCII character.

        Returns:
            If c is a hex digit its numeric value. Otherwise, -1.
        
     **************************************************************************/
    
    int   g_ascii_xdigit_value(int c);
    
    /**************************************************************************
    
        Converts a single character to UTF-8.
        
        @see http://developer.gnome.org/glib/stable/glib-Unicode-Manipulation.html#g-unichar-to-utf8
        
        Params:
            c      = a Unicode character code
            outbuf = output buffer, must have at least 6 bytes of space.
                     If NULL, the length will be computed and returned and
                     nothing will be written to outbuf.
        
        Returns:
            number of bytes written
            
     **************************************************************************/
    
    int g_unichar_to_utf8(dchar c, char* outbuf);
}

/******************************************************************************

    UrlDecoder class
    
    Memory friendly, suitable for stack-allocated 'scope' instances.
    
 ******************************************************************************/

class UrlDecoder
{
    /**************************************************************************
    
        Source string, may be changed at any time except during decoding
        'foreach' iteration.
        
     **************************************************************************/
    
    public char[] source;
    
    /**************************************************************************
    
        Constructor
        
        Params: 
            source_in = source string
        
     **************************************************************************/
    
    public this ( char[] source_in = null )
    {
        this.source = source_in;
    }
    
    /***************************************************************************
        
        Decodes this.source in an 'foreach' iteration over decoded chunks. 
        
        Checks whether the passed source string contains any characters encoded
        according to the RFC 2396 escape format. (A '%' character followed by
        two hexadecimal digits.)

        The non-standard 4-digit unicode encoding scheme is also supported ("%u"
        followed by four hex digits).
        
    **************************************************************************/
    
    public int opApply ( int delegate ( ref char[] chunk ) dg )
    {
        int callDg ( char[] str )
        {
            return dg(str);
        }
        
        scope iterate_markers = new ChrSplitIterator('%');
        
        iterate_markers.include_remaining = false;
        
        size_t first_marker = iterate_markers.reset(this.source).locateDelim();
        
        if (first_marker < this.source.length)
        {
            int result = callDg(this.source[0 .. first_marker]);
            
            if (!result) foreach (ref pos, between; iterate_markers.reset(this.source[first_marker .. $]))
            {
                result = dg(between);
                
                if (result) break;
                
                char[] remaining = iterate_markers.remaining;
                
                char[6] decoded_buf;
                size_t read_pos = 0;
                
                char[] decoded = decoded_buf.decodeCharacter(remaining, read_pos);
                
                if (decoded.length)
                {
                    assert (read_pos);
                    
                    char[] original = this.source[0 .. read_pos];
                    
                    result = callDg(this.copyDecoded(decoded, original)?
                                        decoded : original);
                    
                    pos += read_pos;
                }
                else                                           // error decoding
                {
                    assert (!read_pos);
                    
                    result = callDg("%");
                }
                
                if (result) break;
            }
            
            return result? result : callDg(iterate_markers.remaining);
        }
        else
        {
            return dg(this.source);
        }
    }
    
    /***************************************************************************

        Extracts a single character from the specified position in the passed
        string, which is expected to be the index of a character preceeded by a
        '%'.
        source[pos .. $] is scanned to see if they represent an encoded
        character in either the RFC 2396 escape format (%XX) or the non-standard
        escape format (%uXXXX) or if they should represent a '%' (%%).

        (See: http://en.wikipedia.org/wiki/Percent-encoding)

        On success the extracted character is written as utf8 into the provided
        output buffer and pos is increased to the index right after the last
        consumed character in source. On failure pos remains unchanged.

        Params:
            dst    = string buffer to receive decoded characters
            source = character string to decode a character from; may be
                     empty or null which will result in failure
            pos    = position in source
        
        Returns:
            a slice to the UTF-8 representation of the decoded character in dst
            on success or an empty string on failure. The returned string is
            guaranteed to slice dst from dst[0].
        
    ***************************************************************************/

    public static char[] decodeCharacter ( char[6] dst, char[] source, ref size_t pos )
    in
    {
        assert(pos <= source.length, typeof (this).stringof ~ ".decodeCharacter (in): offset out of array bounds");
    }
    out (slice)
    {
        assert (slice.ptr is dst.ptr, typeof (this).stringof ~ ".decodeCharacter: bad returned slice");
        assert(pos <= source.length, typeof (this).stringof ~ ".decodeCharacter (out): offset out of array bounds");
    }
    body
    {
        auto src = source[pos .. $];
        
        char[] decodeHex ( size_t start, size_t end )
        {
            if (src.length >= end)
            {
                dchar unicode_char;
                
                if (fromHex(src[start .. end], unicode_char))
                {
                    pos += end; // (%uXXXX == 6 characters)
                    return dst[0 .. g_unichar_to_utf8(unicode_char, dst.ptr)];
                }
            }
            
            return dst[0 .. 0];
        }
        
        if (src.length) switch (src[0])
        {
            default:
                return decodeHex(0, 2);
                
            case 'u':
                return decodeHex(1, 5);
                
            case '%':
                pos++;
                return dst[0 .. 1] = src[0 .. 1];
        }
        else
        {
            return dst[0 .. 0];
        }
    }
    
    /***************************************************************************

        Converts hex, which is expected consist of hexadecimal digits, to the
        code it represents. hex must not be empty and its value must be in the
        range of d.
        
        Params:
            hex = dchar code in hexadeximal representation
            d   = resulting dchar code output, valid only when returning true
        
        Returns:
            true on success or false on failure.
        
    ***************************************************************************/

    public static bool fromHex ( char[] hex, out dchar d )
    {
        if (hex.length)
        {
            const max_length = dchar.sizeof * 4;
            
            // max_mask: The four most significant bits are 1, the rest is 0.
            
            const dchar max_mask = cast (dchar) ~((1u << ((dchar.sizeof * 8) - 4)) - 1);
            
            d = 0;
            
            foreach (i, c; hex)
            {
                if (!(d & max_mask))                           // overflow check
                {
                    int x = g_ascii_xdigit_value(c);
                    
                    if (x >= 0)              // x < 0 => not a hexadecimal digit
                    {
                        d <<= 4;
                        d |= x;
                        
                        continue;
                    }
                }
                
                return false;             // not a hexadecimal digit or overflow
            }
            
            return true;
        }
        else
        {
            return false;
        }
    }
    
    /**************************************************************************
        
        To be overridden as an option, called by opApply().
        
        Determines whether each decoded character should be passed as 'foreach'
        iteration variable string in its decoded or its original (encoded) form.
        This can be used in cases where the decoding of only certain characters
        is desired.
        
        By default always the decoded form is selected.
        
        Params:
            decoded  = decoded form of the character
            original = original (encoded) form
        
        Returns:
            true to use the decoded or false to use the original (encoded) form.
            
     **************************************************************************/
    
    protected bool copyDecoded ( char[] decoded, char[] original )
    {
        return true;
    }
    
    /**************************************************************************/
    
    unittest
    {
        scope decoder = new typeof (this)("%Die %uKatze %u221E%u221E tritt die Treppe %% krumm. %u2207%"),
              decoded = new char[0];
        
        foreach (chunk; decoder)
        {
            decoded ~= chunk;
        }
        
        assert (decoded == "%Die %uKatze ∞∞ tritt die Treppe % krumm. ∇%");
    }
}
