/*******************************************************************************

    Http Session "Cookie" Structure 

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        Apr 2010: Initial release

    author:         David Eckardt
    
    Reference:      RFC 2109, http://www.servlets.com/rfcs/rfc2109.html
    
    Note:           
        
    Usage Example:
    
     ---
             
        import $(TITLE);
        
        
        char[] cookie_header_line;
        
        HttpCookie cookie;
        
        cookie.attributes["max"] = "moritz";
        cookie.path              = "/mypath/";
        
        cookie.write(cookie_header_line);
        
        // cookie_header_line now contains "max=moritz; Path=/mypath/"
        
        cookie_header_line = "MaxAge=4711; eggs=ham; Version=1";
        
        cookie.read(cookie_header_line);
        
        // cookie.attributes now contains {"eggs" => "ham"}
        // cookie.max_age now equals 4711
        // cookie.comment, cookie.domain, cookie.path, are empty
        // cookie.secure is false (default value)
        
        
     ---
    
    
 ******************************************************************************/

module ocean.net.http.HttpCookie;

/******************************************************************************
 
    Imports
 
 ******************************************************************************/

private import ocean.net.http.HttpConstants: HttpCookieAttr;

private import ocean.text.util.StringSearch;

private import ocean.core.Array: copy;

/******************************************************************************

    HttpCookie structure

 ******************************************************************************/

struct HttpCookie
{
    /**************************************************************************

        Version as mandated in RFC 2109, 4.2.2 
    
     **************************************************************************/

    const  Version = '1';
    
    /**************************************************************************

        Predefined attributes
    
        A default value makes an attribute not appear in the cookie header line. 
    
     **************************************************************************/

    char[] comment = ``,
           expires = ``,
           domain  = ``,
           path    = ``;
    
    bool   secure  = false;
    
    /**************************************************************************

        Custom attributes
        
        Attribute values are optional; set to an empty string to indicate no
        value for a particular attribute.
    
     **************************************************************************/

    char[][char[]] attributes;
    
    /**************************************************************************

        HTTP cookie header line buffer, shared between read() and write()
    
     **************************************************************************/

    private char[] line;
    
    /**************************************************************************

        Reused array of slices to line, used by read()
    
     **************************************************************************/
    
    private char[][] slices;

    /**************************************************************************

        Generates the cookie header line.
        
        Params:
            line_out: cookie header line output: exposes an internal buffer
                      which is overwritten by read() and reset(), do not modify
        
        Returns:
            true if any attribute was set or false otherwise. In case of false
            line_out is an empty string.
    
     **************************************************************************/

    public bool write ( out char[] line_out )
    {
        this.line.length = 0;
        
        bool is_set = this.isSet();
        
        const separator = [HttpCookieAttr.Delim.Attributes, ' '];
        
        if (is_set)
        {
            foreach (name, value; this.attributes)
            {
                this.appendAttribute(name, value);
            }
            
            this.appendStdAttribute(HttpCookieAttr.Name.Comment, this.comment);
            this.line ~= separator;
            this.appendStdAttribute(HttpCookieAttr.Name.Expires, this.expires);
            this.line ~= separator;
            this.appendStdAttribute(HttpCookieAttr.Name.Path,    this.path);
            this.line ~= separator;
            this.appendStdAttribute(HttpCookieAttr.Name.Domain,  this.domain);
            this.line ~= separator;
            this.appendAttribute(HttpCookieAttr.Name.Secure, ``, !this.secure);
            //line ~= this.formatAttr(HttpCookieAttr.Name.Version, [this.Version]);
        }
        
        line_out = this.line;
        
        return is_set;
    }
    
    
    /**************************************************************************

        Reads a cookie header line and retrieves the attributes from it.
        
        Params:
            line: input cookie header line
        
        Returns:
            true if any attribute was retrieved or false otherwise. In case of
            false all attributes are at default values or empty.
    
     **************************************************************************/

    public bool read ( char[] line_in )
    {
        bool is_set = false;
        
        this.reset();
        
        if (line_in.length)
        {
            this.line.copy(line_in);
            
            foreach (item; StringSearch!().split(this.slices, this.line, HttpCookieAttr.Delim.Attributes))
            {
                char[] chunk = StringSearch!().trim(item);
                
                StringSearch!().strToLower(chunk);
                
                if (chunk.length)
                {
                    size_t v = StringSearch!().locateChar(chunk, HttpCookieAttr.Delim.AttrValue);
                    
                    this.attributes[chunk[0 .. v]] = (v < chunk.length)? chunk[v + 1 .. $] : "";
                    
                    is_set = true;
                }
            }
        }
        
        return is_set;
    }
    
    /**************************************************************************
     
        Tells whether custom attributes are set.
     
     **************************************************************************/
    
    public bool isSet ()
    {
        return !!this.attributes.length;
    }
    
    /**************************************************************************
    
        Resets all attributes.
     
     **************************************************************************/

    public typeof (this) reset ()
    {
        foreach (key; this.attributes.keys)
        {
            this.attributes.remove(key);
        }
        
        this.line.length = 0;
        
        this.comment.length    = 0;
        this.domain.length     = 0;
        this.path.length       = 0;
        this.expires.length    = 0;
        this.slices.length     = 0;
        
        this.secure = false;
        
        return this;
    }
    
    /**************************************************************************
    
        Appends "name=value" (if value is not empty) to this.line. Does nothing
        if value is empty.
        
        Params:
            name  = attribute name
            value = attribute value
         
         Returns:
             appended string which is empty if value is empty (but never null)
         
     **************************************************************************/
    
    private char[] appendStdAttribute ( char[] name, char[] value )
    {
        return this.appendAttribute(name, value, !value.length);
    }
    
    /**************************************************************************
    
        If skip is false, appends "name=value" (if value is not empty) or "name"
        (if value is empty) to this.line. Does nothing if skip is true.
        
        Params:
            name  = attribute name
            value = attribute value
            skip  = set to true to return an empty string.
         
         Returns:
             appended string which is empty if skip is true (but never null)
         
     **************************************************************************/
    
    private char[] appendAttribute ( char[] name, char[] value, bool skip = false )
    {
        size_t pos = this.line.length;
        
        if (!skip)
        {
            this.line ~= name;
            
            if (value.length != 0)
            {
                this.line ~= HttpCookieAttr.Delim.AttrValue;
            }
            
            this.line ~= value;
        }
        
        return this.line[pos .. $];
    }
}