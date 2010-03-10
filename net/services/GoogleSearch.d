/*******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Feb 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        D API Client for the Google Search API.

        This module provides an D interface to the Google Search Web Service API. 
        
        ---
        
        The Google AJAX Search API is a Javascript library that allows you to 
        include Google Search in your web pages and other web applications. For 
        Flash, and other Non-Javascript environments, the API exposes a raw 
        RESTful interface that returns JSON encoded results that are easily 
        processed by most languages and runtimes.
        
        ---

        Usage example:

            auto oo = new GoogleSearch("__api_key__");
            
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

        http://code.google.com/apis/ajaxsearch/documentation/


*******************************************************************************/

module ocean.net.services.GoogleSearch;

public  import  ocean.core.Exception: GoogleException;

private import  ocean.net.services.model.IClient;

private import  tango.net.http.HttpClient, tango.net.http.HttpGet, tango.net.http.HttpHeaders;

private import  tango.text.Util : containsPattern;

private import  Integer = tango.text.convert.Integer : toString;


/*******************************************************************************

    GoogleSearch

*******************************************************************************/

class GoogleSearch : IClient
{

    
    /*******************************************************************************

         Configuration Variables

    ******************************************************************************/    
    
    
    /**
     * Default API Version
     */
    private     char[]              api_version = "1.0";
    
    
    /**
     * Google API access key 
     */
    private     char[]              access_key;
    
    
    /*******************************************************************************

         Request Variables

    ******************************************************************************/ 
    
    
    /**
    * Default API Request Locale
    */
    private     char[]              request_locale = "en";
    
    
    /**
    * Default API Endpoint
    */
    private     char[]              request_uri = "http://ajax.googleapis.com/ajax/services/search/web";
    
    
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
    
    
    /**
     * Request filter
     */
    private     bool                request_filter;  

    
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
     * HTTP error code of last request
     */    
    private     int                 response_error_code;
    
    
    /**
     * HTTP error code of last request
     */    
    private     int                 response_json_error_code;
    
    
    
    /******************************************************************************

        Public Methods

    ******************************************************************************/
    
    
    /**
     * Return instance of Google search API client
     * 
     * You can sign up for an search API key here:
     *      http://code.google.com/intl/de-DE/apis/ajaxsearch/signup.html
     * 
     * Params:
     *     access_key = Google API access key
     */
    public this ( char[] access_key = null ) 
    {
        this.setAccessKey(access_key);
    }
    
    
    
    /**
     * Sets Google Access Key
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
     * Returns Google Search API Access Key 
     * 
     * Returns:
     *     Access Key
     */
    public char[] getAccessKey() 
    { 
        return this.access_key;
    }
    
    
    
    /**
     * Sets Google Search API Version to use
     * 
     * Params:
     *     apiVersion = API version to use
     */
    public void setApiVersion( char[] api_version ) 
    {
        this.api_version = api_version;
    }
    
    
    
    /**
     * Returns Google Search API version used
     * 
     * Returns:
     *     API Version
     */
    public char[] getApiVersion() 
    {
        return this.api_version; 
    }
    
    
    
    /**
     * Set API request locale
     * 
     * The request locale supplies the host language of the application making the request. 
     * 
     * Default value = en
     * 
     * Params:
     *     locale = Google locale
     */
    public void setRequestLocale( char[] locale ) 
    { 
        this.request_locale = locale;
    }
    
    
    
    /**
     * Return API request locale
     * 
     * Returns:
     *     Google locale used
     */
    public char[] getRequestLocale() 
    { 
        return this.request_locale;
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
     * Disables Googles response filter
     * 
     * Params:
     *     filter = switch google filter on/off
     */
    public void disableFilter( bool filter ) 
    {
        this.request_filter = filter;
    }
    
    
    
    /**
     * Performs API Request
     * 
     *   ---
     *
     *   Usage example:
     *
     *       auto api = new GoogleSearch("__api_key__");
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
     *      There is another argument lr to add to filter for a specific language.
     *      This optional argument allows tto restrict the search to documents written 
     *      in a particular language (e.g., lr=lang_ja).
     *      
     * ---
     * 
     */
    public void search()
    {
        char[][char[]] params;
        
        params["rsz"]   = "large";                  // = 8 items per result set
        
        params["q"]     = this.request_query;
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
     * Returns HTTP Error Code from last request
     * 
     * Returns:
     *     HTTP error code
     */    
    public int getHTTPErrorCode()
    {
        return this.response_error_code;
    }
    
    
    
    /**
     * Returns HTTP Error Code from last request
     * 
     * Returns:
     *     HTTP error code
     */    
    public int getJsonErrorCode()
    {
        return this.response_json_error_code;
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
    
    
    
    /******************************************************************************

         Private Methods

     ******************************************************************************/
    
    
    /**
     * Performs Google Search API Request
     *
     * Params:
     *     params = REST query parameter
     *     
     * Returns:
     *    true, if request was successful
     */
    private bool doRequest( char[][char[]] params )
    {
        char[] request_url;
        
        this.flushRequestParams();
        
        if ( this.getAccessKey.length )
            this.addRequestParam("key", this.getAccessKey);
        
        if ( this.request_filter )
            this.addRequestParam("filter", "0");
        
        this.addRequestParam("v", this.getApiVersion);
        this.addRequestParam("hl", this.getRequestLocale);
        
        foreach(param, value; params)
            this.addRequestParam(param, value);
        
        request_url = http_build_uri(this.getRequestUri, this.getRequestParams);


        auto client = new HttpClient (HttpClient.Get, request_url);
        
        try 
        {
            client.open();
            
            scope (exit) client.close;
            
            if (client.isResponseOK)
            {
                this.setError(false);
                client.read (&this.readResponse, uint.max);
                
                this.checkJsonStatusCode();
                
                return true;
            }
            else
            {
                this.setHTTPErrorCode(client.getStatus);
                
                GoogleException("HTTP error " ~ Integer.toString(client.getStatus) ~ " on URL " ~ request_url); 
            }
            
        }
        catch (Exception e)
            GoogleException("Google Client Error: " ~ e.msg ~ " on url [ " ~ request_url ~ " ] with response [ " ~ this.response_content ~ " ] and status [ " ~ Integer.toString(client.getStatus) ~ " ]");
        
        this.setError(true);
        
        return false;
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
        this.response_content = null;
        this.request_params = null;
        this.response_error_code = 0;
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
    
    
    
    /**
     * Sets HTTP error code
     * 
     * Params:
     *     flag = set to true if error occured
     */
    private void setHTTPErrorCode( int code )
    {
        this.response_error_code = code;
    }

    
    
    /**
     * Checks JSON object status code
     * 
     * Method extracts JSON response code from the response object. If
     * the code doesnt equals 200 the response encountered an error.
     * 
     */
    private void checkJsonStatusCode( )
    {
        JSON.JsonValue* json_item;
        
        try 
        {
            auto js = new JSON;
            
            auto result = js.parse (this.response_content);
            auto obj = result.toObject;
            
            json_item = obj.value("responseStatus");
            
            if ( json_item !is null && json_item.type == JSON.Type.Number)
            {
                this.response_json_error_code = cast(int) json_item.toNumber;
                
                if ( this.response_json_error_code != 200 )
                    this.response_error = true;
            }
        }
        catch (Exception e)
            GoogleException("JSON error on parsing object - " ~ this.response_content);
    }
    
    
} // GoogleSearch
