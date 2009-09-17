/*******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Feb 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        D API Client for the Yahoo Search API.

        This module provides an D interface to the Yahoo Search Web Service API. 
        
        ---
        
        
        Yahoo! Search BOSS (Build your Own Search Service) is an new service to
        enable third parties to build search products leveraging their own data, 
        content, technology, social graph, or other assets. The API suports
        Web, News, and Image Search as well as Spelling Suggestions.
        
        A typical REST request URI looks like this:
            http://boss.yahooapis.com/ysearch/web/v1/{query}?appid={yourBOSSappid}[&param1=val1&param2=val2&etc]
        
        ---

        Usage example:

            auto oo = new YahooSearch("__app_id__");
            
            oo.setQuery("Yeti");
            
            for ( int i = 0; i < 10; i++ )
            {
                oo.setIndex(i*8); // to get to the next page as every page contains 8 results by default
                oo.search();
                
                if ( !oo.isError )
                    Stdout(oo.getResponse());
            }
            
        Hint: Its possible to use the API without a API Key!

        --
        

        Related

        http://developer.yahoo.com/search
        http://developer.yahoo.com/common/json.html

*******************************************************************************/

module ocean.net.services.YahooSearch;

private import  ocean.net.services.model.IClient;

private import  tango.net.http.HttpClient, tango.net.http.HttpGet, tango.net.http.HttpHeaders;

private import  tango.text.Util : containsPattern;

private import  Integer = tango.text.convert.Integer : toString;


/*******************************************************************************

    YahooSearch

*******************************************************************************/

class YahooSearch : IClient
{
    
    
    /*******************************************************************************
    
        Configuration Variables
    
    ******************************************************************************/    
    
    
    /**
    * Yahoo API access key
    */
    private     char[]              access_key;
    
    
    /*******************************************************************************

        Request Variables
    
    ******************************************************************************/ 

    
    /**
    * Default API Endpoint
    */
    private     char[]              request_uri = "http://search.yahooapis.com/WebSearchService/V1/webSearch";    
    
    
    /**
    * Request Params
    */
    private     char[][char[]]      request_params;    
    
    
    /**
    * Default start index position
    */
    private     char[]              request_index = "0";     
    
    
    /**
     * Search query
     */
    private     char[]              request_query;
    
    
    /*******************************************************************************

        Response Variables
    
    ******************************************************************************/ 


    /**
    * Content returned from API request
    */
    private     char[]              response_content;
    
    
    /**
    * Error on request
    */
    private     bool                response_error;   
    
    
    
    /**
     * Return instance of Yahoo search API client
     * 
     * You can sign up for an Yahoo! BOSS search API key here:
     *      http://developer.yahoo.com/wsregapp/
     * 
     * Params:
     *     access_key = Google API access key
     */
    public this ( char[] access_key ) 
    {
        this.setAccessKey(access_key);
    }
    
    
    
    /**
     * Sets Access Key
     * 
     * The key is used to authenticate the Google API requests.
     * 
     * Params:
     *     access_key = google search api access key
     */
    public void setAccessKey( char[] access_key ) 
    {
        this.access_key = access_key;
    }
    

    
    /**
     * Returns API Access Key 
     * 
     * Returns:
     *     Access Key
     */
    public char[] getAccessKey() 
    { 
        return this.access_key;
    }
    
    
    
    /**
     * Set index start position for search request
     * 
     * If you want to use this for pagging forward be aware to multiply it by eight
     *  e.g.
     *      page 1 = index 0
     *      page 2 = index 8
     *      page 3 = index 16
     * 
     * Params:
     *     index = index start position
     */
    public void setIndex( int index ) 
    {
        this.request_index = Integer.toString(index);
    }
    
    
    /**
     * Set search query phrase
     * 
     * Params:
     *     query = search term
     */
    public void setQuery( char[] query ) 
    {
        this.request_query = query;
    }
    
    
    
    /**
     * Performs API Request
     * 
     *   ---
     *
     *   Usage example:
     *
     *       auto api = new YahooSearch("__api_key__");
     *       
     *       oo.setQuery("Yeti");
     *       oo.search();
     *           
     *       if ( !oo.isError )
     *             Stdout(oo.getResponse());
     *   
     * ---
     * 
     * TODO:
     *      
     *      There is another argument zip.
     *      
     * ---
     * 
     */
    public void search()
    {
        char[][char[]] params;
        
        params["results"]   = "8";
        
        params["query"] = this.request_query;
        params["start"] = this.request_index;
        
        this.doRequest(params);
    }
    
    
    
    /**
     * Enable/Disable error flag
     * 
     * Params:
     *     flag = set to true if error occured
     */
    public bool isError()
    {
        return this.response_error;
    }    
    
    
    
    /**
     * Returns reponse
     * 
     * Returns:
     *      XML response
     */
    public char[] getResponse()
    {
        return this.response_content;
    } 
    
    
    
    /**
     * Performs Yahoo Search API Request
     *
     * Params:
     *     params = REST query parameter
     *     
     * Returns:
     *    true, if request was successful
     */
    private void doRequest( char[][char[]] params )
    {
        this.flushRequestParams();
       
        this.addRequestParam("appid", this.getAccessKey);
        this.addRequestParam("output", "json");
        
        foreach(param, value; params)
            this.addRequestParam(param, value);
        
        auto client = new HttpClient (HttpClient.Get, http_build_uri(this.getRequestUri, this.getRequestParams));
        
        client.open();
        
        scope (exit) client.close;
        
        if (client.isResponseOK)
        {
            client.read (&this.readResponse, uint.max);
            
            this.setError(false);
        }
        
        this.setError(true);
    }
    
    
    
    /**
     * Reads HTTP Response
     * 
     * TODO: Read in BufferInput not char[]
     * 
     * Params:
     *     content = buffer with HTTP response
     */
    private void readResponse( void[] content )
    {
        this.response_content ~= cast(char[]) content;
        
        if ( containsPattern(this.response_content, "<Error>") )
            this.setError(true);
    }
    
    
    
    /**
     * Returns URL request parameter
     * 
     * Returns:
     *      request paramter as string
     */
    private char[] getRequestParams()
    {
        return this.http_build_str(this.request_params);
    }

    
    
    /**
     * Adds query parameter to request
     * 
     * Params:
     *     name = name of URI query paramter
     *     value = value of query parameter
     */
    private void addRequestParam( char[] name, char[] value )
    {
        this.request_params[name] = value;
    }
    
    
    
    /**
     * Flushes REST request parameter
     *
     */
    private void flushRequestParams()
    {
        this.request_params = null;
    }
    
    
    
    /**
     * Build query string
     * 
     * Params:
     *     params = params of API request
     *     
     * Returns:
     *     URI of API request
     */
    private char[] http_build_str ( char[][char[]] params )
    {
        char[] uri;
        
        foreach (param, value; params)
            uri = uri.dup ~ param ~ "=" ~ value ~ "&";
            
        return uri[0..$-1];
    }

    
    
    /**
     * Build an REST request URL
     * 
     * Params:
     *     url = request url
     *     query = request query parameter
     *     
     * Returns:
     *     REST request uri
     */
    private char[] http_build_uri( char[] url, char[] params )
    {
        return url ~ "?" ~ params;
    }
    
    
    
    /**
     * Enable/Disable error flag
     * 
     * Params:
     *     flag = set to true if error occured
     */
    private void setError( bool error )
    {
        this.response_error = error;
    }    
    
    
    
    /**
     * Return API request endpoint
     * 
     * Returns:
     *     Google Search API endpoint
     */
    private char[] getRequestUri() 
    { 
        return this.request_uri;
    }
    
      
    
} // YahooSearch



/**
 * This is the base class from which all exceptions generated by this module
 * derive from.
 */
class YahooException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }

    private:
        static void opCall(char[] msg) { throw new YahooException(msg); }

} // class YahooException

