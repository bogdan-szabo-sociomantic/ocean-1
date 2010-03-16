/*******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved
    
        version:        May 2009: Initial release
    
        authors:        Thomas Nicolai, Lars Kirchhoff
    
        D API Client for the Wikipedia Categorizer API.    
        This module provides a D interface to the Wikipedia Categorizer Web 
        Service API.         

        --
        
        Usage:
        
        ---
            import  ocean.net.services.WikipediaCategorizer;
            
            char[] text = " An Examination of the Corporate Social ...";            
            
            auto categorizer = new WikipediaCategorizer("http://web05.mcm.unisg.ch:995");
            
            // Set input type [keyword | text]            
            categorizer.setInputType("text");        
            
            // Set locale
            categorizer.setRequestLocale("en");    
            
            // Set timeout for http connection 
            categorizer.setTimeout(15);
            
            WikipediaCategorizer.Keyword[] keywords;
             
            try 
            {   
                // Issue the query to Wikipedia Categorizer Web Service API
                categorizer.query(text);
                
                // Output the raw response from the API 
                Stdout.formatln("{}", client.getResponse());
                
                // Retrieve keyword id, namea and score for a specific keyword 
                // level
                keywords = categorizer.getKeywordIdsByLevel("mid_level");
                foreach (pos, keyword; keywords)
                {
                    Stdout.format("{} {}: {} ({})\t", 	pos, 
                    									keyword.id, 
                    									keyword.name, 
                    									keyword.score);
                }
            }
            catch (Exception e)
            {
                Stdout.formatln(e.msg);
            }    
            
        ---
           
        Basically you set the input type, either plain text (text) or a comma 
        separated list of keywords (keyword), the language and the response 
        group (e.g. mid_level) you would like to retrieve. Use the response 
        group that suites your needs. It doesn't make sense to use 'large' 
        as response group, if you only need the base keywords.
        
        Default response format is csv. There is no need to change that, 
        unless you need to work with the raw response.
           
        --

        Additional information: 
    
        The HTTP protocol for a query to the Wikipedia categorizer 
         
        ---
        
            POST /<response_format>/<api_version>/<input_type>/categorize?language=<request_locale>&set=<response_group> HTTP/1.1
            
            <data>
        
        ---
        
        <response_format>   = xml | json | csv | text
        <api_version>       = 2009-03-12 | 2009-06-12
        <input_type>        = text | keyword
        <request_locale>    = de | en | ..
        <response_group>    = large | high_level | mid_level | low_level | base
        
        --
        
        TODO: 
       
        1. Integrate proper HTML decoding using ocean.text.Encoding 
        2. Implement to JSON/XML parsing   
    	
    
        ---
    
*******************************************************************************/

module ocean.net.services.WikipediaCategorizer;



/*******************************************************************************

		imports
    
*******************************************************************************/

private import  tango.io.device.Array;

private import  tango.io.stream.Lines;

private import  tango.net.http.HttpPost, tango.net.http.HttpHeaders;

private import  TextUtil = tango.text.Util : containsPattern, split, replace;

private import  Integer = tango.text.convert.Integer : toString;

private	import	ocean.text.Encoding;

private import	tango.io.Stdout;



/*******************************************************************************

    WikipediaCategorizer class
        
*******************************************************************************/

class WikipediaCategorizer
{
	static public struct Keyword
	{
		uint 	id;
		char[]	name;
		uint 	score;
	}
    
    /***************************************************************************

         Default Configuration

     ***************************************************************************/
    
    private     float               timeout         	= 120.0;                // Default timeout for post requests
    
    private     char[]              base_request_uri    = "";  					// Default API Endpoint
    private     char[]              api_version         = "2009-03-12";         // Default API Version    
    private     char[]              response_format     = "csv";                // Default request format [csv, json, xml, plain]    
    private     char[]              request_locale      = "en";                 // Default API Request Locale
    private     char[]              response_group      = "large";              // Request request set       
    private     char[]              input_type          = "text";               // Default input type [text, keyword]
                                                                                // text should be used to input a plain text  
                                                                                // keyword should be used to input a comma separeted list of keywords 
    
    /***************************************************************************

         Class Variables

     **************************************************************************/
    
    private     char[]              request_data;               				// Request data, which is the text to analyze
    private     char[]              response_content;           				// Content returned from API request
    private     bool                response_error;             				// Error on request
    private     int                 response_error_code;        				// HTTP error code of last request    
    private     Keyword[][char[]]   keywords;                   				// Keyword ids from request sorted by level 
    
    
    
    /***************************************************************************

        Public Methods

     **************************************************************************/
        
    
    
    /***************************************************************************
     
		Constructor
		
		Params:
			
     
     **************************************************************************/
    
    public this ( char[] base_request_uri ) 
    {
    	this.setBaseRequestUri(base_request_uri);
    }
    
   
    
    /***************************************************************************
     
		Sets WikipediaCategorizer API base request uri to use

		Params:
			base_request_uri 	= API base request uri to use
     
     **************************************************************************/    
    
    public void setBaseRequestUri ( char[] base_request_uri )
    {
        this.base_request_uri = base_request_uri;   
    }
    
    
    
    /***************************************************************************
     
		Returns WikipediaCategorizer API base request uri used
	
		Returns:
			API base request uri
     
     **************************************************************************/
    
    public char[] getBaseRequestUri () 
    {
        return this.base_request_uri; 
    }
    
    
    
    /***************************************************************************
     
		Sets WikipediaCategorizer API Version to use

		Params:
			api_version 	= API version to use
    
     **************************************************************************/
    
    public void setApiVersion ( char[] api_version ) 
    {
        this.api_version = api_version;
    }
    
    
    
    /***************************************************************************
     
		Returns WikipediaCategorizer API version used
	
		Returns:
			API Version

     **************************************************************************/
    
    public char[] getApiVersion () 
    {
        return this.api_version; 
    }
    
    
    
    /***************************************************************************
     
		Sets WikipediaCategorizer API response format
	
    	format = xml | json | csv | text
	
     	Params:
			response_format = response format
     
     **************************************************************************/
    
    public void setResponseFormat ( char[] response_format ) 
    {
        this.response_format = response_format;
    }
    
    
    
    /***************************************************************************
     
		Returns WikipediaCategorizer API request format
     
		Returns:
     		Request format
    
	 **************************************************************************/
    
    public char[] getResponseFormat () 
    {
        return this.response_format; 
    }
    
    
    
    /***************************************************************************
     
		Sets WikipediaCategorizer API response format
	
		Params:
			input_type 	= type of input for the categorizer [text, keyword]
     
	 **************************************************************************/
    
    public void setInputType ( char[] input_type ) 
    {
        this.input_type = input_type;
    }
    
    
    
    /***************************************************************************
     
		Returns WikipediaCategorizer API request format

		Returns:
			Request format
     
	 **************************************************************************/
    
    public char[] getInputType () 
    {
        return this.input_type; 
    }
    
    
    
    /***************************************************************************
     
		Set WikipediaCategorizer API request locale. 
		The request locale supplies the host language of the application making 
		the request. 

		Default value = en
		Available languages = en | de

		Params:
			locale = WikipediaCategorizer API locale
     
     **************************************************************************/
    
    public void setRequestLocale ( char[] locale ) 
    { 
        this.request_locale = locale;
    }
    
    
    
    /**************************************************************************

		Return WikipediaCategorizer API request locale

		Returns:
			WikipediaCategorizer API locale used
     
	 **************************************************************************/
    
    public char[] getRequestLocale () 
    { 
        return this.request_locale;
    }
    
    
    
    /***************************************************************************
     
		Set WikipediaCategorizer API request set
		The request locale supplies the host language of the application 
		making the request. 

		Params:
			response_group 	= set, which should be returned 
							  [large | high_level | mid_level | low_level | base]
							  Default value = large
    
     **************************************************************************/
    
    public void setResponseGroup ( char[] response_group )
    { 
        this.response_group = response_group;
    }
    
    
    
    /***************************************************************************
     
		Set WikipediaCategorizer API request set
	
		Returns:
			Set, which should be returned [base, low, mid, high]
     
	 **************************************************************************/
    
    public char[] getResponseGroup () 
    { 
        return this.response_group;
    } 
    
    
    
    /***************************************************************************
     
		Set timeout for post requests

		Params:
			timeout 	= time out of client in seconds
     
     **************************************************************************/
    
    public void setTimeout ( float timeout )
    {
        this.timeout = timeout;
    }
    
    
    
    /***************************************************************************
     
		Performs API Request and stores result in global class property 
 		
 		Params:      
			text 	= text that shall be analyzed
    
     **************************************************************************/
    
    public void query ( char[] text )
    {   
        this.reset();          
        
        this.doRequest(text);
        
        if (!this.isError)
        {
            this.parse();
        }
    }
    
    
    
    /***************************************************************************
     
		Enable/Disable error flag
	
		Params:
			flag 	= set to true if error occured
     
	 **************************************************************************/
    
    public bool isError ()
    {
        return this.response_error;
    }    
    
    
    
    /***************************************************************************
     
		Returns HTTP Error Code from last request

		Returns:
   			HTTP error code
     
     **************************************************************************/
    
    public int getHttpErrorCode ()
    {
        return this.response_error_code;
    }
    
    
    
    /***************************************************************************
     
		Returns raw reponse from the request

		Returns:
			XML response
     
	 **************************************************************************/
    
    public char[] getResponse ()
    {
        return this.response_content;
    } 
    
    
    
    /***************************************************************************
		
		This works only for csv format now
 
		Params:
			level 	= keyword level  
			  		  [ base | low_level | mid_level | high_level | large ]
  
		Returns:
			array with keyword ids sorted by level, depending on which level 
			have been queried 
			
     **************************************************************************/
    
    public Keyword[] getKeywordIdsByLevel ( char[] level )
    {   
        if (level in this.keywords)
            return this.keywords[level];
        
        return null;
    }
    
    
    
    
    /***************************************************************************

         Private Methods

     **************************************************************************/
     
    
    
    /***************************************************************************
     
		Performs Wikipedia Categorizer API Request

		Params:
			text 	= text to analyze

		Returns:
			true, if request was successful
     
	 **************************************************************************/
    
    private bool doRequest ( char[] text )
    {        
        char[] response, request_url;
            
        request_url = this.getRequestUri();
        scope post = new HttpPost(request_url);        
        post.setTimeout(this.timeout);
        
        try 
        {   
            this.response_content = cast(char[]) post.write(text, "text/plain");
            
            if (!post.isResponseOK())
            {
                this.setHttpErrorCode(post.getStatus());
                this.setError(true);
            }            
        }
        catch (Exception e)      
        {            
            Stdout.formatln("Exception found.. {}" , e.msg);
            WikipediaCategorizerException("WikipediaCategorizer API Client Error (" ~ Integer.toString(this.getHttpErrorCode) ~ "): " ~ e.msg);
        }
        finally 
        {
        	post.close();
        }
        
        return false;
    }
    
    
    
    /***************************************************************************
      
		Enable/Disable error flag

		Params:
   			flag 	= set to true if error occured
     
     **************************************************************************/
    
    private void setError ( bool error )
    {
        this.response_error = error;
    }    
    
    
    
    /***************************************************************************
     
		Return API request endpoint
	
    	Returns:
   			Query Uri for Wikipedia Categorizer API 
     
     **************************************************************************/
    
    private char[] getRequestUri () 
    {   
        return  this.base_request_uri ~ "/" ~ 
                this.response_format ~ "/" ~ 
                this.api_version ~ "/" ~
                this.input_type ~ "/categorizer?language=" ~
                this.request_locale ~ "&set=" ~
                this.response_group;
    }
    
    
    
    /***************************************************************************
     
		Sets HTTP error code
     
     	Params:
			flag 	= set to true if error occured
    
     **************************************************************************/
    
    private void setHttpErrorCode ( int code )
    {
        this.response_error_code = code;
    }
    
    
    
    /***************************************************************************
     
     	Parse response data for easy access 
     
     **************************************************************************/
    
    private void parse ()
    {   
        switch (this.response_format)
        {
            case "xml":
                this.parseXml();              
                break;            
                
            case "json":                
                this.parseJson();
                break;
            
            case "csv":
                this.parseCsv();
                break;
                
            default:
                this.parseCsv();
                break;
        }        
    }
    
    
    
    /***************************************************************************
     
		Parse csv response data 
		
		TODO: add proper HTML entity encoding
     
     **************************************************************************/
    
    private void parseCsv ()
    {
        char[]      type;
        char[][]    keyword_token, type_token;
        Keyword 	keyword;

        // Encode!(char) encode = new Encode!(char);
        
        foreach (line; new Lines!(char) (new Array(this.response_content)))
        {           	
            if (line != "")
            {   
            	this.htmlDecode(line);
            	// Encode.decodeHtmlEntities(line);
            	
                if (TextUtil.containsPattern(line, ";;"))
                {
                    type_token = TextUtil.split(line, ";");
                    type = type_token[0];                    
                }
                else 
                {	
                    keyword_token = TextUtil.split(line, ";");
                    
                    keyword.id 		= Integer.toInt(keyword_token[0]);
                    keyword.name 	= keyword_token[1];
                    keyword.score 	= Integer.toInt(keyword_token[2]);
                    
                    this.keywords[type] ~= keyword;                	                    
                }
            }
        }
    }
    
    
    
    /***************************************************************************
     
		Parse json response data 
     
     **************************************************************************/
    
    private void parseJson () {}
    
    
    
    /***************************************************************************
     
		Parse xml response data 
     
     **************************************************************************/
    
    private void parseXml () {}    
    
    
    
    /***************************************************************************
    
		Decode html entities  
		
		TODO: replace with ocean class
	 
	 **************************************************************************/    
	
	private void htmlDecode ( ref char[] content )
	{
		content = TextUtil.substitute(content, "&amp;", "&");
	}

	

    /***************************************************************************
     
		Reset keywords array and error states 
     
     **************************************************************************/
    
    private void reset ()
    {
        this.setHttpErrorCode(0);
        this.setError(false);
        
        foreach (level, keywords; this.keywords)
        {
            this.keywords[level].length = 0;
        }
    }
}



/******************************************************************************

    WikipediaCategorizerException

******************************************************************************/

class WikipediaCategorizerException : Exception
{
    this (char[] msg)
    {
        super(msg);
    }

    private:
        static void opCall (char[] msg) { throw new WikipediaCategorizerException(msg); }

}