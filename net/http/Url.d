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
        
*******************************************************************************/

private     import      ocean.net.http.HttpConstants;

private     import      tango.net.http.HttpConst;

private     import      tango.net.Uri;

private     import      Unicode = tango.text.Unicode;

private     import      TextUtil = tango.text.Util : split;


/*******************************************************************************  

    Url parses a url string and seperates its components to be directly 
    and efficiently accessible.
    
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
    
    TODO
    
    add url string (en)decoding and proper exception handling

    See also the Rfc's
    
    http://tools.ietf.org/html/rfc3986
    http://tools.ietf.org/html/rfc1738
    
    An overview about all the Url related Rfc can be found on the apache website
    
    http://labs.apache.org/webarch/uri/rfc/
    
*********************************************************************************/

struct Url
{
    
    /*******************************************************************************
        
        Url string
        
     *******************************************************************************/                                                   
    
    private             char[]                          url;

    /*******************************************************************************
        
        Host subcomponent
    
     *******************************************************************************/
    
    public              Host                            host;

    /*******************************************************************************
        
        Path component
    
     *******************************************************************************/
    
    public              Path                            path;

    /*******************************************************************************
    
        Query component

     *******************************************************************************/
    
    public              Query                           query;
    
    
    /*******************************************************************************
        
        Returns length of url string
            
        Returns:
            length of host name
            
     *******************************************************************************/
    
    public uint length ()
    {
        return this.url.length;        
    }

    
    /*******************************************************************************
        
        Returns url string
            
        Returns:
            url string
            
     *******************************************************************************/
    
    public char[] toString ()
    {
        return this.url;
    }

    
    /*******************************************************************************
        
        Parses request Uri
            
        Params:
            url     = url to parse
            tolower = enable/disable to lowercase
            
        Returns:
            resource format or null if not given
            
     *******************************************************************************/
    
    public void parse ( char[] url, bool tolower = true )
    {
        if (tolower)
            this.url = Unicode.toLower(url.dup);
        
        scope uri = new Uri();
        
        uri.parse(this.url.dup);
        
        if (uri.host)
            this.host.parse(uri.host);
        
        if (uri.path.length)
            this.path.parse(uri.path);

        if (uri.query.length)
            this.query.parse(uri.query);
    }
    
    
    /*******************************************************************************
        
        Host
            
     *******************************************************************************/
    
    struct Host
    {
        
        /*******************************************************************************
            
            Host authority subcomponent string
            
         *******************************************************************************/                                                   
        
        private             char[]                          host;
        
        /*******************************************************************************
            
            Returns length of host subcomponent
                
            Returns:
                length of host name
                
         *******************************************************************************/
        
        public uint length ()
        {
            return this.host.length;        
        }
    
        
        /*******************************************************************************
            
            Returns authority subcomponent string
                
            Returns:
                host subcomponent (hostname)
                
         *******************************************************************************/
        
        public char[] toString ()
        {
            return this.host;
        }
        
        
        /*******************************************************************************
            
            Parses host subcomponent
                
            Params:
                path = url path
                
            Returns:
                void
            
         *******************************************************************************/
        
        public void parse ( char[] host )
        {
            this.host = host.dup;
        }
    }
    
    
    /*******************************************************************************
        
        Path Component
            
     *******************************************************************************/
    
    struct Path
    {
        
        /*******************************************************************************
            
            Path component string
            
         *******************************************************************************/                                                   
        
        private             char[]                          path;
        
        /*******************************************************************************
            
            Path segments
            
         *******************************************************************************/                                                   
        
        private             char[][]                        segments;
    
    
        /*******************************************************************************
            
            Operator overloading; Returns path segment
            
            Params:
                name = name of the paramater 
                
            Returns:
                path segment or null if not existing
                
         *******************************************************************************/
        
        public char[] opIndex(uint key)
        {
            if (this.segments.length > key)
            {
                return this.segments[key];
            }
            
            return null;
        }
        
        
        /*******************************************************************************
            
            Returns number path segments
                
            Returns:
                number of path segments
                
         *******************************************************************************/
        
        public uint length ()
        {
            return this.segments.length;        
        }

        
        /*******************************************************************************
            
            Returns path component as string
                
            Returns:
                url path component
                
         *******************************************************************************/
        
        public char[] toString ()
        {
            return this.path;
        }
        
        
        /*******************************************************************************
            
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
                
            Returns:
                void
            
         *******************************************************************************/
        
        public void parse ( char[] path )
        {
            this.path = path.dup;
            this.segments.length = 0;
            
            char[][] segments = TextUtil.split(path, UriDelim.QUERY_URL);        
            
            for ( uint i = 0; i < segments.length; i++ )        
            {
                if ( segments[i].length )
                {
                    this.segments ~= segments[i].dup;
                }
            }
        }
    }
    
    
    /*******************************************************************************
        
        Query component
            
     *******************************************************************************/
    
    struct Query
    {
        
        /***************************************************************************
    
            QueryPair
        
         ***************************************************************************/
        
        struct QueryPair
        {       
                char[] key;
                char[] value;
        }
    
        /*******************************************************************************
            
            Query component string
            
         *******************************************************************************/                                                   
        
        private             char[]                          query;
        
        /*******************************************************************************
            
            Query key/value pairs
            
         *******************************************************************************/

        private             QueryPair[]                     pairs;
        
        
        /*******************************************************************************
            
            Returns value of key
            
            Params:
                key = name of key
                
            Returns:
                value of key or null if not existing
                
         *******************************************************************************/
        
        public char[] opIndex ( char[] key )
        {
            foreach ( pair; this.pairs )
            {
                if ( pair.key == key )
                {
                    return pair.value; // TODO does this needs a .dup?
                }
            }
            
            return null;
        }
        
        
        /*******************************************************************************
            
            Returns number of query pairs
                
            Returns:
                number of parameter
                
         *******************************************************************************/
        
        public uint length ()
        {
            return this.pairs.length;
        }
        
        
        /*******************************************************************************
            
            Returns query component as string
                
            Returns:
                url query component
                
         *******************************************************************************/
        
        public char[] toString ()
        {
            return this.query;
        }
        
        
        /*******************************************************************************
            
            Parses query component
            
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
                query_string = query string to parse
                
            Returns:
                void
            
         *******************************************************************************/
        
        public void parse ( char[] query_string )
        {
            char[][] elements, split;
            QueryPair pair;
            
            this.pairs.length = 0;
            this.query = query_string;
            
            elements = TextUtil.split(query_string, UriDelim.PARAM);
            
            foreach ( element; elements )
            {
                if ( element.length && element != UriDelim.PARAM ) 
                {
                    split = TextUtil.split(element, UriDelim.KEY_VALUE);
                    
                    if ( split.length )
                    {
                        pair.key   = split[0].dup;
                        pair.value = null;
                        
                        if (split.length == 2)
                        {
                            pair.value = split[1].dup;
                        }
    
                        this.pairs ~= pair;
                    }
                }
            }
        }
        
    }

    
}

/*******************************************************************************

    Unittest

********************************************************************************/

debug ( OceanUnitTest )
{  
    import tango.util.log.Trace;
    import tango.core.Memory;
    
    unittest
    {
        Url    url;
        char[] url_string;
        
        url_string = "http://www.example.com/path1/path2?key1=value1&key2=value2";
        
        Trace.formatln("running unittest ocean.net.http.Url");

        url.parse(url_string);
        
        assert(url.toString == url_string);
        
        assert(url.host.toString  == "www.example.com");
        
        assert(url.path.length  == 2);
        assert(url.path.toString  == "/path1/path2");
        assert(url.path[0] == "path1");
        assert(url.path[1] == "path2");
        
        assert(url.query.length == 2);
        assert(url.query.toString  == "key1=value1&key2=value2");
        assert(url.query["key1"] == "value1");
        assert(url.query["key2"] == "value2");

        Trace.formatln("running mem test on ocean.net.http.Url");
        
        uint x = 0;
        
        for ( uint i=0; i <= 500_000; i++ )
        {
            url.parse(url_string);
            
            assert(url.host.toString  == "www.example.com");
            assert(url.path.toString  == "/path1/path2");
            assert(url.query.toString  == "key1=value1&key2=value2");
            
            if ( x == 50_000 )
            {
                Trace.formatln("finished 50000 calls: alloc mem {} b", 
                        GC.stats["poolSize"]);
                
                assert(GC.stats["poolSize"] < 2000000, "found memory leak");
                
                x = 0;
            }
            
            x++;
        }
        
        Trace.formatln("done unittest ocean.net.http.Url");
    }
}



