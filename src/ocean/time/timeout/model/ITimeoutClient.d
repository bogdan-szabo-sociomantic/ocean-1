/*******************************************************************************

    Interface for a class whose instances can time out.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2011: Initial release

    author:         David Eckardt

*******************************************************************************/

module ocean.time.timeout.model.ITimeoutClient;

/******************************************************************************/

interface ITimeoutClient
{
    /***************************************************************************

        Invoked when the client times out.

    ***************************************************************************/

    void timeout ( );

    /***************************************************************************

        Identifier string for debugging.

    ***************************************************************************/

    debug char[] id ( );
}

