/******************************************************************************

    HTTP message header parser
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
 ******************************************************************************/

module ocean.net.http2.parser.HttpHeaderParser;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.text.util.SplitIterator: ChrSplitIterator, StrSplitIterator;

private import ocean.net.http2.HttpException: HttpParseException;

/******************************************************************************

    Interface for the header parser to get the parse results and set limits

 ******************************************************************************/

interface IHttpHeaderParser
{
    /**************************************************************************

        Heander element
    
     **************************************************************************/
    
    struct HeaderElement
    {
        char[] key, val;
    }

    /**************************************************************************
    
        Obtains a list of HeaderElement instances referring to the header lines
        parsed so far. The key member of each element references the slice of
        the corresponding header line before the first ':', the val member the
        slice after the first ':'. Leading and tailing white space is trimmed
        off both key and val.
        
        Returns:
            list of HeaderElement instances referring to the header lines parsed
            so far
    
     **************************************************************************/
    
    HeaderElement[] header_elements ( );
    
    /**************************************************************************
    
        Returns:
            list of the the header lines parsed so far
    
     **************************************************************************/
    
    char[][] header_lines ( );
    
    /**************************************************************************
    
        Returns:
            limit for the number of HTTP message header lines
    
     **************************************************************************/

    uint header_lines_limit ( );
    
    /**************************************************************************
    
        Sets the limit for the number of HTTP message header lines.
        
        Note: A buffer size is set to n elements so use a realistic value (not
              uint.max for example).
        
        Params:
            n = limit for the number of HTTP message header lines
    
        Returns:
           limit for the number of HTTP message header lines
    
     **************************************************************************/

    uint header_lines_limit ( uint n );
    
    /**************************************************************************
    
        Returns:
            limit for the number of HTTP message header lines
    
     **************************************************************************/

    uint header_length_limit ( );
    
    /**************************************************************************
    
        Sets the HTTP message header size limit. This will reset the parse
        state and clear the content.
        
        Note: A buffer size is set to n elements so use a realistic value (not
              uint.max for example).
        
        Params:
            n = HTTP message header size limit
    
        Returns:
            HTTP message header size limit
    
     **************************************************************************/
    
    uint header_length_limit ( uint n );
}

/******************************************************************************

    HttpHeaderParser class
    
 ******************************************************************************/

class HttpHeaderParser : IHttpHeaderParser
{
    /**************************************************************************

    Default values for header size limitation
    
     **************************************************************************/
    
    const uint DefaultSizeLimit  = 0x4000,
               DefaultLinesLimit = 0x40;

    /**************************************************************************

        End-of-header-line token
    
     **************************************************************************/
    
    const EndOfHeaderLine = "\r\n";

    /**************************************************************************

         HTTP message header content buffer
    
     **************************************************************************/

    private char[] content;
    
    /**************************************************************************

        Split iterators to separate the header lines and find the end of the
        header.
    
     **************************************************************************/

    private StrSplitIterator split_header;
    private ChrSplitIterator split_tokens;
    
    /**************************************************************************

        Position (index) in the content up to which the content has already been
        parsed
    
     **************************************************************************/

    private size_t pos       = 0;
    
    /**************************************************************************

        Actual content length (For performance reasons content.length is not
        incrementally changed when appending content data.)
    
     **************************************************************************/

    private size_t content_length       = 0;
    
    /**************************************************************************

        false after reset() and before the start line is complete
    
     **************************************************************************/

    private bool have_start_line = false;
    
    /**************************************************************************

        Number of header lines parsed so far, excluding the start line
    
     **************************************************************************/

    private size_t n_header_lines = 0;
    
    /**************************************************************************

        Header lines, excluding the start line; elements slice this.content.
    
     **************************************************************************/

    private char[][] header_lines_;
    
    /**************************************************************************

        Header elements
        
        "key" references the slice of the corresponding header line before the
        first ':' and "val" after the first ':'. Leading and tailing white space
        is trimmed off both key and val.
    
     **************************************************************************/

    private HeaderElement[] header_elements_;
    
    /**************************************************************************

        Reusable exception instance
    
     **************************************************************************/

    private HttpParseException exception;
    
    /**************************************************************************

        Indicates that the header is complete
    
     **************************************************************************/

    private bool finished = false;
    
    /**************************************************************************

        Counter consistency check
    
     **************************************************************************/

    invariant
    {
        assert (this.pos                        <= this.content_length);
        assert (this.content_length             <= this.content.length);
        
        assert (this.header_elements_.length    == this.header_lines_.length);
        assert (this.n_header_lines             <= this.header_lines_.length);
    }
    
    /**************************************************************************

        Constructor
    
     **************************************************************************/

    public this ( )
    {
        this (this.DefaultSizeLimit, this.DefaultLinesLimit);
    }
    
    /**************************************************************************

        Constructor
        
        Note: Each a buffer with size_limit and lines_limit elements is
              allocated so use realistic values (not uint.max for example).
        
        Params:
            size_limit  = HTTP message header size limit
            lines_limit = limit for the number of HTTP message header lines
        
     **************************************************************************/

    public this ( uint size_limit, uint lines_limit )
    {
        this.exception = new HttpParseException;
        
        with (this.split_header = new StrSplitIterator)
        {
            delim             = this.EndOfHeaderLine;
            include_remaining = false;
        }
        
        with (this.split_tokens = new ChrSplitIterator)
        {
            collapse          = true;
            include_remaining = false;
        }
        
        this.content          = new char[size_limit];
        this.header_lines_    = new char[][lines_limit];
        this.header_elements_ = new HeaderElement[lines_limit];
    }
    
    /**************************************************************************

        Start line tokens; slice the internal content buffer
    
     **************************************************************************/

    public char[][3] start_line_tokens;
    
    /**************************************************************************
        
        Obtains a list of HeaderElement instances referring to the header lines
        parsed so far. The key member of each element references the slice of
        the corresponding header line before the first ':', the val member the
        slice after the first ':'. Leading and tailing white space is trimmed
        off both key and val.
        
        Returns:
            list of HeaderElement instances referring to the header lines parsed
            so far
    
     **************************************************************************/

    public HeaderElement[] header_elements ( )
    {
        return this.header_elements_[0 .. this.n_header_lines];
    }
    
    /**************************************************************************
    
        Returns:
            list of the the header lines parsed so far
    
     **************************************************************************/

    public char[][] header_lines ( )
    {
        return this.header_lines_[0 .. this.n_header_lines];
    }
    
    /**************************************************************************
    
        Returns:
            limit for the number of HTTP message header lines
    
     **************************************************************************/

    public uint header_lines_limit ( )
    {
        return this.header_lines_.length;
    }
    
    /**************************************************************************
    
        Sets the limit for the number of HTTP message header lines.
        
        Note: A buffer size is set to n elements so use a realistic value (not
              uint.max for example).
        
        Params:
            n = limit for the number of HTTP message header lines
    
        Returns:
           limit for the number of HTTP message header lines
    
     **************************************************************************/

    public uint header_lines_limit ( uint n )
    {
        if (this.n_header_lines > n)
        {
            this.n_header_lines = n;
        }
        
        return this.header_lines_.length = n;
    }
    
    /**************************************************************************
    
        Returns:
            HTTP message header size limit
    
     **************************************************************************/

    public uint header_length_limit ( )
    {
        return this.content.length;
    }
    
    /**************************************************************************
    
        Sets the HTTP message header size limit. This will reset the parse
        state and clear the content.
        
        Note: A buffer size is set to n elements so use a realistic value (not
              uint.max for example).
        
        Params:
            n = HTTP message header size limit
    
        Returns:
            HTTP message header size limit
    
     **************************************************************************/
    
    public uint header_length_limit ( uint n )
    {
        this.reset();
        
        return this.content.length = n;
    }

    /**************************************************************************
    
        Resets the parse state and clears the content.
        
        Returns:
            this instance
    
     **************************************************************************/

    typeof (this) reset ( )
    {
        this.split_header.reset();
        
        this.start_line_tokens[] = null;
        
        this.pos            = 0;
        this.content_length = 0;
        
        this.n_header_lines = 0;
        
        this.have_start_line = false;
        this.finished        = false;
        
        return this;
    }
    
    /**************************************************************************
    
        Parses content which is expected to be either the start of a HTTP
        message or a HTTP message fragment that continues the content passed on
        the last call to this method. Appends the slice of content which is part
        of the HTTP message header (that is, everything before the end-of-header
        token "\r\n\r\n" or content itself if it does not contain that token).
        After the end of the message header has been reached, which is indicated
        by a non-null return value, reset() must be called before calling this
        method again.
        Leading empty header lines are tolerated and ignored:
        
            "In the interest of robustness, servers SHOULD ignore any empty
            line(s) received where a Request-Line is expected."
            
            @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.1
        
        Returns:
            A slice of content after the end-of-header token (which may be an
            empty string) or null if content does not contain the end-of-header
            token.
        
        Throws:
            HttpParseException
                - on parse error: if
                    * the number of start line tokens is different from 3 or
                    * a regular header_line does not contain a ':';
                - on limit excess: if
                    * the header size in bytes exceeds the requested limit or
                    * the number of header lines in exceeds the requested limit.
            
            Assert()s that this method is not called after the end of header had
            been reacched.
            
     **************************************************************************/

    public char[] parse ( char[] content )
    in
    {
        assert (!this.finished);
    }
    body
    {
        char[] msg_body_start = null;
        
        foreach (header_line; this.split_header.reset(this.appendContent(content)))
        {
            char[] remaining = this.split_header.remaining;
            
            if (header_line.length)
            {
                if (this.have_start_line)
                {
                    this.parseRegularHeaderLine(header_line);
                }
                else
                {
                    this.parseStartLine(header_line);
                    
                    this.have_start_line = true;
                }
                
                this.pos = content.length - remaining.length;
            }
            else if (this.have_start_line)                                      // Ignore empty leading header lines
            {
                msg_body_start = remaining;
                
                break;
            }
        }
        
        return msg_body_start;
    }
    
    alias parse opCall;
    
    /**************************************************************************
    
        Appends content to this.content.
        
        Params:
            content = content fragment to append
        
        Returns:
            current content from the current parse position to the end of the
            newly appended fragment
        
        Throws:
            HttpException if the header size in bytes exceeds the requested
            limit.
            
     **************************************************************************/

    private char[] appendContent ( char[] content )
    {
        size_t new_end = this.content_length + content.length;
        
        this.exception.assertEx(new_end <= this.content.length,  __FILE__, __LINE__, "request header too long");
        
        this.content[this.content_length .. new_end] = content[];
        
        this.content_length = new_end;
        
        return this.content[this.pos .. this.content_length];
    }
    
    /**************************************************************************
    
        Parses header_line which is expected to be a regular HTTP message header
        line (not the start line or the empty message header termination line).
        
        Params:
            header_line = regular message header line
        
        Returns:
            HeaderElement instance referring to the parsed line
        
        Throws:
            HttpParseException
                - if the number of header lines exceeds the requested limit or
                - on parse error: if the header_line does not contain a ':'.
            
     **************************************************************************/

    private void parseRegularHeaderLine ( char[] header_line )
    {
        
        this.exception.assertEx(this.n_header_lines <= this.header_lines_.length, __FILE__, __LINE__,
                                "too many request header lines");
        
        foreach (field_name; this.split_tokens.reset(header_line))
        {
            this.header_elements_[this.n_header_lines] = HeaderElement(ChrSplitIterator.trim(field_name),
                                                                       ChrSplitIterator.trim(this.split_tokens.remaining));
            
            break;
        }
        
        this.exception.assertEx(this.split_tokens.n, __FILE__, __LINE__, "invalid header line (no ':')");
        
        this.header_lines_[this.n_header_lines++] = header_line;
    }
    
    /**************************************************************************
    
        Parses start_line which is expected to be the HTTP message header start
        line (not a regular header line or the empty message header termination
        line).
        
        Params:
            header_line = regular message header line
            
        Throws:
            HttpParseException on parse error: if the number of start line
            tokens is different from 3.
            
     **************************************************************************/

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
            
            this.exception.assertEx(i <= this.start_line_tokens.length, __FILE__, __LINE__,
                                    "invalid start line (too many tokens)");
            
            this.start_line_tokens[i - 1] = token;
        }
        
        this.exception.assertEx(i == this.start_line_tokens.length, __FILE__, __LINE__,
                                "invalid start line (too few tokens)");
        
        with (this.split_tokens)
        {
            delim = ':';
            collapse = false;
            include_remaining = false;
        }
    }
}