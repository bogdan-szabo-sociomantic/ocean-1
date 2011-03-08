/*******************************************************************************

    LibCurl D Binding

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Oct 2009: Initial release

    authors:        Thomas Nicolai
           
    Usage example:

    ---

        // cUrl callback - called whenever a chunk of data is received which
        // needs handling.

        // Note that because this callback is called from within the cUrl C
        // library, it is best to always catch all exceptions which might be
        // thrown within it.

        size_t receiveContent ( char[] url, char[] content )
        {
            try
            {
                Trace.formatln("Curl received content from '{}': '{}'", url, content);
            }
            catch ( Exception e )
            {
            }

            return content.length;
        }

        // Create cUrl object
        scope curl = new LibCurl();

        // Set up user agent
        const char[] user_agent = "User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.3; de; rv:1.9.1.10) Gecko/2009102316 Firefox/3.1.10";
        curl.setUserAgent(user_agent);

        // Set up request authorisation
        curl.setAuth("username", "password");

        // Activate request
        curl.read("http://www.sociomantic.com/", &receiveContent);

    ---

********************************************************************************/

module  ocean.net.util.LibCurl;

/*******************************************************************************

    Imports

********************************************************************************/

private import          ocean.core.Array;

public import           ocean.core.Exception: assertEx, CurlException;

private import          ocean.net.util.c.curl;

private import          ocean.text.util.StringC;

private import          tango.stdc.stdlib: free;

debug private import    tango.util.log.Trace;

/*******************************************************************************

    LibCurl

********************************************************************************/

class LibCurl 
{
    
    /***************************************************************************
        
        Curl status code
            
    ****************************************************************************/
    
    alias 			CURLcode 					CurlCode;
    
    /***************************************************************************
    
        Read delegate type alias, used in read() and writeCallback()
            
    ****************************************************************************/
    
    alias 			size_t delegate ( char[], char[] )	ReadDg;

    /***************************************************************************
        
        Curl handle
            
    ****************************************************************************/
    
	protected CURL						curl;

    /***************************************************************************
    
        Request callback delegate
            
    ****************************************************************************/

    private ReadDg request_callback;
    
    /***************************************************************************
    
        Internal copy of the request url
            
    ****************************************************************************/

    private char[] request_url;

    /***************************************************************************
    
        Request authorisation (username:password)
            
    ****************************************************************************/

    private char[] request_auth;

    /***************************************************************************
        
        Default Parameters
            
    ****************************************************************************/

    private			static const uint			DEFAULT_TIME_OUT = 360;
    private         static const size_t     	DEFAULT_MAX_FILE_SIZE = 1_024_000;
    
    /***************************************************************************
        
        Errors
            
     ***************************************************************************/
    
	private    		char[CURL_ERROR_SIZE + 1]	error_msg;
	private        	int                         errorCode;

    /***************************************************************************

        String buffer used to convert an option parameter from a D char[] to a
        C style null-terminated string.

     **************************************************************************/

    private char[] option_buffer;

    /***************************************************************************

        Constructor - init curl and set options

        Throws:
            if initialisation of libcurl fails

     **************************************************************************/
    
	public this ( ) 
    {
		this.curl = curl_easy_init();

		assertEx!(CurlException)(this.curl, typeof(this).stringof ~ ".this - Error on curl_easy_init!");

		this.setOption(CURLoption.ERRORBUFFER, this.error_msg.ptr);
		this.setOption(CURLoption.WRITEHEADER, cast(void*)this);
		this.setOption(CURLoption.HEADERFUNCTION, &headerCallback);
		this.setOption(CURLoption.WRITEFUNCTION, &writeCallback);
		this.setOption(CURLoption.FOLLOWLOCATION, 1);
		this.setOption(CURLoption.FAILONERROR, 1);
		this.setOption(CURLoption.SSL_VERIFYHOST, 0);
		this.setOption(CURLoption.SSL_VERIFYPEER, 0);
		this.setOption(CURLoption.NOSIGNAL, 1); // disable signals for thread safety       
		
		this.setTimeout(this.DEFAULT_TIME_OUT);
	}
    
    /***************************************************************************
    
        Desctructor - close curl session
            
     **************************************************************************/
	
    public ~this ( )
    {
        if ( !(this.curl is null) )
        {
            curl_easy_cleanup(this.curl);
            this.curl = null;
        }
    }

    /***************************************************************************
        
        Returns Error String
            
        Returns:
            last error message, or null
            
     **************************************************************************/
    
    public char[] getErrorMsg ()
    {
        return StringC.toDString(this.error_msg.ptr);
    }
    
    /***************************************************************************
        
        Returns Http Response Code
        
        Params:
            info = curl status info
            T    = type of curl info
            
        Returns:
            http response code
            
     **************************************************************************/
    
    public T getInfo ( CurlInfo info, T = int ) ( )
    {
        T value;

        static if (is (T == char[]))
        {
            curl_easy_getinfo(this.curl, info, value.ptr);
            
            return StringC.toDString(value.ptr);
        }
        else
        {
            static assert (is (T == int) || is (T == double),
                          typeof (this).stringof ~ ": cURL info must be "
                          "int, double or string, not '" ~ T.stringof ~ '\'');        
            
            curl_easy_getinfo(this.curl, info, &value);
            
            return value;
        }
    }

    /***************************************************************************
    
        Returns response code
            
     ***************************************************************************/
        
    public alias getInfo!(CurlInfo.CURLINFO_RESPONSE_CODE) getResponseCode;
    
    /***************************************************************************
        
        Returns amount of time spent on total operation
            
     ***************************************************************************/
    
    public alias getInfo!(CurlInfo.CURLINFO_TOTAL_TIME, double) getTotalTime;
    
    /***************************************************************************
        
        Returns amount of time take to connect
            
     ***************************************************************************/
    
    public alias getInfo!(CurlInfo.CURLINFO_CONNECT_TIME, double) getConnectTime;
      
    /***************************************************************************
        
        Returns amount of time take before data transer
            
     ***************************************************************************/
    
    public alias getInfo!(CurlInfo.CURLINFO_PRETRANSFER_TIME, double)
                 getPretransferTime;
    
    /***************************************************************************
        
        Returns amount of time take before data transer
            
     ***************************************************************************/
    
    public alias getInfo!(CurlInfo.CURLINFO_STARTTRANSFER_TIME, double) 
                 getStarttransferTime;
    
    
    /***************************************************************************
        
        Returns amout of time spent on redirect
            
     **************************************************************************/
    
    public alias getInfo!(CurlInfo.CURLINFO_REDIRECT_TIME, double)      
                 getRedirectTime;

    /***************************************************************************
        
        Returns Retry After Header Parameter Value
            
        Returns:
            http response code
            
        @TODO: still needs to be implemented!
        
    ***************************************************************************/
    
    public long getRetryAfter ()												
    {        
        return 21;
    }
    
    /***************************************************************************
        
        Read content from Url
        
        Params:
            url     = url to download content from
            content = response content output
            
        Returns:
            curl status code of last operation
            
     **************************************************************************/
    
	public CurlCode read ( char[] url, ref char[] content )
	{
	    content.length = 0;

        size_t append_content ( char[] url, char[] received )
        {
            content ~= received;
            
            return received.length;
        }
        
        return this.read(url, &append_content);
	}
	
    /***************************************************************************
    
        Read content from Url
		
        where received is the buffer holding the recently arrived data. read_dg
        shall return the number of elements processed from received, however,
        a return value which differs from received.length is interpreted as an
        error indication and will cause cancelling the current request.
        
        Params:
            url     = url to download content from
            read_dg = callback delegate to be invoked each time data arrive
        
        Returns:
            curl status code of last operation
        
     **************************************************************************/

    public CurlCode read ( char[] url, ReadDg read_dg )
    {
        this.setupRead(url, read_dg);

        return curl_easy_perform(this.curl);
    }

    /***************************************************************************
        
        Encode String
            
        Params:
            str = str reference to encode
        
        Returns:
            void
            
     **************************************************************************/
    
    public void encode ( ref char[] str )
    {
    	char* cvalue = curl_easy_escape(this.curl, str.ptr, str.length);

        str.copy(StringC.toDString(cvalue));

        free(cvalue);
    }

    /***************************************************************************
        
        Returns:
            request url (if previously set), with the trailing '\0' removed.
            
     **************************************************************************/

    public char[] url ( )
    {
        if ( request_url.length > 1 )
        {
            return this.request_url[0..$-1];
        }
        else
        {
            return "";
        }
    }

    /***************************************************************************
    
        Sets cURL query authorisation - username & password.
        
        Params:
            username = username for url authorisation
            password = password for url authorisation
            
     **************************************************************************/

    public void setAuth ( char[] username, char[] password )
    {
        this.request_auth.concat(username, ":", password);
        this.setOptionT!(CURLoption.USERPWD, char[])(this.request_auth);
    }
    
    /***************************************************************************
    
        Sets cURL option. Parameter value must be an integer, pointer or string.
        
        Params:
            value = parameter value for selected option
            
        Returns:
            curl status code of last operation
            
     **************************************************************************/

	public CurlCode setOptionT ( CURLoption option, T ) ( T value )
	{
        static assert (is (T : int) || is (T : void*) || is (T : char[]),
                       typeof (this).stringof ~ ": cURL option must be "
                       "integer, pointer or string, not '" ~ T.stringof ~ '\'');
	    
        return this.setOption(option, value);
	}
    
    /***************************************************************************
    
        Set User Agent
            
        Params:
            value = user agent identifier string
            
     **************************************************************************/
    
    alias setOptionT!(CURLoption.USERAGENT, char[]) setUserAgent;
    
    /***************************************************************************
    
        Set request timeout
            
        Params:
            value = request timeout
            
     **************************************************************************/
    
    alias setOptionT!(CURLoption.TIMEOUT, int) setTimeout;
    
    /***************************************************************************
    
        Set if the connection could be reused for another request
            
        Params:
            value = true or false [0|1]
            
     **************************************************************************/
    
    alias setOptionT!(CURLoption.FORBID_REUSE, int) setForbidReuse;

    /***************************************************************************

        Set Encoding 

        Params:
            value = encoding type (identity|gzip|deflate)

     **************************************************************************/

    public CurlCode setNoEncoding ( )
    {
        return this.setOptionT!(CURLoption.ENCODING, char[])("identity");
    }
    
    public CurlCode setZlibEncoding ( )
    {
        return this.setOptionT!(CURLoption.ENCODING, char[])("deflate");
    }
    
    public CurlCode setGzipEncoding ( )
    {
        return this.setOptionT!(CURLoption.ENCODING, char[])("gzip");
    }

    /***************************************************************************
    
        Sets up the curl object with a request for a url, to be handled by the
        passed delegate.

        Params:
            url = url to read from
            read_dg = delegate to be called on receiving content from the url
         
    ***************************************************************************/

    protected void setupRead ( char[] url, ReadDg read_dg )
    {
        this.request_url.length = 0;
        this.request_url.append(url, "\0");

        this.request_callback = read_dg;

        this.setOption(CURLoption.WRITEDATA, cast(void*)this);
        this.setOption(CURLoption.URL, this.request_url.ptr);
    }
    
    /***************************************************************************

        Called when the curl writeCallback is activated. This method simply
        calls the user-specified delegate with the url of the request and the
        content received.
    
        Params:
            content = content received

        Returns:
            length of content (required by curl)
         
    ***************************************************************************/

    protected size_t receivedContent ( char[] content )
    {
        this.request_callback(this.url(), content);
        return content.length;
    }

    /***************************************************************************
        
        Set LibCurl Option
            
        Params:
            option = libcurl option to set
            str    = parameter value string
        
        Returns:
            0 on success or Curl error code on failure
        
     **************************************************************************/

	private CurlCode setOption ( CURLoption option, char[] str ) 
    {
        this.option_buffer.concat(str, "\0");
		return curl_easy_setopt(this.curl, option, this.option_buffer.ptr);
	}
    
    /***************************************************************************
        
        Set LibCurl Option
            
        Params:
            option = libcurl option to set
            p      = parameter value pointer
            
        Returns:
            0 on success or Curl error code on failure
        
     **************************************************************************/
    
	private CurlCode setOption ( CURLoption option, void* p ) 
    {
		return curl_easy_setopt(this.curl, option, p);
	}
    
    /***************************************************************************
        
        Set LibCurl Option
            
        Params:
            option = libcurl option to set
            value  = numeric parameter value
            
        Returns:
            0 on success or Curl error code on failure
        
     **************************************************************************/
    
	private CurlCode setOption ( CURLoption option, int value ) 
    {
		return curl_easy_setopt(this.curl, option, value);
	}
    

    extern (C) static
    {
        /***********************************************************************
            
            Message Write Callback Method
             
            Interface follows fwrite syntax: 
            	http://www.manpagez.com/man/3/fwrite/
            
            The loop-through custom pointer is supplied to libcurl as argument
            for the CURLoption.WRITEDATA option. The read() method of thi class
            sets it to a pointer to a ReadDg delegate to invoke with the
            received data.
            
            Params:
                ptr   = data pointer
                size  = element size
                nmemb = number of elements
                obj   = loop-through custom pointer
            
            Returns:
                passes through the return value of the read delegate
           
        ***********************************************************************/
        
    	private size_t writeCallback ( void* ptr, size_t size, size_t nmemb, void* obj ) 
        {
            if (!ptr || !obj) return 0;

            auto curlobj = cast(LibCurl) obj;

            char[] content = (cast (char*) ptr)[0 .. size * nmemb];

            return curlobj.receivedContent(content);
    	}
    
    	
        
        /***********************************************************************
            
            Header Write Callback Method
             
            Interface follows fwrite syntax: 
            	http://www.manpagez.com/man/3/fwrite/
            
            Params:
                ptr = data pointer
                size = element size
                nmemb = number of elements
                obj = passthru object instance to work on
            
            Returns:
                zero on write error, or number of written bytes
           
         **********************************************************************/
    	
        private size_t headerCallback ( void* ptr, size_t size, size_t nmemb, void* obj ) 
        {
            auto curlobj = cast(LibCurl) obj;
            
            return size*nmemb;
        }
    }
}
