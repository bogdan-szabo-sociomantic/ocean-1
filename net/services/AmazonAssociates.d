/*******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Feb 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        D API Client for the Amazon Web Services.

        This module provides an D interface to the Amazon Associates Web Services. 
        
        ---
        The Amazon Associates Web Service allows you to advertise millions of new 
        and used products more efficiently on your web site, while earning 
        referral fees. The Service exposes Amazons product data through an 
        easy-to-use web services interface that is a powerful tool to help Amazon 
        Associate website owners and developers to make money. 
        
        ---

        Usage example:

            auto aws = new AmazonAssociates("__access_key_id__");
            
            aws.setRequestLocale("us");
            aws.setAssociateID("__associate_id__");
            
            char[][char[]] options;
            
            options["ResponseGroup"] = "Large";

            aws.getItem("3503112464", options);
            
            if ( !aws.isError )
                Stdout(aws.getResponse());

        --

        Related

        http://aws.amazon.com/associates/
        http://docs.amazonwebservices.com/AWSECommerceService/2009-01-06/DG/

*******************************************************************************/

module ocean.net.services.AmazonAssociates;


/*******************************************************************************

    Imports

*******************************************************************************/

private     import      ocean.crypt.crypto.hashes.SHA256,
                        ocean.crypt.crypto.macs.HMAC;

private     import      tango.net.http.HttpClient, tango.net.http.HttpGet, 
                        tango.net.http.HttpHeaders;

private     import      tango.text.Util : containsPattern;

private     import      Integer = tango.text.convert.Integer: toString;

private     import      tango.sys.Common : sleep;

private     import      tango.time.Clock;

private     import      tango.text.locale.Locale, tango.text.convert.Layout;

private     import      Base64 = tango.io.encode.Base64;


/*******************************************************************************

    AmazonAssociates

*******************************************************************************/

class AmazonAssociates
{

    
    /*******************************************************************************

         Amazon Configuration

    ******************************************************************************/    
    
    
    /**
     * Default API Version
     */
    private     char[]              api_version = "2009-10-01";
    
    
    /**
     * Amazon Associate IDs used in the URL's so a commision may be payed 
     */
    private     char[][char[]]      associate_id;
    
    
    /**
     * Amazon Access Key IDs used when quering Amazon servers
     * (You need to set up an Associate ID for every locale)
     */
    private     char[]              access_key_id;
    
    
    /**
     * Amazon Secret Key IDs used when quering Amazon servers
     * (You need to set up an Associate ID for every locale)
     */
    private     char[]              secret_key_id;
    
    
    /*******************************************************************************

         Request Variables

    ******************************************************************************/ 
    
    
    /**
     * Default API Request Locale
     */
    private     char[]              request_locale = "us";
    
    
    /**
     * API Endpoints
     */
    private     char[][char[]]      request_uri;
    
    
    /**
     * Request Params
     */
    private     char[][char[]]      request_params;

    
    /**
     * Maximum Retries on Connection Errors (HTTP or Socket)
     */
    private     ubyte               request_max_retries = 4;    
    
    
    /******************************************************************************

         Response Variables
 
     ******************************************************************************/ 
    
    
    /**
     * Content returned from API request
     */
    private     char[]              response_content;
    
    
    /**
     * Error on last request
     */
    private     bool                response_error;
    
    
    /**
     * HTTP error code of last request
     */    
    private     int                 response_error_code;
    
    
    
    /******************************************************************************

         Public Methods

     ******************************************************************************/
    
    
    /**
     * Return instance of Amazon Associate Web Services API Client
     * 
     * Sets the AccessKeyID and default locales for the various Amazon sales regions. Currently 
     * US, UK, DE, JP, FR, and CA are supported as sales regions.
     * 
     * Params:
     *     access_key = amazon access key id
     */
    public this ( char[] access_key, char[] secret_key ) 
    {
        this.setAccessKey(access_key);
        this.setSecretKey(secret_key);
        
        this.request_uri["ca"] = "ecs.amazonaws.ca";
        this.request_uri["de"] = "ecs.amazonaws.de";
        this.request_uri["fr"] = "ecs.amazonaws.fr";
        this.request_uri["jp"] = "ecs.amazonaws.jp";
        this.request_uri["uk"] = "ecs.amazonaws.co.uk";
        this.request_uri["us"] = "ecs.amazonaws.com";
    }
    
    
    
    /**
     * Sets Amazon Web Services Access Key Identifier for current locale
     * 
     * The key is used to authenticate the Amazon Web Services client requests.
     * 
     * Params:
     *     access_key_id = amazon access key id
     */
    public void setAccessKey( char[] access_key_id ) 
    {
        this.access_key_id = access_key_id;
    }
    
    
    /**
     * Sets Amazon Web Services Secret Key Identifier for current locale
     * 
     * The key is used to authenticate the Amazon Web Services client requests.
     * 
     * Params:
     *     secret_key_id = amazon secret key id
     */
    public void setSecretKey( char[] secret_key_id ) 
    {
        this.secret_key_id = secret_key_id;
    }
    
    
    /**
     * ShortCut: Sets Amazon Web Services Associate ID for current locale
     * 
     * The key is used to pay the commission to a certain account.
     * 
     * Params:
     *     associate_id = amazon associate id
     */
    public void setAssociateID( char[] associate_id ) 
    {
        this.setAssociateID(this.request_locale, associate_id);
    }
    
    
    
    /**
     * Sets Amazon Web Services Associate Identifier
     * 
     * The key is used to pay the commission to a certain account.
     * 
     * Params:
     *     locale = amazon sales region
     *     associate_id = amazon associate id
     */
    public void setAssociateID( char[] locale, char[] associate_id ) 
    {
        this.associate_id[locale] = associate_id;
    }
    
    
    
    /**
     * Returns Amazon Access Key Identifier for the given 
     * 
     * Params:
     *     locale = amazon sales region
     *     
     * Returns:
     *     Associate ID or null if not set
     */
    public char[] getAssociateID( char[] locale = null ) 
    { 
        if ( locale !is null && locale in this.associate_id )
            return this.associate_id[this.request_locale];
        else 
            if ( this.request_locale in this.associate_id )
                return this.associate_id[this.request_locale];
        
        return null;
    }
    
    
    
    /**
     * Returns Amazon Access Key Identifier
     * 
     * Returns:
     *     Access Key Identifier
     */
    public char[] getAccessKey() 
    { 
        return this.access_key_id;
    }
    
    
    /**
     * Returns Amazon Secret Key Identifier 
     * 
     * Returns:
     *     Secret Key Identifier
     */
    public char[] getSecretKey() 
    { 
        return this.secret_key_id;
    }
    
    
    /**
     * Sets Amazon Web Services API Version to use for requests
     * 
     * Params:
     *     apiVersion = API version to use
     */
    public void setApiVersion( char[] api_version ) 
    {
        this.api_version = api_version;
    }
    
    
    
    /**
     * Returns API version used
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
     * Params:
     *     locale = Amazon locale
     */
    public void setRequestLocale( char[] locale ) 
    { 
        this.request_locale = locale;
    }
    
    
    
    /**
     * Return API request locale
     * 
     * Returns:
     *     Amazon locale
     */
    public char[] getRequestLocale() 
    { 
        return this.request_locale;
    }
    
    
    
    /**
     * Return API request locale
     * 
     * Returns:
     *     Amazon locale
     */
    public char[] getRequestUri() 
    { 
        if ( this.request_locale in this.request_uri )
            return this.request_uri[this.request_locale];
        
        AmazonException("Amazon Client Error: No Amazon Uri for locale!");
    }
    
    
    
    /**
     * Retrieves information for a product
     * 
     * ---
     * 
     * Example:
     * 
     *       char[][char[]] options;
     *      
     *       auto aws = new AmazonAssociates("1NB1TBJHNCPS1MEG9Y02");
     *
     *       options["ResponseGroup"] = "Large";
     *       
     *       aws.getItem("9780747591", options);
     * 
     * ---
     * 
     * Params:
     *     item_id = Product IDs / ASIN
     *     options = optional parameters  
     */
    public void getItem ( char[] itemid, char[][char[]] options = null ) 
    {
        char[][char[]] params = options;
        
        params["ItemId"] = itemid;
        
        this.tryRequest("ItemLookup", params);
    }
    
    
    
    /**
     * Searches for products
     * 
     * ---
     * 
     * Example:
     * 
     *       char[][char[]] options;
     *      
     *       auto aws = new AmazonAssociates("1NB1TBJHNCPS1MEG9Y02");
     *
     *       options["BrowseNode"] = "1000";
     *       options["Sort"] = "salesrank";
     *       options["ResponseGroup"] = "ItemIds,ItemAttributes,Images";
     *       
     *       aws.searchItem("Books", "Harry Potter", options);
     *      
     * ---
     *
     * Params:
     *     search_index = an amazon search index
     *     options = optional parameters     
     */
    public void searchItem ( char[] search_index, char[] search_string = null, char[][char[]] options = null ) 
    {
        char[][char[]] params = options;
        
        params["SearchIndex"] = search_index;
        
        if ( search_string !is null )
            params["Keywords"] = search_string;
        
        this.tryRequest("ItemSearch", params);
    }
    
    
    
    /**
     * Retrieves information about a browse node 
     * 
     * Returns the specified browse nodes name, children, and ancestors of a browse node. Documentation 
     * for browsing specific Amazon Nodes can be found here:
     * 
     *      http://docs.amazonwebservices.com/AWSECommerceService/2008-06-26/DG/BrowseNodeIDs.html
     * 
     * ---
     * 
     * Example
     *  
     *       char[][char[]] options;
     *      
     *       auto aws = new AmazonAssociates("1NB1TBJHNCPS1MEG9Y02");
     *       
     *       options["ResponseGroup"] = "Large";
     *       
     *       aws.browseNode("1000", options);
     * 
     * ---
     * 
     * Params:
     *     node_id =  
     *     options = optional parameters 
     */
    public void browseNode ( char[] node_id, char[][char[]] options = null )
    {
        char[][char[]] params = options;
        
        params["BrowseNodeId"] = node_id;
        
        this.tryRequest("BrowseNodeLookup", params);
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
     * Try Amazon REST Request and check for errors
     * 
     * Method checks for socket connection errors or HTTP errors. If connection fails
     * due to a socket or EOF problem we re-request the resource. If the connection
     * fails due to a 503 HTTP Error Code the method waits for some time and requests 
     * the ressource another time. The number of maximum retries is by default 4 times. 
     * 
     * Params:
     *     operation = AWS operation
     *     params = REST query parameter
     *     retries = number of retries on a ressource
     */
    private void tryRequest( char[] operation, char[][char[]] params, int retries = 0 )
    {
        try 
        {
            this.doRequest(operation, params);     
        } 
        catch ( Exception e )
        {
            if ( retries <= this.request_max_retries )
            {
                if ( this.getHTTPErrorCode == 503 )
                    sleep(1);
                
                this.tryRequest(operation, params, ++retries);
            }
            else
            {
                AmazonException("Max Retries reached (" ~ Integer.toString(retries) ~ ") - " ~ e.msg);
            }
        }       
    }
    
    
    
    /**
     * Performs Amazon Web Services REST request
     *
     * Params:
     *     operation = AWS operation
     *     params = REST query parameter
     *     
     * Returns:
     *    true, if request was successful
     */
    private bool doRequest( char[] operation, char[][char[]] params )
    {
        char[] request_url;
        
        scope layout = new Locale;
        
        this.flushRequestParams();

        this.addRequestParam("Service", "AWSECommerceService");
        this.addRequestParam("AWSAccessKeyId", this.getAccessKey);
        this.addRequestParam("Version", this.getApiVersion);
        this.addRequestParam("Timestamp", layout("{:yyyy-MM-ddTHH%3Amm%3AssZ}", Time(Clock.now.ticks)));
        this.addRequestParam("Operation", operation);
        
        if ( this.getAssociateID !is null )
            this.addRequestParam("AssociateTag", this.getAssociateID);

        foreach(param, value; params)
            this.addRequestParam(param, value);
        
        char[] signature = "GET\n" ~ getRequestUri ~ "\n" ~ "/onca/xml" ~ "\n" ~ getRequestParams;
        
//        Trace.formatln("string2sign = {}\n", signature);
        
        HMAC h = new HMAC(new SHA256(), getSecretKey);
        h.update(signature);
        
        request_url = http_build_uri("http://" ~ this.getRequestUri ~ "/onca/xml", 
            this.getRequestParams ~ "&Signature=" ~ Base64.encode(h.digest));

        Trace.formatln("\n-----\n{}\n", request_url);
        
        try 
        {
            auto client = new HttpClient (HttpClient.Get, request_url);
            
            client.setTimeout(5.0);
            client.open();
            
            scope (exit) client.close;
            
            if ( client.isResponseOK )
            {
                this.setError(false);
                client.read (&this.readResponse, uint.max);

                return true;
            }
            else
            {
                this.setHTTPErrorCode(client.getStatus);
                
                AmazonException("HTTP error " ~ Integer.toString(client.getStatus) ~ " on URL " ~ request_url); 
            }
        }
        catch( Exception e )
            AmazonException("Amazon Client Error: " ~ e.msg);
        
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
        
        foreach( key; params.keys.sort)
        {
            uri = uri.dup ~ key ~ "=" ~ params[key] ~ "&";
        }
            
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
     * Sets HTTP error code
     * 
     * Params:
     *     flag = set to true if error occured
     */
    private void setHTTPErrorCode( int code )
    {
        this.response_error_code = code;
    }
    
    
    
} // AmazonAssociates



/******************************************************************************

    AmazonException

******************************************************************************/

/**
 * This is the base class from which all exceptions generated by this module
 * derive from.
 */
class AmazonException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }

    private:
        static void opCall(char[] msg) { throw new AmazonException(msg); }

} // class AmazonException