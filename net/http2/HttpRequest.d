module ocean.net.http2.HttpRequest;

private import ocean.net.util.ParamSet;

private import ocean.net.http2.message.HttpMessage;

private import ocean.net.http2.consts.HeaderFieldNames;

private import ocean.net.http2.consts.HttpMethod;

private import ocean.core.Array: copy, concat;

private import ocean.core.Exception: AutoException;

private import tango.net.Uri: Uri;

private import tango.io.Stdout;

class HttpRequest : ParamSet
{
    alias size_t delegate ( ) MsgBodyLengthDg;
    
    private MsgBodyLengthDg msg_body_length_dg_;
    
    private HttpMessage message;
    
    public uint max_num_header,
                max_header_length;
    
    public HttpMethod method;
    
    public char[] msg_body;
    
    private size_t msg_body_pos;
    
    private Uri uri_;
    
    private HttpException exception;
    
    public this ( char[][] headers ... )
    {
        this(true, headers);
    }
    
    public this ( bool add_std_headers, char[][] headers ... )
    in
    {
        char[] name = HeaderFieldNames.containsColon(headers);
        
        assert (!name, "\"" ~ name ~ "\" - invalid HTTP header name (contains ':')");
    }
    body
    {
        super(add_std_headers? HeaderFieldNames.Request.NameList : [], headers);
        
        this.message = new HttpMessage;
        
        this.uri_ = new Uri;
        
        this.exception = new HttpException;
    }
    
    public char[] method_name ( )
    {
        return this.message.start_line_tokens[0];
    }
    
    public Uri uri ( )
    {
        return this.uri_;
    }
    
    public char[] http_version ( )
    {
        return this.message.start_line_tokens[2];
    }
    
    public MsgBodyLengthDg msg_body_length_dg ( MsgBodyLengthDg msg_body_length_dg_ )
    {
        return this.msg_body_length_dg_ = msg_body_length_dg_;
    }
    
    private size_t msg_body_length ( )
    {
        return this.msg_body_length_dg_? msg_body_length_dg_() : 0;
    }
    
    public uint getUint ( char[] header_field_name )
    {
        uint n;
        
        bool is_set,
             ok = super.getUint(header_field_name, n, is_set);
        
        this.exception.assertEx(is_set, __FILE__, __LINE__, "missing header parameter \"", header_field_name, "\"");
        this.exception.assertEx(ok,     __FILE__, __LINE__, "integer value expected for \"", header_field_name, "\"");
        
        return n;
    }
    
    private bool header_complete = false;
    
    public size_t parse ( D = void ) ( D[] data )
    {
        if (!this.header_complete)
        {
            char[] msg_body_start = this.message.processHeader(cast (char[]) data);
            
            this.header_complete = msg_body_start !is null;
            
            if (header_complete)
            {
                this.method = HttpMethodNames[this.method_name];
                
                this.exception.assertEx(this.method, __FILE__, __LINE__, "invalid HTTP method");
                
                this.exception.assertEx(this.message.start_line_tokens[1].length, __FILE__, __LINE__, "no uri in request");
                
                this.uri_.parse(this.message.start_line_tokens[1]);
                
                foreach (element; this.message.header_elements)
                {
                    super.set(element.key, element.val);
                }
                
                this.msg_body.length = this.msg_body_length;
                
                data = msg_body_start;
            }
        }
        
        if (this.header_complete && this.msg_body_pos < this.msg_body.length)
        {
            size_t end = this.msg_body_pos + data.length;
            
            this.exception.assertEx(end <= this.msg_body.length, __FILE__, __LINE__, "message body too long");
            
            this.msg_body[this.msg_body_pos .. end] = cast (char[]) data[];
        }
        
        return data.length + (this.header_complete && this.msg_body_pos < this.msg_body.length);
    }
    
    protected override void reset_ ( )
    {
        this.method = this.method.init;
        this.uri_.reset();
        this.message.reset();
        this.msg_body.length = 0;
        this.msg_body_pos    = 0;
        
        this.header_complete = false;
    }
    
    static class HttpException : AutoException { }
}
