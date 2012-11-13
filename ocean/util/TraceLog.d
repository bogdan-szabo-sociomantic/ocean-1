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

    Note that the static init() method *must* be called before any other methods
    can be used.

    Usage example:

    ---

        private import ocean.util.TraceLog;

        TraceLog.init("etc/my_config.ini");

        TraceLog.write("We got {} items", 23);

        TraceLog.enabled = false;

        TraceLog.write("This message is not written to the trace log");

        TraceLog.console_enabled = true;

        TraceLog.write("This message is written to the console only");

    ---

********************************************************************************/

module ocean.util.TraceLog;


// *****************************************************************************
// *****************************************************************************
// *****************************************************************************
pragma(msg, "ocean.util.TraceLog is deprecated: use ocean.util.app.* / tango.util.log.* instead");
// *****************************************************************************
// *****************************************************************************
// *****************************************************************************


/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.log.MessageLogger;


private     import      ocean.util.log.Trace;

private     import      tango.core.Vararg;

/*******************************************************************************

    TraceLog

********************************************************************************/

class TraceLog
{
    /***************************************************************************

        This type alias

    ***************************************************************************/

    public alias typeof(this) This;


    /***************************************************************************

        Logger Instance

    ***************************************************************************/

    static private MessageLogger logger;


    /***************************************************************************

        Logging to file enabled getter / setter

    ***************************************************************************/

    static public bool enabled ( )
    in
    {
        assert(This.logger !is null, This.stringof ~ ".enabled: logger not initialised, call init() before you use it!");
    }
    body
    {
        return This.logger.enabled;
    }

    static public void enabled ( bool enabled )
    in
    {
        assert(This.logger !is null, This.stringof ~ ".enabled: logger not initialised, call init() before you use it!");
    }
    body
    {
        return This.logger.enabled = enabled;
    }


    /***************************************************************************

        Logging to console enabled getter / setter

    ***************************************************************************/

    static public bool console_enabled ( )
    in
    {
        assert(This.logger !is null, This.stringof ~ ".console_enabled: logger not initialised, call init() before you use it!");
    }
    body
    {
        return This.logger.console_enabled;
    }

    static public void console_enabled ( bool console_enabled )
    in
    {
        assert(This.logger !is null, This.stringof ~ ".console_enabled: logger not initialised, call init() before you use it!");
    }
    body
    {
        return This.logger.console_enabled = console_enabled;
    }


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

    static public void init ( char[] file, char[] id = "TraceLog" )
    {
        This.logger = new MessageLogger(file, id);
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

    static public void write ( char[] fmt, ... )
    in
    {
        assert(This.logger !is null, This.stringof ~ ".write: logger not initialised, call init() before you use it!");
    }
    body
    {
        version (DigitalMarsx64)
        {
            va_list ap;

            va_start(ap, __va_argsave);

            scope(exit) va_end(ap);

            This.logger.write(fmt, _arguments, ap);
        }
        else
            This.logger.write(fmt, _arguments, _argptr);

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

    static public MessageLogger.TangoLogger getLogger ( )
    in
    {
        assert(This.logger !is null, This.stringof ~ ".getLogger: logger not initialised, call init() before you use it!");
    }
    body
    {
        return This.logger.getLogger();
    }
}

