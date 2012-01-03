/*******************************************************************************

    Posix process with epoll integration of output streams (stdout & stderr).

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved
    
    version:        January 2012: Initial release
    
    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.select.event.EpollProcess;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.ArrayMap;

private import ocean.io.Stdout;

private import ocean.io.select.model.ISelectClient;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.sys.SignalHandler;

private import ocean.io.select.event.SignalEvent;

private import tango.io.model.IConduit;

private import tango.stdc.posix.sys.wait;

private import tango.sys.Process;



/*******************************************************************************

    Posix process with epoll integration of output streams (stdout & stderr).

*******************************************************************************/

public class EpollProcess
{
    /***************************************************************************

        Manager class for a set of running processes. A single static instance
        of this class is created in the constructor of EpollProcess.

    ***************************************************************************/

    private static class RunningProcesses
    {
        /***********************************************************************

            Signal event instance which handles SIGCHLD, indicating that a child
            process has terminated. Registered with epoll when one or more
            EpollProcesses are running.

        ***********************************************************************/

        private const SignalEvent signal_event;


        /***********************************************************************

            Epoll instance which signal event is reigstered with.

        ***********************************************************************/

        private const EpollSelectDispatcher epoll;


        /***********************************************************************

            Mapping from a process id to an EpollProcess instance.

        ***********************************************************************/

        private const ArrayMap!(EpollProcess, int) processes;


        /***********************************************************************

            Constructor.

            Params:
                epoll = epoll instance to use for registering / unregistering
                    signal event handler

        ***********************************************************************/

        public this ( EpollSelectDispatcher epoll )
        {
            this.epoll = epoll;

            this.processes = new ArrayMap!(EpollProcess, int);

            this.signal_event = new SignalEvent(&this.signalHandler,
                    [SignalHandler.Signals.SIGCHLD]);
        }


        /***********************************************************************

            Adds an EpollProcess instance to the set of running processes. The
            SIGCHLD event handler is registered with epoll, and will call the
            signalHandler() method when a child process terminates.

            Params:
                process = process which has just started

        ***********************************************************************/

        public void add ( EpollProcess process )
        {
            this.processes.put(process.process.pid, process);
            this.epoll.register(this.signal_event);
        }


        /***********************************************************************

            Signal handler, fires when a SIGCHLD signal occurs. Calls waitpid to
            find out which child process caused the signal to fire, informs the
            corresponding EpollProcess instance that the process has exited, and
            removes that process from the set of running signals. If there are
            no further running processes, the SIGCHLD handler is unregistered
            from epoll.

            Params:
                siginfo = signal information struct, contains the id of the
                    process which caused the signal to fire

        ***********************************************************************/

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

                auto process = pid in this.processes;
                if ( process )
                {
                    Stdout.formatln("pid {} finished, ok={}, code={}", pid, exited_ok, exit_code);
                    process.exit(exited_ok, exit_code);
                }
    
                this.processes.remove(pid);
    
                if ( this.processes.length == 0 )
                {
                    this.epoll.unregister(this.signal_event);
                }
            }
        }
    }


    /***************************************************************************

        ISelectClient implementation of an output stream. Enables a stdout or
        stderr stream to be registered with an EpollSelectDispatcher.

    ***************************************************************************/

    abstract private static class OutputStreamHandler : ISelectClient, ISelectable
    {
        /***********************************************************************

            Stream buffer. Receives data from stream.

        ***********************************************************************/
    
        private ubyte[1024] buf;


        /***********************************************************************

            Constructor.

        ***********************************************************************/
    
        public this ( )
        {
            super(this);
        }


        /***********************************************************************

            Returns:
                events to register with epoll (read, in this case)

        ***********************************************************************/

        public Event events ( )
        {
            return Event.Read;
        }


        /***********************************************************************

            ISelectClient handle method. Called by epoll when a read event fires
            for this stream. The stream is provided by the abstract stream()
            method.

            Data is read from the stream into this.buf and the abstract
            handle_() method is called to process the received data. The client
            is left registered with epoll unless a Hangup event occurs. Hangup
            occurs in all cases when the process which owns the stream being
            read from exits (both error and success).

            Params:
                event = event which fired in epoll

        ***********************************************************************/

        public bool handle ( Event event )
        {
            if ( event & Event.Hangup )
            {
                return false;
            }

            size_t received = this.stream.read(this.buf);
            if ( received > 0 && received != InputStream.Eof )
            {
                this.handle_(this.buf[0..received]);
            }

            return true;
        }


        /***********************************************************************

            Returns:
                the stream being read from

        ***********************************************************************/
    
        abstract protected InputStream stream ( );


        /***********************************************************************

            Handles data received from the stream.

            Params:
                data = data received from stream

        ***********************************************************************/

        abstract protected void handle_ ( ubyte[] data );
    }


    /***************************************************************************

        Epoll stdout handler for the process being executed by the outer class.

    ***************************************************************************/

    private class StdoutHandler : OutputStreamHandler
    {
        /***********************************************************************

            Returns:
                file descriptor to register with epoll

        ***********************************************************************/

        public Handle fileHandle ( )
        {
            return this.outer.process.stdout.fileHandle;
        }


        /***********************************************************************

            ISelectClient finalizer. Called from the epoll selector when a 
            client finishes (due to being unregistered or an error).

            Calls the outer class' finalize() method.

        ***********************************************************************/

        protected void finalize ( )
        {
            this.outer.finalize();
        }


        /***********************************************************************

            Returns:
                the stream being read from

        ***********************************************************************/

        protected InputStream stream ( )
        {
            return this.outer.process.stdout;
        }


        /***********************************************************************

            Handles data received from the stream, passing it to the stdout
            delegate of the outer class.

            Params:
                data = data received from stream

        ***********************************************************************/

        protected void handle_ ( ubyte[] data )
        {
            if ( this.outer.stdout_dg )
            {
                this.outer.stdout_dg(data);
            }
        }


        /***********************************************************************

            Returns:
                identifier string for this class

        ***********************************************************************/

        debug public char[] id ( )
        {
            return typeof(this).stringof;
        }
    }


    /***************************************************************************

        Epoll stderr handler for the process being executed by the outer class.

    ***************************************************************************/

    private class StderrHandler : OutputStreamHandler
    {
        /***********************************************************************

            Returns:
                file descriptor to register with epoll

        ***********************************************************************/

        public Handle fileHandle ( )
        {
            return this.outer.process.stderr.fileHandle;
        }


        /***********************************************************************

            Returns:
                the stream being read from

        ***********************************************************************/

        protected InputStream stream ( )
        {
            return this.outer.process.stderr;
        }


        /***********************************************************************

            Handles data received from the stream, passing it to the stderr
            delegate of the outer class.

            Params:
                data = data received from stream

        ***********************************************************************/

        protected void handle_ ( ubyte[] data )
        {
            if ( this.outer.stderr_dg )
            {
                this.outer.stderr_dg(data);
            }
        }


        /***********************************************************************

            Returns:
                identifier string for this class

        ***********************************************************************/

        debug public char[] id ( )
        {
            return typeof(this).stringof;
        }
    }


    /***************************************************************************

        Static manager for all running processes.

    ***************************************************************************/

    private static RunningProcesses running_processes;


    /***************************************************************************

        Process being executed.

    ***************************************************************************/

    private Process process;


    /***************************************************************************

        Handlers integrating the stdout & stderr of the executing process with
        epoll.

    ***************************************************************************/

    private StdoutHandler stdout;

    private StderrHandler stderr;


    /***************************************************************************

        Flag indicating whether the exit() method has been called.

    ***************************************************************************/

    private bool exited;


    /***************************************************************************

        Flag indicating whether the process exited normally, in which case the
        exit_code member is valid. If the process did not exit normally,
        exit_code will be 0 and invalid.

        Set by the exit() method.

    ***************************************************************************/

    private bool exited_ok;


    /***************************************************************************

        Process exit code. Set by the exit() method.

    ***************************************************************************/

    private int exit_code;


    /***************************************************************************

        Flag indicating whether the finalize() method has been called.

    ***************************************************************************/

    private bool finalized;


    /***************************************************************************

        Epoll selector instance. Passed as a reference into the constructor.

    ***************************************************************************/

    private EpollSelectDispatcher epoll;


    /***************************************************************************

        Delegates to call upon receiving data from the process' stdout or stderr
        streams.

    ***************************************************************************/

    protected alias void delegate ( ubyte[] data ) ReceiveDg;

    private ReceiveDg stdout_dg;

    private ReceiveDg stderr_dg;


    /***************************************************************************

        Delegate to call when the process terminates.

    ***************************************************************************/

    protected alias void delegate ( bool exited_ok, int exit_code ) FinishedDg;

    private FinishedDg finished_dg;


    /***************************************************************************

        Process state.

    ***************************************************************************/

    private enum State
    {
        None,
        Running,
        Suspended
    }

    private State state;


    /***************************************************************************

        Constructor.

        Note: the constructor does not actually start a process, the start()
        method does that.

        Params:
            epoll = epoll selector to use

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll )
    {
        this.epoll = epoll;

        this.process = new Process;
        this.stdout = new StdoutHandler;
        this.stderr = new StderrHandler;

        if ( running_processes is null )
        {
            running_processes = new RunningProcesses(this.epoll);
        }
    }


    /***************************************************************************

        Starts the process with the specified command and arguments.

        Params:
            command = command to run
            args = arguments for command
            finished_dg = delegate to call when the process terminates
            stdout_dg = delegate to receive data from the process' stdout stream
            stderr_dg = delegate to receive data from the process' stderr stream

    ***************************************************************************/

    public void start ( char[] command, char[][] args,
            FinishedDg finished_dg, ReceiveDg stdout_dg, ReceiveDg stderr_dg )
    {
        assert(this.state == State.None); // TODO: error notification?

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

        this.running_processes.add(this);
    }


    /***************************************************************************

        Suspends the process.

    ***************************************************************************/

    public void suspend ( )
    {
        if ( this.state == State.Running )
        {
            this.state = State.Suspended;
            this.epoll.unregister(this.stdout);
        }
    }


    /***************************************************************************

        Returns:
            true if the process has been suspended using the suspend() method.

    ***************************************************************************/

    public bool suspended ( )
    {
        return this.state == State.Suspended;
    }


    /***************************************************************************

        Resumes the process if it has been suspended using the suspend() method.

    ***************************************************************************/

    public void resume ( )
    {
        if ( this.state == State.Suspended )
        {
            this.state = State.Running;
            this.epoll.register(this.stdout);
        }
    }


    /***************************************************************************

        Called when the process' stdout handler is finalized by epoll. This
        occurs when the process terminates.

        The finished delegate (set in the start() method) is called once both
        the finalize() and exit() methods have been called, ensuring that no
        more data will be received once the finished delegate is called.

    ***************************************************************************/

    private void finalize ( )
    {
        Stdout.formatln("Finalized pid {}", this.process.pid);
        this.finalized = true;
        this.finished();
    }


    /***************************************************************************

        Called when the process exits. The RunningProcesses instance is notified
        of this via a SIGCHLD signal.

        The finished delegate (set in the start() method) is called once both
        the finalize() and exit() methods have been called, ensuring that no
        more data will be received once the finished delegate is called.

    ***************************************************************************/
    
    private void exit ( bool exited_ok, int exit_code )
    {
        Stdout.formatln("Set exit status pid {}", this.process.pid);
        this.exited_ok = exited_ok;
        this.exit_code = exit_code;
        this.exited = true;

        this.finished();
    }


    /***************************************************************************

        Calls the finished delegate (set in the start() method) once both the
        finalize() and exit() methods have been called, ensuring that no more
        data will be received once the finished delegate is called.

    ***************************************************************************/
    
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
}

