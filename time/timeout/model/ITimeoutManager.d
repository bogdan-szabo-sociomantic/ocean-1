/*******************************************************************************

    Interface for the timeout manager internals accessor object in the expiry
    registration.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2011: Initial release

    author:         David Eckardt
    
*******************************************************************************/

module ocean.time.timeout.model.ITimeoutManager;

interface ITimeoutManager
{
    /***************************************************************************
    
        Tells the wall clock time time when the next client will expire.
        
        Returns:
            the wall clock time when the next client will expire as UNIX time
            in microseconds or ulong.max if no client is currently registered.
    
    ***************************************************************************/

    ulong next_expiration_us ( );
    
    /***************************************************************************
    
        Tells the time until the next client will expire.
        
        Returns:
            the time left until next client will expire in microseconds or
            ulong.max if no client is currently registered. 0 indicates that
            there are timed out clients that have not yet been notified and
            unregistered.
    
    ***************************************************************************/

    ulong us_left ( );
    
    /***************************************************************************
    
        Checks for timed out clients. For any expired client its timeout()
        method is called, then it is unregistered.
        
        This method should be called when the time reported by
        next_expiration_us or us_left has expired.
        
        Returns:
            the number of expired clients.
        
    ***************************************************************************/
    
    uint checkTimeouts ( );
}
