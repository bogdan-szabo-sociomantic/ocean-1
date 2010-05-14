/*******************************************************************************

    Module to parse the Query URL and to provide an easy interface for it.

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Mar 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai
    
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

    Http query parser
    
    Usage example on retrieving query parameter
    ---
    char[] query = "/index.php?param1=212&param2=47392";
    
    HttpQueryParams query_params = new HttpQueryParams(query);
    
    char[][char[]] parameter = query_params.getAllParams();
    
    foreach (name, value; parameter) 
    {
        Stdout.formatln("{}: {}", name, value);
    }
    ---
    
    Retrieving url path elements
    ---
    char[] url = query_params.getURL();
    
    char[][] url_token = query_params.getURLToken();
    
    foreach (name; url_token) 
    {
        Stdout.formatln("{}", name);
    }
    ---
    
    Returning the number of query parameters
    ---
    Stdout.formatln("Number of request parameter: {}", query_params.count());
    ---
    
    Returning a single parameter value
    ---
    char[] param_value = query_params.get(param_name);
    ---
    ---
    
    TODO
    
    change class to struct
    add URL string (en)decode and exception handling


********************************************************************************/

class HttpQueryParams
{
    
    /*******************************************************************************
    
        Request Uri parameter

     ******************************************************************************/

    
    private             char[][char[]]                  params;
    
    /*******************************************************************************
        
       Request Uri path elements

     ******************************************************************************/
    
    private             char[][]                        request_uri_token;
    
    /*******************************************************************************
        
        Request Uri string
        
     ******************************************************************************/                                                   
    
    private             char[]                          request_uri;
    
    
    /*******************************************************************************
        
        Constructor; nothing to do.
    
     *******************************************************************************/
    
    public this () {}
        
    
    /*******************************************************************************
        
        Return Query Parameter Value
        
        Params:
            name = name of the paramater 
            
        Returns:
            parameter value or null if not existing
            
     *******************************************************************************/
    
    public char[] get ( char[] name )
    {
        if (name in this.params) 
        {
            return this.params[name];
        }
        
        return null;       
    }
    
    
    /*******************************************************************************
        
        Returns the parameter names
            
        Returns:
            names of all parameter
            
     *******************************************************************************/

    public char[][] getNames () 
    {
        char[][] names;
        
        foreach (name, value; this.params) 
        {
            names ~= name;
        }
        
        return names;
    }
   
   
    /*******************************************************************************
        
        Returns all parameter
            
        Returns:
            list of parameter
            
     *******************************************************************************/

    public char[][char[]] getAllParams ()
    {
        return this.params;        
    }
     
    
    /*******************************************************************************
        
        Returns Uri path tokens
            
        Returns:
            list of tokens
            
     *******************************************************************************/

    public char[][] getUrlToken ()
    {
        return this.request_uri_token;
    }
    
    
    /*******************************************************************************
        
        Returns the url path without parameter 
            
        Returns:
            url path
            
     *******************************************************************************/
    
    public char[] getRequestUrl ()
    {
        return this.request_uri;       
    }
    
    
    /*******************************************************************************
        
        Returns the number of parameter
            
        Returns:
            number of parameter
            
     *******************************************************************************/
    
    public uint count ()
    {
        return this.params.length;        
    }
    
    
    /*******************************************************************************
        
        Return resource version
            
        Returns:
            resource version or null if not given
            
     *******************************************************************************/

    deprecated public char[] getVersion ()
    {
        if (this.request_uri_token.length > 1) 
        {
            return this.request_uri_token[2];
        }
        
        return null;
    }

    
    /*******************************************************************************
        
        Return resource format
            
        Returns:
            resource format or null if not given
            
     *******************************************************************************/

    deprecated public char[] getFormat ()
    {
        if (this.request_uri_token.length > 0) 
        {
            return this.request_uri_token[1];
        }
        
        return null;
    }
    
    
    /*******************************************************************************
        
        Parses request Uri
            
        Params:
            request_uri = request uri
            tolower     = enable/disable transformation of elements to lowercase
            
        Returns:
            resource format or null if not given
            
     *******************************************************************************/
    
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
    
        Parses URL params into an associative array
        
        Method transforms
        ---
        char[] = "language=en&set=large"
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

    private void parseQuery ( char[] query_string )
    {
        char[][] elements, pair;
        
        elements = TextUtil.split(query_string, UriDelim.PARAM);
        
        foreach ( element; elements )
        {
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
    
    
    /*******************************************************************************
        
        Parses the path elements of a URL string
        
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
            path = uri path
            
        Returns:
            void
        
     *******************************************************************************/
    
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
