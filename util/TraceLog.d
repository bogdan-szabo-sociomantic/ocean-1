/*******************************************************************************

    Writes messages to a trace log file

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Feb 2009: Initial release

    authors:        Thomas Nicolai
                    Lars Kirchhoff

    Writes trace log messages to a log file. Tracing can be enabled and disabled.

    --

    Usage example:

        TraceLog.init("etc/my_config.ini");

        TraceLog.write("We got {} items", 23);

        TraceLog.disable;

        TraceLog.write("This message is not written to the trace log");

    --

*******************************************************************************/

module ocean.util.TraceLog;


/*******************************************************************************

    Imports

*******************************************************************************/

private     import      tango.util.log.Log, tango.util.log.LayoutDate, tango.util.log.AppendFile;

private     import      tango.text.convert.Layout;


/*******************************************************************************

    TraceLog

********************************************************************************/

class TraceLog
{

    /**
     * location of the trace log file
     */
    private     static      char[]      trace_log_file;

    /**
     * trace logging enabled by default
     */
    private     static      bool        enabled = true;

    /**
     * logger instance
     */
    private     static      Logger      logger;



    /**
     * Constructor: prevented from being called directly
     *
     * instantiate the daemon object
     */
    private this() {}



    /**
     * Initialization of TraceLog
     *
     * Sets the file to write TraceInformation to
     *
     * ---
     *
     * Usage Example:
     *
     * TraceLog.init("log/trace.log");
     *
     * ---
     *
     * Params:
     *   trace_file = string that contains the path to the trace log file
     */
    public static void init( char[] trace_file )
    {
        this.trace_log_file = trace_file;

        auto appender = new AppendFile(trace_file);
        appender.layout(new LayoutDate);

        TraceLog.logger = Log.getLogger("TraceLog");
        TraceLog.logger.add(appender);
    }



    /**
     * Writes information to the trace log file
     *
     * ---
     *
     * Usage Example:
     *
     * TraceLog.write("Counted 16767 times...");
     *
     * ---
     *
     * Params:
     *   fmt  = message to format with given arguments
     *   _arg = arguments passed to include into formating
     */
    public static void write( char[] fmt, ... )
    {
        if ( TraceLog.enabled && fmt.length )
            TraceLog.logger.append(Logger.Level.Trace, (new Layout!(char)).convert(_arguments, _argptr, fmt));
    }


    
    /**
     * Return Logger instance
     * 
     * ---
     * 
     * Usage Example
     * 
     *  
     *      auto log   = Logger.getLogger()
     *      auto queue = new QueueFile (log, "Queue", 30 * 1024 * 1024);
     *      
     * ---
     * 
     * Returns:
     *      Logger instance
     */
    public static Logger getLogger ()
    {
        if ( TraceLog.logger )
            return TraceLog.logger;
        
        return null;
    }
    
    
    
    /**
     * Disables trace logging
     *
     * ---
     *
     * Usage Example:
     *
     * TraceLog.disableTrace;
     *
     * ---
     */
    public static void disableTrace()
    {
        TraceLog.enabled = false;
    }



    /**
     * Enables trace logging
     *
     * ---
     *
     * Usage Example:
     *
     * TraceLog.enableTrace;
     *
     * ---
     */
    public static void enableTrace()
    {
        TraceLog.enabled = true;
    }


}

/******************************************************************************

    TraceLogException

*******************************************************************************/

class TraceLogException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }

    protected:
        static void opCall(char[] msg) { throw new TraceLogException(msg); }
}


