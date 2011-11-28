/******************************************************************************

    Extended IAdvancedSelectClient with per-client timeout capabilities. For use
    with ocean.io.select.TimeoutEpollSelector.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman

******************************************************************************/

module ocean.io.select.model.ITimeoutSelectClient;



/******************************************************************************

    Imports

******************************************************************************/

private import ocean.io.select.model.ISelectClient;

private import ocean.io.select.timeout.ExpiryRegistry;

debug private import ocean.util.log.Trace;



/******************************************************************************

    IAdvancedTimeoutSelectClient abstract class

    Note that the advanced select client is extended here. If a timeout capable
    base select client is needed, an extension of that class could also be
    added, though it would need to be a separate class.

******************************************************************************/

abstract class IAdvancedTimeoutSelectClient : IAdvancedSelectClient
{
    /**************************************************************************
    
        Instance of expiry registration struct -- used to register this client
        with a timeout / expiry registry, and to keep track of this client's
        timeout values.
    
     **************************************************************************/
    
    public ExpiryRegistration expiry_registration;
    
    /**************************************************************************
    
        Constructor
        
        Params:
            conduit_     = I/O device instance
    
     **************************************************************************/

    protected this ( ISelectable conduit_ )
    {
        super(conduit_);
    }

    /***************************************************************************
    
        Sets the timeout in ms.
    
        The timeout represents the time before which the select client should be
        completed. (This is not that same as a socket timeout, where the timout
        value represents the maximum time before which the socket should have
        seen activity.) If the client has not finished within the specified
        time, its tomeout() method is called and it is unregistered from the
        select dispatcher.
    
        Note: this method accepts timeout values as an int, as this is what the
        epoll_wait function (called in tango.io.selector.EpollSelector) expects.
    
        Params:
            ms = new timeout in ms (< 0 means timeout is disabled)
    
        Returns:
            this instance
    
     **************************************************************************/
    
    override public typeof(this) setTimeout ( int ms )
    {
        if ( ms >= 0 )
        {
            this.expiry_registration.setTimeout(ms * 1000);
        }
        else
        {
            this.expiry_registration.disableTimeout();
        }
    
        return this;
    }
}

