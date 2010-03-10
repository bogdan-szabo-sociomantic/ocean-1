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

private     import  	tango.stdc.stdlib : free;

private     import      tango.stdc.string : strlen;

private     import      tango.stdc.stringz : toDString = fromStringz, 
                                             toCString = toStringz;


/*******************************************************************************

    LibCurl

********************************************************************************/

class LibCurl 
{
    
    /******************************************************************************
        
        Curl Session
            
    *******************************************************************************/
    
	private             CURL*                            curl;


    /******************************************************************************
        
        Default Parameter
            
    *******************************************************************************/

    private             static const uint                DEFAULT_TIME_OUT = 360;
    private             ulong                            maxFileSize = 1_024_000;


    /******************************************************************************
        
        Reponse Message Buffer Pointer & Header Buffer
            
    *******************************************************************************/
    
    private             char[]*                          messageBuffer;
    private             char[][]                         headerBuffer;
    
    
    /******************************************************************************
        
        Errors
            
    *******************************************************************************/
    
	private             char[CURL_ERROR_SIZE + 1]        errorBuffer = "\0";
	private             int                              errorCode;
	

    
    /******************************************************************************
        
        Constructor
            
    *******************************************************************************/
    
	this() 
    {
		curl = curl_easy_init();

		if (curl is null) throw new CurlException("Error on curl_easy_init!");

		setOption(CURLoption.ERRORBUFFER, &errorBuffer);
		setOption(CURLoption.WRITEHEADER, cast(void*)this);
		setOption(CURLoption.WRITEDATA, cast(void*)this);
        
		setOption(CURLoption.HEADERFUNCTION, &headerCallback);
		setOption(CURLoption.WRITEFUNCTION, &writeCallback);
        
		setOption(CURLoption.FOLLOWLOCATION, 1);
        setOption(CURLoption.FAILONERROR, 1);
        
        setOption(CURLoption.SSL_VERIFYHOST, 0);
        setOption(CURLoption.SSL_VERIFYPEER, 0);
        
        setOption(CURLoption.NOSIGNAL, 1); // no signals for thread safety
        
        setOption(CURLoption.TIMEOUT, DEFAULT_TIME_OUT);
        setOption(CURLoption.MAXFILESIZE, maxFileSize);
	}
    
    
    /******************************************************************************
        
        Destructor
            
    *******************************************************************************/
    
	public void close ()
    {
		if (curl !is null) 
			curl_easy_cleanup(curl);
	}
    
    
    /******************************************************************************
        
        Set Response Buffer
            
        Params:
            p = pointer to string write buffer
            
    *******************************************************************************/
    
    public void setResponseBuffer ( char[]* p ) 
    {
        messageBuffer = p;
    }
  
    
    /******************************************************************************
        
        Sets Maximum File Size
        
        If the downloaded content exceeds the maximum file size the download
        is stopped and returns with an error.
            
        Params:
            max = max file size
            
    *******************************************************************************/
    
    public void setMaxFileSize ( long max ) 
    {
        maxFileSize = max;
        setOption(CURLoption.MAXFILESIZE, maxFileSize);
    }
    
    
    /******************************************************************************
        
        Set User Agent
            
        Params:
            agent = user agent identifier string
            
    *******************************************************************************/
    
    public void setUserAgent ( char[] string ) 
    {
        setOption(CURLoption.USERAGENT, string);
    }
    
    
    /******************************************************************************
        
        Returns Curl Error Code
            
        Returns:
            last error code, or zero if none
            
    *******************************************************************************/
    
    public int error () 
    {
        return errorCode;
    }
    
    
    /******************************************************************************
        
        Returns Error String
            
        Returns:
            last error message, or null
            
    *******************************************************************************/
    
    public char[] errorString ()
    {
        return errorBuffer;
    }
    
    
    /******************************************************************************
        
        Returns Http Response Code
            
        Returns:
            http response code
            
    *******************************************************************************/
    
    public long getReturnCode ()
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
            url = url to download content from
            
    *******************************************************************************/
    
	public void read( char[] url ) 
    { 
        assert(url, "no url given!");
        assert(messageBuffer, "no response buffer set");
        
		clearBuffers();
		setOption(CURLoption.URL, toCString(url));
        
		errorCode = curl_easy_perform(curl);
	}
    
    
    /******************************************************************************
        
        Encode String
            
        Params:
            string = string reference to encode
            
    *******************************************************************************/
    
    public void encode ( ref char[] string )
    {
    	char* cvalue;
    	
    	cvalue = curl_easy_escape(curl, toCString(string), string.length);
        
    	string = toDString(cvalue).dup;
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
//        errorBuffer = "\0";
	}
    
    
    /******************************************************************************
        
        Set LibCurl Option
            
        Params:
            option = libcurl option to set
            string = parameter value string
            
    *******************************************************************************/
    
	private bool setOption(CURLoption option, char[] string) 
    {
		return curl_easy_setopt(curl, option, toCString(string)) == CURLcode.CURLE_OK;
	}
    
    
    /******************************************************************************
        
        Set LibCurl Option
            
        Params:
            option = libcurl option to set
            str = parameter value pointer
            
    *******************************************************************************/
    
	private bool setOption(CURLoption option, void* p) 
    {
		return curl_easy_setopt(curl, option, p) == CURLcode.CURLE_OK;
	}
    
    
    /******************************************************************************
        
        Set LibCurl Option
            
        Params:
            option = libcurl option to set
            str = numeric parameter value
            
    *******************************************************************************/
    
	private bool setOption(CURLoption option, int prarm) 
    {
		return curl_easy_setopt(curl, option, prarm) == CURLcode.CURLE_OK;
	}
    
    extern (C) static
    {
        /******************************************************************************
            
            Message Write Callback Method
             
            Interface follows fwrite syntax: http://www.manpagez.com/man/3/fwrite/
            
            Params:
                ptr = data pointer
                size = element size
                nmemb = number of elements
                obj = passthru object instance to work on
            
            Returns:
                zero on write error, or number of written bytes
           
        *******************************************************************************/
        
    	private size_t writeCallback( void* ptr, size_t size , size_t nmemb, void* obj ) 
        {
    		LibCurl curl = cast(LibCurl)obj;
            
            if ( curl is null || !nmemb || ptr is null )
                return 0;
            
            if ( (curl.messageBuffer.length + (size * nmemb)) < curl.maxFileSize )
            {
                try 
                {
                    *curl.messageBuffer ~= toDString(cast(char*)ptr)[0 .. (size * nmemb)].dup;
                }
                catch (Exception e)
                {
                    //*curl.messageBuffer ~= toDString(cast(char*)ptr)[0 .. strlen(cast(char*)ptr)].dup;
                    return 0;
                }
            }
            else
            {
                return 0; // exceeded download limit
            }
            
    		return size*nmemb;
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
