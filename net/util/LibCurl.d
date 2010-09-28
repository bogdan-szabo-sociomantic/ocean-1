/*******************************************************************************

        LibCurl D Binding
    
        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved
    
        version:        Oct 2009: Initial release
    
        authors:        Thomas Nicolai
           
********************************************************************************/

module  ocean.net.util.LibCurl;

/*******************************************************************************

    Imports

********************************************************************************/

public      import      ocean.core.Exception: CurlException;

public      import      ocean.net.util.c.curl;

private     import      ocean.text.util.StringC;

private     import  	tango.stdc.stdlib: free;

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
    
    alias 			size_t delegate ( char[] )	ReadDg; 

    /***************************************************************************
        
        Curl handle
            
    ****************************************************************************/
    
	private			CURL						curl;

    /***************************************************************************
        
        Default Parameter
            
    ****************************************************************************/

    private			static const uint			DEFAULT_TIME_OUT = 360;
    private         static const size_t     	DEFAULT_MAX_FILE_SIZE = 1_024_000;
    
    /***************************************************************************
        
        Errors
            
     ***************************************************************************/
    
	private    		char[CURL_ERROR_SIZE + 1]	error_msg;
	private        	int                         errorCode;

    /***************************************************************************
        
        Constructor; init curl and set options
            
     **************************************************************************/
    
	public this ( ) 
    {
		this.curl = curl_easy_init();

		assert (this.curl, "Error on curl_easy_init!");

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
    
        Desctructor; close curl session
            
     **************************************************************************/
	
    public ~this ( )
    {
        this.close();
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
    
    public T getInfo ( CURLINFO info, T = int ) ( )
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
        
    public alias getInfo!(CURLINFO.CURLINFO_RESPONSE_CODE) getResponseCode;
    
    /***************************************************************************
        
        Returns amount of time spent on total operation
            
     ***************************************************************************/
    
    public alias getInfo!(CURLINFO.CURLINFO_TOTAL_TIME, double) getTotalTime;
    
    /***************************************************************************
        
        Returns amount of time take to connect
            
     ***************************************************************************/
    
    public alias getInfo!(CURLINFO.CURLINFO_CONNECT_TIME, double) getConnectTime;
      
    /***************************************************************************
        
        Returns amount of time take before data transer
            
     ***************************************************************************/
    
    public alias getInfo!(CURLINFO.CURLINFO_PRETRANSFER_TIME, double)
                 getPretransferTime;
    
    /***************************************************************************
        
        Returns amount of time take before data transer
            
     ***************************************************************************/
    
    public alias getInfo!(CURLINFO.CURLINFO_STARTTRANSFER_TIME, double) 
                 getStarttransferTime;
    
    
    /***************************************************************************
        
        Returns amout of time spent on redirect
            
     **************************************************************************/
    
    public alias getInfo!(CURLINFO.CURLINFO_REDIRECT_TIME, double)      
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
    
	public CurlCode read ( ref char[] url, ref char[] content )
	{
	    content.length = 0;

        size_t append_content ( char[] received )
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

    public CurlCode read ( ref char[] url, ReadDg read_dg )
    {
        int response_code;
        
        url ~= '\0';
        
        scope (exit) url.length = url.length - 1;  // remove null terminator
        
        this.setOption(CURLoption.WRITEDATA, &read_dg);
        this.setOption(CURLoption.URL, url.ptr);
        
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
        
    	str = StringC.toDString(cvalue).dup;
        
        free(cvalue);
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
    
        Set Encoding 
            
        Params:
            value = encoding type (identity|gzip|deflate)
            
     **************************************************************************/
    
    alias setOptionT!(CURLoption.ENCODING, char[]) setEncoding;
    
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
        
        Close curl session
        
         Returns:
             void
             
     **************************************************************************/
    
    public void close ()
    {
        curl_easy_cleanup(this.curl);
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
		return curl_easy_setopt(this.curl, option, StringC.toCstring(str));
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
            
            ReadDg read_dg = *(cast (ReadDg*) obj);
            
            char[] content = (cast (char*) ptr)[0 .. size * nmemb].dup;
            
            return read_dg(content);
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
            LibCurl curlobj = cast(LibCurl) obj;
            
            return size*nmemb;
        }
    }
}
