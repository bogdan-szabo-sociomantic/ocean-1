/*******************************************************************************

    SafeFork
    
    copyright:      Copyright (c) 2009-2011 sociomantic labs. 
                    All rights reserved
    
    version:        June 2011: initial release
    
    authors:        Mathias L. Baumann
        
    Offers some wrappers for the usage of fork to call expensive blocking
    functions without interrupting the main process and without the need to
    synchronize.
    
*******************************************************************************/

module ocean.sys.SafeFork;

private import ocean.util.ReusableException;

debug private import ocean.util.log.Trace;

debug private import tango.core.Thread;

/*******************************************************************************

    Tango Imports

*******************************************************************************/

private import tango.stdc.posix.stdlib : exit;

private import tango.stdc.posix.unistd : fork;

private import tango.stdc.posix.sys.wait;

private import tango.stdc.posix.signal;

private import tango.stdc.errno;

private import tango.stdc.string;

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

class SafeFork
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
        if ( this.child_pid == 0 ) return false;
        
        siginfo_t siginfo;
        
        auto result = waitid(idtype_t.P_PID, this.child_pid, &siginfo, 
                             WEXITED | WNOHANG | WNOWAIT);
                    
        if (result < 0)
        {   
            auto err = strerror(errno);
            
            throw exception(err[0 .. strlen(err)], __FILE__, __LINE__);
        }
        
        return result == 0 && siginfo._sifields._kill.si_pid == 0;
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
        bool childIsRunning ( )
        {
            siginfo_t siginfo;
            
            auto result = waitid(idtype_t.P_PID, this.child_pid, &siginfo, 
                                  WEXITED | (block ? 0 : WNOHANG));
                        
            if (result < 0)
            {   
                auto err = strerror(errno);
                
                throw exception(err[0 .. strlen(err)], __FILE__, __LINE__);
            }
                     
            return result == 0 && siginfo._sifields._kill.si_pid == 0;
        }

        if ( this.child_pid == 0 || !childIsRunning() ) 
        {
            if ( block )
            {
                this.dg();
                
                this.child_pid = 0;
                
                return true;
            }
            else
            {
                this.child_pid = fork();
                
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
}