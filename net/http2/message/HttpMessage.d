module ocean.net.http2.parser.HttpMessage;

//private import ocean.net.http2.header.HeaderElement;

private import ocean.text.util.Split: SplitChr, SplitStr;

private import ocean.core.Array;
private import ocean.core.Exception: assertEx;

private import tango.io.Stdout;

class HttpMessage
{
    private char[] data;
    
    private SplitStr split_header;
    private SplitChr split_tokens;
    
    const EndOfHeaderLine = "\r\n",
          EndOfHeader = EndOfHeaderLine ~ EndOfHeaderLine;
    
    struct HeaderElement
    {
        char[] key, val;
    }
    
    public uint max_header_lines,
                max_header_length;
    
    private HttpException exception;
    
    public this ( )
    {
        this.exception = new HttpException;
        
        with (this.split_header = new SplitStr)
        {
            delim             = this.EndOfHeaderLine;
            include_remaining = false;
        }
        
        with (this.split_tokens = new SplitChr)
        {
            collapse          = true;
            include_remaining = false;
        }
    }
    
    public char[][3] start_line_tokens;
    
    public HeaderElement[] header_elements;
    
    public char[][] header_lines;
    
    typeof (this) reset ( )
    {
        this.split_header.reset();
        
        this.start_line_tokens[] = null;
        
        this.header_elements.length = 0;
        this.header_lines.length    = 0;
        
        this.data.length = 0;
        
        return this;
    }
    
    public char[] processHeader ( char[] data )
    {
        size_t header_length = SplitStr.locateDelimT!(EndOfHeader)(data);
        
        char[] msg_body_start = null;
        
        if (header_length == data.length)
        {
            this.data ~= data;
        }
        else
        {
            this.data ~= data[0 .. header_length];
            
            msg_body_start = data[header_length + EndOfHeader.length .. $];
            
            this.parseHeader();
        }
        
        return msg_body_start;
    }
    
    
    alias processHeader opCall;
    
    private void parseHeader ( )
    {
        foreach (header_line; this.split_header.reset(this.data))
        {
            switch (this.split_header.n)
            {
                case 0:
                    assert (false);
                
                case 1:
                    this.parseStartLine(header_line);
                    continue;
                
                default:
                    this.header_elements ~= parseHeaderLine(header_line);
                    this.header_lines ~= header_line;
            }
        }
        
        assertEx(this.split_header.n, this.exception(__FILE__, __LINE__, "invalid request"));
    }
    
    private HeaderElement parseHeaderLine ( char[] header_line )
    {
        foreach (field_name; this.split_tokens.reset(header_line))
        {
            return HeaderElement(SplitChr.trim(field_name), SplitChr.trim(this.split_tokens.remaining));
        }
        
        throw this.exception(__FILE__, __LINE__, "invalid header line (no ':'): ", header_line);
    }
    
    private void parseStartLine ( char[] start_line )
    {
        with (this.split_tokens)
        {
            delim = ' ';
            collapse = true;
            include_remaining = true;
        }
        
        uint i = 0;
        
        foreach (token; this.split_tokens.reset(start_line))
        {
            i = this.split_tokens.n;
            
            assertEx(i <= this.start_line_tokens.length, this.exception(__FILE__, __LINE__, "invalid start line (too many tokens): ", start_line));
            
            this.start_line_tokens[i - 1] = token;
        }
        
        assertEx(i == this.start_line_tokens.length, this.exception(__FILE__, __LINE__, "invalid start line (too few tokens): ", start_line));
        
        with (this.split_tokens)
        {
            delim = ':';
            collapse = false;
            include_remaining = false;
        }
    }
    
    static class HttpException : Exception
    {
        this ( ) {super("");}
        
        typeof (this) opCall ( char[] file, long line, char[][] msg ... )
        {
            super.file.copy(file);
            super.line = line;
            
            return this.opCall(msg);
        }
        
        typeof (this) opCall ( char[][] msg ... )
        {
            super.msg.concat(msg);
            
            return this;
        }
    }
    
    version (none) unittest
    {
        for (uint i = 0; i < 3; i++)
        {
            Stderr(subStrT!("ie")("Die Katze tritt die Treppe krumm", i))("\n").flush();
        }
    }

}