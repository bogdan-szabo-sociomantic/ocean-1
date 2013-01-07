module ocean.util.app.ext.RefuseRootExt;

import ocean.util.app.ext.model.IArgumentsExtExtension;

class RefuseRootExt : IArgumentsExtExtension
{    
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
        if ( args.exists("asroot") ) return null;
        
        return "Won't run as root!";
    }


    /***************************************************************************

        Function executed after (successfully) validating the command line
        arguments.

        Params:
            app = application instance
            args = command line arguments instance

    ***************************************************************************/

    void processArgs ( IApplication app, Arguments args ) {}
}

