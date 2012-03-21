/*******************************************************************************

    ArgumentsExt extension to get a DHT node specification xml file name.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.DhtClientExt;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.app.Application;
private import ocean.util.app.ext.model.IArgumentsExtExtension;

private import ocean.text.Arguments;



/*******************************************************************************

    ArgumentsExt extension to get a DHT node specification xml file name.

    In the future it might add other common DHT client tasks, like doing
    the handshake.

*******************************************************************************/

class DhtClientExt : IArgumentsExtExtension
{

    /***************************************************************************

        Default source xml file name.

    ***************************************************************************/

    char[] default_source_file;


    /***************************************************************************

        Constructor.

        Params:
            default_source_file = default source xml file name

    ***************************************************************************/

    this ( char[] default_source_file = "etc/dhtmemory.xml" )
    {
        this.default_source_file = default_source_file;
    }


    /***************************************************************************

        Extension order. Use the default order as it should not be important for
        this extension.

    ***************************************************************************/

    public override int order ( )
    {
        return 0;
    }


    /***************************************************************************

        Adds a --source/-S option to get the xml file name.

    ***************************************************************************/

    public override void setupArgs ( Application app, Arguments args )
    {
        args("source").aliased('S').params(1).smush()
            .defaults(this.default_source_file)
            .help("use SOURCE nodes definition file (default: " ~
                this.default_source_file ~ ")");
    }


    /***************************************************************************

        Unused IArgumentsExtExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    char[] validateArgs ( Application app, Arguments args )
    {
        // Unused
        return null;
    }

    void processArgs ( Application app, Arguments args )
    {
        // Unused
    }

}

