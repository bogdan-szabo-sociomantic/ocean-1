/*******************************************************************************

    Http Header

    Copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    Version:        Mar 2009: Initial release
                    May 2010: Revised version
                    
    Authors:        Lars Kirchhoff, Thomas Nicolai & David Eckhardt
    
 ******************************************************************************/

module ocean.net.http.HttpHeader;

/*******************************************************************************

    Imports
    
 ******************************************************************************/

private     import      ocean.text.util.StringSearch;

/*******************************************************************************

    HeaderValues
    
    Keeps a pointer to an associative array of header names and their values
    and provides read-only access to this array.
    Header parameter names are case-insensitive; values are case-sensitive.  

 ******************************************************************************/

struct HeaderValues
{
    
    /***************************************************************************
        
        Header Element
    
     **************************************************************************/
    
    struct HeaderElement
    {       
            char[] key;
            char[] value;
    }
    
    /***************************************************************************
        
        Header key/value pairs
        
     **************************************************************************/
    
    private             HeaderElement[]                  values;
    
    /***************************************************************************
    
        Temporary string buffer for case conversion
    
     **************************************************************************/
    
    private              char[]                          tmp_buf;
    
    /***************************************************************************
    
        Return value of header parameter
        
        Retrieves a header parameter value via indexing by name. If there
        is no header parameter with the provided name, an empty string is
        returned.
    
        Params:
            key = name of header parameter
        
        Returns:
            value of key or null if not existing
        
     **************************************************************************/
    
    public char[] opIndex ( in char[] key )
    {
        char[] k = this.cleanHeaderName(key);
        
        foreach ( param; this.values )
        {
            if ( param.key == k )
            {
                return param.value;
            }
        }
        
        return null;
    }
    
    /***************************************************************************
        
        Add header element
        
        Params:
            value = array value
            key = array key           
        
     **************************************************************************/
    
    public void opIndexAssign ( in char[] value, in char[] key )
    {
        char[] k = this.cleanHeaderName(key);

        this.values ~= HeaderElement(k.dup, value.dup);
    }
   
    /***************************************************************************
        
        Returns iterator with key and value as reference
        
        Params:
            dg = delegate to pass key & values to
        
        Returns:
            delegate result
    
    ***************************************************************************/
    
    public int opApply (int delegate(ref char[] key, ref char[] value) dg)
    {
        int result = 0;
        
        foreach ( ref element; this.values )
        {
            if ((result = dg(element.key, element.value)) != 0) 
            {
                break;
            }
        }
        
        return result;
    }
    
    /***************************************************************************
        
        Reset header values
        
        Returns:
            void
        
     **************************************************************************/
    
    public void reset ()
    {
        this.values.length = 0;
    }
    
    /***************************************************************************
    
        'in' tells whether there is a header parameter named name.
        
        Params:
            key = header key
    
     **************************************************************************/
    
    public bool opIn_r ( char[] key )
    {
        char[] k = this.cleanHeaderName(key);
        
        foreach ( ref param; this.values )
        {
            if ( param.key == k ) 
            {
                return true;
            }
        }
        
        return false;
    }
    
    /***************************************************************************
    
        Strips a trailing ':' from name, trims off whitespace and converts
        name to lower case.
        ':' stripping is done since header name constants in HttpHeader in
        tango.net.http.HttpConst have a trailing ':'.
        
        Params:
            name = input header name
            
        Returns:
            cleaned header name
    
     **************************************************************************/
    
    private char[] cleanHeaderName ( char[] name )
    {
        bool trailing_colon = false;
    
        if (name.length)
        {
            trailing_colon = name[$ - 1] == ':';
        }
    
        this.tmp_buf = StringSearch!().trim(name[0 .. $ - trailing_colon]).dup;
        
        StringSearch!().strToLower(this.tmp_buf);
        
        return this.tmp_buf;
    }
}