/*******************************************************************************

    SafeFork

    copyright:      Copyright (c) 2009-2011 sociomantic labs.
                    All rights reserved

    version:        June 2011: initial release

    authors:        Mathias L. Baumann

    Offers some wrappers for the usage of fork to call expensive blocking
    functions without interrupting the main process and without the need to
    synchronize.

    Useful version switches:
        TimeFork = measures and displays the time taken by the linux fork() call

*******************************************************************************/

module ocean.sys.SafeFork;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.ReusableException;

private import tango.stdc.posix.stdlib : exit;

private import tango.stdc.posix.unistd : fork;

private import tango.stdc.posix.sys.wait;

private import tango.stdc.posix.signal;

private import tango.stdc.errno;

private import tango.stdc.string;



/*******************************************************************************

    Imports for TimeFork version

*******************************************************************************/

version ( TimeFork )
{
    private import ocean.io.Stdout;

    private import tango.time.StopWatch;
}



/*******************************************************************************

    External C

*******************************************************************************/

private extern (C)
{
    enum idtype_t
    {
      P_ALL,        /* Wait for any child.  */
      P_PID,        /* Wait for specified process.  */
      P_PGID        /* Wait for members of process group.  */
    };

    int waitid(idtype_t, id_t, siginfo_t*, int);

    const WEXITED = 0x00000004;
    const WNOWAIT = 0x01000000;
}



/*******************************************************************************

    SafeFork

    Offers some wrappers for the usage of fork to call expensive blocking
    functions without interrupting the main process and without the need to
    synchronize.

    Usage Example:
    -----
    private import ocean.sys.SafeFork;
    private import ocean.util.log.Trace;

    void main ( )
    {
        auto dont_block = new SafeFork(&blocking_function);

        dont_block.call(); // call blocking_function

        if ( !dont_block.call() )
        {
            Trace("blocking function is currently running and not done yet!");
        }

        while ( dont_block.isRunning() )
        {
            Trace("blocking function is still running!");
        }

        if ( !dont_block.call() )
        {
            Trace("blocking function is currently running and not done yet!");
        }

        dont_block.call(true); // wait for a unfinished fork and then call
                               // blocking_function without forking
    }
    -----

*******************************************************************************/

public class SafeFork
{
    /***************************************************************************

        Exception, reusable

    ***************************************************************************/

    private const ReusableException exception;

    /***************************************************************************

        Pid of the forked child

    ***************************************************************************/

    private int child_pid = 0;

    /***************************************************************************

        Delegate to call

    ***************************************************************************/

    private const void delegate () dg;

    /***************************************************************************

        Constructor

        Params:
            dg = delegate to call

    ***************************************************************************/

    public this ( void delegate () dg )
    {
        this.dg = dg;

        this.exception = new ReusableException;
    }

    /***************************************************************************

        Find out whether the fork is still running or not

        Returns:
            true if the fork is still running, else false

    ***************************************************************************/

    public bool isRunning ( )
    {
        return this.child_pid == 0
            ? false
            : this.isRunning(false, false);
    }

    /***************************************************************************

        Call the delegate, possibly within a fork.
        Ensures that the delegate will only be called when there is not already
        a fork running. The fork exits after the delegate returned.

        Note that the host process is not informed about any errors in
        the forked process.

        Params:
            block = if true, wait for a currently running fork and don't fork
                             when calling the delegate
                    if false, don't do anything when a fork is currently running

        Returns:
            true when the delegate was called

        See_Also:
            SafeFork.isRunning

    ***************************************************************************/

    public bool call ( bool block = false )
    {
        if ( this.child_pid == 0 || !this.isRunning(block) )
        {
            if ( block )
            {
                version ( TimeFork )
                {
                    Stdout.formatln("Running task without forking...");
                }
                this.dg();

                this.child_pid = 0;

                return true;
            }
            else
            {
                version ( TimeFork )
                {
                    Stdout.formatln("Running task in fork...");
                    StopWatch sw;
                    sw.start;
                }

                this.child_pid = fork();

                version ( TimeFork )
                {
                    Stdout.formatln("Fork took {}s",
                        (cast(float)sw.microsec) / 1_000_000.0f);
                }

                if ( this.child_pid < 0 )
                {
                    throw this.exception("Failed to fork", __FILE__, __LINE__);
                }
                else if ( this.child_pid == 0 )
                {
                    this.dg();
                    exit(0);
                }

                return true;
            }
        }
        else
        {
            return false;
        }
    }

    /***************************************************************************

        Checks whether the forked process is already running.

        Params:
            block = if true, wait for a currently running fork
                    if false, don't do anything when a fork is currently running
            clear = if true, the waiting status of the forked process is cleared

        Returns:
            true if the forked process is running

        See_Also:
            SafeFork.isRunning

    ***************************************************************************/

    private bool isRunning ( bool block, bool clear = true )
    {
        siginfo_t siginfo;

        auto result = waitid(idtype_t.P_PID, this.child_pid, &siginfo,
                             WEXITED |
                             (block ? 0 : WNOHANG) |
                             (clear ? 0 : WNOWAIT) );

        if (result < 0)
        {
            auto err = strerror(errno);

            throw exception(err[0 .. strlen(err)], __FILE__, __LINE__);
        }

        return result == 0 && siginfo._sifields._kill.si_pid == 0;
    }
}

