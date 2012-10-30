/*******************************************************************************

    HTTP request functionality using child process running curl.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        January 2012: Initial release
                    August  2012: Added support for more request then get

    authors:        Gavin Norman, Hans Bjerkander

    Usage example:

    ---

        see CurlProcessMulti

    ---

*******************************************************************************/

module ocean.net.client.curl.CurlProcessSingle;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.net.client.curl.process.NotificationInfo;
private import ocean.net.client.curl.process.ExitStatus;
private import ocean.net.client.curl.process.HttpResponse;
private import ocean.net.client.curl.process.RequestParams;

private import ocean.io.select.event.EpollProcess;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.io.serialize.StructSerializer;

private import ocean.text.convert.Layout;
private import ocean.core.Array : copy;

debug private import ocean.io.Stdout;



/*******************************************************************************

    Curl process -- manages a process which is executing a curl command
    line instance.

*******************************************************************************/

private class CurlProcess : EpollProcess
{
    /***************************************************************************

        Local type realias.

    ***************************************************************************/

    public alias .HttpResponse.Code HttpStatus;


    /***************************************************************************

        Initialisation settings for this request. Set by the start()
        method.

    ***************************************************************************/

    private ubyte[] serialized_params;

    private RequestParams* params;


    /***************************************************************************

        Array of arguments for the curl process.

    ***************************************************************************/

    private char[][] args;


    /***************************************************************************

        Buffer used for formatting the optional authentication argument.

    ***************************************************************************/

    private char[] authenticate_buf;


    /***************************************************************************

        Buffer used for formatting the optional timeout argument.

    ***************************************************************************/

    private char[] timeout_buf;


    /***************************************************************************

        Helper struct to extract the HTTP response from the last 3 bytes
        received from the stdout stream.

    ***************************************************************************/

    private HttpResponse http_response;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll )
    {
        super(epoll);
    }


    /***************************************************************************

        Starts the request process according to the specified configuration.

        Params:
            params = request configuration settings

    ***************************************************************************/

    public void start ( RequestParams params)
    {
        StructSerializer!().dump(&params, this.serialized_params);

        this.start();
    }


    /***************************************************************************

        Starts the request process according to the specified configuration.

        Params:
            serialized_params = serialized request configuration settings

    ***************************************************************************/

    public void start ( ubyte[] serialized_params )
    {
        this.serialized_params.copy(serialized_params);

        this.start();
    }


    /***************************************************************************

        Called when data is received from the process' stdout stream.

        Params:
            data = data read from stdout

    ***************************************************************************/

    protected void stdout ( ubyte[] data )
    {
        auto receive_dg = this.params.receive_dg.get();
        receive_dg(this.params.context.get(), this.params.url, data);

        this.http_response.update(data);
    }


    /***************************************************************************

        Called when data is received from the process' stderr stream.

        Params:
            data = data read from stderr

    ***************************************************************************/

    protected void stderr ( ubyte[] data )
    {
        auto error_dg = this.params.error_dg.get();
        error_dg(this.params.context.get(), this.params.url, data);
    }


    /***************************************************************************

        Called when the process has finished. Once this method has been
        called, it is guaranteed that stdout() will not be called again.

        Params:
            exited_ok = if true, the process exited normally and the
                exit_code parameter is valid. Otherwise the process exited
                abnormally, and exit_code will be 0.
            exit_code = the process' exit code, if exited_ok is true.
                Otherwise 0.

    ***************************************************************************/

    protected void finished ( bool exited_ok, int exit_code )
    {
        debug ( CurlProcess ) Stdout.formatln("Curl finished: ok={}, code={}",
                exited_ok, exit_code);

        ExitStatus status = exited_ok
        ? cast(ExitStatus)exit_code
                : ExitStatus.ProcessTerminatedAbnormally;

        auto notification_dg = this.params.notification_dg.get();
        notification_dg(NotificationInfo(NotificationInfo.Type.Finished,
            this.params.context.get(), this.params.url, status, 
            this.http_response.code));
    }


    /***************************************************************************

        Starts the request described by the configuration settings in
        this.serialized_params.

    ***************************************************************************/

    private void start ( )
    {
        StructSerializer!().loadSlice(this.params, this.serialized_params);

        this.http_response.reset;

        auto notification_dg = this.params.notification_dg.get();
        notification_dg(NotificationInfo(NotificationInfo.Type.Started,
                    this.params.context.get(), this.params.url));

        this.args.length = 0;
        this.args ~= "curl";

        // Standard options
        this.args ~= "-s"; // silent -- nothing sent to stderr
        this.args ~= "-S"; // show errors
        this.args ~= "-w";
        this.args ~= "%{http_code}"; 
            // output HTTP status as last 3 bytes of stdout stream

        // Switch off the URL globbing parser, so that URLs can contain {}[]
        this.args ~= "-g";

        // Authentication
        if ( this.params.authentication_set )
        {
            this.args ~= "-u";

            this.authenticate_buf.length = 0;
            Layout!(char).print(this.authenticate_buf, "{}:{}",
                    this.params.username, this.params.passwd);

            this.args ~= this.authenticate_buf;
        }

        // Timeout
        if ( this.params.timeout_set )
        {
            this.args ~= "-m";
            this.timeout_buf.length = 0;
            Layout!(char).print(this.timeout_buf, "{}", this.params.timeout_s);

            this.args ~= this.timeout_buf;
        }

        // SSL
        if ( this.params.ssl_insecure_set )
        {
            this.args ~= "-k";
        }

        // Header only
        if ( this.params.header_only_set )
        {
            this.args ~= "-I";
        }

        // extra info to header...
        if ( this.params.extra_header_set )
        {
            foreach ( head; this.params.extra_header_params )
            {
                this.args ~= "-H";
                this.args ~= head;
            }
        }
        
        if ( this.params.form_params.length )
        {
            foreach ( form; this.params.form_params )
            {
                this.args ~= "-F";
                this.args ~= form;
            }
        }

        //request command
        if (this.params.req_command)
        {
            this.args ~= "-X";
            this.args ~= this.params.req_command;
        }

        if ( this.params.req_data.length )
        {
            this.args ~= "-d";
            this.args ~= this.params.req_data;
            
        }

        // Url
        this.args ~= this.params.url;

        debug ( CurlProcess ) 
            Stdout.formatln("Starting curl process with parameters: {}",
                this.args);
        
        super.start(this.args);
    }
}