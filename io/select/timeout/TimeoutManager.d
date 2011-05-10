/*******************************************************************************

    TODO

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.select.timeout.TimeoutManager;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.timeout.ExpiryRegistry;

private import ocean.core.ArrayMap;

private import ocean.io.select.model.ISelectClient;

private import tango.stdc.posix.sys.time: timeval, gettimeofday;

private import tango.time.Time : TimeSpan;

debug private import tango.util.log.Trace;



public class TimeoutManager : IExpiryRegistry
{
    /***************************************************************************

        Start time (microseconds since unix epoch start).

    ***************************************************************************/

    private ulong start_;

    
    /***************************************************************************

        Time now (microseconds since start time).

    ***************************************************************************/

    private ulong now_;


    /***************************************************************************

        EBTree storing expiry time of registred clients in terms of microseconds
        since the construction of this object (for direct comparison against
        this.now_).

    ***************************************************************************/

    private ExpiryList expiry_tree;


    /***************************************************************************

        Array map mapping from an expiry registration ( a node in the tree of
        expiry times) to an ISelectClient.

    ***************************************************************************/

    private alias ArrayMap!(ISelectClient, ExpiryItem) ExpiryToClient;

    private ExpiryToClient expiry_to_client;


    /***************************************************************************

        List of expired registrations. Used by the checkTimeouts() method.

    ***************************************************************************/

    private ExpiryRegistration[] expired_list;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.expiry_tree = new ExpiryList;
        this.expiry_to_client = new ExpiryToClient;

        this.start();
    }


    /***************************************************************************

        Updates the time now.

    ***************************************************************************/
    
    public void updateNow ( )
    {
        timeval now_timeval;
        gettimeofday(&now_timeval, null);
        
        this.now_ = this.timevalMicro(now_timeval) - this.start_;
    }
    
    
    /***************************************************************************

        Returns:
            the number of microseconds since this object was constructed

    ***************************************************************************/
    
    public ulong now ( )
    {
        if ( this.now_ == 0 )
        {
            this.updateNow();
        }
        
        return this.now_;
    }


    /***************************************************************************

        Registers a client with the timeout manager.

        Params:
            client = client to register

    ***************************************************************************/

    public void register ( ISelectClient client )
    {
        if ( client.expiry_registration.active )
        {
            this.unregister(client.expiry_registration);

            auto expiry_time = this.now + client.expiry_registration.timeout;

            client.expiry_registration.item = this.expiry_tree.add(expiry_time);
            client.expiry_registration.registry = this;
        }
        else
        {
            this.unregister(client.expiry_registration);
            client.expiry_registration.clear();
        }

        this.expiry_to_client.put(client.expiry_registration.item, client);
    }


    /***************************************************************************

        Registers an already registered client with the timeout manager, via a
        registration item. This ensures that the old registration item is
        removed.

        Params:
            expiry = registration item to re-register

    ***************************************************************************/

    public void reregister ( ref ExpiryRegistration expiry )
    {
        auto client = expiry.item in this.expiry_to_client;
        if ( client !is null )
        {
            this.register(*client);
        }
        else
        {
            this.unregister(expiry);
        }
    }


    /***************************************************************************

        Unregisters an already registered client with the timeout manager.
    
        Params:
            client = client to unregister
    
    ***************************************************************************/
    
    public void unregister ( ISelectClient client )
    {
        this.unregister(client.expiry_registration);
    }
    
    
    /***************************************************************************
    
        Unregisters an already registered client with the timeout manager, via a
        registration item.
        
        Params:
            expiry = registration item to unregister
    
    ***************************************************************************/
    
    public void unregister ( ExpiryRegistration expiry )
    {
        if ( expiry.item !is null )
        {
            this.expiry_tree.remove(expiry.item);
            this.expiry_to_client.remove(expiry.item);
        }
    }


    /***************************************************************************

        Tells whether a client has timed out.
    
        Returns:
            true if the client is registered and its expiry time is before or
            equal to now, false otherwise
    
    ***************************************************************************/
    
    public bool timedOut ( ISelectClient client )
    {
        if ( client.expiry_registration.item !is null )
        {
            return client.expiry_registration.item.key < this.now;
        }
        else
        {
            return false;
        }
    }


    /***************************************************************************

        Gets the a timeout value to pass into an epoll selector.

        Returns:
            TimeSpan value with a timeout up to the nearest expiry time of all
            registered clients

    ***************************************************************************/

    public TimeSpan getTimeout ( )
    out ( timespan )
    {
        assert(timespan.ticks >= 0, typeof(this).stringof ~ ".timeout: negative timeout!");
    }
    body
    {
        TimeSpan timeout = TimeSpan.max; // no timeout

        if ( this.expiry_tree.length )
        {
            timeout = TimeSpan.fromMicros(this.expiry_tree.first - this.now);
        }

        return timeout;
    }


    /***************************************************************************

        Checks for expired clients. First the now time is updated, then the
        timeout() method of any expired clients is called. Expired clients are
        also removed from the expiry registry.

    ***************************************************************************/

    public void checkTimeouts ( )
    {
        this.updateNow();

        this.expired_list.length = 0;
        foreach ( client; this.timedOutClients )
        {
            client.timeout();
            this.expired_list ~= client.expiry_registration;
        }

        foreach ( expired; this.expired_list )
        {
            this.unregister(expired);
        }
    }


    /***************************************************************************

        Updates the start time.
    
    ***************************************************************************/
    
    private void start ( )
    {
        timeval start_timeval;
        gettimeofday(&start_timeval, null);
        this.start_ = this.timevalMicro(start_timeval);
    }
    
    
    /***************************************************************************

        Converts from a timeval to the number of microseconds since the start of
        the unix epoch.

        Params:
            tv = timeval to convert

        Returns:
            the number of microseconds since the start of the unix epoch, as
            defined by the passed timeval

    ***************************************************************************/

    private ulong timevalMicro ( timeval tv )
    {
        return tv.tv_sec * 1000_000UL + tv.tv_usec;
    }


    /***************************************************************************

        Returns:
            an iterator over all clients whose expiry is <= the time now

    ***************************************************************************/

    private ExpiredIterator timedOutClients ( )
    {
        ExpiredIterator it;
        it.outer = this;
        it.now = this.now;
        return it;
    }


    /***************************************************************************

        Iterator over expired clients.

    ***************************************************************************/

    struct ExpiredIterator
    {
        TimeoutManager outer;
        uint now;

        int opApply ( int delegate ( ref ISelectClient ) dg )
        {
            int ret;

            foreach ( token, expire_time; this.outer.expiry_tree.lessEqual(now) )
            {
                auto client = token in this.outer.expiry_to_client;
                assert(client !is null);

                if ( client )
                {
                    ret = dg(*client);
                    if ( ret ) break;
                }
            }

            return ret;
        }
    }
}

