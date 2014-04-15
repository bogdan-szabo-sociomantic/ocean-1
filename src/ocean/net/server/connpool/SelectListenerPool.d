/*******************************************************************************

    Copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    Version:        2013-07-19: Initial release

    Authors:        Gavin Norman

    The pool of connections handled by a SelectListener.

*******************************************************************************/

module ocean.net.server.connpool.SelectListenerPool;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.net.server.connpool.ISelectListenerPoolInfo;

private import ocean.net.server.connection.IConnectionHandler;

private import ocean.util.container.pool.ObjectPool : AutoCtorPool;



/*******************************************************************************

    SelectListenerPool class template.

    Extends AutoCtorPool with the additional methods demanded by
    ISelectListenerPoolInfo.

    The additional T constructor argument parameters must appear after those for
    the mandatory IConnectionHandler constructor.

    Template params:
        T    = connection handler class
        Args = additional constructor arguments for T

*******************************************************************************/

public class SelectListenerPool ( T, Args ... ) :
    AutoCtorPool!(T, IConnectionHandler.FinalizeDg, Args), ISelectListenerPoolInfo
{
    /***************************************************************************

        Constructor.

        Params:
            finalize_dg = delegate for a connection to call when finished
                (should recycle it into this pool)
            args = T constructor arguments to be used each time an
                   object is created

    ***************************************************************************/

    public this ( IConnectionHandler.FinalizeDg finalize_dg, Args args )
    {
        super(finalize_dg, args);
    }


    /***************************************************************************

        foreach iterator over informational interfaces to the active connections
        in the pool.

    ***************************************************************************/

    public int opApply ( int delegate ( ref IConnectionHandlerInfo ) dg )
    {
        int ret;
        scope it = this.new BusyItemsIterator;
        foreach ( conn; it )
        {
            auto conn_info = cast(IConnectionHandlerInfo)conn;
            ret = dg(conn_info);
            if ( ret ) break;
        }
        return ret;
    }


    /***************************************************************************

        foreach iterator over informational interfaces to the active connections
        in the pool, and their indices.

    ***************************************************************************/

    public int opApply ( int delegate ( ref size_t, ref IConnectionHandlerInfo ) dg )
    {
        int ret;
        scope it = this.new BusyItemsIterator;
        foreach ( i, conn; it )
        {
            auto conn_info = cast(IConnectionHandlerInfo)conn;
            ret = dg(i, conn_info);
            if ( ret ) break;
        }
        return ret;
    }


    /***************************************************************************

        IPoolInfo method, wrapper to super class implementation.

        Returns:
            limit of items in pool

    ***************************************************************************/

    public uint limit ( )
    {
        return super.limit();
    }


    /***************************************************************************

        IPoolInfo method, wrapper to super class implementation.

        Returns:
            true if the number of items in the pool is limited or fase otherwise

    ***************************************************************************/

    public bool is_limited ( )
    {
        return super.is_limited();
    }
}

