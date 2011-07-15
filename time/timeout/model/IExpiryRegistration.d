/*******************************************************************************

    Interface for the timeout manager expiry registration object in the
    ISelectClient.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2011: Initial release

    author:         David Eckardt
    
*******************************************************************************/

module ocean.time.timeout.model.IExpiryRegistration;

private import ocean.time.timeout.model.ITimeoutClient;

interface IExpiryRegistration : ITimeoutClient
{
    /***************************************************************************

        Sets the timeout for the client and registers it with the timeout
        manager. On timeout the client will automatically be unregistered.
        The client must not currently be registered.
        
        Params:
            timeout_us = timeout in microseconds from now. 0 is ignored.
            
        Returns:
            true if registered or false if timeout_us is 0.
        
    ***************************************************************************/

    bool register ( ulong timeout_us );
    
    /***************************************************************************

        Unregisters the current client.
        If a client is currently not registered, nothing is done.
        
        Must not be called from within timeout().
        
        Returns:
            true on success or false if no client was registered.
        
    ***************************************************************************/

    bool unregister ( );
    
    /***************************************************************************

        Returns:
            true if the client has timed out or false otherwise.
    
    ***************************************************************************/

    bool timed_out ( );
}
