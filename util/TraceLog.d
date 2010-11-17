/*******************************************************************************

    Writes messages to a trace log file

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Feb 2009: Initial release

    authors:        Thomas Nicolai
                    Lars Kirchhoff
                    Gavin Norman

    Writes trace log messages to a log file and / or to the console via Trace.
    Tracing to log is on by default, while tracing to the console is off by
    default. Both can be individually enabled and disabled.

    --

    Usage example:

        TraceLog.init("etc/my_config.ini");

        TraceLog.write("We got {} items", 23);

        TraceLog.enabled = false;

        TraceLog.write("This message is not written to the trace log");

        TraceLog.console_enabled = true;

        TraceLog.write("This message is written to the console only");

    --

********************************************************************************/

module ocean.util.TraceLog;



/*******************************************************************************

    Imports

********************************************************************************/

private     import      tango.util.log.Log, tango.util.log.LayoutDate, 
                        tango.util.log.AppendFile;

private     import      tango.text.convert.Layout;

private     import      tango.util.log.Trace;



/*******************************************************************************

    TraceLog

********************************************************************************/

struct TraceLog
{
static:

    /***************************************************************************

        Struct type alias

    ***************************************************************************/

    public alias            typeof(*this)        This;


    /***************************************************************************
        
        Log file logging Activated/Deactivated
    
    ***************************************************************************/

    public                  bool                enabled = true;


    /***************************************************************************
        
        Console logging Activated/Deactivated
    
    ***************************************************************************/

    public                  bool                console_enabled = false;


    /***************************************************************************
        
        Trace Log File Location
    
    ***************************************************************************/
    
    private                 char[]              traceLogFile;

    
    /***************************************************************************
        
        Logger Instance
    
    ***************************************************************************/
    
    private synchronized    Logger              logger = null;
    
    
    /***************************************************************************
        
        Layout Instance
    
    ***************************************************************************/
    
    private synchronized    Layout!(char)       layout;


    /***************************************************************************
        
        Initialization of TraceLog
    
        Sets the file to write TraceInformation to
        
        ---
     
        Usage Example:
     
            TraceLog.init("log/trace.log");
     
        ---
     
        Params:
            file = string that contains the path to the trace log file
            id = name of logger
       
    ***************************************************************************/
    
    public void init( char[] file, char[] id = "TraceLog" )
    {
        This.traceLogFile = file;

        auto appender = new AppendFile(file);
        appender.layout(new LayoutDate);

        This.logger = Log.getLogger(id);
        logger.additive(false); // disable default console output
        This.logger.add(appender);

        This.layout = new Layout!(char);
    }


    /***************************************************************************
        
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
       
    ***************************************************************************/

    public void write ( char[] fmt, ... )
    {
        static char[] buffer;
        
        uint layoutSink ( char[] s )
        {
            buffer ~= s;
            return s.length;
        }

        synchronized
        {
            auto log_output = This.enabled && This.logger;
            auto console_output = This.console_enabled;

            char[] out_str = fmt;
            if ( _arguments.length && log_output || console_output )
            {
                buffer.length = 0;
                This.layout.convert(&layoutSink, _arguments, _argptr, fmt);
                out_str = buffer;
            }

            if ( log_output )
            {
                This.logger.append(Logger.Level.Trace, out_str);
            }
    
            if ( console_output )
            {
                Trace.formatln(out_str);
            }
        }
    }
    
    
    /***************************************************************************
        
        Returns Logger Instance
        
        ---
     
        Usage Example:
     
            auto log   = Logger.getLogger()
            auto queue = new QueueFile (log, "Queue", 30 * 1024 * 1024);
        
        ---
     
        Returns:
            Logger instance
       
    ***************************************************************************/

    public Logger getLogger ()
    {
        return This.logger;
    }
}
