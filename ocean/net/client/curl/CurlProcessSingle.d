/*******************************************************************************

    Url download functionality using child process running curl.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        January 2012: Initial release

    authors:        Gavin Norman

    Usage example:

    ---

        TODO

    ---

*******************************************************************************/

module ocean.net.client.curl.CurlProcessSingle;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.net.client.curl.process.DownloadSetup;
private import ocean.net.client.curl.process.NotificationInfo;
private import ocean.net.client.curl.process.ExitStatus;

private import ocean.io.select.event.EpollProcess;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.io.serialize.StructSerializer;

private import ocean.text.convert.Layout;



/*******************************************************************************

    Curl process -- manages a process which is executing a curl command
    line instance.

*******************************************************************************/

private class CurlProcess : EpollProcess
{
    /***************************************************************************

        Initialisation settings for this download. Set by the start()
        method.

    ***************************************************************************/

    private ubyte[] serialized_setup;

    private DownloadSetup* setup;


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

        Constructor.

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll )
    {
        super(epoll);
    }


    /***************************************************************************

        Starts the download process according to the specified configuration.

        Params:
            setup = download configuration settings

    ***************************************************************************/

    public void start ( DownloadSetup setup )
    {
        StructSerializer!().dump(&setup, this.serialized_setup);

        this.start();
    }


    /***************************************************************************

        Starts the download process according to the specified configuration.

        Params:
            serialized_setup = serialized download configuration settings

    ***************************************************************************/

    public void start ( ubyte[] serialized_setup )
    {
        this.serialized_setup.copy(serialized_setup);

        this.start();
    }


    /***************************************************************************

        Called when data is received from the process' stdout stream.

        Params:
            data = data read from stdout

    ***************************************************************************/

    protected void stdout ( ubyte[] data )
    {
        auto receive_dg = this.setup.receive_dg();
        receive_dg(this.setup.context, this.setup.url, data);
    }


    /***************************************************************************

        Called when data is received from the process' stderr stream.

        Params:
            data = data read from stderr

    ***************************************************************************/

    protected void stderr ( ubyte[] data )
    {
        auto error_dg = this.setup.error_dg();
        error_dg(this.setup.context, this.setup.url, data);
    }


    /***************************************************************************

        Called when the process has finished. Once this method has been
        called, it is guaraneteed that stdout() will not be called again.

        Params:
            exited_ok = if true, the process exited normally and the
                exit_code parameter is valid. Otherwise the process exited
                abnormally, and exit_code will be 0.
            exit_code = the process' exit code, if exited_ok is true.
                Otherwise 0.

    ***************************************************************************/

    protected void finished ( bool exited_ok, int exit_code )
    {
        debug ( EpollProcess ) Stdout.formatln("Curl finished: ok={}, code={}",
                exited_ok, exit_code);

        ExitStatus status = exited_ok
        ? cast(ExitStatus)exit_code
                : ExitStatus.ProcessTerminatedAbnormally;

        auto notification_dg = this.setup.notification_dg();
        notification_dg(NotificationInfo(NotificationInfo.Type.Finished,
                this.setup.context, this.setup.url, status));
    }


    /***************************************************************************

        Starts the download described by the configuration settings in
        this.serialized_setup.

    ***************************************************************************/

    private void start ( )
    {
        StructSerializer!().loadSlice(this.setup, this.serialized_setup);

        auto notification_dg = this.setup.notification_dg();
        notification_dg(NotificationInfo(NotificationInfo.Type.Started,
                    this.setup.context, this.setup.url));

        this.args.length = 0;

        // Standard options
        this.args ~= "-s"; // silent -- nothing sent to stderr
        this.args ~= "-S"; // show errors

        // Authentication
        if ( this.setup.authentication_set )
        {
            this.args ~= "-u";

            this.authenticate_buf.length = 0;
            Layout!(char).print(this.authenticate_buf, "{}:{}",
                    this.setup.username, this.setup.passwd);

            this.args ~= this.authenticate_buf;
        }

        // Timeout
        if ( this.setup.timeout_set )
        {
            this.args ~= "-m";
            this.timeout_buf.length = 0;
            Layout!(char).print(this.timeout_buf, "{}", this.setup.timeout_s);

            this.args ~= this.timeout_buf;
        }

        this.args ~= this.setup.url;

        super.start("curl", this.args);
    }
}

