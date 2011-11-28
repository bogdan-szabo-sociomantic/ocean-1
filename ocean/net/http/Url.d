/*******************************************************************************

    Module to parse the Query URL and to provide an easy interface for it.

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Mar 2009: Initial release
                    May 2010: Revised version
                    
    authors:        Lars Kirchhoff, Thomas Nicolai & David Eckhardt
    
********************************************************************************/

module      ocean.net.http.Url;

/*******************************************************************************

    Imports
        
********************************************************************************/

private     import      ocean.net.http.HttpConstants;

private     import      ocean.core.Array;

private     import      Utf = tango.text.convert.Utf;

private     import      tango.core.Array;

private     import      tango.stdc.string : memchr;

private     import      tango.net.http.HttpConst;

private     import      tango.net.Uri;

private     import      Unicode = tango.text.Unicode;

debug private import ocean.util.log.Trace;



/*******************************************************************************  

    Url parses a url string and seperates its components to be directly 
    and efficiently accessible.

    Escaped characters (eg "%20") in values of url query parameters are
    automatically decoded. (See Url.decode().)

    Url parser usage example
    ---
    Url    url;
    char[] url_string = "http://www.example.com/path1/path2?key=value";
    
    url.parse(url);
    ---
    
    Retrieving the number of path segments
    ---
    uint count = url.path.length
    ---
    
    Retrieving a specific path segment
    ---
    char[] segment = url.path[1];
    ---
    
    Retrieving the number of query parameter
    ---
    uint count = url.query.length
    ---
    
    Retrieving a specific query value for a given key
    ---
    char[] value = url.query["key"];
    ---

    TODO: Add url string encoding function (at least one using tango.net.Uri).

    TODO: The Url.parse method is still using tango.net.Uri.parse, whereas
        Url.Query.parse is using the new static method in this class. Could this
        all be combined into using a single function?

    See also the Rfc's

    http://tools.ietf.org/html/rfc3986
    http://tools.ietf.org/html/rfc1738
    
    An overview about all the Url related Rfc can be found on the apache website
    
    http://labs.apache.org/webarch/uri/rfc/
    
********************************************************************************/

struct Url
{
    
    /***************************************************************************
        
        Uri Parser
    
     ***************************************************************************/
    
    private             Uri                             parser;
    
    /***************************************************************************
        
        Url string
        
     ***************************************************************************/                                                   
    
    private             char[]                          url;

    /***************************************************************************
        
        Host subcomponent
   
     ***************************************************************************/
    
    public              char[]                          host;
    
    /***************************************************************************
        
        Path component
    
     ***************************************************************************/
    
    public              Path                            path;

    /***************************************************************************
        
        Path tolower conversion buffer
    
     ***************************************************************************/
    
    public              char[]                          path_buffer;

    /***************************************************************************
    
        Query component

     ***************************************************************************/
    
    public              Query                           query;
    
    /***************************************************************************
        
        Returns length of url string
            
        Returns:
            length of host name
            
     ***************************************************************************/
    
    public uint length ()
    {
        return this.url.length;        
    }

    
    /***************************************************************************
        
        Returns url string
            
        Returns:
            url string
            
     ***************************************************************************/
    
    public char[] toString ()
    {
        return this.url;
    }

    
    /***************************************************************************
        
        Parses request Uri
            
        Params:
            url     = url to parse
            tolower = enable/disable lowercase conversion of the url path
            
        Returns:
            resource format or null if not given
        
        Throws:
            May throw an Exception if url is invalid or bad UTF-8
        
     ***************************************************************************/

    public void parse ( in char[] url, bool tolower = true )
    {
        this.host.length = 0;
        
        assert(url.length, `parse error: url has zero length`);
        
        if ( parser is null )
            this.parser = new Uri();

        this.url.copy(url);
        
        this.parser.parse(this.url);        
        
        this.host = this.parser.host;

        this.query.parse(url);
        this.path.parse(this.parser.path, this.parser, tolower);
    }

    /***************************************************************************
        
        Path Component
            
     ***************************************************************************/
    
    struct Path
    {
        
        /***********************************************************************
            
            Path component string
            
         ***********************************************************************/                                                   
        
        private             char[]                          path;
        
        /***********************************************************************
            
            Path segments
            
         ***********************************************************************/                                                   
        
        private             char[][]                        segments;
        private             char[][]                        splits;
    
        /***********************************************************************
            
            Operator overloading; Returns path segment
            
            Params:
                name = name of the paramater 
                
            Returns:
                path segment or null if not existing
                
         ***********************************************************************/
        
        public char[] opIndex(uint key)
        {
            if (this.segments.length > key)
            {
                return this.segments[key];
            }
            
            return null;
        }
        
        /***********************************************************************
            
            Resets path variables
            
         ***********************************************************************/
        
        public void reset ()
        {
            this.path.length = 0;
            this.segments.length = 0;
            this.splits.length = 0;
        }
        
        /***********************************************************************
            
            Returns number path segments
                
            Returns:
                number of path segments
                
         ***********************************************************************/
        
        public uint length ()
        {
            return this.segments.length;        
        }
        
        /***********************************************************************
            
            Returns url encoded path component as string
                
            Returns:
                url path component
                
         ***********************************************************************/
        
        public char[] toString ()
        {
            return this.path;
        }
        
        /***********************************************************************
            
            Parses the path component
            
            Method transforms
            ---
            char[] = "/path/element"
            ---
            
            into 
            ---
            char[][] param;
            
            param[] = 'path';
            param[] = 'element';
            ---
                
            Params:
                path = url path
                tolower = enable/disable tolower case conversion 
                
            Returns:
                void
            
         ***********************************************************************/
        
        public void parse ( in char[] path, Uri uri, bool tolower = true )
        {
            this.reset;
            
            if ( tolower )
            {
                this.path.length = path.length;
                this.path = Unicode.toLower(path, this.path);
                
                uri.path(this.path);
            }
            else
            {
                this.path = path;
            }
            
            this.path.split(UriDelim.QUERY_URL, this.splits);
            
            for ( uint i = 0; i < this.splits.length; i++ )        
            {
                if ( this.splits[i].length )
                {
                    this.segments ~= this.splits[i];
                }
            }
        }
    }
    
    
    /***************************************************************************
        
        Query component
            
     ***************************************************************************/
    
    struct Query
    {
        
        /***********************************************************************
    
            QueryPair
        
         ***********************************************************************/
        
        struct QueryPair
        {       
                char[] key;
                char[] value;
        }
    
        /***********************************************************************
            
            Query component string. If decoding is required, this is a new
            string, otherwise it's a slice into the string passed to parse().
            
        ***********************************************************************/                                                   
        
        private             char[]                          query;
        
        /***********************************************************************

            Buffer used when decoding query parameters.

        ***********************************************************************/                                                   

        private             char[]                          decode_buf;

        /***********************************************************************
            
            Query key/value pairs (all slices into this.query)
            
         ***********************************************************************/

        private             QueryPair[]                     pairs;
        
        /***********************************************************************
            
            Temporary split values (slices)
            
         ***********************************************************************/
        
        private             char[][]                        elements;
        private             char[][]                        splits;
        
        /***********************************************************************
            
            Returns value of key
            
            Params:
                key = name of key
                
            Returns:
                value of key or null if not existing
                
         ***********************************************************************/
        
        public char[] opIndex ( char[] key )
        {
            foreach ( pair; this.pairs )
            {
                if ( pair.key == key )
                {
                    return pair.value; // TODO does this needs a .dup? -- (Gavin:) why would it?
                }
            }

            return null;
        }
       
        /***********************************************************************
            
            Returns number of query pairs
                
            Returns:
                number of parameter
                
         ***********************************************************************/
        
        public uint length ()
        {
            return this.pairs.length;
        }
        
        /***********************************************************************
            
            Returns query component as string
                
            Returns:
                url query component
                
         ***********************************************************************/
        
        public char[] toString ()
        {
            return this.query;
        }
        
        /***********************************************************************
            
            Resets path variables
            
         ***********************************************************************/
        
        public void reset ()
        {
            this.query.length = 0;
            this.decode_buf.length = 0;
            this.elements.length = 0;
            this.pairs.length = 0;
            this.splits.length = 0;
        }
        
        /***********************************************************************

            Parses query component, optionally decoding query values.

            Method extracts the query element from the given url by searching 
            for '?' character denoting start of url query. The '#' fragment
            character is denoting the end of the url query, otherwise the end of
            string is used. After identifying the query string its splitted into
            its elements and the values are decoded.

            Method transforms

            ---
                char[] = "?language=en&set=large"
            ---
            
            into 

            ---
                char[][char[]] param;
            
                param['language'] = 'en';
                param['set']      = 'large';
            ---

            Params:
                url    = encoded url character string
                decode_values = if true, query parameter values will be decoded
                    (note that keys are never decoded)

        ***********************************************************************/

        public void parse ( in char[] url, bool decode_values = true )
        {
            this.reset;

            uint start = url.find(UriDelim.QUERY);

            if ( start < url.length )
            {
                uint end = url[start..$].find(UriDelim.FRAGMENT);
                this.extract(url[start + 1 .. start + end], decode_values);
            }
        }

        /***********************************************************************
            
            Seperates the query path elements and optionally decodes value.
            
            Params:
                query  = encoded url character string
                decode_values = if true, query parameter values will be decoded
                    (note that keys are never decoded)

        ***********************************************************************/
        
        private void extract ( in char[] query, bool decode_values = true )
        {
            if ( decode_values )
            {
                this.query.length = 0;
            }
            else
            {
                this.query    = query;
            }

            query.split(UriDelim.PARAM, this.elements);

            foreach ( i, ref element; this.elements )
            {
                if ( element.length && element != UriDelim.PARAM ) 
                {
                    element.split(UriDelim.KEY_VALUE, this.splits);

                    if ( this.splits.length == 2 )
                    {
                        if ( decode_values )
                        {
                            if ( i > 0 )
                            {
                                this.query.append(UriDelim.PARAM);
                            }

                            auto decoded_value = Url.decode(this.splits[1], this.decode_buf);
                            this.query.append(this.splits[0], UriDelim.KEY_VALUE, decoded_value);

                            auto key_start = this.query.length - decoded_value.length - 1 - this.splits[0].length;
                            auto key = this.query[key_start .. key_start + this.splits[0].length];

                            auto value_start = this.query.length - decoded_value.length;
                            auto value = this.query[value_start .. value_start + decoded_value.length];

                            this.pairs ~= QueryPair(key, value);
                        }
                        else
                        {
                            this.pairs ~= QueryPair(this.splits[0], this.splits[0]);
                        }
                    }
                    else if ( this.splits.length == 1 )
                    {
                        this.pairs ~= QueryPair(this.splits[0], null);
                    }
                }
            }
        }
    }

    /***************************************************************************

        Checks whether the passed source string contains any characters encoded
        according to the RFC 2396 escape format. (A '%' character followed by
        two hexadecimal digits.)

        The non-standard 4-digit unicode encoding scheme is also supported ("%u"
        followed by four hex digits).

        If the string does contain encoded characters, the passed working buffer
        is filled with a decoded version of the source string.

        Params:
            source = character string to decode
            working = decode buffer
            char_dg = an optional delegate to determine whether each decoded
                character should be written to the output string in its decoded
                or its original (encoded) form. This delegate can be used in
                cases where the decoding of only certain characters is desired.

        Returns:
            the original string, if it contained no escaped characters, or the
            decoded string otherwise.

    ***************************************************************************/

    private const EncodedMarker = '%';

    public static char[] decode ( char[] source, ref char[] working,
            bool delegate ( char[] decoded, char[] source, size_t offset, size_t c_len ) char_dg = null )
    {
        // take a peek first, to see if there's work to do
        if ( source.length && memchr(source.ptr, EncodedMarker, source.length) )
        {
            size_t read_pos;
            size_t write_pos;

            // ensure we have enough decoding space available
            working.length = source.length;

            // scan string, stripping % encodings as we go
            while ( read_pos < source.length )
            {
                char[8] decoded_buf;
                size_t consumed, produced;

                decodeCharacter(source, read_pos, decoded_buf, consumed, produced);
                char[] decoded = decoded_buf[0..produced];

                bool write_decoded = true;
                if ( consumed > 1 && char_dg )
                {
                    write_decoded = char_dg(decoded, source, read_pos, consumed);
                }

                if ( write_decoded )
                {
                    working[write_pos .. write_pos + decoded.length] = decoded[];
                    write_pos += decoded.length;
                }
                else
                {
                    working[write_pos .. write_pos + consumed] = source[read_pos .. read_pos + consumed];
                    write_pos += consumed;
                }
                read_pos += consumed;
            }

            // return decoded content
            working.length = write_pos;
            return working;
        }

        // return original content
        return source;
    }


    /***************************************************************************

        Extracts a single character from the specified position in the passed
        string. If the specified position contains a '%' character then the
        following characters are scanned to see if they represent an encoded
        character in either the RFC 2396 escape format (%XX) or the non-standard
        escape format (%uXXXX).

        (See: http://en.wikipedia.org/wiki/Percent-encoding)

        The extracted character is written as utf8 into the provided output
        buffer.

        Params:
            source = character string to decode a character from
            offset = position to extract character from
            dst = string buffer to receive decoded characters
            consumed = out value which is set to the number of characters
                consumed from the source
            produced = out value which is set to the number of characters
                written into the destination buffer (will always be at least 1,
                and at most 8)

    ***************************************************************************/

    public static void decodeCharacter ( char[] source, size_t offset, char[8] dst,
            out size_t consumed, out size_t produced )
    in
    {
        assert(source.length, "Url.decodeCharacter: cannot decode an empty string");
        assert(offset < source.length, "Url.decodeCharacter: offset out of array bounds");
    }
    body
    {
        auto src = source[offset .. $];

        if ( src[0] == EncodedMarker && src.length >= 3 )
        {
            // Non-standard case: '%uABCD'
            if ( src[1] == 'u' && src.length >= 6
                 && isHex(src[2]) && isHex(src[3]) && isHex(src[4]) && isHex(src[5]) )
            {
                dchar unicode_char =
                    (toInt(src[2]) * 16 * 16 * 16) + (toInt(src[3]) * 16 * 16) + (toInt(src[4]) * 16) + toInt(src[5]);

                auto written_chars = Utf.encode(dst, unicode_char);

                produced = written_chars.length;
                consumed = 6; // (%uXXXX == 6 characters)
            }
            // Standard case: '%EF'
            else if ( isHex(src[1]) && isHex(src[2]) )
            {
                dchar unicode_char = (toInt(src[1]) * 16) + toInt(src[2]);

                auto written_chars = Utf.encode(dst, unicode_char);

                produced = written_chars.length;
                consumed = 3; // (%XX == 3 characters)
            }
        }

        // Not a percent encoded character, simply pass through
        if ( !consumed )
        {
            dst[0] = src[0];
            produced = 1;
            consumed = 1;
        }
    }


    // TODO: these hex decoding functions should be put somewhere central in
    // ocean (see also swam.dht.DhtHash for more similar functions)

    /***************************************************************************

        Tells if a character is a valid hexadecimal digit.

        Params:
            c = character to check

        Returns:
            true if character is a valid hex digit (ie 0..9, a..f or A..F)

    ***************************************************************************/

    private static bool isHex ( char c )
    {
        return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
    }


    /***************************************************************************

        Converts a hex character to an integer.

        Params:
            c = character to convert

        Returns:
            integer value of hex character (always in the decimal range 0..15)

    ***************************************************************************/

    private static int toInt ( char c )
    in
    {
        assert(isHex(c), "Url.decodeCharacter - invalid hex character");
    }
    out ( n )
    {
        assert(n >= 0 && n <= 15, "Url.decodeCharacter - invalid hex output");
    }
    body
    {
        if      (c >= '0' && c <= '9')  return c - '0';
        else if (c >= 'a' && c <= 'f')  return c - ('a' - 10);
        else if (c >= 'A' && c <= 'F')  return c - ('A' - 10);
        else                            return 0;
    }
}



/*******************************************************************************

    Unittest

    TODO needs to be adjusted to new tango

********************************************************************************/

version (none) debug ( OceanUnitTest )
{  
    import ocean.util.log.Trace;
    import tango.math.random.Random;


    import ocean.core.Memory;

    import Tango = tango.core.Memory;

    void printUsage ( bool b = false )
    {
        static double before = 0; //GC.stats["usedsize"];
       if(!b) 
        Trace.formatln("Used: {} byte ({} kb) (+{}), poolsize {}kb",
                       GC.stats.usedsize, GC.stats.usedsize / 1024,
                       GC.stats.usedsize - before, 
                       GC.stats.poolsize / 1024);
        if (b && before != GC.stats.usedsize) assert (false);
        before = GC.stats.usedsize;
    }
    
    
    unittest
    {
        Url    url;
        char[] url_string;
        
        url_string = "http://www.example.com/path1/path2?key1=value1&key2=value2";
        
        Trace("running unittest ocean.net.http.Url");

        url.parse(url_string);
        
        assert(url.toString == url_string);
        
        assert(url.host == "www.example.com");
        
        assert(url.path.length  == 2);
        assert(url.path.toString  == "/path1/path2");
        assert(url.path[0] == "path1");
        assert(url.path[1] == "path2");
        
        assert(url.query.length == 2);
        assert(url.query.toString  == "key1=value1&key2=value2");
        assert(url.query["key1"] == "value1");
        assert(url.query["key2"] == "value2");

        Trace("running mem test on ocean.net.http.Url");
        
        uint x = 0;
        
        Tango.GC.disable;

        auto mem_before = GC.stats.poolsize;

        for ( uint i=0; i <= 5_000_000; i++ )
        {
            url.parse(url_string);
            
            assert(url.host == "www.example.com");
            assert(url.path.toString  == "/path1/path2");
            assert(url.query.toString  == "key1=value1&key2=value2");
            
            if ( x == 50_000 )
            {
            	auto mem_now = GC.stats.poolsize;

                Trace("finished 50000 calls: alloc mem {} b", mem_now);

                assert(mem_now - mem_before == 0, "found memory leak");

                x = 0;
            }
            
            x++;
        }
        
        char[][] urls;
        urls.length = 2048*10;
        
        auto random = new Random();
        char[] genWord(uint len=0)
        {
            if(len==0)
            {
                random(len);
                len%=7; len++;
            }
            char[] ret; ret.length = len;
            ret.length = 0;
            long val;
            char[] s;
            for(uint i=0;i<len;++i)
            {
                
                
                if(i%8==0)
                {
                    random(val);            
                    s=(cast(char*)&val)[0..8];
                    foreach(ref c; s)
                    {
                        c = (c%('z'-'a'))+'a';
                        
                    }
                }
                assert(s[i%8]<='z' && s[i%8]>='a');

                ret~=s[i%8];
            }
            return ret;
            
        }
        
        
        uint longest = 0;
        for (uint i=0; i< 2048*10; ++i)
        {
            urls[i] = genWord(3)~"://"~
                genWord()~"."~
                genWord(3)~"/";
            
            uint r=void; random(r); r%=30;
            for(uint o=0;o<r;++o)
                urls[i]~=genWord();
            
            urls[i]~="/"~genWord;
            
            longest = (urls[longest].length > urls[i].length) ? longest : i;
        }
        Tango.GC.collect;
        Tango.GC.disable;
        url.parse(urls[longest]);
        Trace("After list setup  ");
        printUsage();
        
        
        
        url.parse(urls[longest]);
        Trace("after longest url ");
        printUsage();
        
        foreach(urlstr;urls)
        {
            url.parse(urlstr);
            //printUsage(true);
        }
        Trace("After mem test #2 ");
        printUsage();
        
        Trace("done unittest ocean.net.http.Url");
    }
}



