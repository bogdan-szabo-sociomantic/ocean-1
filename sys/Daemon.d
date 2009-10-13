/*******************************************************************************

    copyright:      Copyright (c) 2009 Sociomantic Labs. All rights reserved

    version:        Dec 2008: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai

    Module to create a unix daemon with several child processes. The daemon 
    detaches from the console to run as background process and starts a given
    number of child processes that run parallel. All child processes execute 
    the same code.

    --

    Usage example:

    //
    // class that should be executed in the child processes
    // 
    class doSomething
    {
        int cool () 
        {
            // do something very cool
            return 0;
        }
    }

    Daemon daemon = new Daemon();           // create daemon object

    daemon.setNumChildren(10);              // set number of children
    daemon.setPidFile("daemon.pid");        // set daemon PID file in which pid of the daemon will be written
                                            // if nothing is set no PID file will be created
                                            // The PID file is important for creation of rc startup files
    daemon.setFuncCall(&d.cool);            // set function that should be called in each children

    daemon.daemonize();                     // start daemon

    --

    References:

    Unix Daemon Server Programming
        http://www.enderunix.org/docs/eng/daemon.php
        http://www.netzmafia.de/skripten/unix/linux-daemon-howto.html
        http://linux.die.net/man/2/wait
        http://bytes.com/groups/c/517843-how-run-multiple-processes-single-process
        http://www.yolinux.com/TUTORIALS/ForkExecProcesses.html
        http://www.dsource.org/projects/tutorials/wiki/ThreadsAndDelegatesExample

*******************************************************************************/

module      ocean.sys.Daemon;



/*******************************************************************************

            constants

*******************************************************************************/


/**
 * Logfile 
 */
const       char[]      logfile     = "/var/log/daemon.log";


/**
 *  path
 */
const       char[]      pidpath     = "/var/run/";
                        


/*******************************************************************************

            tango imports

*******************************************************************************/

private     import      tango.stdc.signal,
                        tango.stdc.stdlib,
                        tango.sys.linux.linux;

private     import		tango.util.log.Log,
						tango.util.log.AppendFile;

private     import		Integer = tango.text.convert.Integer;

private		import  	tango.io.device.File,
						tango.io.FilePath;



/*******************************************************************************

        C POSIX functions definition

*******************************************************************************/

extern (C)
{    
	alias	int pid_t;
	pid_t	fork();
	pid_t   getpid();
	int		umask(int);
	int		setsid();
	int		close(int fd);
	int		getdtablesize();
	int		getpgrp();	
	int		setpgid(pid_t pid, pid_t pgid);
	int		kill(pid_t pid, int sig);
	int		wait();
	
	void sighandler(int sig) 
    {		
		signal_handler(sig);
	}	
}



/*******************************************************************************

		SIGNAL HANDLER

*******************************************************************************/

/**
 * Signal handler
 * Receives and handles all process signals
 *
 * Params
 *     signal = recieved signal 
 */
void signal_handler ( int sig )
{
	pid_t process_group, process;
	Daemon d = new Daemon();
	
	// if termination signal is send
	if (sig == SIGTERM) 
    {	
		// get process group ID
		process_group = getpgrp();
		
		// get process ID
		process = getpid();
		
		// kill all other processes only if parent process is terminated 
		if (process_group == process) 
        {			
			d.shutdown();			
		}    	
    	exit(EXIT_SUCCESS);
    }
           
	// if child terminates create a new child
	if (sig == SIGCHLD) 
    {      
		d.log("Start new child.");
		d.startChildren();
    }	
}



/*******************************************************************************

        Daemon creates a daemon process with a given number of childs

        @author  Lars Kirchhoff <lars.kirchhoff () sociomantic () com>
        @author  Thomas Nicolai <thomas.nicolai () sociomantic () com>        
        @package ocean
        @link    http://www.sociomantic.com
    
*******************************************************************************/

class Daemon
{
	/**
	 * holds the daemon instance for the singleton pattern
	 */
	static		Daemon	            instance;
	            
	/**
	 * holds the reference to the function that should be executed.
	 */
	static      int delegate()      func;
	                                
	/**
	 * Number of process to be started, default = 2
	 */
	private     static int          number_process      = 2;
	            	
    /**
     * pid file for a safe kill 
     */
	private     static char[]       pidfile;


    
    /**
     * Constructor
     *
     * instantiate the daemon object 
     */
	static this()
    {
		if (!this.instance) 
        {			
			this.instance = new Daemon();
		}	
    }


	
    /**
     * Constructor
     */
    this () {}
    

    
    /**
     * Set number of children that should be created 
     * 
     * Params:
     *     num_children = number of children
     */
    public void setNumChildren ( int num_children )
    {
    	 this.number_process = num_children;
    }
    
    
    
    /**
     * Return number of children
     * 
     * Returns:
     *      number of children
     */
    public int getNumChildren ()
    {
    	 return this.number_process;
    }

    
    
    /**
     * Set the function reference to a global variable to be accessed
     * later in startChildren function without passing it directly to the
     * function. This is because the signal handler has no information 
     * about the function reference any more.
     * 
     * Params:
     *     dg = function delegate
     */
    public void setFuncCall ( int delegate() dg )
    {
    	this.func = dg;
    }
        
    
    /**
     * Starts the daemon
     * 
     * Forks a new process and kills the parent process to detach
     * from the console. The new process starts the spawning of the 
     * childs. The number of childs is set by number_process variable
     * 
     * Params:
     *     restart_on_termination = restart on termination
     */
    public void daemonize ( bool restart_on_termination = true )
    {
    	pid_t pid, sid;
		
    	// Fork off the parent process
    	pid = fork();
    	
    	this.log("Start Daemon");
    	
    	// couldnt fork
    	if (pid < 0)
        {
            exit(EXIT_FAILURE);
        }
         	 
    	// If we got a good PID, then we can exit the parent process.
    	if (pid > 0) 
        {
            exit(EXIT_SUCCESS);
        }
    		
    	sid = setsid();
    	 
    	if (sid < 0) 
        {
    	    exit(EXIT_FAILURE);
        }
    	
    	// Change the file mode mask
    	umask(0);
    	    	
    	 // change directory to pid file directory (same as .log file location)      
        try 
        {        	
            // write pid to file        	
        	int process_pid = getpid();
            this.writePidFile(process_pid);
        } 
        catch (Exception e)
        {
            // still need to write something to the logfile
        	this.log("Couldn't create pid file!");        	
            return;
        }    	
     		
    	for (int no_childs=0; no_childs < this.number_process; no_childs++) 
        {					
    		this.startChildren(restart_on_termination);
    	}	
    	
        if (restart_on_termination)
        {
        	// set signal handler for parent process
        	signal(SIGTERM, &sighandler);
        	signal(SIGCHLD, &sighandler);
        }
        
    	for (int i=1; i<= this.number_process; i++) 
        {
    		int status = wait();
    		this.log("Child killed.");
    	}
    	
    	for (int i=getdtablesize(); i>=0; --i) 
        { 
    	    close(i);
        }
    }
         
      
    
    /**
     * Start children process
     * Forks child, assigns function to run and sets 
     * the signal handler.
     * 
     * Params:
     *     restart_on_termination = restart on termination
     */
    public void startChildren ( bool restart_on_termination = true ) 
    {    	
    	// get process group ID
    	pid_t process_group = getpgrp();
    	
    	// fork child
    	pid_t child_pid = fork();    	
    	    	
    	// if work is successful set process group ID 
    	// for child and set signal handler 
    	if(child_pid == 0)
    	{		
            setpgid(child_pid, process_group);
            pid_t pgid = getpgrp();
            
            if (restart_on_termination)
            {
                signal(SIGTERM, &sighandler);
            }
            
    		// run children code
    		this.func();    		
    		
    		exit(EXIT_SUCCESS);
    	}
    	else if (child_pid < 0)
    	{
    		exit(0);    		
    	}
    } 
    

    
    /**
     * shutdown complete process tree
     */
    public void shutdown ()
    {    	
    	// ignore signals from childs and kill all processes 
    	signal(SIGCHLD,SIG_IGN);
		
		// write log file
		this.log("Shutdown daemon process.");
		
		// remove PID file
		this.removePidFile();
		
		// kill all processes
		kill(0, SIGTERM);    	
    }
    
    
    
    /**
     * Set name for PID file of daemon 
     * 
     * Params:
     *     filename = name of the PID file that should be created
     */
    public void setPidFile ( char[] filename )
    {
        this.pidfile = filename;
    }
    
    
    
    /**
     * Get method to return the name of the PID file
     * 
     * Returns:
     *     name of the PID file for the daemon
     */
    public char[] getPidFile ()
    {
        return this.pidfile;
    }
    
    
    
    /**
     * Create PID file if PID file property is set 
     * 
     * Params:
     *     pid = process ID of the daemon 
     */
    private void writePidFile ( int pid )
    {
        if (this.pidfile != "") 
        {
            File fi = new File (pidpath ~ this.pidfile, File.WriteCreate);            
            fi.output.write(Integer.toString(pid));
            fi.close;
        }
    }
    
    
    
    /**
     * Remove PID file  
     */
    private void removePidFile () 
    {
        if (this.pidfile != "") 
        {
            pid_t process_pid = getpgrp();
            FilePath path = FilePath(pidpath ~ this.pidfile);
            path.remove();
        }
    }
    
    
        
    /**
     * Log function 
     * Creates and appends log file for log messages 
     * of the daemon process
     *
     * Params
     * 	   log_message = string with the message for the log file
     */
    private void log ( char[] log_message ) 
    {
    	Logger logger = Log.getLogger("daemon");
    	logger.add(new AppendFile(logfile));
        logger.append(Logger.Level.Info, log_message);        
    }    
    
} // class Daemon

