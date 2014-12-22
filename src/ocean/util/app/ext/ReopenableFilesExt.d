/*******************************************************************************

    Copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    Set of files which are reopened upon calling the reopenAll() method. The
    extension cooperates with the SignalExt, allowing the registered set of
    files to be reopened when a specific signal is received by the application.
    The constructor provides a convenient means to configure this behaviour.

*******************************************************************************/

module ocean.util.app.ext.ReopenableFilesExt;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.app.model.IApplication;
import ocean.util.app.model.IApplicationExtension;

import ocean.util.app.ext.SignalExt;

import ocean.util.app.ext.model.ISignalExtExtension;

import tango.stdc.posix.signal : SIGHUP;

import tango.io.device.File;



public class ReopenableFilesExt : IApplicationExtension, ISignalExtExtension
{
    /***************************************************************************

        List of open files to be reopened when reopenAll() is called.

    ***************************************************************************/

    private File[] open_files;


    /***************************************************************************

        The code of the signal to trigger reopening the files, when used with
        the SignalExt. See onSignal().

    ***************************************************************************/

    private int reopen_signal;


    /***************************************************************************

        Constructor. Optionally registers this extension with the signal
        extension and activates the handling of the specified signal, which will
        cause the registered files to be reopened.

        Params:
            signal_ext = optional SignalExt instance to register with
            reopen_signal = if signal_ext is non-null, signal to trigger
                reopening of registered files

    ***************************************************************************/

    public this ( SignalExt signal_ext = null, int reopen_signal = SIGHUP )
    {
        if ( signal_ext )
        {
            this.reopen_signal = reopen_signal;
            signal_ext.register(this.reopen_signal);
            signal_ext.registerExtension(this);
        }
    }


    /***************************************************************************

        Registers the specified file, to be reopened when reopenAll() is called.

        Params:
            file = file to add to the set of reopenable files

    ***************************************************************************/

    public void register ( File file )
    {
        this.open_files ~= file;
    }


    /***************************************************************************

        Reopens all registered files.

    ***************************************************************************/

    public void reopenAll ( )
    {
        foreach ( file; this.open_files )
        {
            file.close();
            file.open(file.toString(), file.style);
        }
    }


    /***************************************************************************

        Signal handler. Called by SignalExt when a signal occurs. Reopens all
        log files.

        Params:
            signal = signal which fired

    ***************************************************************************/

    public void onSignal ( int signal )
    {
        if ( signal == this.reopen_signal )
        {
            this.reopenAll();
        }
    }


    /***************************************************************************

        Required by ISignalExtExtension.

        Returns:
            a number to provide ordering to extensions

    ***************************************************************************/

    override public int order ( )
    {
        return 0;
    }


    /***************************************************************************

        Unused IApplicationExtension method.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    override public void preRun ( IApplication app, char[][] args )
    {
        // Unused
    }


    /// ditto
    override public void postRun ( IApplication app, char[][] args, int status )
    {
        // Unused
    }


    /// ditto
    override public void atExit ( IApplication app, char[][] args, int status,
            ExitException exception )
    {
        // Unused
    }


    /// ditto
    override public ExitException onExitException ( IApplication app, char[][] args,
            ExitException exception )
    {
        // Unused
        return exception;
    }
}

