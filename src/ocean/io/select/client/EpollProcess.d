/*******************************************************************************

    Posix process with epoll integration of output streams (stdout & stderr).

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        January 2012: Initial release

    authors:        Gavin Norman

    Usage example:

    ---

        import ocean.io.Stdout;
        import ocean.io.select.client.EpollProcess;
        import ocean.io.select.EpollSelectDispatcher;

        // Simple epoll process class which uses curl to download data from a
        // url
        class CurlProcess : EpollProcess
        {
            this ( EpollSelectDispatcher epoll )
            {
                super(epoll);
            }

            // Starts the process downloading a url
            public void start ( char[] url )
            {
                super.start("curl", [url]);
            }

            // Called by the super class when the process sends data to stdout.
            // (In the case of curl this is data downloaded from the url.)
            protected void stdout ( ubyte[] data )
            {
                Stdout.formatln("Received: '{}'", data);
            }

            // Called by the super class when the process sends data to stderr.
            // (In the case of curl this is progress & error messages, which we
            // just ignore in this example.)
            protected void stderr ( ubyte[] data )
            {
            }

            // Called by the super class when the process is finished.
            protected void finished ( bool exited_ok, int exit_code )
            {
                if ( exited_ok )
                {
                    Stdout.formatln("Process exited with code {}", exit_code);
                }
                else
                {
                    Stdout.formatln("Process terminated abnormally");
                }
            }
        }

        // Create epoll selector instance.
        auto epoll = new EpollSelectDispatcher;

        // Create a curl process instance.
        auto process = new CurlProcess(epoll);

        // Start the process running, executing a curl command to download data
        // from a url.
        process.start("http://www.google.com");

        // Handle arriving data.
        epoll.eventLoop;


        All EpollProcess instances created in this manner need to share the same
        EpollSelectDispatcher instance (since they would rely on the singleton
        instance of the ProcessMonitor class).

        However, it is sometimes desirable to use more than one
        EpollSelectDispatcher instance with various EpollProcess instances.
        One example of such usage is when an application needs to create
        short-lived EpollProcess instance(s) in a unittest block. In this case
        one EpollSelectDispatcher instance would be needed in the unittest
        block, and a different one in the application's main logic.
        To achieve this, the singleton ProcessMonitor instance needs to be
        circumvented for the EpollProcess instances of the unittest block.
        This can be done by explicitly creating a ProcessMonitor instance and
        passing it to both the constructor and the 'start' method of
        EpollProcess. This involves the following changes to the usage example
        above:

        class CurlProcess : EpollProcess
        {
            // Change the constructor to allow a process monitor to be passed.
            this ( EpollSelectDispatcher epoll,
                   ProcessMonitor process_monitor = null )
            {
                super(epoll, process_monitor);
            }

            // Similarly change the start method to allow a process monitor to
            // be passed.
            public void start ( char[] url,
                                ProcessMonitor process_monitor = null )
            {
                super.start("curl", [url], process_monitor);
            }

            // The remaining code in this class is same as above.
        }

        // Create epoll selector instance (as above)

        // Explicitly create a process monitor instance.
        auto process_monitor = new EpollProcess.ProcessMonitor(epoll);

        // Create a curl process instance passing the created process monitor.
        auto process = new CurlProcess(epoll, process_monitor);

        // Start the process, again passing the created process monitor.
        process.start("http://www.google.com", process_monitor);

        // Handle arriving data (as above)

    ---

*******************************************************************************/

module ocean.io.select.client.EpollProcess;



/*******************************************************************************

    Imports

*******************************************************************************/

import tango.transition;

import ocean.util.container.map.Map;

import ocean.io.select.client.model.ISelectClient;

import ocean.io.select.EpollSelectDispatcher;

import ocean.io.select.client.SignalEvent;

import tango.io.model.IConduit;

import tango.stdc.posix.sys.wait;

import tango.sys.Process;

debug import ocean.io.Stdout;

import tango.stdc.errno;

import tango.util.log.Log;

import tango.stdc.posix.signal : SIGCHLD;



/*******************************************************************************

    Static module logger

*******************************************************************************/

static private Logger log;
static this ( )
{
    log = Log.lookup("ocean.io.select.client.EpollProcess");
}


/*******************************************************************************

    Posix process with epoll integration of output streams (stdout & stderr).

*******************************************************************************/

public abstract class EpollProcess
{
    /***************************************************************************

        Class to monitor and handle inter-process signals via a signal event
        registered with epoll. All processes monitored by a given ProcessMonitor
        instance must share the same EpollSelectDispatcher instance.

        Note that an application would normally not need to explicitly
        instantiate this class. Instead it could rely on the implicit singleton
        instance created in the constructor of EpollProcess. However sometimes
        an application needs to use different EpollSelectDispatcher instances
        with different EpollProcess instances. In such situations, this class
        can be explicitly instantiated and passed to EpollProcess. Refer the
        usage example at the top of this module to see how this is done.

    ***************************************************************************/

    public static class ProcessMonitor
    {
        /***********************************************************************

            Signal event instance which handles SIGCHLD, indicating that a child
            process has terminated. Registered with epoll when one or more
            EpollProcesses are running.

        ***********************************************************************/

        private SignalEvent signal_event;


        /***********************************************************************

            Epoll instance which signal event is registered with.

        ***********************************************************************/

        private EpollSelectDispatcher epoll;


        /***********************************************************************

            Mapping from a process id to an EpollProcess instance.

        ***********************************************************************/

        private StandardKeyHashingMap!(EpollProcess, int) processes;


        /***********************************************************************

            Constructor.

            Params:
                epoll = epoll instance to use for registering / unregistering
                    signal event handler

        ***********************************************************************/

        public this ( EpollSelectDispatcher epoll )
        {
            this.epoll = epoll;

            this.processes = new StandardKeyHashingMap!(EpollProcess, int)(20);

            this.signal_event = new SignalEvent(&this.signalHandler, [SIGCHLD]);
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
            this.processes[process.process.pid] = process;
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
            debug ( EpollProcess ) Stdout.formatln("Signal fired in epoll: "
                                                   "pid = {}", siginfo.ssi_pid);

            pid_t pid;
            do
            {
                int status;
                pid = waitpid(-1, &status, WNOHANG);

                // waitpid returns -1 and error ECHILD if the calling process
                // has no children

                if (pid == -1)
                {
                    assert( errno() == ECHILD );
                    assert( this.processes.length == 0 );
                    return;
                }

                // waitpid returns 0 in the case where it would hang (if no
                // pid has changed state).
                if ( pid )
                {
                    debug ( EpollProcess ) Stdout.formatln("Signal fired in "
                                                        "epoll: pid = {}", pid);

                    auto exited_ok = WIFEXITED(status);
                    int exit_code = exited_ok ? WEXITSTATUS(status) : 0;

                    auto process = pid in this.processes;
                    if ( process )
                    {
                        debug ( EpollProcess ) Stdout.formatln("pid {} "
                                                 "finished, ok = {}, code = {}",
                                                 pid, exited_ok, exit_code);
                        process.exit(exited_ok, exit_code);
                    }

                    this.processes.remove(pid);

                    if ( this.processes.length == 0 )
                    {
                        this.epoll.unregister(this.signal_event);

                        // There cannot be any more children.
                        return;
                    }
                }
            }
            while ( pid );
        }
    }


    /***************************************************************************

        ISelectClient implementation of an output stream. Enables a stdout or
        stderr stream to be registered with an EpollSelectDispatcher.

    ***************************************************************************/

    abstract private static class OutputStreamHandler : ISelectClient
    {
        /***********************************************************************

            Stream buffer. Receives data from stream.

        ***********************************************************************/

        private ubyte[1024] buf;


        /***********************************************************************

            Events to register for

        ***********************************************************************/

        public override Event events ( )
        {
            return Event.EPOLLIN;
        }


        /***********************************************************************

            Catches exceptions thrown by the handle() method.

            Params:
                exception = Exception thrown by handle()
                event     = Selector event while exception was caught

        ***********************************************************************/

        protected override void error_ ( Exception exception, Event event )
        {
            log.error("EPOLL error {} at {} {} event = {}", exception.msg,
                           exception.file, exception.line, event);
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

            Returns:
                true to stay registered with epoll and be called again when a
                read event fires for this stream, false to unregister.

        ***********************************************************************/

        public override bool handle ( Event event )
        {
            /* It is possible to get Event.Read _and_ Hangup
             * simultaneously. If this happens, just deal with the
             * Read. We will be called again with the Hangup.
             */

            size_t received = ( event & event.EPOLLIN ) ?
                    this.stream.read(this.buf) : 0;


            if ( received > 0 && received != InputStream.Eof )
            {
                this.handle_(this.buf[0..received]);
            }
            else
            {
                if ( event & Event.EPOLLHUP )
                {
                    return false;
                }
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

        public override Handle fileHandle ( )
        {
            return this.outer.process.stdout.fileHandle;
        }


        /***********************************************************************

            ISelectClient finalizer. Called from the epoll selector when a
            client finishes (due to being unregistered or an error).

            Calls the outer class' finalize() method.

        ***********************************************************************/

        override public void finalize ( FinalizeStatus status )
        {
            this.outer.stdoutFinalize();
        }


        /***********************************************************************

            Returns:
                the stream being read from

        ***********************************************************************/

        protected override InputStream stream ( )
        {
            return this.outer.process.stdout;
        }


        /***********************************************************************

            Handles data received from the stream, passing it to the stdout()
            method of the outer class.

            Params:
                data = data received from stream

        ***********************************************************************/

        protected override void handle_ ( ubyte[] data )
        {
            assert(!this.outer.stdout_finalized);
            this.outer.stdout(data);
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

        public override Handle fileHandle ( )
        {
            return this.outer.process.stderr.fileHandle;
        }


        /***********************************************************************

            ISelectClient finalizer. Called from the epoll selector when a
            client finishes (due to being unregistered or an error).

            Calls the outer class' finalize() method.

        ***********************************************************************/

        override public void finalize ( FinalizeStatus status )
        {
            this.outer.stderrFinalize();
        }


        /***********************************************************************

            Returns:
                the stream being read from

        ***********************************************************************/

        protected override InputStream stream ( )
        {
            return this.outer.process.stderr;
        }


        /***********************************************************************

            Handles data received from the stream, passing it to the stderr()
            method of the outer class.

            Params:
                data = data received from stream

        ***********************************************************************/

        protected override void handle_ ( ubyte[] data )
        {
            assert(!this.outer.stderr_finalized);
            this.outer.stderr(data);
        }
    }


    /***************************************************************************

        Singleton instance of ProcessMonitor that is used if an instance was not
        explicitly given when instantiating the EpollProcess class.

    ***************************************************************************/

    private static ProcessMonitor process_monitor;


    /***************************************************************************

        Handlers integrating the stdout & stderr of the executing process with
        epoll.

    ***************************************************************************/

    private StdoutHandler stdout_handler;

    private StderrHandler stderr_handler;


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

    private bool stdout_finalized;

    private bool stderr_finalized;


    /***************************************************************************

        Epoll selector instance. Passed as a reference into the constructor.

    ***************************************************************************/

    private EpollSelectDispatcher epoll;


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

        Process being executed.

    ***************************************************************************/

    protected Process process;


    /***************************************************************************

        Constructor.

        Note: the constructor does not actually start a process, the start()
        method does that.

        Params:
            epoll = epoll selector to use
            process_monitor = process monitor to use (null if the implicit
                              singleton process monitor is to be used)

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll,
                  ProcessMonitor process_monitor = null )
    {
        this.epoll = epoll;

        this.process = new Process;
        this.stdout_handler = new StdoutHandler;
        this.stderr_handler = new StderrHandler;

        if ( process_monitor is null )
        {
            if ( this.process_monitor is null )
            {
                debug ( EpollProcess ) Stdout.formatln("Creating the implicit "
                                                   "singleton process monitor");

                this.process_monitor = new ProcessMonitor(this.epoll);
            }

            process_monitor = this.process_monitor;
        }

        assert(this.epoll == process_monitor.epoll, "Mismatch between given "
                   "EpollSelectDispatcher instance and the process monitor's "
                   "EpollSelectDispatcher instance");
    }


    /***************************************************************************

        Starts the process with the specified command and arguments. Registers
        the handlers for the process' stdout and stderr streams with epoll, so
        that notifications will be triggered when the process generates output.
        The command to execute is args_with_command[0].

        Params:
            args_with_command = command followed by arguments
            process_monitor = process monitor to use (null if the implicit
                              singleton process monitor is to be used)

    ***************************************************************************/

    public void start ( cstring[] args_with_command,
                        ProcessMonitor process_monitor = null )
    {
        assert(this.state == State.None); // TODO: error notification?

        this.stdout_finalized = false;
        this.stderr_finalized = false;
        this.exited = false;

        this.process.argsWithCommand(args_with_command);
        this.process.execute();

        debug ( EpollProcess ) Stdout.formatln("Starting process pid {}, {}",
                                           this.process.pid, args_with_command);

        this.epoll.register(this.stdout_handler);
        this.epoll.register(this.stderr_handler);

        this.state = State.Running;

        if ( process_monitor is null )
        {
            assert(this.process_monitor !is null, "Implicit singleton process "
                                                  "monitor not initialised");

            debug ( EpollProcess ) Stdout.formatln("Starting process using the "
                                          "implicit singleton process monitor");

            process_monitor = this.process_monitor;
        }

        process_monitor.add(this);
    }


    /***************************************************************************

        Suspends the output of a process. This is achieved simply by
        unregistering its stdout handler from epoll. This will have the effect
        that the process will, at some point, reach the capacity of its stdout
        buffer, and will then pause until the buffer has been emptied.

    ***************************************************************************/

    public void suspend ( )
    {
        if ( this.state == State.Running )
        {
            this.state = State.Suspended;

            if ( !this.stdout_finalized )
            {
                this.epoll.unregister(this.stdout_handler);
            }
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
        The stdout handler is reregistered with epoll.

    ***************************************************************************/

    public void resume ( )
    {
        if ( this.state == State.Suspended )
        {
            this.state = State.Running;
            this.epoll.register(this.stdout_handler);
        }
    }


    /***************************************************************************

        Abstract method called when data is received from the process' stdout
        stream.

        Params:
            data = data read from stdout

    ***************************************************************************/

    abstract protected void stdout ( ubyte[] data );


    /***************************************************************************

        Abstract method called when data is received from the process' stderr
        stream.

        Params:
            data = data read from stderr

    ***************************************************************************/

    abstract protected void stderr ( ubyte[] data );


    /***************************************************************************

        Abstract method called when the process has finished. Once this method
        has been called, it is guaraneteed that stdout() will not be called
        again.

        Params:
            exited_ok = if true, the process exited normally and the exit_code
                parameter is valid. Otherwise the process exited abnormally, and
                exit_code will be 0.
            exit_code = the process' exit code, if exited_ok is true. Otherwise
                0.

    ***************************************************************************/

    abstract protected void finished ( bool exited_ok, int exit_code );


    /***************************************************************************

        Called when the process' stdout handler is finalized by epoll. This
        occurs when the process terminates and all data from its stdout buffer
        has been read.

        The checkFinished() method is called once the stdoutFinished(),
        stderrFinished() and exit() methods have been called, ensuring that no
        more data will be received after this point.

    ***************************************************************************/

    private void stdoutFinalize ( )
    {
        debug ( EpollProcess ) Stdout.formatln("Finalized stdout pid {}",
                                               this.process.pid);
        this.stdout_finalized = true;
        this.checkFinished();
    }


    /***************************************************************************

        Called when the process' stderr handler is finalized by epoll. This
        occurs when the process terminates and all data from its stderr buffer
        has been read.

        The checkFinished() method is called once the stdoutFinished(),
        stderrFinished() and exit() methods have been called, ensuring that no
        more data will be received after this point.

    ***************************************************************************/

    private void stderrFinalize ( )
    {
        debug ( EpollProcess ) Stdout.formatln("Finalized stderr pid {}",
                                               this.process.pid);
        this.stderr_finalized = true;
        this.checkFinished();
    }


    /***************************************************************************

        Called when the process exits, by the process monitor that is
        responsible for this process. The process monitor, in turn, was notified
        of this via a SIGCHLD signal.

        The checkFinished() method is called once the stdoutFinished(),
        stderrFinished() and exit() methods have been called, ensuring that no
        more data will be received after this point.

        Params:
            exited_ok = if true, the process exited normally and the exit_code
                parameter is valid. Otherwise the process exited abnormally, and
                exit_code will be 0.
            exit_code = the process' exit code, if exited_ok is true. Otherwise
                0.

    ***************************************************************************/

    private void exit ( bool exited_ok, int exit_code )
    {
        debug ( EpollProcess ) Stdout.formatln("Set exit status pid {}",
                                               this.process.pid);
        this.exited_ok = exited_ok;
        this.exit_code = exit_code;
        this.exited = true;

        // We know the process has already exited, as we have explicitly been
        // notified about this by the SIGCHLD signal (handled by the
        // signalHandler() method of ProcessMonitor, above). However the tango
        // Process instance contains a flag (running_) which needs to be reset.
        // This can be achieved by calling wait(), which internally calls
        // waitpid() again. In this case waitpid() will return immediately with
        // an error code (as the child process no longer exists).
        this.process.wait();

        this.checkFinished();
    }


    /***************************************************************************

        Calls the protected finished() method once both the finalize() and
        exit() methods have been called, ensuring that no more data will be
        received after this point.

    ***************************************************************************/

    private void checkFinished ( )
    {
        if ( this.stdout_finalized && this.stderr_finalized && this.exited )
        {
            this.state = State.None;

            debug ( EpollProcess ) Stdout.formatln("Streams finalised & "
                                                   "process exited");
            this.finished(this.exited_ok, this.exit_code);
        }
    }
}



/*******************************************************************************

    Unit tests

*******************************************************************************/

version ( UnitTest )
{
    import ocean.core.Test;
}

unittest
{
    /* IMPORTANT NOTE:
     * In this unittest block, do not do anything that would cause
     * EpollProcess to be instantiated with the 'process_monitor' argument
     * being null. Doing so would result in the singleton process monitor
     * instance being created even before an application's main function is
     * entered. This would preclude the application's ability to use the
     * singleton process monitor instance, as there would be no way for the
     * application to use the same EpollSelectDispatcher instance as that of
     * the already created singleton process monitor. */

    class MyProcess : EpollProcess
    {
        /* The 'process_monitor' argument of this constructor deliberately
         * does not have a default value. This makes sure that a process
         * monitor must be explicitly supplied to create an instance of this
         * class, and thus prevents automatic creation of the singleton
         * process monitor. */
        public this ( EpollSelectDispatcher epoll,
                      ProcessMonitor process_monitor )
        {
            super(epoll, process_monitor);
        }
        protected override void stdout ( ubyte[] data ) { }
        protected override void stderr ( ubyte[] data ) { }
        protected override void finished ( bool exited_ok, int exit_code ) { }
    }

    scope epoll1 = new EpollSelectDispatcher;
    scope epoll2 = new EpollSelectDispatcher;

    scope process_monitor1 = new EpollProcess.ProcessMonitor(epoll1);
    scope process_monitor2 = new EpollProcess.ProcessMonitor(epoll2);

    scope proc1 = new MyProcess(epoll1, process_monitor1);

    bool thrown = false;
    try
    {
        // should throw because of mismatch between epoll2 and
        // process_monitor1.
        scope proc2 = new MyProcess(epoll2, process_monitor1);
    }
    catch
    {
        thrown = true;
    }
    test(thrown, "Expected exception was not thrown");

    try
    {
        // should not throw now because the instances of
        // EpollSelectDispatcher now match.
        scope proc2 = new MyProcess(epoll2, process_monitor2);
    }
    catch
    {
        test(false, "Exception should not have been thrown");
    }
}

