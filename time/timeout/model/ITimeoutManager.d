/*******************************************************************************

    Timeout manager interface

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2011: Initial release

    author:         David Eckardt
    
    The reason for this interface is to avoid requiring an application to be
    linked against the libebtree, which is required by TimeoutManager and
    ExpiryRegistration, when it uses a library module that supports a timeout
    functionality as an optional feature.
    Therefore, library modules that support a timeout functionality as an
    optional feature should always use this interface and not import
    TimeoutManager/ExpiryRegistration.

*******************************************************************************/

module ocean.time.timeout.model.ITimeoutManager;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.time.timeout.model.ITimeoutClient,
               ocean.time.timeout.model.IExpiryRegistration : ISelectExpiryRegistration;

/******************************************************************************/

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

interface ISelectTimeoutManager: ITimeoutManager
{
    /***************************************************************************
    
        Registers client with the timeout manager and returns the expiry
        registration object which the registered client is associated to.
        
        Note: Depending on the implementation, this method may return a newly
              created object that should be kept and reused by the application.
              It is also application dependent whether the client remains
              associated to the expiry registration object after it has been
              unregistered from the timeout manager or not.
        
        Params:
            client = client to register
            
        Returns:
            expiry registration object.
        
    ***************************************************************************/
    
    ISelectExpiryRegistration register ( ITimeoutClient client );
}
