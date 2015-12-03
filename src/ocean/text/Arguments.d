/*******************************************************************************

    Command line arguments parser with automatic help text output

    copyright:      Copyright (c) 2010-2012 sociomantic labs. All rights reserved

    version:        October 2010: Initial release

    authors:        Gavin Norman, Leandro Lucarella

    This module extends the 'tango.text.Arguments' module.

    Usage example:

    ---

        void main ( istring[] cmdl )
        {
            // Parse command line args
            scope args = new Arguments(cmdl[0],
                    "Test ocean's Arguments parser",
                    "{0} [OPTIONS]",
                    "This program test the ocean's Argument parser. It takes "
                    "no positional arguments but can take several options.");

            args("help").aliased('?').aliased('h').help("display this help");
            args("start").aliased('s').help("start of range to query (hash value - defaults to 0x00000000)");
            args("end").aliased('e').help("end of range to query (hash value - defaults to 0xFFFFFFFF)");
            args("channel").aliased('c').help("channel name to query");
            args("all_channels").aliased('A').help("query all channels");

            args.parse(cmdl[1..$]);

            args.displayHelp(Stdout);
        }

    ---

    Running the above code writes the following to Stderr:

     ./NAME command line arguments:
       -s,     --start         start of range to query (hash value - defaults to 0x00000000)
       -e,     --end           end of range to query (hash value - defaults to 0xFFFFFFFF)
       -h, -?, --help          display this help
       -c,     --channel       channel name to query
       -A,     --all_channels  query all channels

*******************************************************************************/

module ocean.text.Arguments;



/*******************************************************************************

    Imports

*******************************************************************************/

import tango.transition;

import Tango = tango.text.Arguments;

import tango.io.Stdout;

import tango.math.Math : max;

import Integer = tango.text.convert.Integer;




/*******************************************************************************

    Arguments class.

    Derives from tango.text.Arguments, and adds a displayHelp() method.

*******************************************************************************/

class Arguments : Tango.Arguments
{
    /***************************************************************************

        Initializes the Arguments

        Params:
            name = Name of the application (to show in the help message)
            desc = Short description of what the program does (should be
                         one line only, preferably less than 80 characters)
            usage = How the program is supposed to be invoked
            help = Long description of what the program does and how to use it

    ***************************************************************************/

    public this ( istring app_name = null, istring desc = null,
            istring usage = null, istring help = null )
    {
        super(app_name, desc, usage, help);
    }
}

