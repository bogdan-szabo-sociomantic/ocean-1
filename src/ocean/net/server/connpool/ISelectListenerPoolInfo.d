/*******************************************************************************

    Copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    Version:        2013-07-19: Initial release

    Authors:        Gavin Norman

    Informational (i.e. non-destructive) interface to a select listener
    connection pool.

*******************************************************************************/

module ocean.net.server.connpool.ISelectListenerPoolInfo;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.net.server.connection.IConnectionHandlerInfo;

import ocean.util.container.pool.model.IPoolInfo;



public interface ISelectListenerPoolInfo : IPoolInfo
{
    /***************************************************************************

        Convenience alias for implementing classes.

    ***************************************************************************/

    alias .IConnectionHandlerInfo IConnectionHandlerInfo;


    /***************************************************************************

        foreach iterator over informational interfaces to the active connections
        in the pool.

    ***************************************************************************/

    int opApply ( int delegate ( ref IConnectionHandlerInfo ) dg );


    /***************************************************************************

        foreach iterator over informational interfaces to the active connections
        in the pool, and their indices.

    ***************************************************************************/

    int opApply ( int delegate ( ref size_t, ref IConnectionHandlerInfo ) dg );
}

