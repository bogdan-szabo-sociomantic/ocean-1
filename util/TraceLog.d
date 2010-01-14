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

********************************************************************************/

module ocean.util.TraceLog;


/*******************************************************************************

    Imports

********************************************************************************/

private     import      tango.util.log.Log, tango.util.log.LayoutDate, tango.util.log.AppendFile;

private     import      tango.text.convert.Layout;


/*******************************************************************************

    TraceLog

********************************************************************************/

class TraceLog
{
    
    /*******************************************************************************
        
        Trace Log File Location
    
     *******************************************************************************/
    
    private             static char[]                   trace_log_file;

    
    /*******************************************************************************
        
        Trace Logging Activated/Deactivated
    
     *******************************************************************************/

    private             static bool                     enabled = true;

    
    /*******************************************************************************
        
        Logger Instance
    
     *******************************************************************************/
    
    private             static Logger                   logger;


    /*******************************************************************************
        
        Constructor 
        
        Don't called directly as its protected to be called. Use function directly
        instead as they are static.
    
     *******************************************************************************/
    
    private this() {}


    /*******************************************************************************
        
        Initialization of TraceLog
    
        Sets the file to write TraceInformation to
        
        ---
     
        Usage Example:
     
            TraceLog.init("log/trace.log");
     
        ---
     
        Params:
            trace_file = string that contains the path to the trace log file
       
     *******************************************************************************/
    
    public static void init( char[] trace_file, char[] id = "TraceLog" )
    {
        this.trace_log_file = trace_file;

        auto appender = new AppendFile(trace_file);
        appender.layout(new LayoutDate);

        TraceLog.logger = Log.getLogger(id);
        TraceLog.logger.add(appender);
    }


    /*******************************************************************************
        
        Writes Trace Message
    
        Formats a message string and writes it to the trace log file. String 
        formatting is done in Stdout.formatln(...) fashion.
        
        ---
     
        Usage Example:
     
            int i = 16767;
            
            TraceLog.write("Counted {} times...", i);
            TraceLog.write("Trace message without parameter");
        
        ---
     
        Params:
            fmt = message to format with given arguments
            ... = optional arguments to format
       
     *******************************************************************************/
    
    public static void write( char[] fmt, ... )
    {
        if ( TraceLog.enabled && fmt.length )
        {
            if ( _arguments.length )
            {
                TraceLog.writeString((new Layout!(char)).convert(_arguments, _argptr, fmt));
            }
            else
            {
                TraceLog.logger.append(Logger.Level.Trace, message);
            }
        }
    }
    
    
    /*******************************************************************************
        
        Returns Logger Instance
        
        ---
     
        Usage Example:
     
            auto log   = Logger.getLogger()
            auto queue = new QueueFile (log, "Queue", 30 * 1024 * 1024);
        
        ---
     
        Returns:
            Logger instance
       
     *******************************************************************************/

    public static Logger getLogger ()
    {
        if ( TraceLog.logger )
            return TraceLog.logger;
        
        return null;
    }
    
    
    /*******************************************************************************
        
        Disable Trace Logging
        
        ---
     
        Usage Example:
     
            TraceLog.disableTrace;
        
        ---
     
        Returns:
            Logger instance
       
     *******************************************************************************/

    public static void disableTrace()
    {
        TraceLog.enabled = false;
    }


    /*******************************************************************************
        
        Enable Trace Logging
        
        ---
     
        Usage Example:
     
            TraceLog.enableTrace;
        
        ---
     
        Returns:
            Logger instance
       
     *******************************************************************************/

    public static void enableTrace()
    {
        TraceLog.enabled = true;
    }

}


/*******************************************************************************

    TraceLogException

********************************************************************************/

class TraceLogException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }

    protected:
        static void opCall(char[] msg) { throw new TraceLogException(msg); }
}


