/*******************************************************************************

    Copyright:      Copyright (C) 2014 sociomantic labs. All rights reserved

    Interface for SelectedKeysHandler.

*******************************************************************************/

module ocean.io.select.selector.model.ISelectedKeysHandler;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.sys.Epoll: epoll_event_t;

/******************************************************************************/

interface ISelectedKeysHandler
{
    /***************************************************************************

        Handles the clients in selected_set.

        Params:
            selected_set = the result list of epoll_wait()

    ***************************************************************************/

    void opCall ( epoll_event_t[] selected_set );
}
