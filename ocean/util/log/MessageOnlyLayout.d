/*******************************************************************************

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    version:        1/10/2013: Initial release

    authors:        Ben Palmer

    A log layout that only displays the message and no extra data such as the
    date, level, etc

*******************************************************************************/

module ocean.util.log.MessageOnlyLayout;



/*******************************************************************************

    Imports

*******************************************************************************/

private import  tango.util.log.Log;



/*******************************************************************************

        A layout with only the message

*******************************************************************************/

public class MessageOnlyLayout : Appender.Layout
{
    /***************************************************************************

        Constructor

    ***************************************************************************/

    this ( )
    {
    }

    /***************************************************************************

        Subclasses should implement this method to perform the
        formatting of the actual message content.

    ***************************************************************************/

    void format (LogEvent event, size_t delegate(void[]) dg)
    {
        dg (event.toString);
    }

}

