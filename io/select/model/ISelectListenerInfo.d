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


    /**************************************************************************

        Increments the count of received bytes by the specified amount.
    
        Params:
            bytes = number of bytes received
    
     **************************************************************************/
    
    public void receivedBytes ( size_t bytes );

    
    /**************************************************************************
    
        Increments the count of sent bytes by the specified amount.
    
        Params:
            bytes = number of bytes sent
    
     **************************************************************************/
    
    public void sentBytes ( size_t bytes );


    /**************************************************************************
    
        Returns:
            number of bytes received
    
     **************************************************************************/
    
    public ulong bytesReceived ( );


    /**************************************************************************
    
        Returns:
            number of bytes sent
    
     **************************************************************************/
    
    public ulong bytesSent ( );


    /**************************************************************************
    
        Resets the count of received and sent bytes.
    
     **************************************************************************/
    
    public void resetByteCounters ( );
}

