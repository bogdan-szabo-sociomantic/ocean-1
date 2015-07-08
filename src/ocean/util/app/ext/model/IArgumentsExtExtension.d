/*******************************************************************************

    Extension for the ArgumentsExt Application extension.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.model.IArgumentsExtExtension;



/*******************************************************************************

    Imports

*******************************************************************************/

import tango.transition;

public import ocean.util.app.model.IApplication;
public import ocean.text.Arguments : Arguments;

import ocean.util.app.model.IExtension;



/*******************************************************************************

    Interface for extensions for the ArgumentsExt Application extension.

*******************************************************************************/

interface IArgumentsExtExtension : IExtension
{

    /***************************************************************************

        Function executed when command line arguments are set up (before
        parsing).

        Params:
            app = application instance
            args = command line arguments instance

    ***************************************************************************/

    void setupArgs ( IApplication app, Arguments args );


    /***************************************************************************

        Function executed after parsing the command line arguments.

        This function is only called if the arguments are valid so far.

        Params:
            app = application instance
            args = command line arguments instance

        Returns:
            string with an error message if validation failed, null otherwise

    ***************************************************************************/

    cstring validateArgs ( IApplication app, Arguments args );


    /***************************************************************************

        Function executed after (successfully) validating the command line
        arguments.

        Params:
            app = application instance
            args = command line arguments instance

    ***************************************************************************/

    void processArgs ( IApplication app, Arguments args );

}
