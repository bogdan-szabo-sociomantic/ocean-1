/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Initial release: May 2004

        author:         Kris

*******************************************************************************/

deprecated module ocean.util.log.Config_tango;

public import ocean.util.log.Log : Log;

import ocean.util.log.LayoutDate,
       ocean.util.log.AppendConsole;

pragma(msg, "Set the root logger in your main file instead of relying on module ctor order");

/*******************************************************************************

        Utility for initializing the basic behaviour of the default
        logging hierarchy.

        Adds a default console appender with a generic layout to the
        root node, and set the activity level to be everything enabled

*******************************************************************************/

static this ()
{
        Log.root.add (new AppendConsole (new LayoutDate));
}

