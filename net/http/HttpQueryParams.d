/*******************************************************************************

    Module to parse the Query URL and to provide an easy interface for it.

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Mar 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai

    --
    
    Description:
    
    --
    
    Usage:
    
    ---
    
    HttpQueryParams query_params = new HttpQueryParams("/index.php?param1=212&param2=47392);
    
    // get all parameter from the URL 
    char[][char[]] parameter = query_params.getAllParams();
    foreach (name, value; parameter) 
    {
        Stdout.formatln("{}: {}", name, value);
    }
    
    // get request URL 
    char[] url = query_params.getURL();
    
    char[][] url_token = query_params.getURLToken();
    foreach (name; url_token) 
    {
        Stdout.formatln("{}", name);
    }
    
    // get number of parameter
    Stdout.formatln("Number of request parameter: {}", query_params.count());
    
    char[] param_value = query_params.get(param_name);
    
    ---
    
    --
    
    TODO: 
    1. Add URL string decode
    2. Add exceptions
    
    
********************************************************************************/

module      ocean.net.http.HttpQueryParams;


/*******************************************************************************

    Imports
        
*******************************************************************************/

private     import      ocean.net.http.HttpConstants;

private     import      tango.net.http.HttpConst;

private     import      tango.net.Uri;

private     import      Unicode = tango.text.Unicode;

private     import      TextUtil = tango.text.Util : split;


/*******************************************************************************

    HttpQueryParams

********************************************************************************/

class HttpQueryParams
{
    
    /*******************************************************************************
    
        Request Uri
    
    *******************************************************************************/

    
    private             char[][char[]]                  params; // uri query parameter
    private             char[][]                        request_uri_token; // uri token (path elements)
    private             char[]                          request_uri; // requested url
                                                        
    
    /*******************************************************************************
        
        Public Methods
    
     *******************************************************************************/
    
    
    /**
     * Constructor
     * 
     */
    public this () {}
        
    
    
    /**
     * Return Query Parameter Value
     * 
     * Params:
     *     name = name of the paramater 
     *      
     * Returns:
     *     the value for a parameter 
     */
    public char[] get ( char[] name )
    {
        if (name in this.params) 
        {
            return this.params[name];
        }
        
        return null;       
    }
    
    
    
    /**
     * Returns the names of all parameter passed with the query
     *
     * Returns:
     *     names of all parameter passed with the query
     */
    public char[][] getNames () 
    {
        char[][] names;
        
        foreach (name, value; this.params) 
        {
            names ~= name;
        }
        
        return names;
    }
   
   
    
    /**
     * Returns all parameter
     * 
     * Returns:
     */
    public char[][char[]] getAllParams ()
    {
        return this.params;        
    }
        
    
    
    /**
     * Returns the token of the URL path
     * 
     * Returns:
     */
    public char[][] getUrlToken ()
    {
        return this.request_uri_token;
    }
    
    
    
    /**
     * Returns the request url path without parameter 
     * 
     * Returns:
     *     request url path without parameter
     */
    public char[] getRequestUrl ()
    {
        return this.request_uri;       
    }
    
    
    
    /**
     * Returns the number of parameters passed with the query
     * 
     * Returns:
     *     number of parameter passed with the query
     */
    public uint count ()
    {
        return this.params.length;        
    }
    
    
    
    /**
     * Return resource version  
     *  
     * Returns:
     */
    public char[] getVersion ()
    {
        if (this.request_uri_token.length > 1) 
        {
            return this.request_uri_token[2];
        }
        
        return null;
    }

    
    
    /**
     * Return resource format
     * 
     * Returns:
     */
    public char[] getFormat ()
    {
        if (this.request_uri_token.length > 0) 
        {
            return this.request_uri_token[1];
        }
        
        return null;
    }
    
    
    
    /**
     * Parses Request Uri
     * 
     * Params:
     *     uri     = request uri
     *     tolower = transform elements to lowercase
     */
    public void parse ( char[] request_uri, bool tolower = true )
    {
        scope uri = new Uri();
        
        if (tolower)
            request_uri = Unicode.toLower(request_uri.dup);
        
        uri.parse(request_uri.dup);
        
        if (uri.path.length)
            this.parseUriPath(uri.path());
        
        if (uri.query.length)
            this.parseQuery(uri.query());
    }
    
    
    
    /*******************************************************************************
        
        Private Methods
    
     *******************************************************************************/
    
    
    /**
     * Parses URL params into an associative array
     * this.params
     * 
     *  e.g. language=en&set=large
     *  
     *       this.params['language'] = 'en';
     *       this.params['set']      = 'large';
     *       
     * Params:
     *      query_string = query string to parse     
     */
    private void parseQuery ( char[] query_string )
    {
        char[][] elements, pair;
        
        elements = TextUtil.split(query_string, UriDelim.PARAM);
        
        foreach ( element; elements )
        {
            // if the delim will be passed to split, a segmentation is thrown
            if ( element.length && element != UriDelim.PARAM ) 
            {
                pair = TextUtil.split(element, UriDelim.KEY_VALUE);
                
                if (pair.length == 2)
                {
                    this.params[pair[0].dup] = pair[1].dup;                      
                }
                else
                {
                    this.params[pair[0].dup] = null;  
                }
            }
        }
    }
    
    
    
    /**
     * Parses the path elements of a URL string and puts it into
     * this.request_uri_token as single elements
     * 
     * e.g. /url/example
     *       
     *       [1] => url
     *       [2] => example
     * 
     * Params:
     *      str = uri path
     */
    private void parseUriPath ( char[] path )
    {
        char[][] token;
        
        token = TextUtil.split(path, UriDelim.QUERY_URL);        
        
        for (uint i=0; i<token.length; i++)        
        {
            if ( token[i].length )
            {
                this.request_uri_token ~= token[i].dup;
            }
        }
        
    }
    
    
}


/*******************************************************************************

    HttpQueryParamsException

********************************************************************************/

class HttpQueryParamsException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }

    private:
        static void opCall(char[] msg) { throw new HttpQueryParamsException(msg); }

}