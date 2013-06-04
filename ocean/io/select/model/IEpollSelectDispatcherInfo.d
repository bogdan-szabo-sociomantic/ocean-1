/*******************************************************************************

    Copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    Version:        2013-06-04: Initial release

    Authors:        Gavin Norman

    Informational interface to an EpollSelectDispatcher instance.

*******************************************************************************/

module ocean.io.select.model.IEpollSelectDispatcherInfo;



public interface IEpollSelectDispatcherInfo
{
    size_t num_registered ( );
}

