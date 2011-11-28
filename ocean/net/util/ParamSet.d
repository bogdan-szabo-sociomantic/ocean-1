/******************************************************************************

    Manages a set of parameters where each parameter is a string key/value pair.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        David Eckardt
    
    Wraps an associative array serving as map of parameter key and value
    strings.
    The parameter keys are set on instantiation; that is, a key list is passed
    to the constructor. The keys cannot be changed, added or removed later by
    ParamSet. However, a subclass can add keys.
    All methods that accept a key handle the key case insensitively (except the
    constructor). When keys are output, the original keys are used.
    Note that keys and values are meant to slice string buffers in a subclass or
    external to this class.
    
    Build note: Requires linking against libglib-2.0: add

    -L-lglib-2.0
    
    to the DMD build parameters.

 ******************************************************************************/

module ocean.net.util.ParamSet;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.text.util.SplitIterator: ISplitIterator;

private import tango.stdc.ctype:  tolower;

private import tango.stdc.stdlib: div;

private import tango.core.Exception: ArrayBoundsException;

/******************************************************************************

    Compares each of the the first n characters in s1 and s2 in a
    case-insensitive manner.
    
    @see http://www.gtk.org/api/2.6/glib/glib-String-Utility-Functions.html#g-ascii-strncasecmp
    
    Params:
        s1 = string to compare each of the first n characters aganst those in s2
        s2 = string to compare each of the first n characters aganst those in s1
        n  = number of characters to compare
        
    Returns:
        an integer less than, equal to, or greater than zero if the first n
        characters of s1 is found, respectively, to be less than, to match, or
        to be greater than the first n characters of s2

 ******************************************************************************/

extern (C) private int g_ascii_strncasecmp ( char* s1, char* s2, size_t n );

/******************************************************************************/

class ParamSet
{
    struct Element
    {
        char[] key, val;
    }
    
    /**************************************************************************

        Set to true to skip key/value pairs with a null value on 'foreach'
        iteration.
    
     **************************************************************************/

    public bool skip_null_values_on_iteration = false;
    
    /**************************************************************************

        Key/value map of the parameter set
        
        Keys are the parameter keys in lower case, values are structs containing
        the original key and the parameter value. The value stored in the struct
        is set to null initially and by reset().
    
     **************************************************************************/

    private Element[char[]] paramset;
    
    /**************************************************************************

        Reused buffer for case conversion
    
     **************************************************************************/

    private char[] tolower_buf;
    
    /**************************************************************************

        Obtains the parameter value corresponding to key. key must be one of
        the parameter keys passed on instantiation or added by a subclass.
        
        Params:
            key = parameter key (case insensitive)
            
        Returns:
            parameter value; null indicates that no value is currently set for
            this key
            
        Throws:
            Behaves like regular associative array indexing.
        
     **************************************************************************/

    char[] opIndex ( char[] key )
    {
        try
        {
            return this.paramset[this.tolower(key)].val;
        }
        catch (ArrayBoundsException e)
        {
            e.msg ~= " [\"" ~ key ~ "\"]";
            throw e;
        }
    }
    
    /**************************************************************************

        Obtains the parameter value corresponding to key.
        
        Params:
            key = parameter key (case insensitive)
            
        Returns:
            pointer to the corresponding parameter value or null if the key is
            unknown. A pointer to null indicates that no value is currently set
            for this key.
        
     **************************************************************************/

    char[]* opIn_r ( char[] key )
    {
        Element* element = this.get_(key);
        
        return element? &element.val : null;
    }
    
    /**************************************************************************

        Obtains the parameter value corresponding to key, bundled with the
        original key.
        
        Params:
            key = parameter key (case insensitive)
            
        Returns:
            Struct containing original key and parameter value or null for key
            and value if the key was not found. A non-null key with a null value
            indicates that no value is currently set for this key.
        
     **************************************************************************/

    Element getElement ( char[] key )
    out (element)
    {
       assert (element.key || !element.val); 
    }
    body
    {
        Element* element = this.get_(key);
        
        return element? *element : Element.init;
    }
    
    /**************************************************************************

        Obtains the parameter value corresponding to key which is expected to be
        an unsigned decimal integer number and not empty. key must be one of the
        parameter keys passed on instantiation or added by a subclass.
        
        Params:
            key    = parameter key (case insensitive)
            n      = result destination; will be changed only if a value exists
                     for key
            is_set = will be changed to true if a value exists for key (even if
                     it is empty or not an unsigned decimal integer number)
            
        Returns:
            true on success or false if either no value exists for key or the
            value is empty or not an unsigned decimal integer number or.
        
        Throws:
            Behaves like regular associative array indexing using key as key.

     **************************************************************************/

    bool getUint ( T = uint ) ( char[] key, ref T n, out bool is_set )
    {
        char[] val = this[key];
        
        is_set = val !is null;
        
        return is_set? !this.readUint(val, n).length && val.length : false;
    }
    
    /**************************************************************************

        ditto

     **************************************************************************/
    
    bool getUint ( T = uint ) ( char[] key, ref T n )
    {
        char[] val = this[key];
        
        return val.length? !this.readUint(val, n).length : false;
    }
    
    /**************************************************************************

        Sets the parameter value for key. Key must be one of the parameter keys
        passed on instantiation or added by a subclass.
        
        Params:
            val = parameter value (will be sliced)
            key = parameter key (case insensitive)
            
        Returns:
            val
            
        Throws:
            Asserts that key is one of the parameter keys passed on
            instantiation or added by a subclass.
        
     **************************************************************************/
    
    char[] opIndexAssign ( char[] val, char[] key )
    {
        Element* element = this.get_(key);
        
        assert (element !is null, "cannot assign to unknown key \"" ~ key ~ "\"");
        
        return element.val = val;
    }

    /**************************************************************************

        Sets the parameter value for key if key is one of the parameter keys
        passed on instantiation or added by a subclass.
        
        Params:
            key = parameter key (case insensitive)
            val = parameter value (will be sliced)
            
        Returns:
            true if key is one of parameter keys passed on instantiation or
            added by a subclass or false otherwise. In case of false nothing has
            changed.
        
     **************************************************************************/

    bool set ( char[] key, char[] val )
    {
        return this.access(key, (char[], ref char[] dst){dst = val;});
    }
    
    /**************************************************************************
        
        ditto
        
        Params:
            key     = parameter kay (case insensitive)
            val     = parameter value
            str_val = destination string for number to string conversion; will
                      be resized where required and sliced
            
        Returns:
            true if key is one of parameter keys passed on instantiation or
            false otherwise. In case of false nothing has changed.
        
     **************************************************************************/

    bool set ( char[] key, uint val, ref char[] str_val )
    {
        return this.access(key, (char[], ref char[] dst)
                                {
                                    dst = this.writeUint(str_val, val);
                                });
    }
    
    /**************************************************************************

        Invokes dg with the original key and a reference to the parameter value
        for key if key is one of parameter keys passed on instantiation or added
        by a subclass.
        
        Params:
            key = parameter key (case insensitive)
            dg  = callback delegate
            
        Returns:
            true if key is one of the parameter keys passed on instantiation or
            added by a subclass or false otherwise. In case of false dg was not
            invoked.
        
     **************************************************************************/

    bool access ( char[] key, void delegate ( char[] key, ref char[] val ) dg )
    {
        Element* element = this.get_(key);
        
        if (element) with (*element)
        {
            dg(key, val);
        }
        
        return element !is null;
    }
    
    /**************************************************************************

        Compares the parameter value corresponding to key with val in a
        case-insensitive manner.
    
        Params:
            key = parameter key (case insensitive)
            val = parameter key (case insensitive)
    
        Returns:
            true if a parameter for key exists and its value case-insensitively
            equals val
    
     **************************************************************************/

    bool matches ( char[] key, char[] val )
    {
        Element* element = this.get_(key);
        
        return element?
                   (val !is null && element.val.length == val.length)?
                        !g_ascii_strncasecmp(element.val.ptr, val.ptr, val.length):
                        false:
                   false;
    }
    
    /**************************************************************************

        'foreach' iteration over parameter key/value pairs
        
     **************************************************************************/

    public int opApply ( int delegate ( ref char[] key, ref char[] val ) dg )
    {
        int result = 0;
        
        foreach (ref element; this.paramset) with (element)
        {
            if (val || !skip_null_values_on_iteration)
            {
                result = dg(key, val);
                
                if (result) break;
            }
        }
        
        return result;
    }
    
    /**************************************************************************

        Resets all parameter values to null.
        
     **************************************************************************/

    final void reset ( )
    {
        this.reset_();
        
        foreach (ref element; this.paramset)
        {
            element.val = null;
        }
    }
    
    /**************************************************************************

        Custom reset method for a subclass, will be invoked by reset() before
        doing anything else.
        
     **************************************************************************/

    protected void reset_ ( ) { }
    
    /**************************************************************************

        Adds an entry for key.

        Params:
            key = parameter key to add
        
     **************************************************************************/
    
    protected void addKeys ( char[][] keys ... )
    {
        foreach (key; keys)
        {
            this.addKey(key);
        }
    }
    
    /**************************************************************************

        Adds an entry for key.

        Params:
            key = parameter key to add
        
     **************************************************************************/

    protected char[] addKey ( char[] key )
    {
        char[] lower_key = this.tolower(key);
        
        if (!(key in this.paramset))
        {
            this.paramset[lower_key.dup] = Element(key);
        }
        
        return lower_key;
    }
    
    /**************************************************************************

        Looks up key in a case-insensitive manner.
        
        Params:
            key = parameter key
            
        Returns:
            - Pointer to a a struct which contains the original key and the
              parameter value, where a null value indicates that no value is
              currently set for this key, or
            - null if the key was not found.
            
     **************************************************************************/

    protected Element* get_ ( char[] key )
    out (element)
    {
        if (element) with (*element) assert (key || !val);
    }
    body
    {
        return this.tolower(key) in this.paramset;
    }
    
    /**************************************************************************

        Converts key to lower case, writing to a separate buffer so that key is
        left untouched.
        
        Params:
            key = key to convert to lower case
            
        Returns:
            result (references an internal buffer)
            
     **************************************************************************/

    protected char[] tolower ( char[] key )
    {
        if (this.tolower_buf.length < key.length)
        {
            this.tolower_buf.length = key.length;
        }
        
        foreach (i, c; key)
        {
            this.tolower_buf[i] = .tolower(c);
        }
        
        return this.tolower_buf[0 .. key.length];
    }
    
    /**************************************************************************

        Rehashes the associative array.
            
     **************************************************************************/

    protected void rehash ( )
    {
        this.paramset.rehash;
    }
    
    /**************************************************************************

        Converts n to decimal representation, writing to dst, resizing dst as
        required.
        
        Params:
            dst = destination string
            n   = number to convert to decimal representation
        
        Returns:
            result (dst)
        
     **************************************************************************/

    protected static char[] writeUint ( ref char[] dst, uint n )
    {
        size_t len = 0;
        
        for (uint p = 1; p <= n; p *= 10)
        {
            len++;
        }
        
        dst.length = len? len : 1;
        
        return writeUintFixed(dst, n);
    }
    
    /**************************************************************************

        Converts n to decimal representation, writing to dst. dst must be long
        enough to hold the result; the result will be padded with ' '
        characters from thhe left where required.
        
        Params:
            dst = destination string
            n   = number to convert to decimal representation
        
        Returns:
            result (dst)
        
     **************************************************************************/

    protected static char[] writeUintFixed ( char[] dst, uint n )
    out
    {
        assert (!n);
    }
    body
    {
        foreach_reverse (i, ref c; dst) with (div(n, 10))
        {
            c = rem + '0';
            n = quot;
            
            if (!n)
            {
                dst[0 .. i] = ' ';
                break;
            }
        }
        
        return dst;
    }
    
    /**************************************************************************

        Converts str, which is expected to contain a decimal number, to the
        number it represents. Tailing and leading whitespace is allowed and will
        be trimmed. If src contains non-decimal digit characters after trimming,
        conversion will be stopped at the first non-decimal digit character.
        
        Example:
        
        ---
        
            uint n;
        
            char[] remaining = readUint("  123abc45  ", n);
            
            // n is now 123
            // remaining is now "abc45"
            
        ---
        
        Params:
            src = source string
            n   = result output
        
        Returns:
            slice of src starting with the first character that is not a decimal
            digit or an empty string if src contains only decimal digits
        
     **************************************************************************/

    protected static char[] readUint ( T = uint ) ( char[] src, out T x )
    in
    {
        static assert (T.init == 0, "initial value of type \"" ~ T.stringof ~ "\" is " ~ T.init.stringof ~ " (need 0)");
        static assert (cast (T) (T.max + 1) < T.max);                           // ensure overflow checking works
    }
    body
    {
        char[] trimmed = ISplitIterator.trim(src);
        
        foreach (i, c; trimmed)
        {
            if ('0' <= c && c <= '9')
            {
                T y = x * 10 + (c - '0');
                
                if (y >= x)                                                     // overflow checking
                {
                    x = y;
                    continue;
                }
            }
            
            return trimmed[i .. $];
        }
        
        return src? "" : null;
    }
    
    /**************************************************************************

        TODO: unittest
        
     **************************************************************************/
    
    unittest {}
}
