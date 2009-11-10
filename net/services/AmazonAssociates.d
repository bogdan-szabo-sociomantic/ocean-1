/*******************************************************************************

        D API Client for the Amazon Web Services.
        
        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Feb 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        ---

        Usage:

            char[][char[]] options;
            char[] buffer;
            
            options["ResponseGroup"] = "Large";
            
            scope w = new AmazonAssociates("__access_key__", "__public_key__");
            
            w.setResponseBuffer(buffer);
            w.getItem("3503112464", options);
            
            if ( !w.isError )
                Stdout(buffer);

        --

        Related

        http://aws.amazon.com/associates/
        http://docs.amazonwebservices.com/AWSECommerceService/2009-01-06/DG/

********************************************************************************/

module ocean.net.services.AmazonAssociates;


/*******************************************************************************

    Imports

********************************************************************************/

private     import      ocean.crypt.crypto.hashes.SHA256,
                        ocean.crypt.crypto.macs.HMAC;

//private     import      tango.net.http.HttpClient, tango.net.http.HttpGet, 
//                        tango.net.http.HttpHeaders;
private     import      ocean.net.util.LibCurl;

private     import      tango.text.Util : containsPattern;

private     import      Integer = tango.text.convert.Integer: toString;

private     import      tango.sys.Common : sleep;

private     import      tango.time.Clock;

private     import      tango.text.locale.Locale, tango.text.convert.Layout;

private     import      Base64 = tango.io.encode.Base64;

private import tango.util.log.Trace;
/*******************************************************************************

    AmazonAssociates

********************************************************************************/

class AmazonAssociates
{

    /*******************************************************************************

         Api Version

     *******************************************************************************/    
    
    private             char[]                           apiVersion = "2009-10-01";
    private             char[][char[]]                   apiEndpoint;
    
    
    /*******************************************************************************
    
        Security Credentials
    
     *******************************************************************************/ 

    private             char[][char[]]                   associateId;
    private             char[]                           publicKey;
    private             char[]                           secretKey;
    private             char[]                           signature;
    
    
    /*******************************************************************************

         Default Settings

     *******************************************************************************/ 
    
    private             const ubyte                      maxRetries = 4;    
    private             char[]                           locale = "us";
    
    
    /*******************************************************************************
    
         Url & Query
    
     *******************************************************************************/ 
    
    private             char[]                           requestUrl;
    private             char[][char[]]                   queryParameter;
    private             char[]                           queryString;

    
    /******************************************************************************

         Curl
 
     ******************************************************************************/ 
    
    private             LibCurl                          curl;
    private             char[]*                          responseBuffer;
    
    
    /******************************************************************************
    
         Error
    
    ******************************************************************************/ 
    
    private             bool                             error;
    
    
    /******************************************************************************

         Constructor
         
         Sets the AccessKeyID and default locales for the various Amazon sales 
         regions. Currently US, UK, DE, JP, FR, and CA are supported as sales 
         regions.
         
         Params:
             public_key = amazon public key
             secret_key = amazon secret key

     ******************************************************************************/
    
    public this ( char[] publicKey, char[] secretKey ) 
    {
        this.publicKey = publicKey;
        this.secretKey = secretKey;
        
        setApiEndpoints();
        
        curl = new LibCurl();
    }
    
    
    /******************************************************************************
        
         Set Associate Id
         
         Params:
             associateId = amazon associate id
             locale = amazon sales region
             
     ******************************************************************************/

    public void setAssociateId ( char[] associateId, char[] locale ) 
    {
        assert(locale in apiEndpoint, "no api endpoint for given locale " ~ locale);
        
        this.associateId[locale] = associateId;
    }
    
    
    /******************************************************************************
        
         Set Api Version
         
         Params:
             apiVersion = amazon api version
            
     ******************************************************************************/
    
    public void setVersion( char[] apiVersion ) 
    {
        this.apiVersion = apiVersion;
    }
    
    
    /******************************************************************************
        
         Set Api Locale
        
         Params:
             locale = api locale
           
     ******************************************************************************/

    public void setLocale( char[] locale ) 
    { 
        assert(locale in apiEndpoint, "no api endpoint for given locale " ~ locale);
        
        this.locale = locale;
    }
    
    
    /******************************************************************************
        
         Set Response Buffer
       
         Params:
             buffer = output buffer
          
     ******************************************************************************/
    
    public void setResponseBuffer( char[]* buffer ) 
    {
        responseBuffer = buffer;
        curl.setResponseBuffer(responseBuffer);
    }

    
    /******************************************************************************
        
         Get Item
        
         --
         
         Usage:
         
         char[][char[]] options;
         
         options["ResponseGroup"] = "Large";
         
         scope client = new AmazonAssociates(..., ...);
         client.getItem("9780747591", options);
         
         --
         
         Params:
             itemId = asin or product id
             options = optional parameters  
         
     ******************************************************************************/
    
    public void getItem ( char[] itemId, char[][char[]] options = null ) 
    {
        options["ItemId"] = itemId;
        tryRequest("ItemLookup", options);
    }
    
    
    /******************************************************************************
        
         Search Product
         
         --
         
         Usage:
         
         char[][char[]] options;
         
         options["BrowseNode"] = "1000";
         options["Sort"] = "salesrank";
         options["ResponseGroup"] = "ItemIds,ItemAttributes,Images";
         
         scope client = new AmazonAssociates(..., ...);
         client.searchItem("Books", "Harry Potter", options);
         
         --
         
         Params:
             index   = an amazon search index
             string  = search string
             options = optional parameters
         
     ******************************************************************************/
    
    public void searchItem ( char[] index, char[] string = null, 
        char[][char[]] options = null ) 
    {
        options["SearchIndex"] = index;
        
        if ( string !is null )
            options["Keywords"] = string;
        
        tryRequest("ItemSearch", options);
    }
    
    
    /******************************************************************************
        
         Return Browse Nodes
         
         Returns the specified browse nodes name, children, and ancestors of a 
         browse node. Documentation for browsing specific Amazon Nodes can be 
         found at:
         
         http://docs.amazonwebservices.com/AWSECommerceService/2008-06-26/DG/
         BrowseNodeIDs.html
         
         --
         
         Usage:
         
         char[][char[]] options;
         
         options["ResponseGroup"] = "Large";
         
         scope client = new AmazonAssociates(..., ...);
         client.browseNode("1000", options);
         
         --
         
         Params:
             nodeId = browse node id
             options = request options
             
     ******************************************************************************/
    
    public void getBrowseNodes ( char[] node_id, char[][char[]] options = null )
    {
        char[][char[]] params = options;
        
        params["BrowseNodeId"] = node_id;
        
        tryRequest("BrowseNodeLookup", params);
    }
    
    
    /******************************************************************************
        
         Is Request Error?
         
     ******************************************************************************/
    
    public bool isError ()
    {
        if ( containsPattern(*responseBuffer, "<Error>") )
            error = true;

        return error;
    }
    
    
    /******************************************************************************

         Try Amazon REST Request
         
         Method checks for socket connection errors or HTTP errors. If connection 
         fails due to a socket or EOF problem we re-request the resource. If the 
         connection fails due to a 503 HTTP Error Code the method waits for some 
         time and requests the ressource another time. The number of maximum 
         retries is by default 4 times. 

         Params:
             operation = amazon web services operation
             params = rest request parameter
             retries = number of retries before giving up
             
     ******************************************************************************/
    
    private void tryRequest( char[] operation, char[][char[]] params )
    {
        reset();
        
        setQueryParameter(operation, params);

        buildQueryString();
        buildSignature();
        
        requestUrl = "http://" ~ getApiEndpoint ~ "/onca/xml" ~ "?" ~ queryString ~ "&Signature=" ~ signature;
        
        doRequest();
    }
    
    
    /******************************************************************************
    
         Performs Request
    
         Params:
             operation = amazon web services operation
             params = rest request query parameter
            
     ******************************************************************************/
    
    private void doRequest ( uint wait = 0, ubyte retry = 0 )
    {
        if ( wait )
            sleep(wait);
        
        curl.read(requestUrl);
        
        if (curl.error)
        {
            if (curl.getReturnCode == 503)
            {
                if ( retry < maxRetries )
                {
                    doRequest(1, retry++); // recursive call
                }
                else
                {
                    error = true;
                }
            }
            else
            {
                error = true;
            }
        }
    }

    
    /******************************************************************************
        
         Set Default Query Parameter
         
         Params:
              operation = aws operation to perform
              params = rest request query parameter
              
     ******************************************************************************/

    private void setQueryParameter ( char[] operation, char[][char[]] params  )
    {
        scope layout = new Locale;
        
        queryParameter["Service"] = "AWSECommerceService";
        queryParameter["Version"] = apiVersion;
        queryParameter["AWSAccessKeyId"] = publicKey;
        queryParameter["Timestamp"] = layout("{:yyyy-MM-ddTHH%3Amm%3AssZ}", Time(Clock.now.ticks));
        queryParameter["Operation"] = operation;
        
        if (getAssociateId)
            queryParameter["AssociateTag"] = getAssociateId;
        
        foreach(param, value; params)
        {
            curl.encode(value);
            queryParameter[param] = value;
        }
    }
    
    
    /******************************************************************************
        
         Reset Parameter
          
     ******************************************************************************/

    private void reset()
    {
        *responseBuffer = null;
        
        requestUrl.length = 0;
        queryString.length = 0;
        
        queryParameter = null;
        error = false;
    }
    
    
    /******************************************************************************
        
         Build query string
             
     ******************************************************************************/
    
    private void buildQueryString ()
    {
        char[] uri;
        
        foreach( key; queryParameter.keys.sort)
        {
            uri = uri.dup ~ key ~ "=" ~ queryParameter[key] ~ "&";
        }
            
        queryString = uri[0..$-1].dup;
    }
    
    
    /******************************************************************************
        
         Build Request Signature
            
     ******************************************************************************/
    
    private void buildSignature ()
    {
        scope h = new HMAC(new SHA256(), secretKey);
        
        h.update("GET\n" ~ getApiEndpoint ~ "\n" ~ "/onca/xml" ~ "\n" ~ queryString);
      
        signature = Base64.encode(h.digest);
        curl.encode(signature);
    }
    

    /******************************************************************************
    
         Set Api Endpoints
    
     ******************************************************************************/
    
    private void setApiEndpoints ()
    {
        apiEndpoint["ca"] = "ecs.amazonaws.ca";
        apiEndpoint["de"] = "ecs.amazonaws.de";
        apiEndpoint["fr"] = "ecs.amazonaws.fr";
        apiEndpoint["jp"] = "ecs.amazonaws.jp";
        apiEndpoint["uk"] = "ecs.amazonaws.co.uk";
        apiEndpoint["us"] = "ecs.amazonaws.com";
    }
    
    
    /******************************************************************************
        
         Return Api Endpoint
          
     ******************************************************************************/
    
    private char[] getApiEndpoint() 
    {
        return apiEndpoint[locale];
    }
    
    
    /******************************************************************************
        
         Return Associate Id
        
         Params:
             locale = amazon sales region
         
         Returns:
             associate id for given locale, or null if none
             
     ******************************************************************************/
    
    private char[] getAssociateId( char[] locale = null ) 
    {
        if ( locale !is null && locale in associateId )
        {
            return associateId[locale];
        }
        else if ( this.locale in associateId )
        {
            return associateId[this.locale];
        }
        
        return null;
    }
    
}



/******************************************************************************

    AmazonException

******************************************************************************/

class AmazonException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }

    private:
        static void opCall(char[] msg) { throw new AmazonException(msg); }

}