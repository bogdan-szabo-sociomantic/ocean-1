/*******************************************************************************

    Exception to raise to safely exit the program.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ExitException;


/*******************************************************************************

    Imports

*******************************************************************************/

import tango.transition;


/*******************************************************************************

    Exception to raise to safely exit the program.

    Should usually be used via Application.exit().

*******************************************************************************/

public class ExitException : Exception
{

    /***************************************************************************

        Exit status to return to the OS at exit.

    ***************************************************************************/

    int status;


    /***************************************************************************

        Exit exception constructor.

        Params:
            status = exit status to return to the OS at exit
            msg = optional message to show just before exiting

    ***************************************************************************/

    this ( int status, istring msg = null )
    {
        super(msg);
        this.status = status;
    }

}
