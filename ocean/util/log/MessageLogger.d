/*******************************************************************************

    Message logger -- writes messages to a log file and / or the console.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        April 2011: Initial release

    authors:        Thomas Nicolai, Lars Kirchhoff, Gavin Norman

*******************************************************************************/

module ocean.util.log.MessageLogger;



/*******************************************************************************

    Imports

*******************************************************************************/

private import TangoLog = tango.util.log.Log;

private import tango.util.log.LayoutDate,
               tango.util.log.AppendFile;

private import tango.text.convert.Layout;

private import ocean.util.log.Trace;



/*******************************************************************************

    MessageLogger

*******************************************************************************/

class MessageLogger
{
    /***************************************************************************
    
        Alias for the tango Logger class
    
    ***************************************************************************/

    public alias TangoLog.Logger TangoLogger;


    /***************************************************************************
        
        Log file logging activated / deactivated
    
    ***************************************************************************/
    
    public bool enabled = true;
    
    
    /***************************************************************************
        
        Console logging activated / deactivated
    
    ***************************************************************************/
    
    public bool console_enabled = false;
    
    
    /***************************************************************************
        
        Log file Location
    
    ***************************************************************************/
    
    private char[] file;
    
    
    /***************************************************************************
        
        Logger instance
    
    ***************************************************************************/
    
    private TangoLog.Logger logger;
    
    
    /***************************************************************************

        Layout instance
    
    ***************************************************************************/
    
    private Layout!(char) layout;


    /***************************************************************************

        Internal string buffer used by layout

    ***************************************************************************/

    private char[] buffer;


    /***************************************************************************

        Initialization of Logger. Sets the file which messages are written to.

        Params:
            file = string that contains the path to the trace log file
            id = name of logger

    ***************************************************************************/

    public this ( char[] file, char[] id )
    in
    {
        assert(id.length > 0);
    }
    body
    {
        this.file = file;

        auto appender = new AppendFile(file);
        appender.layout(new LayoutDate);

        this.logger = TangoLog.Log.getLogger(id);
        this.logger.additive(false); // disable default console output
        this.logger.add(appender);

        this.layout = new Layout!(char);
    }


    /***************************************************************************

        Writes a message string or a formatted string to the log file and / or
        the console via Trace.

        If no argument is passed after fmt, fmt is simply written to the log.
        For further arguments, string formatting is done in
        Stdout.formatln(...) fashion using fmt as formatting string.

        Params:
            fmt = message string to format with given arguments if any
            ... = optional arguments to format

    ***************************************************************************/

    public void write ( char[] fmt, ... )
    {
        this.write(fmt, _arguments, _argptr);
    }


    /***************************************************************************

        Writes a message string or a formatted string to the log file and / or
        the console via Trace.

        This method allows a variadic arguments list to be forwarded from
        another function.

        Params:
            fmt = message string to format with given arguments if any
            arguments = list of argument types
            args = list of arguments

    ***************************************************************************/

    public void write ( char[] fmt, TypeInfo[] arguments, ArgList args )
    {
        uint layoutSink ( char[] s )
        {
            this.buffer ~= s;
            return s.length;
        }
    
        synchronized
        {
            auto log_output = this.enabled && this.logger !is null;
            auto console_output = this.console_enabled;

            char[] out_str = fmt;
            if ( arguments.length && (log_output || console_output) )
            {
                this.buffer.length = 0;
                this.layout.convert(&layoutSink, arguments, args, fmt);
                out_str = this.buffer;
            }

            if ( log_output )
            {
                this.logger.append(TangoLog.Logger.Level.Trace, out_str);
            }

            if ( console_output )
            {
                Trace.formatln(out_str);
            }
        }
    }


    /***************************************************************************
        
        Returns Logger instance

        Returns:
            Logger instance

    ***************************************************************************/
    
    public TangoLog.Logger getLogger ()
    {
        return this.logger;
    }
}
