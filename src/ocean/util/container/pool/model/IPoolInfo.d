/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        15/08/2012: Initial release

    authors:        Gavin Norman

    Informational interface to an object pool, which only provides methods to
    get info about the state of the pool, no methods to modify anything.

*******************************************************************************/

module ocean.util.container.pool.model.IPoolInfo;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.pool.model.IFreeList;
import ocean.util.container.pool.model.ILimitable;



public interface IPoolInfo : IFreeListInfo, ILimitableInfo
{
    /**************************************************************************

        Returns the number of items in pool.

        Returns:
            the number of items in pool

     **************************************************************************/

    size_t length ( );

    /**************************************************************************

        Returns the number of busy items in pool.

        Returns:
            the number of busy items in pool

     **************************************************************************/

    size_t num_busy ( );
}
