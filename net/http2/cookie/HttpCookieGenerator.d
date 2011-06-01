module ocean.net.http2.cookie.HttpCookieGenerator;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.net.util.ParamSet;

private import ocean.core.AppendBuffer;

/******************************************************************************/

class HttpCookieGenerator : ParamSet
{
    /**************************************************************************
    
        Content buffer
        
     **************************************************************************/
    
    private AppendBuffer!(char) content;
    
    /**************************************************************************
        
        Constructor
        
        Params:
            attribute_names = cookie attribute names
        
     **************************************************************************/

    this ( char[][] attribute_names ... )
    {
        super.addKeys(attribute_names);
        super.rehash();
        
        this.content = new AppendBuffer!(char)(0x400);
    }
    
    /**************************************************************************
    
        Renders the HTTP response Cookie header line field value.
        
        Returns:
            HTTP response Cookie header line field value (exposes an internal
            buffer)
        
     **************************************************************************/

    char[] render ( )
    {
        this.content.clear();
        
        foreach (key, val; super) if (val)
        {
            this.content.append(key, "=", val, ";");
        }
        
        return this.content[];
    }
    
    /**************************************************************************
    
        Sets the content buffer length to the lowest currently possible value.
        
        Returns:
            this instance
    
     **************************************************************************/
    
    public typeof (this) minimizeContentBuffer ( )
    {
        this.content.minimize();
        
        return this;
    }
}
