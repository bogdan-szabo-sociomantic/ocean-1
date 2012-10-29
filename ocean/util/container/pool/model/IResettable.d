/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        15/08/2012: Initial release

    authors:        Gavin Norman

    TODO: description of module

*******************************************************************************/

module ocean.util.container.pool.model.IResettable;



/*******************************************************************************

    Interface for pool items that offer a reset method. For each object stored
    in the object pool which implements this interface reset() is called when
    it is recycled or removed.

*******************************************************************************/

public interface Resettable
{
    void reset ( );
}

