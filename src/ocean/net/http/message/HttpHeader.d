/******************************************************************************

    HTTP header managing base class

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    author:         David Eckardt

    The names of all header fields whose values will be accessed must be added,
    except the General-Header fields specified in RFC 2616 section 4.5.

        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5

 ******************************************************************************/

module ocean.net.http.message.HttpHeader;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import ocean.core.TypeConvert;

import ocean.net.http.consts.HeaderFieldNames,
       ocean.net.http.consts.HttpVersion;

import ocean.net.util.ParamSet;

/******************************************************************************/

abstract class HttpHeader : ParamSet
{
    /**************************************************************************

        Type alias for request header field constant definitions

     **************************************************************************/

    alias .HeaderFieldNames HeaderFieldNames;

    /**************************************************************************

        HTTP version

     **************************************************************************/

    protected HttpVersion http_version_;

    /**************************************************************************

        Constructor

     **************************************************************************/

    protected this ( in cstring[][] standard_header_lists ... )
    {
        super.addKeys(HeaderFieldNames.General.NameList);

        foreach (standard_headers; standard_header_lists)
        {
            super.addKeys(standard_headers);
        }

        super.rehash();
    }

    /**************************************************************************

        Sets the response HTTP version to v. v must be a known HttpVersion
        enumerator value and not be HttpVersion.Undefined.

        reset() will not change this value.

        Params:
            v = response HTTP version

        Returns
            response HTTP version

     **************************************************************************/

    public HttpVersion http_version ( HttpVersion v )
    in
    {
        assert (v,          "HTTP version undefined");
        assert (v <= v.max, "invalid HttpVersion enumerator value");
    }
    body
    {
        this.http_version_ = v;

        return v;
    }

    /**************************************************************************

        Gets the response HTTP version.

        Returns:
            response HTTP version

     **************************************************************************/

    public HttpVersion http_version ( )
    {
        return this.http_version_;
    }

    /**************************************************************************

        Adds the elements of header_field_names to the set of request message
        header fields of interest.

        Params:
            header_field_names = list of header field names of interest

        Returns:
            this instance

     **************************************************************************/

    public void addCustomHeaders ( in cstring[] header_field_names ... )
    {
        super.addKeys(header_field_names);

        super.rehash();
    }
}
