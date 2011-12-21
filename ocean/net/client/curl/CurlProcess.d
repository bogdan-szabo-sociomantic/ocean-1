module ocean.net.client.curl.CurlProcess;



private import ocean.core.ContextUnion;

private import ocean.core.ObjectPool;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.text.convert.Layout;

private import ocean.io.select.event.EpollProcess;

debug private import ocean.util.log.Trace;



public class CurlDownloads
{
    public alias ContextUnion Context;

    private alias void delegate ( Context context, char[] address, ubyte[] data ) CurlReceiveDg;
    // TODO: total_received probably not necessary, user can track if needed

    private alias void delegate ( Context context, char[] address, ExitStatus status ) CurlFinishedDg;

    private static struct ConnectionSetup
    {
        private char[] address;
        private CurlReceiveDg receive_dg;
        private CurlFinishedDg finished_dg;

        private char[] username;
        private char[] passwd;

        private uint timeout_s;

        private Context context_;

        public ConnectionSetup* context ( Context context )
        {
            this.context_ = context;
            return this;
        }

        public ConnectionSetup* context ( Object object )
        {
            this.context_ = Context(object);
            return this;
        }

        public ConnectionSetup* context ( void* pointer )
        {
            this.context_ = Context(pointer);
            return this;
        }

        public ConnectionSetup* context ( hash_t integer )
        {
            this.context_ = Context(integer);
            return this;
        }

        public ConnectionSetup* authenticate ( char[] username, char[] passwd )
        {
            this.username = username;
            this.passwd = passwd;
            return this;
        }

        public ConnectionSetup* timeout ( uint s )
        {
            this.timeout_s = s;
            return this;
        }

        private bool authentication_set ( )
        {
            return this.username.length > 0 && this.passwd.length > 0;
        }

        private bool timeout_set ( )
        {
            return this.timeout_s > 0;
        }
    }

    public static struct ExitStatus
    {
        public bool exited_ok;
        public int exit_code;

        public bool ok ( )
        {
            return this.exited_ok && this.exit_code == 0;
        }

        public bool timed_out ( )
        {
            return this.exited_ok && this.exit_code == 28;
        }
    }


    private class CurlProcess : EpollProcess
    {
        public uint object_pool_index;

        public this ( )
        {
            super(this.outer.epoll);
        }

        private char[][] args;
        private char[] authenticate_buf;
        private char[] timeout_buf;

        private CurlReceiveDg receive_dg;
        private CurlFinishedDg finished_dg;
        private char[] address;
        private Context context;

        private void start ( ConnectionSetup initialise )
        {
            this.receive_dg = initialise.receive_dg;
            this.finished_dg = initialise.finished_dg;
            this.address = initialise.address;
            this.context = initialise.context_;

            this.args.length = 0;

            this.args ~= "-s"; // silent -- nothing sent to stderr

            if ( initialise.authentication_set )
            {
                this.args ~= "-u";

                this.authenticate_buf.length = 0;
                Layout!(char).print(this.authenticate_buf, "{}:{}",
                        initialise.username, initialise.passwd);

                this.args ~= this.authenticate_buf;
            }

            if ( initialise.timeout_set )
            {
                this.args ~= "-m";
                this.timeout_buf.length = 0;
                Layout!(char).print(this.timeout_buf, "{}", initialise.timeout_s);
                
                this.args ~= this.timeout_buf;
            }

            this.args ~= initialise.address;

            super.start("curl", this.args, &this.finishedCb, &this.receiveCb, null);
        }

        private void receiveCb ( ubyte[] data )
        {
            this.receive_dg(this.context, this.address, data);
        }

        private void finishedCb ( bool exited_ok, int exit_code )
        {
            Trace.formatln("Curl finished: ok={}, code={}", exited_ok, exit_code);

            this.finished_dg(this.context, this.address, ExitStatus(exited_ok, exit_code));
        }
    }


    private alias Pool!(CurlProcess) DownloadPool;

    private DownloadPool downloads;

    private EpollSelectDispatcher epoll;

    private const size_t max;


    public this ( EpollSelectDispatcher epoll, size_t max )
    {
        this.epoll = epoll;
        this.max = max;

        this.downloads = new DownloadPool;
    }

    public ConnectionSetup download ( char[] address, CurlReceiveDg receive_dg, CurlFinishedDg finished_dg )
    {
        return ConnectionSetup(address, receive_dg, finished_dg);
    }

    public void assign ( ConnectionSetup* initialise )
    {
        this.assign(*initialise);
    }

    public void assign ( ConnectionSetup initialise )
    {
        if ( this.downloads.length < this.max )
        {
            auto dl = this.downloads.get(new CurlProcess);
            dl.start(initialise);
        }
        else
        {
            Trace.formatln("TOO MANY!"); // TODO: queue?
        }
    }
}

