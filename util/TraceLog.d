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

private     import      tango.util.log.Log, tango.util.log.LayoutDate, 
                        tango.util.log.AppendFile;

private     import      tango.text.convert.Layout;


/*******************************************************************************

    TraceLog

********************************************************************************/

class TraceLog
{
    
    /*******************************************************************************
        
        Trace Log File Location
    
     *******************************************************************************/
    
    private             static char[]                   traceLogFile;

    
    /*******************************************************************************
        
        Trace Logging Activated/Deactivated
    
     *******************************************************************************/

    private             static bool                     enabled = true;

    
    /*******************************************************************************
        
        Logger Instance
    
     *******************************************************************************/
    
    private             static Logger                   logger;
    
    
    /*******************************************************************************
        
        Layout Instance
    
     *******************************************************************************/
    
    private             static Layout!(char)             layout;


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
    
    public static void init( char[] file, char[] id = "TraceLog" )
    {
        this.traceLogFile = file;

        auto appender = new AppendFile(file);
        appender.layout(new LayoutDate);

        this.logger = Log.getLogger(id);
        this.logger.add(appender);
        
        this.layout = new Layout!(char);
    }


    /*******************************************************************************
        
        Writes Trace Message
    
        Writes a message string or a formatted string to the trace log file.
        If no argument is passed after fmt, fmt is simply written to the trace
        log. For further arguments, string formatting is done in
        Stdout.formatln(...) fashion using fmt as formatting string.
        
        ---
     
        Usage Example:
     
            int i = 16767;
            
            TraceLog.write("Counted {} times...", i);
            TraceLog.write("Trace message without parameter {not formatted}");
        
        ---
     
        Params:
            fmt = message string to format with given arguments if any
            ... = optional arguments to format
       
     *******************************************************************************/
    
    public static void write( char[] fmt, ... )
    {
        if (this.enabled)
        {
            this.logger.append(Logger.Level.Trace, _arguments.length?
                                   this.layout.convert(_arguments, _argptr, fmt) :
                                   fmt);
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
        if ( this.logger )
            return this.logger;
        
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
        this.enabled = false;
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
        this.enabled = true;
    }

}
