/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        20/08/2012: Initial release

    authors:        Gavin Norman

    Application interface passed to methods of IApplicationExtension and others.

*******************************************************************************/

module ocean.util.app.model.IApplication;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.app.model.IApplicationExtension;



public interface IApplication : IApplicationExtension
{
    /***************************************************************************

        Returns:
            the name of the application

    ***************************************************************************/

    istring name ( );


    /***************************************************************************

        Exit cleanly from the application.

        Calling exit() will properly unwind the stack and all the destructors
        will be called. Should be used only from the main application thread
        though.

        Params:
            status = status code to return to the OS
            msg = optional message to show just before exiting

    ***************************************************************************/

    void exit ( int status, istring msg = null );
}
