module ocean.net.http2.cookie.HttpCookieGenerator;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.net.util.ParamSet;

private import ocean.net.http2.consts.CookieAttributeNames;

private import ocean.net.http2.time.HttpTimeFormatter;

/******************************************************************************/

class HttpCookieGenerator : ParamSet
{
    public const char[] id;
    
    public char[] domain, path;
    
    private static class ExpirationTime
    {
        protected bool is_set_ = false;
        
        protected time_t t;
        
        public time_t opAssign ( time_t t )
        in
        {
            assert (t >= 0, "negative time value");
        }
        body
        {
            this.is_set_ = true;
            return this.t = t;
        }
        
        public void clear ( )
        {
            this.is_set_ = false;
        }
        
        public bool is_set ( )
        {
            return this.is_set_;
        }
        
        public bool get ( ref time_t t )
        {
            if (this.is_set_)
            {
                t = this.t;
            }
            
            return this.is_set_;
        }
    }
    
    private static class FormatExpirationTime : ExpirationTime
    {
        private HttpTimeFormatter formatter;
        
        public char[] format ( )
        {
            return super.is_set_? this.formatter.format(super.t) : null;
        }
    }
    
    public  const ExpirationTime       expiration_time;
    private const FormatExpirationTime fmt_expiration_time;
    
    /**************************************************************************
        
        Constructor
        
        Params:
            attribute_names = cookie attribute names
        
     **************************************************************************/

    this ( char[] id, char[][] attribute_names ... )
    {
        super.addKeys(this.id = id);
        
        super.addKeys(attribute_names);
        
        super.rehash();
        
        this.expiration_time = this.fmt_expiration_time = new FormatExpirationTime;
    }
    
    char[] value ( char[] val )
    {
        return super[this.id] = val;
    }
    
    char[] value ( )
    {
        return super[this.id];
    }
    
    /**************************************************************************
    
        Renders the HTTP response Cookie header line field value.
        
        Returns:
            HTTP response Cookie header line field value (exposes an internal
            buffer)
        
     **************************************************************************/

    void render ( void delegate ( char[] str ) appendContent )
    {
        uint i = 0;
        
        void append ( char[] key, char[] val )
        {
            if (val)
            {
                if (i++)
                {
                    appendContent("; ");
                }
                
                appendContent(key);
                appendContent("=");
                appendContent(val);
            }
        }
        
        foreach (key, val; super) 
        {
            append(key, val);
        }
        
        append(CookieAttributeNames.Names.Domain,  this.domain);
        append(CookieAttributeNames.Names.Path,    this.path);
        append(CookieAttributeNames.Names.Expires, this.fmt_expiration_time.format());
    }
    
    protected override void reset_ ( )
    {
        this.expiration_time.clear();
    }
}

