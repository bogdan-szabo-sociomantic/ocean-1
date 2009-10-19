/*******************************************************************************

    Ocean Exception Handling Template

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Jan 2009: Initial release

    authors:        Lars Kirchhoff
                    Thomas Nicolai

    Basic Exception handling template for use in modules and projects. The
    Exception template can be used as extension for custom routines to redirect
    error messages to files or command line via a Logger Interface.

    ---

    Exception Console Output Usage Example:

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

        The example shows how to catch OceanException thrown by some part of
        your code. The highest catch is going to print your exception to the
        screen. In case you dont use a catch statement at the end your
        message just gets printed on stdout and the code exits at this stage.

    ---

    Exception File Logging Usage Example:

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


        The example shows on how to use OceanExeption in combination with a log
        file. To set it up you need to include the proper Appender from
        tango.util.log. You have the choice between a file, socket, mail and
        console appender. This appender just get passed to OceanExeption at the
        beginning of your code.

    ---

*******************************************************************************/

module      ocean.util.OceanException;

private     import      tango.util.Arguments;

private     import      tango.util.log.Log, tango.util.log.LayoutDate;

private     import      tango.io.Stdout;


/*******************************************************************************

    OceanException

*******************************************************************************/

class OceanException: Exception
{

    /**
     * logger
     */
    private static Logger logger;

    /**
     * default logger name
     */
    private static char[] logger_name = "OceanException";


    /**
     * Protected Construtor
     *
     * Params:
     *     msg = exception message
     */
    protected this (char[] msg)
    {
        super(msg);
    }



    /**
     * Runs and catches exceptions from static method executed
     *
     * This function should be called to invoke a static module, method or class that
     * will be monitored and exception be written to a stdout or the defined appenders.
     *
     * ---
     *
     *   Usage:
     *
     *   class Module
     *   {
     *      public static bool run() { return true; }
     *   }
     *
     *   OceanException.run(&Module.run);
     *
     * ---
     *
     * Params:
     *     func = static function to be called by OceanException
     *     ...  = any number of arguments to pass to the static function called
     *
     * Returns:
     *     true, if function was executed successfully
     */
    public static bool run( bool function(TypeInfo[] arguments, void* args) func, ... )
    {
        try
        {
            return func(_arguments, _argptr);
        }
        catch (Exception e)
        {
            if ( OceanException.isAppender() )
                OceanException.write(Logger.Level.Error, e.msg);

            Stdout.formatln(e.msg).flush;
        }

        return true;
    }
    
    
    /**
     * Runs and catches exceptions from static method executed
     *
     * This function should be called to invoke a static module, method or class that
     * will be monitored and exception be written to a stdout or the defined appenders.
     *
     * ---
     *
     *   Usage:
     *
     *   class Module
     *   {
     *      public static bool run(Arguments argument) { return true; }
     *   }
     *
     *   OceanException.run(&Module.run, arguments);
     *
     * ---
     *
     * Params:
     *     func = static function to be called by OceanException
     *     ...  = any number of arguments to pass to the static function called
     *
     * Returns:
     *     true, if function was executed successfully
     */
    public static bool run( bool function(Arguments arguments) func, Arguments arguments )
    {
        try
        {
            return func(arguments);
        }
        catch (Exception e)
        {
            if ( OceanException.isAppender() )
                OceanException.write(Logger.Level.Error, e.msg);

            Stdout.formatln(e.msg).flush;
        }

        return true;
    }
    
    
    /**
     * Runs and catches exceptions from static method executed
     *
     * This function should be called to invoke a static module, method or class that
     * will be monitored and exception be written to a stdout or the defined appenders.
     *
     * ---
     *
     *   Usage:
     *
     *   class Module
     *   {
     *      public static bool run() { return true; }
     *   }
     *
     *   OceanException.run(&Module.run);
     *
     * ---
     *
     * Params:
     *     func = static function to be called by OceanException
     *
     * Returns:
     *     true, if function was executed successfully
     */
    public static bool run( bool function ( ) func )
    {
        try
        {
            return func();
        }
        catch (Exception e)
        {
            if ( OceanException.isAppender() )
                OceanException.write(Logger.Level.Error, e.msg);

            Stdout.formatln(e.msg).flush;
        }

        return true;
    }
    

    /**
     * Runs and catches exceptions from non-static method executed
     *
     * This function should be called to invoke a non-static module, method or class that
     * will be monitored and exception be written to a stdout or the defined appenders.
     *
     * ---
     *
     *   Usage:
     *
     *   class Module
     *   {
     *      public bool run() { return true; }
     *   }
     *
     *   OceanException.run(&Module.run);
     *
     * ---
     *
     * Params:
     *     func = static function to be called by OceanException
     *
     * Returns:
     *     true, if function was executed successfully
     */
    public static bool run( bool delegate() func )
    {
        try
        {
            return func();
        }
        catch (Exception e)
        {
            if ( OceanException.isAppender() )
                OceanException.write(Logger.Level.Error, e.msg);

            Stdout.formatln(e.msg).flush;
        }

        return true;
    }


    /**
     * Throw ocean exception
     *
     * opCall is invoked by calling OceanException() statically. If there is an appender
     * attached to OceanException that the message gets written to the appender.
     *
     * ---
     *
     * Usage example:
     *
     *      OceanException("Input Exception ...");
     *
     * ---
     * Params:
     *     msg = error message
     */
    public static void opCall( char[] msg )
    {
        if ( OceanException.isAppender() )
            OceanException.write(Logger.Level.Error, msg);

        throw new OceanException(msg);
    }



    /**
     * Throw exception and stops code execution immediately
     *
     * This method has the same functionaly as by throwing a normal OceanException.
     *
     * Params:
     *     msg = error message
     */
    public static void Critical( char[] msg )
    {
        OceanException(msg);
    }



    /**
     * Throws exception without stoping code execution
     *
     * Params:
     *     msg = error message
     */
    public static void Warn( char[] msg )
    {
        if ( OceanException.isAppender() )
            OceanException.write(Logger.Level.Warn, msg);
        else
            Stdout.formatln("{}", msg).flush;
    }



    /**
     * Set Log appender (output target)
     *
     * If appender is not set exceptions are written to stdout. An appender can write
     * exceptions to console, socket, mail or file.
     *
     * Params:
     *     appender = output to write to file, mail, socket or console
     * Returns:
     *      true, if appender could be set
     */
    public static bool setOutput ( Appender ap )
    {
        try
        {
            OceanException.logger = Log.getLogger(OceanException.logger_name);

            ap.layout(new LayoutDate);
            OceanException.logger.add(ap);

            return true;
        }
        catch (Exception e)
            OceanException(e.msg);

        return false;
    }
    


    /**
     * Sets the OceanException Logger Name
     *
     * Params:
     *     name = name of logger instance
     */
    public static void setLoggerName( char[] name )
    {
        OceanException.logger_name = name;
    }

    
    
    /**
     * Returns the logger
     * 
     * Returns:
     *  the logger
     */
    public static Logger getLogger ( )
    {
        return logger;
    }
    
    
    
    /**
     * Write exception to attached appender
     *
     * Params:
     *     msg = error message
     */
    private static void write( Level level, char[] msg  )
    {
        OceanException.logger.append(level, msg);
    }



    /**
     * Checks if appender is attached
     *
     * Returns:
     *      true, if appender is set
     */
    private static bool isAppender()
    {
        if ( OceanException.logger )
            return true;

        return false;
    }


} // OceanException

