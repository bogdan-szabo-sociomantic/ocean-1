module ocean.net.http2.HttpHeaders;

import ocean.core.Array: copy, concat;

import ocean.text.util.Split;

import ocean.core.Exception: assertEx;

import ocean.net.http2.Headers;

import tango.io.Stdout;

class HttpHeaders
{
    private char[] data;
    
    private SplitStr split_headers;
    private SplitChr split_tokens;
    
    const EndOfHeader = "\r\n",
          EndOfHeaders = EndOfHeader ~ EndOfHeader;
    
    public uint max_num_headers,
                max_header_length;
    
    public Headers headers;
    
    private HttpException exception;
    
    this ( char[][] expected_headers ... )
    {
        this.exception = new HttpException;
        
        with (this.split_headers = new SplitStr)
        {
            delim = this.EndOfHeader;
        }
        
        with (this.split_tokens = new SplitChr)
        {
            collapse = true;
        }
        
        foreach (expected_header; expected_headers)
        {
            this.headers.expected[expected_header.dup] = null;
        }
    }
    
    char[][] header_lines ( )
    {
        return this.split_headers.segments;
    }
    
    typeof (this) reset ( )
    {
        this.split_headers.reset();
        
        this.data.length = 0;
        
        return this;
    }
    
    size_t parse ( D = void ) ( D[] data )
    in
    {
        static assert (D.sizeof == 1, typeof (this).stringof ~ ".parse: "
                       "need a single-byte type, not " ~ D.stringof);
    }
    body
    {
        return this.parse_(cast (char[]) data);
    }
    
    private size_t parse_ ( char[] data )
    {
        size_t header_length = SplitStr.locateDelimT!(EndOfHeaders)(data);
        
        bool incomplete = header_length == data.length;
        
        if (incomplete)
        {
            this.data ~= data;
        }
        else
        {
            assert (data.length >= EndOfHeader.length);
            assert (data.length - EndOfHeader.length >= header_length);
            
            this.data ~= data[0 .. header_length];
            
            this.parseHeaders();
        }
        
        return header_length + incomplete;
    }
    
    private void parseHeaders ( )
    {
        char[][] header_lines = this.split_headers(this.data);
        
        foreach (header_line; header_lines)
        {
            Stderr("\t")(header_line)("\n");
        }
        
        assertEx(header_lines.length, this.exception(__FILE__, __LINE__, "invalid request"));
        
        this.headers.reset();
        
        this.parseRequestLine(header_lines[0]);
        
        with (this.split_tokens)
        {
            delim = ':';
            n = 2;
            collapse = false;
        }
        
        foreach (header_line; header_lines[1 .. $])
        {
            char[][] tokens = this.split_tokens(header_line);
            
            assertEx(tokens.length == 2, this.exception(__FILE__, __LINE__, "invalid header line"));
            
            this.headers.set(SplitChr.trim(tokens[0]), SplitChr.trim(tokens[1]));
        }
    }
    
    private void parseRequestLine ( char[] request_line )
    {
        with (this.split_tokens)
        {
            delim = ' ';
            n = n.max;
            collapse = true;
        }
        
        char[][] tokens = this.split_tokens(header_lines[0]);
        
        assertEx(tokens.length == 3, this.exception(__FILE__, __LINE__, "invalid request line"));
        
        with (this.headers)
        {
            Method  = SplitChr.trim(tokens[0]);
            Uri     = SplitChr.trim(tokens[1]);
            Version = SplitChr.trim(tokens[2]);
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
