/*******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Feb 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        D Library Binding for LibCURL multiprotocol file transfer library.

        This module provides bindings for the libcurl library. This is just a
        first draft and needs further extension.

        Be aware that you have to pass the D parser the path to the
        libcurl library. If you use DSSS you have to add the buildflags option
        to your dsss.conf e.g.

        buildflags=-L/usr/lib/libcurl.so

        You'll need to ensure that the libcurl.so is located under the /usr/lib
        directory.

        --

        Usage example:

            auto curl = new LibCurl;

            curl.URL = "http://www.google.com";
            curl.setOption( CURLOPT_SSL_VERIFYPEER, false);

            results = curl.getContent();

            curl.flush();

            curl.URL = "http://www.google.com";

            FormField [1] search;

            search[0].name = "search_string";
            search[0].value = "duffy duck";

            curl.postForm(search);

            results = curl.getContent();

        --

        Related

        http://curl.haxx.se/libcurl/
        http://de2.php.net/curl


*******************************************************************************/

module LibCurl;

private import c.libcurl;

private import tango.stdc.stringz : toDString = fromStringz, toCString = toStringz;

private import tango.net.Uri;

/*******************************************************************************

    LibCurl

*******************************************************************************/

class LibCurl
{

    /**
     * Proxy Authentication Data
     */
    struct ProxyData {
        char [] url;
        char [] userName;
        char [] password;
        curl_proxytype type;
        long authType;
    }


    /**
     * Formular Field
     */
    struct FormField {
        char [] name;
        char [] value;
    }


    /**
     * Curl instance
     */
	private	CURL * mCurl;


    /**
     * URL to Access
     */
	private	char [] url;


    /**
     * Last Error Message
     */
	private	char [CURL_ERROR_SIZE] lastErrorMessage;


    /**
     * Proxy Data
     */
	private ProxyData mProxyData;



    /**
     * StringWriter C callback function
     */
    extern (C)
    {
    	static int stringWriter(char * newData, size_t size, size_t nmemb, inout char [] data)
        {
    		data ~= newData[0 .. (size * nmemb)];
    		return size * nmemb;
    	}
    }



    /**
     * Initializes LibCurl
     *
     */
    private void init()
    {
    	this.mCurl = curl_easy_init();

    	if (this.mCurl is null)
    		throw new LibCurlException("Exception Initializing CURL: " ~ this.lastErrorMessage);

    	setOption( CURLOPT_ERRORBUFFER, &this.lastErrorMessage);
    	setOption( CURLOPT_COOKIEFILE, "");
    	setOption( CURLOPT_FOLLOWLOCATION, 1);
    }



    /**
     * Constructor: Initializing LibCurl with default values
     *
     */
	public this()
    {
		init();
	}



    /**
     * Destructor: Cleaning up
     *
     */
	public ~this()
    {
		curl_easy_cleanup(this.mCurl);
	}



    /**
     * Set URL
     *
     * Params:
     *     newURL = new URL to fetch data from
     */
	public void URL(char [] newURL)
    {
        this.url = newURL;
		setOption( CURLOPT_URL, this.url);
	}



    /**
     * Get URL
     *
     * Returns:
     *     return current URL
     */
	public char [] URL ()
    {
		return url;
	}



    /**
     * Set Proxy data
     *
     * Params:
     *     pData = proxy data
     */
	public void proxy(ProxyData pData)
    {
		this.mProxyData = pData;

		this.setOption( CURLOPT_PROXY, pData.url);

		if (pData.userName != null)
			setOption( CURLOPT_PROXYUSERPWD, Uri.encode(pData.userName) ~ ":" ~ Uri.encode(pData.password));

		this.setOption( CURLOPT_PROXYTYPE, pData.type);

		if (pData.authType != 0)
			this.setOption( CURLOPT_PROXYAUTH, pData.authType);
		else
			this.setOption( CURLOPT_PROXYAUTH, CURLAUTH_ANY);
	}



    /**
     * Get proxy data
     *
     * Returns:
     *     proxy data
     */
	public ProxyData proxy()
    {
		return this.mProxyData;
	}



    /**
     * Set Curl Option
     *
     * Params:
     *     opt = Curl option
     *     optData = value of option
     */
	public void setOption(CURLoption opt, char [] optData)
    {
		CURLcode code;

		code = curl_easy_setopt(this.mCurl, opt, toCString(optData));

		if (code != CURLE_OK)
			throw new LibCurlException("Exception Setting Option: " ~ lastErrorMessage);
	}



    /**
     * Set Curl Option
     *
     * Params:
     *     opt = Curl option
     *     optData = value of option
     */
	public void setOption(CURLoption opt, int optData)
    {
		CURLcode code;

		code = curl_easy_setopt(this.mCurl, opt, optData);

		if (code != CURLE_OK)
			throw new LibCurlException("Exception Setting Option: " ~ lastErrorMessage);
	}



    /**
     * Sets Curl Option
     *
     * Params:
     *     opt = Curl option
     *     optData = value of option
     */
	public void setOption(CURLoption opt, bool optData)
    {
		CURLcode code;

		code = curl_easy_setopt(this.mCurl, opt, optData);

		if (code != CURLE_OK)
			throw new LibCurlException("Exception Setting Option: " ~ lastErrorMessage);
	}


    /**
     * Set Curl Option
     *
     * Params:
     *     opt = Curl option
     *     optData = value of option
     */
	public void setOption(CURLoption opt, void * optData)
    {
		CURLcode code;

		code = curl_easy_setopt(this.mCurl, opt, optData);

		if (code != CURLE_OK)
			throw new LibCurlException("Exception Setting Option: " ~ lastErrorMessage);
	}


    /**
     * Gets URL content
     *
     * Returns:
     *    content of URL
     */
	public char [] getContent()
    {
        char [] data = "";

		this.setOption( CURLOPT_WRITEFUNCTION, &stringWriter);
		this.setOption( CURLOPT_WRITEDATA, &data);

		CURLcode code = curl_easy_perform(this.mCurl);

		if (code != CURLE_OK)
			throw new LibCurlException("Failed to Download: " ~ url ~ " - " ~ lastErrorMessage);

		this.setOption( CURLOPT_HTTPGET, 1);

		return data;
	}


    /**
     * Posts formular data
     *
     * Params:
     *     data =
     */
	public void postForm(FormField [] data)
    {
        char [] fieldBuffer;

        this.setOption( CURLOPT_POST, 1);

		foreach (FormField curForm; data)
			fieldBuffer ~= Uri.encode(curForm.name) ~ "=" ~ Uri.encode(curForm.value) ~ "&";

		if (fieldBuffer.length > 0)
        {
			fieldBuffer = fieldBuffer[0 .. fieldBuffer.length - 1];
			setOption( CURLOPT_POSTFIELDS, fieldBuffer);
		}

	}


    /**
     * Cleans up curl buffers
     *
     */
	public void flush()
    {
		curl_easy_cleanup(this.mCurl);
		this.init();
	}


} // LibCurl



/**
 * This is the base class from which all exceptions generated by this module
 * derive from.
 */
class LibCurlException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }

    private:
        static void opCall(char[] msg) { throw new LibCurlException(msg); }

} // LibCurlException
