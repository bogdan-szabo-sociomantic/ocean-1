/*******************************************************************************

    Mixins for request structs used in CurlProcess*.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        August 2012: Initial release

    authors:        Gavin Norman, Hans Bjerkander

    Contains different templates for different http requests. Combinations of 
    this templates creates a struct that can be used as a request.

*******************************************************************************/

module ocean.net.client.curl.process.RequestSetup;


/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.net.client.curl.process.RequestParams;

/*******************************************************************************

    Mixin for the methods shared by all different HTTP requests

*******************************************************************************/

public template RequestBase ( )
{

    /***************************************************************************

        Invariant to make sure that this object only can be created with opcall

    ***************************************************************************/
       
    invariant
    {
        assert(this.params.url && this.params.req_command, 
            "Invalid request object -- command not set");
    }    

    /***************************************************************************

        Struct containing the different paramaters that can be used. To set the
        parameters use methods in the templates.

    ***************************************************************************/
    
    private RequestParams params;    
    
    /***************************************************************************

        Sets the download context from a Context instance.

        Params:
            context = context to set for download

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) context ( ContextUnion context )
    {
        this.params.context.set(context);
        return this;
    }


    /***************************************************************************

        Sets the download context from an object reference.

        Params:
            object = context to set as context for download

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) context ( Object object )
    {
        this.params.context.set(ContextUnion(object));
        return this;
    }


    /***************************************************************************

        Sets the download context from a pointer.

        Params:
            pointer = pointer to set as context for download

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) context ( void* pointer )
    {
        this.params.context.set(ContextUnion(pointer));
        return this;
    }


    /***************************************************************************

        Sets the download context from a hash (integer).

        Params:
            integer = integer to set as context for download

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) context ( hash_t integer )
    {
        this.params.context.set(ContextUnion(integer));
        return this;
    }


    /***************************************************************************

        Sets this download to use authentication with the specified username
        and password.

        Params:
            username = authentication username
            passwd = authentication password

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) authenticate ( char[] username, char[] passwd )
    {
        this.params.username = username;
        this.params.passwd = passwd;
        return this;
    }


    /***************************************************************************

        Sets this download to timeout after the specified time.

        Params:
            s = seconds to timeout after

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) timeout ( uint s )
    {
        this.params.timeout_s = s;
        return this;
    }


    /***************************************************************************

        Sets this download to allow "insecure" SSL connections and transfers.

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) ssl_insecure ( )
    {
        this.params.ssl_insecure = true;
        return this;
    }


    /***************************************************************************

        Adds extra information in the header

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) extraHeader(char[] header)
    {
        this.params.extra_header_params ~= header;
        return this;   
    }


    /***************************************************************************

        Adds status code to standard output? Default yes

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) appendStatusCode(bool append)
    {
        this.params.append_statuscode = append;
        return this;   
    }

    /***************************************************************************

        "Constructor" method. Creates an instance of this struct from the given
        parameters. This struct is essentail a wrapper around a RequestParams
        struct which opens only a cerntain methods to use.

        Params:
            url = url to request
            recieve_dg = delegate to which request data is passed
            error_dg = delegate to which error messages are passed
            notification_dg = delegate to which notifications of states changes
                are sent (when a request is queued / started / finished)
            data = the data that will be "posted"

    ***************************************************************************/    
    
    public static typeof(*this) opCall ( char[] url, CurlReceiveDg receive_dg,
            CurlReceiveDg error_dg, CurlNotificationDg notification_dg ,
            char[] cmd)
    {
        typeof(*this) req;

        req.params.url = url;
        req.params.receive_dg.set      ( receive_dg );
        req.params.error_dg.set        ( error_dg   );
        req.params.notification_dg.set ( notification_dg );       
        req.params.req_command = cmd;

        return req;
    }   
}

/*******************************************************************************

    Mixin for a request with data

*******************************************************************************/

public template RequestData ( )
{

    /***************************************************************************

        Adds status code to standard output? Default yes

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) setRequestData(char[] data)
    {
        this.params.req_data = data;
        return this;   
    }
}