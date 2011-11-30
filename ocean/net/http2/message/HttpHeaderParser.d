/******************************************************************************

    HTTP message header parser
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
 ******************************************************************************/

module ocean.net.http2.message.HttpHeaderParser;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.text.util.SplitIterator: ChrSplitIterator, StrSplitIterator;

private import ocean.net.http2.HttpException: HttpParseException;

private import ocean.core.AppendBuffer;

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

    private const AppendBuffer!(char) content;
    
    /**************************************************************************

        Split iterators to separate the header lines and find the end of the
        header.
    
     **************************************************************************/

    private const StrSplitIterator split_header;
    private const ChrSplitIterator split_tokens;
    
    /**************************************************************************

        Position (index) in the content up to which the content has already been
        parsed
    
     **************************************************************************/

    private size_t pos       = 0;
    
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

    private const HeaderElement[] header_elements_;
    
    /**************************************************************************

        Reusable exception instance
    
     **************************************************************************/

    private const HttpParseException exception;
    
    /**************************************************************************

        Indicates that the header is complete
    
     **************************************************************************/

    private bool finished = false;
    
    /**************************************************************************

        Counter consistency check
    
     **************************************************************************/

    invariant
    {
        assert (this.pos                        <= this.content.length);
        assert (this.header_elements_.length    == this.header_lines_.length);
        assert (this.n_header_lines             <= this.header_lines_.length);
    }
    
    /**************************************************************************

        Constructor
    
     **************************************************************************/

    public this ( )
    {
        this(this.DefaultSizeLimit, this.DefaultLinesLimit);
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
        
        this.content          = new AppendBuffer!(char)(size_limit, true);
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
        return this.content.capacity;
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
        
        return this.content.capacity = n;
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
        this.content.clear();
        
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
        assert (!this.finished, "parse() called after finished");
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
                
                this.pos = this.content.length - remaining.length;
            }
            else
            {
                this.finished = this.have_start_line;                           // Ignore empty leading header lines
                
                if (this.finished)
                {
                    msg_body_start = remaining;
                    break;
                }
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
            HttpParseException if the header size in bytes exceeds the requested
            limit.
            
     **************************************************************************/

    private char[] appendContent ( char[] chunk )
    {
        char[] appended = this.content.append(chunk);
        
        this.exception.assertEx!(__FILE__, __LINE__)(appended.length == chunk.length, "request header too long");
        
        return this.content[this.pos .. this.content.length];
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
        
        this.exception.assertEx!(__FILE__, __LINE__)(this.n_header_lines <= this.header_lines_.length,
                                                     "too many request header lines");
        
        foreach (field_name; this.split_tokens.reset(header_line))
        {
            this.header_elements_[this.n_header_lines] = HeaderElement(ChrSplitIterator.trim(field_name),
                                                                       ChrSplitIterator.trim(this.split_tokens.remaining));
            
            break;
        }
        
        this.exception.assertEx!(__FILE__, __LINE__)(this.split_tokens.n, "invalid header line (no ':')");
        
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
            
            this.exception.assertEx!(__FILE__, __LINE__)(i <= this.start_line_tokens.length,
                                                         "invalid start line (too many tokens)");
            
            this.start_line_tokens[i - 1] = token;
        }
        
        this.exception.assertEx!(__FILE__, __LINE__)(i == this.start_line_tokens.length,
                                                     "invalid start line (too few tokens)");
        
        with (this.split_tokens)
        {
            delim = ':';
            collapse = false;
            include_remaining = false;
        }
    }
}

//version = OceanPerformanceTest;

import tango.stdc.time: time;
import tango.stdc.posix.stdlib: srand48, drand48;

version (OceanPerformanceTest)
{
    import tango.io.Stdout;
    import tango.core.internal.gcInterface: gc_disable, gc_enable;
}

unittest
{
    const char[] lorem_ipsum =
        "Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod "
        "tempor incidunt ut labore et dolore magna aliqua. Ut enim ad minim "
        "veniam, quis nostrud exercitation ullamco laboris nisi ut aliquid ex "
        "ea commodi consequat. Quis aute iure reprehenderit in voluptate velit "
        "esse cillum dolore eu fugiat nulla pariatur. Excepteur sint obcaecat "
        "cupiditat non proident, sunt in culpa qui officia deserunt mollit "
        "anim id est laborum. Duis autem vel eum iriure dolor in hendrerit in "
        "vulputate velit esse molestie consequat, vel illum dolore eu feugiat "
        "nulla facilisis at vero eros et accumsan et iusto odio dignissim qui "
        "blandit praesent luptatum zzril delenit augue duis dolore te feugait "
        "nulla facilisi. Lorem ipsum dolor sit amet, consectetuer adipiscing "
        "elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna "
        "aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud "
        "exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea "
        "commodo consequat. Duis autem vel eum iriure dolor in hendrerit in "
        "vulputate velit esse molestie consequat, vel illum dolore eu feugiat "
        "nulla facilisis at vero eros et accumsan et iusto odio dignissim qui "
        "blandit praesent luptatum zzril delenit augue duis dolore te feugait "
        "nulla facilisi. Nam liber tempor cum soluta nobis eleifend option "
        "congue nihil imperdiet doming id quod mazim placerat facer possim "
        "assum. Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed "
        "diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam "
        "erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci "
        "tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo "
        "consequat. Duis autem vel eum iriure dolor in hendrerit in vulputate "
        "velit esse molestie consequat, vel illum dolore eu feugiat nulla "
        "facilisis. At vero eos et accusam et justo duo dolores et ea rebum. "
        "Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum "
        "dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing "
        "elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore "
        "magna aliquyam erat, sed diam voluptua. At vero eos et accusam et "
        "justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea "
        "takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor "
        "sit amet, consetetur sadipscing elitr, At accusam aliquyam diam diam "
        "dolore dolores duo eirmod eos erat, et nonumy sed tempor et et "
        "invidunt justo labore Stet clita ea et gubergren, kasd magna no "
        "rebum. sanctus sea sed takimata ut vero voluptua. est Lorem ipsum "
        "dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing "
        "elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore "
        "magna aliquyam erat. Consetetur sadipscing elitr, sed diam nonumy "
        "eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed "
        "diam voluptua. At vero eos et accusam et justo duo dolores et ea "
        "rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem "
        "ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur "
        "sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et "
        "dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam "
        "et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea "
        "takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor "
        "sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor "
        "invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. "
        "At vero eos et accusam et justo duo dolores et ea rebum. Stet clita "
        "kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit "
        "amet.";
    
    const char[] content =
        "GET /dir?query=Hello%20World!&abc=def&ghi HTTP/1.1\r\n"
        "Host: www.example.org:12345\r\n"
        "User-Agent: Mozilla/5.0 (X11; U; Linux i686; de; rv:1.9.2.17) Gecko/20110422 Ubuntu/9.10 (karmic) Firefox/3.6.17\r\n"
        "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n"
        "Accept-Language: de-de,de;q=0.8,en-us;q=0.5,en;q=0.3\r\n"
        "Accept-Encoding: gzip,deflate\r\n"
        "Accept-Charset: UTF-8,*\r\n"
        "Keep-Alive: 115\r\n"
        "Connection: keep-alive\r\n"
        "Cache-Control: max-age=0\r\n"
        "\r\n" ~
        lorem_ipsum;
    
    const parts = 10;
    
    /*
     * content will be split into parts parts where the length of each part is
     * content.length / parts + d with d a random number in the range
     * [-(content.length / parts) / 3, +(content.length / parts) / 3].
     */
    
    static size_t random_chunk_length ( )
    {
        const c = content.length * (2.f / (parts * 3));
        
        static assert (c >= 3, "too many parts");
        
        return cast (size_t) (c + cast (float) drand48() * c);
    }
    
    srand48(time(null));
    
    scope parser = new HttpHeaderParser;
    
    version (OceanPerformanceTest)
    {
        const n = 1000_000;
    }
    else
    {
        const n = 10;
    }
    
    version (OceanPerformanceTest)
    {
        gc_disable();
        
        scope (exit) gc_enable();
    }
    
    for (uint i = 0; i < n; i++)
    {
        parser.reset();
        
        {
            size_t next = random_chunk_length();
            
            char[] msg_body_start = parser.parse(content[0 .. next]);
            
            while (msg_body_start is null)
            {
                size_t pos = next;
                
                next = pos + random_chunk_length();
                
                if (next < content.length)
                {
                    msg_body_start = parser.parse(content[pos .. next]);
                }
                else
                {
                    msg_body_start = parser.parse(content[pos .. content.length]);
                    
                    assert (msg_body_start !is null);
                    assert (msg_body_start.length <= content.length);
                    assert (msg_body_start == content[content.length - msg_body_start.length .. content.length]);
                }
            }
        }
        
        assert (parser.start_line_tokens[0]  == "GET");
        assert (parser.start_line_tokens[1]  == "/dir?query=Hello%20World!&abc=def&ghi");
        assert (parser.start_line_tokens[2]  == "HTTP/1.1");
        
        {
            auto elements = parser.header_elements;
            
            with (elements[0]) assert (key == "Host"            && val == "www.example.org:12345");
            with (elements[1]) assert (key == "User-Agent"      && val == "Mozilla/5.0 (X11; U; Linux i686; de; rv:1.9.2.17) Gecko/20110422 Ubuntu/9.10 (karmic) Firefox/3.6.17");
            with (elements[2]) assert (key == "Accept"          && val == "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
            with (elements[3]) assert (key == "Accept-Language" && val == "de-de,de;q=0.8,en-us;q=0.5,en;q=0.3");
            with (elements[4]) assert (key == "Accept-Encoding" && val == "gzip,deflate");
            with (elements[5]) assert (key == "Accept-Charset"  && val == "UTF-8,*");
            with (elements[6]) assert (key == "Keep-Alive"      && val == "115");
            with (elements[7]) assert (key == "Connection"      && val == "keep-alive");
            with (elements[8]) assert (key == "Cache-Control"   && val == "max-age=0");
            
            assert (elements.length == 9);
        }
        
        {
            auto lines = parser.header_lines;
            
            assert (lines[0] == "Host: www.example.org:12345");
            assert (lines[1] == "User-Agent: Mozilla/5.0 (X11; U; Linux i686; de; rv:1.9.2.17) Gecko/20110422 Ubuntu/9.10 (karmic) Firefox/3.6.17");
            assert (lines[2] == "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
            assert (lines[3] == "Accept-Language: de-de,de;q=0.8,en-us;q=0.5,en;q=0.3");
            assert (lines[4] == "Accept-Encoding: gzip,deflate");
            assert (lines[5] == "Accept-Charset: UTF-8,*");
            assert (lines[6] == "Keep-Alive: 115");
            assert (lines[7] == "Connection: keep-alive");
            assert (lines[8] == "Cache-Control: max-age=0");
            
            assert (lines.length == 9);
        }
        
        version (OceanPerformanceTest) 
        {
            uint j = i + 1;
            
            if (!(j % 10_000))
            {
                Stderr(HttpHeaderParser.stringof)(' ')(j)("\n").flush();
            }
        }
    }
}