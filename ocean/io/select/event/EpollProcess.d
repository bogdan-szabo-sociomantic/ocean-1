module ocean.io.select.event.EpollProcess;



private import ocean.core.ArrayMap;

private import ocean.io.Stdout;

private import ocean.io.select.model.ISelectClient;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.sys.SignalHandler;

private import ocean.io.select.event.SignalEvent;

private import tango.io.model.IConduit;

private import tango.stdc.posix.sys.wait;

private import tango.sys.Process;



public abstract class EpollProcess
{
    abstract private class OutputStreamHandler : ISelectClient, ISelectable
    {
        private ubyte[1024] buf;

        public this ( )
        {
            super(this);
        }

        public Event events ( )
        {
            return Event.Read;
        }

        public bool handle ( Event event )
        {
            if ( event & Event.Hangup ) // hangup occurs in all exit cases
            {
                return false;
            }

            size_t received = this.input_stream.read(this.buf);
            if ( received > 0 && received != InputStream.Eof )
            {
                this.handle_(this.buf[0..received]);
            }

            return true;
        }

        abstract protected InputStream input_stream ( );

        abstract protected void handle_ ( ubyte[] data );
    }

    private class StdoutHandler : OutputStreamHandler
    {
        public Handle fileHandle ( )
        {
            return this.outer.process.stdout.fileHandle();
        }

        protected void finalize ( )
        {
            this.outer.finalize();
        }

        protected InputStream input_stream ( )
        {
            return this.outer.process.stdout;
        }

        protected void handle_ ( ubyte[] data )
        {
            if ( this.outer.stdout_dg )
            {
                this.outer.stdout_dg(data);
            }
        }

        debug public char[] id ( )
        {
            return typeof(this).stringof;
        }
    }

    private class StderrHandler : OutputStreamHandler
    {
        public Handle fileHandle ( )
        {
            return this.outer.process.stderr.fileHandle();
        }

        protected InputStream input_stream ( )
        {
            return this.outer.process.stderr;
        }

        protected void handle_ ( ubyte[] data )
        {
            if ( this.outer.stderr_dg )
            {
                this.outer.stderr_dg(data);
            }
        }

        debug public char[] id ( )
        {
            return typeof(this).stringof;
        }
    }

    private Process process;
    private StdoutHandler stdout;
    private StderrHandler stderr;

    private bool exited;
    private bool exited_ok;
    private int exit_code;

    private void setExitStatus ( bool exited_ok, int exit_code )
    {
        Stdout.formatln("Set exit status pid {}", this.process.pid);
        this.exited_ok = exited_ok;
        this.exit_code = exit_code;
        this.exited = true;

        this.finished();
    }

    private EpollSelectDispatcher epoll;

    protected alias void delegate ( ubyte[] data ) ReceiveDg;
    private ReceiveDg stdout_dg;
    private ReceiveDg stderr_dg;

    protected alias void delegate ( bool exited_ok, int exit_code ) FinishedDg;
    private FinishedDg finished_dg;

    public this ( EpollSelectDispatcher epoll )
    {
        this.epoll = epoll;

        this.process = new Process;
        this.stdout = new StdoutHandler;
        this.stderr = new StderrHandler;
    }

    final protected void start ( char[] command, char[][] args,
            FinishedDg finished_dg, ReceiveDg stdout_dg, ReceiveDg stderr_dg )
    {
        this.finished_dg = finished_dg;
        this.stdout_dg = stdout_dg;
        this.stderr_dg = stderr_dg;

        this.finalized = false;
        this.exited = false;

        this.process.args(command, args);
        this.process.execute();

        this.epoll.register(this.stdout);
        this.epoll.register(this.stderr);

        this.state = State.Running;

        RunningProcesses(this.epoll).add(this);
    }

    private enum State
    {
        None,
        Running,
        Suspended
    }

    private State state;

    public void suspend ( )
    {
        if ( this.state == State.Running )
        {
            this.state = State.Suspended;
            this.epoll.unregister(this.stdout);
        }
    }

    public bool suspended ( )
    {
        return this.state == State.Suspended;
    }

    public void resume ( )
    {
        if ( this.state == State.Suspended )
        {
            this.state = State.Running;
            this.epoll.register(this.stdout);
        }
    }


    private bool finalized;

    private void finalize ( )
    {
        Stdout.formatln("Finalized pid {}", this.process.pid);
        this.finalized = true;
        this.finished();
    }

    private void finished ( )
    {
        if ( this.finalized && this.exited )
        {
            this.state = State.None;

            Stdout.formatln("Finalised & exited ");
            if ( this.finished_dg !is null )
            {
                this.finished_dg(this.exited_ok, this.exit_code);
            }
        }
    }

    private static class RunningProcesses
    {
        private static typeof(this) instance;

        public static typeof(this) opCall ( EpollSelectDispatcher epoll )
        {
            if ( instance is null )
            {
                instance = new typeof(this)(epoll);
            }
            return instance;
        }

        private SignalEvent signal_event;

        private ArrayMap!(EpollProcess, int) processes;

        private EpollSelectDispatcher epoll;

        private this ( EpollSelectDispatcher epoll )
        {
            this.epoll = epoll;

            this.processes = new ArrayMap!(EpollProcess, int);

            this.signal_event = new SignalEvent(&this.signalHandler,
                    [SignalHandler.Signals.SIGCHLD]);
        }

        private void signalHandler ( SignalEvent.SignalInfo siginfo )
        {
            Stdout.formatln("Signal fired in epoll: pid={}", siginfo.ssi_pid);

            int status;
            auto pid = waitpid(siginfo.ssi_pid, &status, WNOHANG);
            // waitpid returns 0 in the case where it would hang (if the
            // specified pid has not yet changed state)
            if ( pid )
            {
                auto exited_ok = WIFEXITED(status);
                int exit_code = exited_ok ? WEXITSTATUS(status) : 0;

                this.remove(pid, exited_ok, exit_code);
            }
        }

        public void add ( EpollProcess process )
        {
            this.processes.put(process.process.pid, process);
            this.epoll.register(this.signal_event);
        }

        private void remove ( int pid, bool exited_ok, int exit_code )
        {
            auto process = pid in this.processes;
            if ( process )
            {
                Stdout.formatln("pid {} finished, ok={}, code={}", pid, exited_ok, exit_code);
                process.setExitStatus(exited_ok, exit_code);
            }

            this.processes.remove(pid);

            if ( this.processes.length == 0 )
            {
                this.epoll.unregister(this.signal_event);
            }
        }
    }
}

