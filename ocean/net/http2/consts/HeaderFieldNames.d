/******************************************************************************

    HTTP header field name constants

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    author:         David Eckardt

 ******************************************************************************/

module ocean.net.http2.consts.HeaderFieldNames;

/******************************************************************************/

struct HeaderFieldNames
{
    /**************************************************************************

        General header fields for request and response
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5

     **************************************************************************/

    struct General
    {
        char[] CacheControl,        Connection,         Date,
               Pragma,              Trailer,            TransferEncoding,
               Upgrade,             Via,                Warning;

        alias HeaderFieldNames.GeneralNames    Names;
        alias HeaderFieldNames.GeneralNameList NameList;
    }

    /**************************************************************************

        Constant instance holding field names

     **************************************************************************/

    const General GeneralNames =
    {
        "Cache-Control",        "Connection",       "Date",
        "Pragma",               "Trailer",          "Transfer-Encoding",
        "Upgrade",              "Via",              "Warning"
    };

    /**************************************************************************

        List of field names.

        (Two arrays as a workaround for the issue that it is impossible to have
        run-time initialised static array constants.)

     **************************************************************************/

    public static const char[][] GeneralNameList;

    private static char[][GeneralNames.tupleof.length] GeneralNameList_;

    /**************************************************************************

        Request specific header fields in addition to the Genereal fields
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.3

     **************************************************************************/

    struct Request
    {
        char[] Accept,              AcceptCharset,      AcceptEncoding,
               AcceptLanguage,      Authorization,      Expect,
               From,                Host,               IfMatch,
               IfModifiedSince,     IfNoneMatch,        IfRange,
               IfUnmodifiedSince,   MaxForwards,        ProxyAuthorization,
               Range,               Referer,            TE,
               UserAgent;

        alias HeaderFieldNames.RequestNames    Names;
        alias HeaderFieldNames.RequestNameList NameList;
    }

    /**********************************************************************

        Constant instance holding field names

     **********************************************************************/

    const Request RequestNames =
    {
        "Accept",               "Accept-Charset",   "Accept-Encoding",
        "Accept-Language",      "Authorization",    "Expect",
        "From",                 "Host",             "If-Match",
        "If-Modified-Since",    "If-None-Match",    "If-Range",
        "If-Unmodified-Since",  "Max-Forwards",     "Proxy-Authorization",
        "Range",                "Referer",          "TE",
        "User-Agent"
    };

    /**************************************************************************

        List of field names.

        (Two arrays as a workaround for the issue that it is impossible to have
        run-time initialised static array constants.)

     **************************************************************************/

    public static const char[][] RequestNameList;

    private static char[][RequestNames.tupleof.length] RequestNameList_;

    /**************************************************************************

        Response specific header fields in addition to the Genereal fields
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html#sec6.2

     **************************************************************************/

    struct Response
    {
        char[] AcceptRanges,        Age,                ETag,
               Location,            ProxyAuthenticate,  RetryAfter,
               Server,              Vary,               WwwAuthenticate,

               Allow,               ContentEncoding,    ContentLanguage,
               ContentLength,       ContentLocation,    ContentMD5,
               ContentRange,        ContentType,        Expires,
               LastModified;

        alias HeaderFieldNames.ResponseNames    Names;
        alias HeaderFieldNames.ResponseNameList NameList;
    }

    /**********************************************************************

        Constant instance holding field names

     **********************************************************************/

    const Response ResponseNames =
    {
        "Accept-Ranges",        "Age",              "ETag",
        "Location",             "Proxy-Authenticate","Retry-After",
        "Server",               "Vary",             "WWW-Authenticate",

        "Allow",                "Content-Encoding", "Content-Language",
        "Content-Length",       "Content-Location", "Content-MD5",
        "Content-Range",        "Content-Type",     "Expires",
        "Last-Modified"
    };

    /**************************************************************************

        List of field names.

        (Two arrays as a workaround for the issue that it is impossible to have
        run-time initialised static array constants.)

     **************************************************************************/

    public static const char[][] ResponseNameList;

    private static char[][ResponseNames.tupleof.length] ResponseNameList_;

    /**************************************************************************

        Entity header fields for requests/responses which support entities.
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1

     **************************************************************************/

    struct Entity
    {
        char[] Allow,               ContentEncoding,    ContentLanguage,
               ContentLength,       ContentLocation,    ContentMD5,
               ContentRange,        ContentType,        Expires,
               LastModified;

        alias HeaderFieldNames.EntityNames    Names;
        alias HeaderFieldNames.EntityNameList NameList;
    }

    /**********************************************************************

        Constant instance holding field names

     **********************************************************************/

    const Entity EntityNames =
    {
        "Allow",                "Content-Encoding", "Content-Language",
        "Content-Length",       "Content-Location", "Content-MD5",
        "Content-Range",        "Content-Type",     "Expires",
        "Last-Modified"
    };

    /**************************************************************************

        List of field names.

        (Two arrays as a workaround for the issue that it is impossible to have
        run-time initialised static array constants.)

     **************************************************************************/

    public static const char[][] EntityNameList;

    private static char[][EntityNames.tupleof.length] EntityNameList_;

    /**************************************************************************

        Static constructor, populates the lists of field names.

     **************************************************************************/

    static this ( )
    {
        foreach (i, name; this.GeneralNames.tupleof)
        {
            this.GeneralNameList_[i] = name;
        }

        this.GeneralNameList = this.GeneralNameList_;

        foreach (i, name; this.RequestNames.tupleof)
        {
            this.RequestNameList_[i] = name;
        }

        this.RequestNameList = this.RequestNameList_;

        foreach (i, name; this.ResponseNames.tupleof)
        {
            this.ResponseNameList_[i] = name;
        }

        this.ResponseNameList = this.ResponseNameList_;

        foreach (i, name; this.EntityNames.tupleof)
        {
            this.EntityNameList_[i] = name;
        }

        this.EntityNameList = this.EntityNameList_;
    }
}