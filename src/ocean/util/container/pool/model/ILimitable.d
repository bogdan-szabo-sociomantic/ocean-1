/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        14/09/2012: Initial release

    authors:        Gavin Norman

    Interfaces to manage and get information about a limitable pool. A limitable
    pool has a maximum size (i.e. number of items) which cannot be exceeded.

*******************************************************************************/

module ocean.util.container.pool.model.ILimitable;



/*******************************************************************************

    Informational interface to a limitable pool.

*******************************************************************************/

public interface ILimitableInfo
{
    /***************************************************************************

        Returns:
            limit of items in pool

    ***************************************************************************/

    uint limit ( );


    /***************************************************************************

        Returns:
            true if the number of items in the pool is limited or fase otherwise

    ***************************************************************************/

    bool is_limited ( );
}


/*******************************************************************************

    Management interface to a limitable pool.

*******************************************************************************/

public interface ILimitable : ILimitableInfo
{
    /**************************************************************************

        Magic limit value indicating no limitation

     **************************************************************************/

    const uint unlimited = uint.max;


    /***************************************************************************

        Sets the limit of number of items in pool or disables limitation for
        limit = unlimited. When limiting the pool, any excess idle items are
        reset and deleted.

        Params:
            limit = new limit of number of items in pool; unlimited disables
               limitation

        Returns:
            new limit

    ***************************************************************************/

    uint setLimit ( uint limit );
}

