/*******************************************************************************

        LibCurl D Interface
    
        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved
    
        version:        Oct 2009: Initial release
    
        authors:        Thomas Nicolai
        
           
********************************************************************************/

module  ocean.net.util.LibCurl;


/*******************************************************************************

    Imports

********************************************************************************/

public      import      ocean.core.Exception: CurlException;

private     import      ocean.net.util.c.curlh;

private     import  	tango.math.Math: max;

private     import  	tango.stdc.stdlib : free;

private     import      tango.stdc.string : strlen;

private     import      tango.stdc.stringz : toDString = fromStringz, 
                                             toCString = toStringz;

/*******************************************************************************

    LibCurl

********************************************************************************/

class LibCurl 
{
    alias CURLcode CurlCode;
    
    /******************************************************************************
    
        Read delegate type alias, used in read() and writeCallback()
            
    *******************************************************************************/
    
    alias size_t delegate ( char[] ) ReadDg; 
    
    
    /******************************************************************************
        
        Curl handle
            
    *******************************************************************************/
    
	private             CURL                             curl;


    /******************************************************************************
        
        Default Parameter
            
    *******************************************************************************/

    private             static const uint                DEFAULT_TIME_OUT = 360;
    public              static const size_t              DEFAULT_MAX_FILE_SIZE = 1_024_000;


    /******************************************************************************
        
        Reponse Message Buffer Pointer & Header Buffer
            
    *******************************************************************************/
    
    private             char[][]                         headerBuffer;
    
    
    /******************************************************************************
        
        Errors
            
    *******************************************************************************/
    
	private             char[CURL_ERROR_SIZE + 1]        error_msg;
	private             int                              errorCode;
	
    /******************************************************************************
        
        Constructor
            
    *******************************************************************************/
    
	this() 
    {
		this.curl = curl_easy_init();

		if (curl is null) throw new CurlException("Error on curl_easy_init!");

		setOption(CURLoption.ERRORBUFFER, this.error_msg.ptr);
		setOption(CURLoption.WRITEHEADER, cast(void*)this);
        
		setOption(CURLoption.HEADERFUNCTION, &headerCallback);
		setOption(CURLoption.WRITEFUNCTION, &writeCallback);
        
		setOption(CURLoption.FOLLOWLOCATION, 1);
        setOption(CURLoption.FAILONERROR, 1);
        
        setOption(CURLoption.SSL_VERIFYHOST, 0);
        setOption(CURLoption.SSL_VERIFYPEER, 0);
        
        setOption(CURLoption.NOSIGNAL, 1); // no signals for thread safety
        
        setOption(CURLoption.FORBID_REUSE, 1);
        
        //this.setMaxFileSize(this.DEFAULT_MAX_FILE_SIZE);
        this.setTimeout(this.DEFAULT_TIME_OUT);
	}
    
    
    /******************************************************************************
        
        Destructor
            
    *******************************************************************************/
    
	public void close ()
    {
		if (curl !is null) 
			curl_easy_cleanup(curl);
	}
    
    /+
    /******************************************************************************
        
        Returns Curl Error Code
            
        Returns:
            last error code, or zero if none
            
    *******************************************************************************/
    
    public int error () 
    {
        return errorCode;
    }
    +/
    
    /******************************************************************************
        
        Returns Error String
            
        Returns:
            last error message, or null
            
    *******************************************************************************/
    
    public char[] getErrorMsg ()
    {
        return this.error_msg[0 .. strlen(this.error_msg.ptr)];
    }
    
    
    /******************************************************************************
        
        Returns Http Response Code
            
        Returns:
            http response code
            
    *******************************************************************************/
    
    public long getResponseCode ()
    {
        long code;
        
        curl_easy_getinfo(curl, CURLINFO.CURLINFO_RESPONSE_CODE, &code);
        
        return code;
    }
    
    
    /******************************************************************************
        
        Returns Retry After Header Parameter Value
            
        Returns:
            http response code
            
    *******************************************************************************/
    
    public long getRetryAfter ()
    {
        // still needs to be implemented!
        return 21;
    }
    

    /******************************************************************************
        
        Read Url
        
        Params:
            url     = url to download content from
            content = response content output
            
     *******************************************************************************/
    
	public CurlCode read ( ref char[] url, out char[] content ) 
    {
        /// appends received to content
        
        size_t append_content ( char[] received )
        {
            content ~= received;
            
            return received.length;
        }
        
        return this.read(url, &append_content);
	}
    
    /**************************************************************************
    
        Read Url
        
        ReadDg is a type alias of
                                                                             ---
            size_t delegate ( ref char[] received )
                                                                             ---
        where received is the buffer holding the recently arrived data. read_dg
        shall return the number of elements processed from received, however,
        a return value which differs from received.length is interpreted as an
        error indication and will cause cancelling the current request.
        
        Params:
            url     = url to download content from
            read_dg = callback delegate to be invoked each time data arrive
            
     **************************************************************************/

    public CurlCode read ( ref char[] url, ReadDg read_dg )
    {
        int response_code;
        
        url ~= '\0';
        
        scope (exit) url.length = url.length - 1;  // remove null terminator from url
        
        this.setOption(CURLoption.WRITEDATA, &read_dg);
        
        this.setOption(CURLoption.URL, url.ptr);
        
        return curl_easy_perform(this.curl);
    }
    
    
    /******************************************************************************
        
        Encode String
            
        Params:
            str = str reference to encode
            
    *******************************************************************************/
    
    public void encode ( ref char[] str )
    {
    	char* cvalue = curl_easy_escape(curl, str.ptr, str.length);
        
    	str = cvalue[0 .. strlen(cvalue)].dup;
        
        free(cvalue);
    }
    
    
    /******************************************************************************
        
        Return Raw Http Response Header
            
        Params:
            list of http header lines
            
    *******************************************************************************/
    
    public char[][] getResponseHeader() 
    { 
        return headerBuffer; 
    }

    
    /******************************************************************************
        
        Clears Internal Buffers
            
    *******************************************************************************/
    
	private void clearBuffers() 
    {
		headerBuffer.length = 0;
	}
    
    
    
    /******************************************************************************
    
        Sets cURL option. Parameter value must be an integer, pointer or string.
        
        Params:
            value = parameter value for selected option
            
    *******************************************************************************/

	public CurlCode setOptionT ( CURLoption option, T ) ( T value )
	{
        static assert (is (T : int) || is (T : void*) || is (T == char[]),
                       typeof (this).stringof ~ ": cURL option must be "
                       "integer, pointer or string, not '" ~ T.stringof ~ '\'');
	    
        return this.setOption(option, value);
	}
	
    /******************************************************************************
    
        Set User Agent
            
        Params:
            value = user agent identifier string
            
    *******************************************************************************/

    
	alias setOptionT!(CURLoption.USERAGENT,   char[]) setUserAgent;
    
    
    /******************************************************************************
    
        Set request timeout
            
        Params:
            value = request timeout
            
    *******************************************************************************/

    
    alias setOptionT!(CURLoption.TIMEOUT,     int)    setTimeout;

    
    /******************************************************************************
        
        Set LibCurl Option
            
        Params:
            option = libcurl option to set
            str    = parameter value string
        
        Returns:
            0 on success or Curl error code on failure
        
    *******************************************************************************/
    
	private CurlCode setOption(CURLoption option, char[] str) 
    {
		return curl_easy_setopt(curl, option, (str ~ '\0').ptr);
	}
    
    
    /******************************************************************************
        
        Set LibCurl Option
            
        Params:
            option = libcurl option to set
            p      = parameter value pointer
            
        Returns:
            0 on success or Curl error code on failure
        
    *******************************************************************************/
    
	private CurlCode setOption(CURLoption option, void* p) 
    {
		return curl_easy_setopt(curl, option, p);
	}
    
    
    /******************************************************************************
        
        Set LibCurl Option
            
        Params:
            option = libcurl option to set
            value  = numeric parameter value
            
        Returns:
            0 on success or Curl error code on failure
        
    *******************************************************************************/
    
	private CurlCode setOption(CURLoption option, int value) 
    {
		return curl_easy_setopt(curl, option, value);
	}
    
    extern (C) static
    {
        /******************************************************************************
            
            Message Write Callback Method
             
            Interface follows fwrite syntax: http://www.manpagez.com/man/3/fwrite/
            
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
           
        *******************************************************************************/
        
    	private size_t writeCallback ( void* ptr, size_t size, size_t nmemb, void* obj ) 
        {
            if (!ptr || !obj) return 0;
            
            
            ReadDg read_dg = *(cast (ReadDg*) obj);
            
            char[] content = (cast (char*) ptr)[0 .. size * nmemb].dup;
            
            return read_dg(content);
    	}
    
        
        /******************************************************************************
            
            Header Write Callback Method
             
            Interface follows fwrite syntax: http://www.manpagez.com/man/3/fwrite/
            
            Params:
                ptr = data pointer
                size = element size
                nmemb = number of elements
                obj = passthru object instance to work on
            
            Returns:
                zero on write error, or number of written bytes
           
        *******************************************************************************/
        private size_t headerCallback( void* ptr, size_t size, size_t nmemb, void* obj ) 
        {
            LibCurl curlobj = cast(LibCurl)obj;
            
            //char [] str = chomp(toDString(cast(char*)ptr)[0 .. (size * nmemb)].dup);
    //        char [] str = toDString(cast(char*)ptr)[0 .. (size * nmemb)].dup;
    //
    //        if (str.length) 
    //        {
    //            curlobj.headerBuffer ~= str;
    //        }
            
            return size*nmemb;
        }
    }
}
