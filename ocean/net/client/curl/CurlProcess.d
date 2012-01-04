/*******************************************************************************

    Url download functionality using a set of child processes running curl.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        January 2012: Initial release

    authors:        Gavin Norman

    Usage example:

    ---

        import ocean.io.Stdout;
        import ocean.net.client.curl.CurlProcess;
        import ocean.io.select.EpollSelectDispatcher;

        // Create epoll selector instance.
        auto epoll = new EpollSelectDispatcher;

        // Create a curl downloads instance which can process a maximum of 10
        // downloads in parallel.
        const max_downloads = 10;
        auto curl = new CurlDownloads(epoll, max_downloads);

        // Initialise some downloads, one with authorization.
        curl.assign(curl.download("http://www.google.com"));
        curl.assign(curl.download("http://www.wikipedia.org"));
        curl.assign(
            curl.download("http://www.zalando.de/var/export/display_zalando_de.csv")
            .authorize("zalando-user", "dewE23#f4"));

        // Handle arriving data.
        epoll.eventLoop;

    ---

    TODO: the structure of this client is very similar to the swarm clients. It
    could perhaps be integrated, if it were either moved to swarm, or if the
    core of swarm were moved to ocean. The former would probably make more
    sense. Two great benefits of integration would be a common interface and a
    base of shared code (leading to greater stability and wider functionality in
    all sharing modules).

*******************************************************************************/

module ocean.net.client.curl.CurlProcess;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.ContextUnion;

private import ocean.core.ObjectPool;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.text.convert.Layout;

private import ocean.io.select.event.EpollProcess;

debug private import ocean.io.Stdout;



/*******************************************************************************

    Class encapsulating a set of one or more url downloads using curl.

*******************************************************************************/

public class CurlDownloads
{
    /***************************************************************************

        Convenience alias for a context union.

    ***************************************************************************/

    public alias ContextUnion Context;


    /***************************************************************************

        Alias for a delegate which is called when a chunk of data is received
        from a url.

    ***************************************************************************/

    private alias void delegate ( Context context, char[] address,
            ubyte[] data ) CurlReceiveDg;


    /***************************************************************************

        Alias for a delegate which is called when a download finishes.

    ***************************************************************************/

    private alias void delegate ( RequestFinishedInfo info ) CurlFinishedDg; //Context context, char[] address, ExitStatus status ) CurlFinishedDg;


    /***************************************************************************

        Curl download setup struct. Instances of this struct can only be
        created externally by calling the download() method (see below). The
        method initialises a struct instance with the required parameters, then
        the struct provides methods to set the optional properties of a
        connection. When all options have been set the struct should be passed
        to the assign() method (see below).

    ***************************************************************************/

    private static struct DownloadInit
    {
        /***********************************************************************

            Address of download.

        ***********************************************************************/

        private char[] address;


        /***********************************************************************

            Delegate to receive data from the download.

        ***********************************************************************/

        private CurlReceiveDg receive_dg;


        /***********************************************************************

            Delegate to receive errors from the download.

        ***********************************************************************/

        private CurlReceiveDg error_dg;


        /***********************************************************************

            Delegate to be called when the download finishes.

        ***********************************************************************/

        private CurlFinishedDg finished_dg;


        /***********************************************************************

            Username & password to use for download authentication. Set using
            the authenticate() method.

        ***********************************************************************/

        private char[] username;

        private char[] passwd;


        /***********************************************************************

            Download timeout (in seconds). Set using the timeout() method.

        ***********************************************************************/

        private uint timeout_s;


        /***********************************************************************

            User-defined context associated with download. Set using the
            context() methods.

        ***********************************************************************/

        private Context context_;


        /***********************************************************************

            Sets the download context from a Context instance.

            Params:
                context = context to set for download

            Returns:
                this pointer for method chaining

        ***********************************************************************/

        public typeof(this) context ( Context context )
        {
            this.context_ = context;
            return this;
        }


        /***********************************************************************

            Sets the download context from an object reference.

            Params:
                object = context to set as context for download

            Returns:
                this pointer for method chaining

        ***********************************************************************/

        public typeof(this) context ( Object object )
        {
            this.context_ = Context(object);
            return this;
        }


        /***********************************************************************

            Sets the download context from a pointer.

            Params:
                pointer = pointer to set as context for download

            Returns:
                this pointer for method chaining

        ***********************************************************************/

        public typeof(this) context ( void* pointer )
        {
            this.context_ = Context(pointer);
            return this;
        }


        /***********************************************************************

            Sets the download context from a hash (integer).

            Params:
                integer = integer to set as context for download

            Returns:
                this pointer for method chaining

        ***********************************************************************/

        public typeof(this) context ( hash_t integer )
        {
            this.context_ = Context(integer);
            return this;
        }


        /***********************************************************************

            Sets this download to use authentication with the specified username
            and password.

            Params:
                username = authentication username
                passwd = authentication password

            Returns:
                this pointer for method chaining

        ***********************************************************************/

        public typeof(this) authenticate ( char[] username, char[] passwd )
        {
            this.username = username;
            this.passwd = passwd;
            return this;
        }


        /***********************************************************************

            Sets this download to timeout after the specified time.

            Params:
                s = seconds to timeout after

            Returns:
                this pointer for method chaining

        ***********************************************************************/

        public typeof(this) timeout ( uint s )
        {
            this.timeout_s = s;
            return this;
        }


        /***********************************************************************

            Returns:
                true if this download is set to use authentication (by a call to
                the authenticate() method)

        ***********************************************************************/

        private bool authentication_set ( )
        {
            return this.username.length > 0 && this.passwd.length > 0;
        }


        /***********************************************************************

            Returns:
                true if this download is set to use a timeout (by a call to the
                timeout() method)

        ***********************************************************************/

        private bool timeout_set ( )
        {
            return this.timeout_s > 0;
        }
    }


    /***************************************************************************

        Status code enum, contains all curl exit codes plus code 0, meaning ok,
        and code -1, meaning that the curl process terminated abnormally and did
        not provide an exit code.

    ***************************************************************************/

    public enum Status
    {
        ProcessTerminatedAbnormally = -1,
        OK = 0,
        UnsupportedProtocol = 1, // Unsupported protocol. This build of curl has no support for this protocol.
        FailedToInitialize = 2, // Failed to initialize.
        URLMalformed = 3, // URL malformed. The syntax was not correct.
        FeatureNotAvailable = 4, // A feature or option that was needed to perform the desired request was not enabled or was explicitly disabled at build-time. To make curl able to do this, you probably need another build of libcurl!
        CouldntResolveProxy = 5, // Couldn't resolve proxy. The given proxy host could not be resolved.
        CouldntResolveHost = 6, // Couldn't resolve host. The given remote host was not resolved.
        FailedToConnect = 7, // Failed to connect to host.
        FTPWeirdServerReply = 8, // FTP weird server reply. The server sent data curl couldn't parse.
        FTPAccessDenied = 9, // FTP access denied. The server denied login or denied access to the particular resource or directory you wanted to reach. Most often you tried to change to a directory that doesn't exist on the server.
        FTPWeirdPASSReply = 11, // FTP weird PASS reply. Curl couldn't parse the reply sent to the PASS request.
        FTPWeirdPASVReply = 13, // FTP weird PASV reply, Curl couldn't parse the reply sent to the PASV request.
        FTPWeird227Format = 14, // FTP weird 227 format. Curl couldn't parse the 227-line the server sent.
        FTPCantGetHost = 15, // FTP can't get host. Couldn't resolve the host IP we got in the 227-line.
        FTPCouldntSetBinary = 17, // FTP couldn't set binary. Couldn't change transfer method to binary.
        PartialFile = 18, // Partial file. Only a part of the file was transferred.
        FTPCouldntDownload = 19, // FTP couldn't download/access the given file, the RETR (or similar) command failed.
        FTPQuoteError = 21, // FTP quote error. A quote command returned error from the server.
        HTTPPageNotRetrieved = 22, // HTTP page not retrieved. The requested url was not found or returned another error with the HTTP error code being 400 or above. This return code only appears if -f, --fail is used.
        WriteError = 23, // Write error. Curl couldn't write data to a local filesystem or similar.
        FTPCouldntSTORFile = 25, // FTP couldn't STOR file. The server denied the STOR operation, used for FTP uploading.
        ReadError = 26, // Read error. Various reading problems.
        OutOfMemory = 27, // Out of memory. A memory allocation request failed.
        OperationTimeout = 28, // Operation timeout. The specified time-out period was reached according to the conditions.
        FTPPORTFailed = 30, // FTP PORT failed. The PORT command failed. Not all FTP servers support the PORT command, try doing a transfer using PASV instead!
        FTPCouldntUseREST = 31, // FTP couldn't use REST. The REST command failed. This command is used for resumed FTP transfers.
        HTTPRangeError = 33, // HTTP range error. The range "command" didn't work.
        HTTPPostError = 34, // HTTP post error. Internal post-request generation error.
        SSLConnectError = 35, // SSL connect error. The SSL handshaking failed.
        FTPBadDownloadResume = 36, // FTP bad download resume. Couldn't continue an earlier aborted download.
        FILECouldntReadFile = 37, // FILE couldn't read file. Failed to open the file. Permissions?
        LDAPCannotBind = 38, // LDAP cannot bind. LDAP bind operation failed.
        LDAPSearchFailed = 39, // LDAP search failed.
        FunctionNotFound = 41, // Function not found. A required LDAP function was not found.
        AbortedByCallback = 42, // Aborted by callback. An application told curl to abort the operation.
        InternalError = 43, // Internal error. A function was called with a bad parameter.
        InterfaceError = 45, // Interface error. A specified outgoing interface could not be used.
        TooManyRedirects = 47, // Too many redirects. When following redirects, curl hit the maximum amount.
        UnknownOption = 48, // Unknown option specified to libcurl. This indicates that you passed a weird option to curl that was passed on to libcurl and rejected. Read up in the manual!
        MalformedTelnetOption = 49, // Malformed telnet option.
        BadSSLCertificate = 51, // The peer's SSL certificate or SSH MD5 fingerprint was not OK.
        ServerDidntReply = 52, // The server didn't reply anything, which here is considered an error.
        NoSSLCryptoEngine = 53, // SSL crypto engine not found.
        CannotSetSSLCryptoEngine = 54, // Cannot set SSL crypto engine as default.
        FailedSendingNetworkData = 55, // Failed sending network data.
        FailedReceivingNetworkData = 56, // Failure in receiving network data.
        BadLocalCertificate = 58, // Problem with the local certificate.
        BadSSLCipher = 59, // Couldn't use specified SSL cipher.
        CouldntAuthenticateCertificate = 60, // Peer certificate cannot be authenticated with known CA certificates.
        UnrecognizedTransferEncoding = 61, // Unrecognized transfer encoding.
        InvalidLDAPURL = 62, // Invalid LDAP URL.
        MaximumFileSizeExceeded = 63, // Maximum file size exceeded.
        FTPSSLLevelFailed = 64, // Requested FTP SSL level failed.
        RewindFailed = 65, // Sending the data requires a rewind that failed.
        SSLInitializationFailed = 66, // Failed to initialise SSL Engine.
        LoginFailed = 67, // The user name, password, or similar was not accepted and curl failed to log in.
        TFTPFileNotFound = 68, // File not found on TFTP server.
        TFTPPermissionProblem = 69, // Permission problem on TFTP server.
        TFTPOutOfDiskSpace= 70, // Out of disk space on TFTP server.
        TFTPIllegalOperation = 71, // Illegal TFTP operation.
        TFTPUnknownTransferId = 72, // Unknown TFTP transfer ID.
        TFTPFileAlreadyExists = 73, // File already exists (TFTP).
        TFTPNoSuchUser = 74, // No such user (TFTP).
        CharacterConversionFailed = 75, // Character conversion failed.
        CharacterConversionFunctionRequired = 76, // Character conversion functions required.
        ProblemReadingSSLCertificate = 77, // Problem with reading the SSL CA cert (path? access rights?).
        ResourceDoesntExist = 78, // The resource referenced in the URL does not exist.
        SSHUnspecifiedError = 79, // An unspecified error occurred during the SSH session.
        SSLShutdownFailed = 80, // Failed to shut down the SSL connection.
        CouldntLoadCRLFile = 82, // Could not load CRL file, missing or wrong format (added in 7.19.0).
        IssuerCheckFailed = 83, // Issuer check failed (added in 7.19.0).
        FTPPRETFailed = 84, // The FTP PRET command failed
        RTSPCSeqMismatch = 85, // RTSP: mismatch of CSeq numbers
        RTSPSessionIdMismatch = 86, // RTSP: mismatch of Session Identifiers
        FTPCouldntParseFileList = 87, // unable to parse FTP file list
        FTPChunkCallbackError = 88, // FTP chunk callback reported error
    }


    /***************************************************************************

        Finished download information struct which is returned to the finished
        delegate. Provides convenient methods to test a few common exit statuses
        of a curl process.

    ***************************************************************************/

    public static struct RequestFinishedInfo
    {
        /***********************************************************************

            .

        ***********************************************************************/

        public Context context;


        /***********************************************************************

            .

        ***********************************************************************/

        public char[] address;


        /***********************************************************************

            .

        ***********************************************************************/

        public Status status;


        /***********************************************************************

            .

        ***********************************************************************/

        public bool succeeded ( )
        {
            return this.status == Status.OK;
        }


        /***********************************************************************

            .

        ***********************************************************************/

        public bool timed_out ( )
        {
            return this.status == Status.OperationTimeout;
        }
    }


    /***************************************************************************

        Curl process -- manages a process which is executing a curl command
        line instance.

    ***************************************************************************/

    private class CurlProcess : EpollProcess
    {

        /***********************************************************************

            Object pool index -- allows the construction of a pool of objects of
            this type.

        ***********************************************************************/

        public uint object_pool_index;


        /***********************************************************************

            Initialisation settings for this download. Set by the start()
            method.

        ***********************************************************************/

        private DownloadInit initialise;


        /***********************************************************************

            Array of arguments for the curl process.

        ***********************************************************************/

        private char[][] args;


        /***********************************************************************

            Buffer used for formatting the optional authentication argument.

        ***********************************************************************/

        private char[] authenticate_buf;


        /***********************************************************************

            Buffer used for formatting the optional timeout argument.

        ***********************************************************************/

        private char[] timeout_buf;


        /***********************************************************************

            Constructor.

        ***********************************************************************/

        public this ( )
        {
            super(this.outer.epoll);
        }


        /***********************************************************************

            Starts the download process according to the specified
            configuration.

            Params:
                initialise = download configuration settings

        ***********************************************************************/

        private void start ( DownloadInit initialise )
        {
            this.initialise = initialise;

            this.args.length = 0;

            this.args ~= "-s"; // silent -- nothing sent to stderr
            this.args ~= "-S"; // show errors

            if ( this.initialise.authentication_set )
            {
                this.args ~= "-u";

                this.authenticate_buf.length = 0;
                Layout!(char).print(this.authenticate_buf, "{}:{}",
                        this.initialise.username, this.initialise.passwd);

                this.args ~= this.authenticate_buf;
            }

            if ( this.initialise.timeout_set )
            {
                this.args ~= "-m";
                this.timeout_buf.length = 0;
                Layout!(char).print(this.timeout_buf, "{}", this.initialise.timeout_s);

                this.args ~= this.timeout_buf;
            }

            this.args ~= this.initialise.address;

            super.start("curl", this.args);
        }


        /***********************************************************************

            Called when data is received from the process' stdout stream.
    
            Params:
                data = data read from stdout

        ***********************************************************************/

        protected void stdout ( ubyte[] data )
        {
            this.initialise.receive_dg(this.initialise.context_,
                    this.initialise.address, data);
        }


        /***********************************************************************

            Called when data is received from the process' stderr stream.
    
            Params:
                data = data read from stderr

        ***********************************************************************/

        protected void stderr ( ubyte[] data )
        {
            this.initialise.error_dg(this.initialise.context_,
                    this.initialise.address, data);
        }


        /***********************************************************************

            Called when the process has finished. Once this method has been
            called, it is guaraneteed that stdout() will not be called again.

            Params:
                exited_ok = if true, the process exited normally and the
                    exit_code parameter is valid. Otherwise the process exited
                    abnormally, and exit_code will be 0.
                exit_code = the process' exit code, if exited_ok is true.
                    Otherwise 0.

        ***********************************************************************/

        protected void finished ( bool exited_ok, int exit_code )
        {
            Stdout.formatln("Curl finished: ok={}, code={}", exited_ok, exit_code);

            Status status = exited_ok
                ? cast(Status)exit_code
                : Status.ProcessTerminatedAbnormally;

            this.initialise.finished_dg(
                    RequestFinishedInfo(this.initialise.context_,
                            this.initialise.address, status));
        }
    }



    /***************************************************************************

        Pool of download processes.

    ***************************************************************************/

    private alias Pool!(CurlProcess) DownloadPool;

    private const DownloadPool downloads;


    /***************************************************************************

        Epoll selector used by processes. Passed as a reference to the
        constructor.

    ***************************************************************************/

    private const EpollSelectDispatcher epoll;


    /***************************************************************************

        Maximum number of concurrent download processes.

    ***************************************************************************/

    public const size_t max;


    /***************************************************************************

        Flag which is set when downloads are suspended using the supsend()
        method. Reset by resume(). When suspended_ is true, no new downloads may
        be assigned.

    ***************************************************************************/

    public bool suspended_;


    /***************************************************************************

        Constructor.

        Params:
            epoll = epoll dispatcher to use
            max = maximum number of concurrent download processes

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, size_t max )
    {
        this.epoll = epoll;
        this.max = max;

        this.downloads = new DownloadPool;
    }


    /***************************************************************************

        Sets up a DownloadInit struct describing a new download. Any desired
        methods of the struct should be called (to configure optional download
        settings), and it should be passed to the assign() method to start the
        download.

        Params:
            address = url to download
            receive_dg = delegate which will be called when data is received
                from the url
            error_dg = delegate which will be called when error messages are
                sent from curl
            finished_dg = delegate which will be called when the download
                process finishes

        Returns:
            DownloadInit struct to be passed to assign

    ***************************************************************************/

    public DownloadInit download ( char[] address, CurlReceiveDg receive_dg,
            CurlReceiveDg error_dg, CurlFinishedDg finished_dg )
    {
        return DownloadInit(address, receive_dg, error_dg, finished_dg);
    }


    /***************************************************************************

        Assigns a new download as described by a DownloadInit struct.

        Two versions of this method exist, accepting either a DownloadInit
        struct, or a pointer to such a struct.

        Params:
            initialise = DownloadInit struct describing a new download

        Returns:
            true if the download was started, or false if all download processes
            are busy or suspended

    ***************************************************************************/

    public bool assign ( DownloadInit* initialise )
    {
        return this.assign(*initialise);
    }

    public bool assign ( DownloadInit initialise )
    {
        if ( this.all_busy || this.suspended_ )
        {
            return false;
        }

        auto dl = this.downloads.get(new CurlProcess);
        dl.start(initialise);

        return true;
    }


    /***************************************************************************

        Returns:
            the number of currently active downloads

    ***************************************************************************/

    public size_t length ( )
    {
        return this.downloads.length;
    }


    /***************************************************************************

        Returns:
            true if all download processes are busy

    ***************************************************************************/

    public bool all_busy ( )
    {
        return this.length == this.max;
    }


    /***************************************************************************

        Suspends all active downloads.

    ***************************************************************************/

    public void suspend ( )
    {
        scope active_downloads = this.downloads.new BusyItemsIterator;
        foreach ( dl; active_downloads )
        {
            dl.suspend;
        }
    }


    /***************************************************************************

        Resumes any suspended downloads.

    ***************************************************************************/

    public void resume ( )
    {
        scope active_downloads = this.downloads.new BusyItemsIterator;
        foreach ( dl; active_downloads )
        {
            dl.resume;
        }
    }
}

