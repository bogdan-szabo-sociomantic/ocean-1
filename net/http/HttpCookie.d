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

private import Integer = tango.text.convert.Integer: toString, toInt;

private import ocean.text.util.StringSearch;

private import tango.util.log.Trace;

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

        Temporary string buffer
    
     **************************************************************************/

    private char[] tmp;
    
    /**************************************************************************

        Temporary split buffer
    
     **************************************************************************/
    
    private char[][] slices;

    /**************************************************************************

        Writes the cookie header line and formats the attributes into it.
        
        Params:
            line: cookie header line output
        
        Returns:
            true if any attribute was set or false otherwise. In case of false
            line remains empty.
    
     **************************************************************************/

    bool write ( ref char[] line )
    {
        line.length = 0;
        
        bool is_set = this.isSet();
        
        if (is_set)
        {
            foreach (name, value; this.attributes)
            {
                line ~= this.formatAttr(name, value);
            }
            
            line ~= this.formatStdAttr(HttpCookieAttr.Name.Comment, this.comment);
            line ~= this.formatStdAttr(HttpCookieAttr.Name.Expires, this.expires);
            line ~= this.formatStdAttr(HttpCookieAttr.Name.Path,    this.path);
            line ~= this.formatStdAttr(HttpCookieAttr.Name.Domain,  this.domain);
            line ~= this.formatAttr(HttpCookieAttr.Name.Secure, ``, !this.secure);
            //line ~= this.formatAttr(HttpCookieAttr.Name.Version, [this.Version]);
            
            line.length = line.length - 1; // removing the last ;
        }
        
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

    bool read ( char[] line )
    {
        bool is_set = false;
        
        this.reset();
        
        if (line.length)
        {
            StringSearch!().split(this.slices, line, HttpCookieAttr.Delim.Attributes);
            
            foreach (item; this.slices)
            {
                this.tmp = StringSearch!().trim(item).dup;
                
                StringSearch!().strToLower(this.tmp);
                
                if (this.tmp.length)
                {
                    size_t v = StringSearch!().locateChar(this.tmp, HttpCookieAttr.Delim.AttrValue);
                    
                    bool has_value = v < this.tmp.length;
                    
                    this.attributes[this.tmp[0 .. v].dup] = has_value? this.tmp[v + 1 .. $].dup : "";
                    
                    is_set = true;
                }
            }
        }
        return is_set;
    }
    
    /**************************************************************************
     
        Tells whether custom attributes are set.
     
     **************************************************************************/
    
    bool isSet ()
    {
        return !!this.attributes.length;
    }
    
    /**************************************************************************
    
        Resets all attributes.
     
     **************************************************************************/

    void reset ()
    {
        this.attributes = this.attributes.init;
        
        this.comment.length    =
        this.domain.length     =
        this.path.length       = 
        this.expires.length    = 0;
            
        this.secure = false;
    }
    
    /**************************************************************************
    
        Returns "name=value; " (if value is not empty) or "name;" (if value is
        empty) if skip is false. Returns an empty string if skip is true.
        
        Params:
            name  = attribute name
            value = attribute value
            skip  = set to true to return an empty string.
         
         Returns:
             formatted name/value pair or an empty string 
         
     **************************************************************************/

    private char[] formatAttr ( char[] name, char[] value, bool skip = false )
    {
        return skip? "": name ~ (!value.length? value:
                                                HttpCookieAttr.Delim.AttrValue  ~ value) ~
                                HttpCookieAttr.Delim.Attributes ~ ' ';
    }
    
    /**************************************************************************
    
        Returns "name=value; " (if value is not empty) or "name;" (if value is
        empty).
        
        Params:
            name  = attribute name
            value = attribute value
         
         Returns:
             formatted name/value pair 
         
     **************************************************************************/

    private char[] formatStdAttr ( char[] name, char[] value )
    {
        return this.formatAttr(name, value, !value.length);
    }

}