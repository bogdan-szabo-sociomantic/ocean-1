/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        Gavin Norman

    Interface for a SelectListener which can be safely used externally to
    retrieve information about the listener's status.

*******************************************************************************/

module ocean.io.select.model.ISelectListenerInfo;



interface ISelectListenerInfo
{
    /**************************************************************************

        Returns:
             the number of active connections being handled
    
     **************************************************************************/

    public size_t numOpenConnections ( );
}

