/*******************************************************************************

    Ocean Exception Handling Template

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Jan 2009: Initial release

    authors:        Lars Kirchhoff
                    Thomas Nicolai

    Basic Exception handling template for use in modules and projects. The
    Exception template can be used as extension for custom routines to redirect
    error messages to files or command line via a Logger Interface.


    Exception Console Output Usage Example:

    ---
        void run()
        {
            try
                this.readSocket();
            catch (Exception e)
                OceanException(e.msg);
        }

        void main ( char[][] args )
        {
            // execute method
            OceanException.run(&run);

        }
    ---
        The example shows how to catch OceanException thrown by some part of
        your code. The highest catch is going to print your exception to the
        screen. In case you dont use a catch statement at the end your
        message just gets printed on stdout and the code exits at this stage.

    Exception File Logging Usage Example:

    ---
        import tango.util.log.AppendFile;


        void run()
        {
            try
                this.readSocket();
            catch (Exception e)
                OceanException(e.msg);
        }

        void main ( char[][] args )
        {
            appender = new AppendFile("error.log")
            OceanException.setOutput(appender);

            // execute method
            OceanException.run(&run);
        }
    ---

        The example shows on how to use OceanExeption in combination with a log
        file. To set it up you need to include the proper Appender from
        tango.util.log. You have the choice between a file, socket, mail and
        console appender. This appender just get passed to OceanExeption at the
        beginning of your code.

********************************************************************************/

module      ocean.util.OceanException;


// *****************************************************************************
// *****************************************************************************
// *****************************************************************************
pragma(msg, "ocean.util.OceanException is deprecated: use ocean.util.app.* / tango.util.log.* instead");
// *****************************************************************************
// *****************************************************************************
// *****************************************************************************


/*******************************************************************************

    Imports

********************************************************************************/

private     import      ocean.text.Arguments;

private     import      Tango = tango.text.Arguments;

private     import      tango.util.log.Log, tango.util.log.LayoutDate;

private     import      ocean.util.log.Trace;

private     import      tango.text.convert.Layout;

private     import      tango.core.Vararg;

/*******************************************************************************

    OceanException

********************************************************************************/

class OceanException: Exception
{
    /***************************************************************************

        This alias

    ***************************************************************************/

    public              alias typeof(this)              This;


    /***************************************************************************

        Shared Layout instance - used repeatedly in the Warn() method

    ***************************************************************************/

    private             static Layout!(char)            layout_instance;


    /***************************************************************************

        Trace Log File Location

    ***************************************************************************/

    private             static Logger                   logger;


    /***************************************************************************

        Default Logger Name

    ***************************************************************************/

    private             static char[]                   loggerName = "OceanException";


    /***************************************************************************

        Whether to output to console

    ***************************************************************************/

    public              static bool                     console_output = false;


    /***************************************************************************

        Constructor

        Params:
            msg = exception message

    ***************************************************************************/

    protected this (char[] msg)
    {
        super(msg);
    }


    /***************************************************************************

        Runs static method and catch exception

        This function should be called to invoke a static module, method or class
        that will be monitored and exception be written to a stdout or the defined
        appenders.

        ---

        Usage Example:

            class Module
            {
                public static bool run() { return true; }
            }

            OceanException.run(&Module.run);

        ---

        Params:
            func = static function to be called by OceanException
            ...  = any number of arguments to pass to the static function called

        Returns:
            true, if function was executed successfully

    ***************************************************************************/

    public static bool run( bool function(TypeInfo[] arguments, void* args) func, ... )
    {
        try
        {
            version(X86_64)
                assert (0, "Use va_ functions for varargs");
            return func(_arguments, _argptr);
        }
        catch (Exception e)
        {
            if ( OceanException.isAppender() )
            {
                OceanException.write(Logger.Level.Error, e.msg);
            }

            Trace.formatln(e.msg);
        }

        return true;
    }


    /***************************************************************************

        Runs static method and catch exception

        This function should be called to invoke a static module, method or class
        that will be monitored and exception be written to a stdout or the defined
        appenders.

        ---

        Usage Example:

            class Module
            {
                public static bool run(Arguments argument) { return true; }
            }

            OceanException.run(&Module.run, arguments);

        ---

        Params:
            func = static function to be called by OceanException
            ...  = any number of arguments to pass to the static function called

        Returns:
            true, if function was executed successfully

    ***************************************************************************/

    public static bool run( bool function(Tango.Arguments arguments) func,
            Tango.Arguments arguments )
    {
        try
        {
            return func(arguments);
        }
        catch (Exception e)
        {
            if ( OceanException.isAppender() )
            {
                OceanException.write(Logger.Level.Error, e.msg);
            }

            Trace.formatln(e.msg);
        }

        return true;
    }

    public static bool run( bool function(Arguments arguments) func,
            Arguments arguments )
    {
        try
        {
            return func(arguments);
        }
        catch (Exception e)
        {
            if ( OceanException.isAppender() )
            {
                OceanException.write(Logger.Level.Error, e.msg);
            }

            Trace.formatln(e.msg);
        }

        return true;
    }


    /***************************************************************************

        Runs static method and catch exception

        This function should be called to invoke a static module, method or class
        that will be monitored and exception be written to a stdout or the defined
        appenders.

        ---

        Usage Example:

            class Module
            {
                public static bool run() { return true; }
            }

            OceanException.run(&Module.run, arguments);

        ---

        Params:
            func = static function to be called by OceanException

        Returns:
            true, if function was executed successfully

    ***************************************************************************/

    public static bool run( bool function ( ) func )
    {
        try
        {
            return func();
        }
        catch (Exception e)
        {
            if ( OceanException.isAppender() )
            {
                OceanException.write(Logger.Level.Error, e.msg);
            }

            Trace.formatln(e.msg);
        }

        return true;
    }


    /***************************************************************************

        Runs static method and catch exception

        This function should be called to invoke a static module, method or class
        that will be monitored and exception be written to a stdout or the defined
        appenders.

        ---

        Usage Example:

            class Module
            {
                public bool run() { return true; }
            }

            OceanException.run(&Module.run);

        ---

        Params:
            func = static function to be called by OceanException

        Returns:
            true, if function was executed successfully

    ***************************************************************************/

    public static bool run( bool delegate() func )
    {
        try
        {
            return func();
        }
        catch (Exception e)
        {
            if ( OceanException.isAppender() )
            {
                OceanException.write(Logger.Level.Error, e.msg);
            }

            Trace.formatln(e.msg);
        }

        return true;
    }


    /***************************************************************************

        Throw Exception

        opCall is invoked by calling OceanException() statically. If there is an
        appender attached to OceanException that the message gets written to the
        appender.

        ---

        Usage Example:

            OceanException("Input Exception ...");

        ---

        Params:
            msg = error message

    ***************************************************************************/

    public static void opCall ( char[] msg )
    {
        if ( OceanException.isAppender() )
            OceanException.write(Logger.Level.Error, msg);

        throw new OceanException(msg);
    }


    /***************************************************************************

        Throws Critical Exception

        Throws exception and stops code execution immediately. This method has the
        same functionaly as by throwing a normal OceanException.

        ---

        Usage Example:

            OceanException.Critical("Input Exception ...");

        ---

        Params:
            msg = error message

    ***************************************************************************/

    public static void Critical ( char[] msg )
    {
        OceanException(msg);
    }


    /***************************************************************************

        Writes Warn Message

        Throws no exception and doesn't stops code execution.

        ---

        Usage Example:

            char[] message = "exception message";

            OceanException.Warn("Input Exception {}", message);

        ---

        Params:
            fmt = error message format string
            ... = arguments passed to include into formatting

    ***************************************************************************/

    public static void Warn ( char[] fmt, ... )
    {
        static char[] buffer;

        uint layoutSink ( char[] s )
        {
            buffer ~= s;
            return s.length;
        }

        synchronized
        {
            buffer.length = 0;
            This.layout.convert(&layoutSink, _arguments, _argptr, fmt);

            if ( OceanException.isAppender() )
            {
                OceanException.write(Logger.Level.Warn, buffer);
            }

            if (console_output)
            {
                Trace.formatln("OceanException.Warn: {}", buffer);
            }
        }
    }


    /***************************************************************************

        Set Log Appender (output target)

        If the appender is not set exceptions are written to stdout. An appender
        can write exceptions to console, socket, mail or file.

        Params:
            appender = output to write to file, mail, socket or console

        Returns:
            true, if appender could be set

    ***************************************************************************/

    public static bool setOutput ( Appender ap )
    {
        try
        {
            OceanException.logger = Log.getLogger(OceanException.loggerName);

            ap.layout(new LayoutDate);
            OceanException.logger.add(ap);
            OceanException.logger.additive(false); // disable default console output

            return true;
        }
        catch (Exception e)
            OceanException(e.msg);

        return false;
    }


    /***************************************************************************

        Sets Logger Name

        Params:
            name = name of logger instance

    ***************************************************************************/

    public static void setLoggerName( char[] name )
    {
        OceanException.loggerName = name;
    }


    /***************************************************************************

        Returns Logger Instance

        Returns:
            logger instance

    ***************************************************************************/

    public static Logger getLogger ( )
    {
        return logger;
    }


    /***************************************************************************

        Write Exception to the attached Appender

        Params:
            msg = error message

    ***************************************************************************/

    private static void write( Level level, char[] msg  )
    {
        OceanException.logger.append(level, msg);
    }


    /***************************************************************************

        Returns if Appender is attached

        Returns:
            true, if appender is set

    ***************************************************************************/

    private static bool isAppender()
    {
        if ( OceanException.logger )
            return true;

        return false;
    }


    /***************************************************************************

        Gets an instance of the Layout class, shared by all methods of this
        class. A Layout is newed if one doesn't exist already.

        Returns:
            Layout instance

    ***************************************************************************/

    private static Layout!(char) layout ( )
    {
        if ( !This.layout_instance )
        {
            This.layout_instance = new Layout!(char);
        }

        return This.layout_instance;
    }
}
