/*******************************************************************************

    Arguments extension to refuse startup of the process if run as root.

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    authors:        Mathias Baumann

*******************************************************************************/

module ocean.util.app.ext.RefuseRootExt;

import ocean.util.app.ext.model.IArgumentsExtExtension;
import tango.stdc.posix.unistd;

/*******************************************************************************

    Arguments extension that refuses to start if the program is run as root.
    Behavior can be overridden by specifying --asroot

*******************************************************************************/

class RefuseRootExt : IArgumentsExtExtension
{  
    /***************************************************************************

        Order doesn't matter, so return default -> 0

    ***************************************************************************/
      
    int order ()
    {
        return 0;
    }
    
    /***************************************************************************

        Function executed when command line arguments are set up (before
        parsing).

        Params:
            app = application instance
            args = command line arguments instance

    ***************************************************************************/

    void setupArgs ( IApplication app, Arguments args )
    {
        args("asroot").params(0).help("Run as root");
    }


    /***************************************************************************

        Function executed after parsing the command line arguments.

        This function is only called if the arguments are valid so far.

        Params:
            app = application instance
            args = command line arguments instance

        Returns:
            string with an error message if validation failed, null otherwise

    ***************************************************************************/

    char[] validateArgs ( IApplication app, Arguments args )
    {
        if ( getuid() == 0 && !args.exists("asroot"))
        {        
            return "Won't run as root! (use --asroot if you really need to do this)";
        }
        else
        {
            return null;
        }
    }


    /***************************************************************************

        Function executed after (successfully) validating the command line
        arguments.
    
        Exists to satisfy the interface.

        Params:
            app = application instance
            args = command line arguments instance

    ***************************************************************************/

    void processArgs ( IApplication app, Arguments args ) {}
}

