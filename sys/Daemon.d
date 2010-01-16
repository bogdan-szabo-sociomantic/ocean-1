/*******************************************************************************

    copyright:      Copyright (c) 2009 Sociomantic Labs. All rights reserved

    version:        Dec 2008: Initial release

    authors:        Lars Kirchhoff 
                    Thomas Nicolai
                    David Eckhardt
                    
    Module to create a unix daemon with several child processes. The daemon 
    detaches from the console to run as background process and starts a given
    number of child processes that run parallel. All child processes execute 
    the same code.

    --

    Usage example:

        class doSomething
        {
            int cool () 
            {
                // run code...
                
                return 0;
            }
        }
    
        Daemon daemon = new Daemon();
    
        daemon.setNumChildren(10);
        daemon.setPidFile("daemon.pid"); 
        daemon.setFuncCall(&d.cool);
    
        daemon.daemonize();

    --

    References:

    Unix Daemon Server Programming
    
    http://www.enderunix.org/docs/eng/daemon.php
    http://www.netzmafia.de/skripten/unix/linux-daemon-howto.html
    http://linux.die.net/man/2/wait
    http://bytes.com/groups/c/517843-how-run-multiple-processes-single-process
    http://www.yolinux.com/TUTORIALS/ForkExecProcesses.html
    http://www.dsource.org/projects/tutorials/wiki/ThreadsAndDelegatesExample


********************************************************************************/

module      ocean.sys.Daemon;

/*******************************************************************************

    Imports

********************************************************************************/

private         import          tango.stdc.signal, tango.stdc.stdlib;

private         import          tango.sys.linux.linux;

private         import          tango.util.log.Log, tango.util.log.AppendFile;

private         import          Integer = tango.text.convert.Integer;

private         import          tango.io.device.File, tango.io.FilePath;


/*******************************************************************************

    Log File Path

********************************************************************************/

const               char[]                  logfile     = "/var/log/daemon.log";


/*******************************************************************************

    PID File Path

********************************************************************************/

const               char[]                  pidpath     = "/var/run/";


/*******************************************************************************

    C POSIX Functions

********************************************************************************/

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

    Signal Handler

    Receives and handles all process signals. The method is called by the
    external C signal handler defined above.
    
    Params
        signal = recieved signal
        
********************************************************************************/

void signal_handler ( int sig )
{
	pid_t process_group, process;
	Daemon daemon = new Daemon();
	
	if (sig == SIGTERM)               // if termination signal is send
    {	
		
		process_group = getpgrp();    // get process group ID
		process = getpid();           // get process ID
		
		
		if (process_group == process) // kill all other processes only if parent process is terminated 
        {			
            daemon.shutdown();			
		}
        
    	exit(EXIT_SUCCESS);
    } 
	
	if (sig == SIGCHLD)               // if child terminates create a new child
    {      
        daemon.log("Starting new child");
        daemon.startChildren();
    }	
}


/*******************************************************************************

    Daemon
    
********************************************************************************/

class Daemon
{
    
    /*******************************************************************************
        
        Daemon Instance
    
     *******************************************************************************/

	private            static Daemon                       instance;

    
    /*******************************************************************************
        
        Delegate Callback
    
     *******************************************************************************/

	private            static int delegate()               func;
	    
    
    /*******************************************************************************
        
        Number of Processes started
    
     *******************************************************************************/

	private            static int                          number_process      = 2;
	          
    
    /*******************************************************************************
        
        PID File
    
     *******************************************************************************/

	private            static char[]                       pidfile;


    /*******************************************************************************
        
        Static Constructor 
    
     *******************************************************************************/
    
	public static this()
    {
		if (!this.instance) 
        {			
			this.instance = new Daemon();
		}	
    }

	
    /*******************************************************************************
        
        Constructor 
    
     *******************************************************************************/
    
    public this () {}

    
    /*******************************************************************************
        
        Sets Number of Children created
        
        Params:
            num_children = number of children
            
     *******************************************************************************/
    
    public void setNumChildren ( int num_children )
    {
    	 this.number_process = num_children;
    }
    
    
    /*******************************************************************************
        
        Returns Number of Children
        
        Returns:
            number of children
            
     *******************************************************************************/
    
    public int getNumChildren ()
    {
    	 return this.number_process;
    }

    
    /*******************************************************************************
        
        Sets Function Callback
        
        Set the function reference to a global variable to be accessed later in 
        startChildren function without passing it directly to the function. This 
        is because the signal handler has no information about the function 
        reference any more.
        
        Params:
            dg = function delegate
            
     *******************************************************************************/
    
    public void setFuncCall ( int delegate() dg )
    {
    	this.func = dg;
    }
      
    
    /*******************************************************************************
        
        Starts Daemon
        
        Forks a new process and kills the parent process to detach from the console. 
        The new process starts the spawning of the childs. The number of childs is 
        set by number_process variable
        
        Params:
            restart_on_termination = restart on termination
            
     *******************************************************************************/
    
    public void daemonize ( bool restart_on_termination = true )
    {
    	pid_t pid, sid;
		
    	pid = fork();  // Fork off the parent process
    	
    	this.log("Start Daemon");
    	
    	if (pid < 0)  // couldnt fork
        {
            exit(EXIT_FAILURE);
        }
         	 
    	if (pid > 0) // If we got a good PID, then we can exit the parent process.
        {
            exit(EXIT_SUCCESS);
        }
    		
    	sid = setsid();
    	 
    	if (sid < 0) 
        {
    	    exit(EXIT_FAILURE);
        }
    	
    	umask(0);  // Change the file mode mask
    	    	
        try
        {
        	int process_pid = getpid();  // write pid to file
            this.writePidFile(process_pid);
        } 
        catch (Exception e)
        {
        	this.log("Couldn't create pid file!");
            return;
        }    	
     		
    	for (int no_childs=0; no_childs < this.number_process; no_childs++) 
        {					
    		this.startChildren(restart_on_termination);
    	}	
    	
        if (restart_on_termination)  // set signal handler for parent process
        {
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
         
      
    /*******************************************************************************
        
        Start Child Process
        
        Forks child, assigns function to run and sets the signal handler.
        
        Params:
            restart_on_termination = restart on termination
            
     *******************************************************************************/
    
    public void startChildren ( bool restart_on_termination = true ) 
    {    	
    	pid_t process_group = getpgrp(); // get process group ID
    	pid_t child_pid = fork();    	 // fork child
    	    	
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
            
    		this.func();    		// run children code
    		
    		exit(EXIT_SUCCESS);
    	}
    	else if (child_pid < 0)
    	{
    		exit(0);    		
    	}
    } 
    

    /*******************************************************************************
        
        Shutdown Process Tree
        
        Forks child, assigns function to run and sets the signal handler.
        
        Params:
            restart_on_termination = restart on termination
            
     *******************************************************************************/
    
    public void shutdown ()
    {
    	signal(SIGCHLD,SIG_IGN);  // ignore signals from childs and kill all processes 
		
		this.log("Shutting down daemon process");
		this.removePidFile();
		
		kill(0, SIGTERM);    	  // kill all processes
    }
    
    
    /*******************************************************************************
        
        Sets PID Filename
        
        Sets daemon PID file in which pid of the daemon will be written if nothing 
        is set no PID file will be created. The PID file is important for creation 
        for rc startup files.
        
        Params:
            filename = name of the PID file that should be created
            
     *******************************************************************************/
    
    public void setPidFile ( char[] filename )
    {
        this.pidfile = filename;
    }
    
    
    /*******************************************************************************
        
        Return PID Filename
        
        Returns:
            PID filename
            
     *******************************************************************************/

    public char[] getPidFile ()
    {
        return this.pidfile;
    }
    
    
    /*******************************************************************************
        
        Writes PID file
        
        Params:
            pid = process ID of the daemon 
            
     *******************************************************************************/
    
    private void writePidFile ( int pid )
    {
        if ( this.pidfile ) 
        {
            File fi = new File (pidpath ~ this.pidfile, File.WriteCreate);            
            fi.output.write(Integer.toString(pid));
            fi.close;
        }
    }
    
    
    /*******************************************************************************
        
        Removes PID File
            
     *******************************************************************************/
    
    private void removePidFile () 
    {
        if ( this.pidfile ) 
        {
            pid_t process_pid = getpgrp();
            FilePath path = FilePath(pidpath ~ this.pidfile);
            path.remove();
        }
    }
    
    
    /*******************************************************************************
        
        Writes Message to Log File
        
        Creates and appends log file for log messages of the daemon process
        
        Params:
            log_message = string with the message for the log file
        
     *******************************************************************************/
    
    private void log ( char[] log_message ) 
    {
    	Logger logger = Log.getLogger("daemon");
    	logger.add(new AppendFile(logfile));
        logger.append(Logger.Level.Info, log_message);        
    }    
    
}

