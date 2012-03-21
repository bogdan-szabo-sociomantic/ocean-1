/*******************************************************************************

    Interface for Application extensions.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.model.IApplicationExtension;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.ExitException : ExitException;
public import ocean.util.app.Application : Application;

private import ocean.util.app.model.IExtension;



/*******************************************************************************

    Interface for Application extensions.

*******************************************************************************/

interface IApplicationExtension : IExtension
{

    /***************************************************************************

        Function executed before the program runs.

        Params:
            app = the application instance that will run
            args = command line arguments used to invoke the application

    ***************************************************************************/

    void preRun ( Application app, char[][] args );


    /***************************************************************************

        Function executed after the program runs.

        This will only be called if the program runs completely and the
        Application.exit() method was not called.

        Params:
            app = the application instance that will run
            args = command line arguments used to invoke the application
            status = exit status returned by the application

    ***************************************************************************/

    void postRun ( Application app, char[][] args, int status );


    /***************************************************************************

        Function executed at program exit.

        This is function is executed always just before the program exits, no
        matter if Application.exit() was called or not. This function can be
        useful to do application cleanup that's always needed.

        Params:
            app = the application instance that will run
            args = command line arguments used to invoke the application
            status = exit status returned by the application
            exception = exit exception instance, if one was thrown (null
                        otherwise)

        Returns:
            new exit exception to use when the program exits (can be modified by
            other extension though)

    ***************************************************************************/

    void atExit ( Application app, char[][] args, int status,
            ExitException exception );


    /***************************************************************************

        Function executed if (and only if) an ExitException was thrown.

        It can change the ExitException to change how the program will exit.

        Params:
            app = the application instance that will run
            args = command line arguments used to invoke the application
            exception = current exit exception that will be used to exit

        Returns:
            new exit exception to use when the program exits (can be modified by
            other extension though)

    ***************************************************************************/

    ExitException onExitException ( Application app, char[][] args,
            ExitException exception );

}

