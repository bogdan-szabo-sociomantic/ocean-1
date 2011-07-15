/*******************************************************************************

    Manages ITimeoutClient instances where each one has an individual timeout
    value.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman, David Eckardt
    
    To use the timeout manager, create a TimeoutManager subclass capable of
    these two things:
        1. It implements setTimeout() to set a timer that expires at the wall
           clock time that is passed to setTimeout() as argument.
        2. When the timer is expired, it calls checkTimeouts().
    
    Objects that can time out, the so-called timeout clients, must implement
    ITimeoutClient. For each client create an ExpiryRegistration instance and
    pass the object to the ExpiryRegistration constructor.
    Call ExpiryRegistration.register() to set a timeout for the corresponding
    client. When checkTimeouts() is called, it calls the timeout() method of 
    each timed out client.
    
    
    Link with:
        -Llibebtree.a

*******************************************************************************/

module ocean.time.timeout.TimeoutManager;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.time.timeout.model.ITimeoutManager,
               ocean.time.timeout.model.ITimeoutClient,
               ocean.time.timeout.model.IExpiryRegistration,
               ocean.time.timeout.model.ExpiryRegistrationBase;                 // ExpiryTree, Expiry, ExpiryRegistrationBase

private import ocean.core.ArrayMap,
               ocean.core.AppendBuffer;

private import tango.stdc.posix.sys.time: timeval, gettimeofday;

debug
{
    private import tango.io.Stdout;
    private import tango.stdc.time: time_t, ctime;
    private import tango.stdc.string: strlen;
}

/*******************************************************************************

    Timeout manager

*******************************************************************************/

class TimeoutManager : TimeoutManagerBase, ISelectTimeoutManager
{
    /***************************************************************************

        Expiry registration class for an object that can time out.
    
    ***************************************************************************/
    
    public class ExpiryRegistration : ExpiryRegistrationBase, ISelectExpiryRegistration
    {
        /***********************************************************************
    
            Constructor
            
            Params:
                client = object that can time out
        
        ***********************************************************************/
    
        public this ( ITimeoutClient client )
        {
            super(this.outer.new TimeoutManagerInternal);
            super.client = client;
        }
        
        /***********************************************************************
    
            Sets the timeout for the client and registers it with the timeout
            manager. On timeout the client will automatically be unregistered.
            Use the unregister() super class method to manually unregister the
            client.
            
            Params:
                timeout_us = timeout in microseconds from now. 0 is ignored.
                
            Returns:
                true if registered or false if timeout_us 0.
                
            In:
                The client must not already be registered.
        
        ***********************************************************************/
    
        public override bool register ( ulong timeout_us )
        {
            return super.register(timeout_us);
        }
    }
    
    /***************************************************************************
    
        Creates a new expiry registration instance, associates client with it
        and registers client with this timeout manager.
        The returned object should be reused. The client will remain associated
        to the expiry registration after it has been unregistered from the
        timeout manager.
        
        Params:
            client = client to register
            
        Returns:
            new expiry registration object with client associated to.
        
    ***************************************************************************/

    public ISelectExpiryRegistration register ( ITimeoutClient client )
    {
        return this.new ExpiryRegistration(client);
    }
    
    /***********************************************************************
    
        Wrappers required to convince DMD that this class implements the
        ITimeoutManager interface.
        
        TODO: Is a newer DMD smart enough so that these wrappers can go? 
        
    ***********************************************************************/

    public override ulong next_expiration_us ( ) { return super.next_expiration_us; }
    public override ulong us_left            ( ) { return super.us_left;            }
    public override uint checkTimeouts       ( ) { return super.checkTimeouts;      }
}

/*******************************************************************************

    Timeout manager base class. Required for derivation because inside a
    TimeoutManager subclass a nested ExpiryRegistration subclass is impossible.

*******************************************************************************/

abstract class TimeoutManagerBase
{
    /***************************************************************************

        Enables IExpiryRegistration to access TimeoutManager internals. 
    
    ***************************************************************************/

    protected class TimeoutManagerInternal : ExpiryRegistrationBase.ITimeoutManagerInternal
    {
        /***********************************************************************

            Registers registration and sets the timeout for its client.
            
            Params:
                registration = IExpiryRegistration instance to register
                timeout_us   = timeout in microseconds from now
                
            Returns:    
                expiry token: required for unregister(); the "key" member is the
                wall clock time of expiration as UNIX time in microseconds.
        
        ***********************************************************************/

        Expiry register ( IExpiryRegistration registration, ulong timeout_us )
        {
            return this.outer.register(registration, timeout_us);
        }
        
        /***********************************************************************

            Unregisters IExpiryRegistration instance corresponding to expiry.
            
            Params:
                expiry = expiry token returned by register() when registering
                         the IExpiryRegistration instance to unregister
            
            In:
                Must not be called from within timeout().
            
        ***********************************************************************/

        void unregister ( Expiry expiry )
        {
            this.outer.unregister(expiry);
        }
        
        /***********************************************************************

            Returns:
                the current wall clock time as UNIX time in microseconds.
        
        ***********************************************************************/

        ulong now ( )
        {
            return this.outer.now();
        }
    }
    
    /***************************************************************************

        EBTree storing expiry time of registred clients in terms of microseconds
        since the construction of this object (for direct comparison against
        this.now_).

    ***************************************************************************/

    private ExpiryTree expiry_tree;


    /***************************************************************************

        Array map mapping from an expiry registration ( a node in the tree of
        expiry times) to an ISelectClient.

    ***************************************************************************/

    private ArrayMap!(IExpiryRegistration, Expiry) expiry_to_client;


    /***************************************************************************

        List of expired registrations. Used by the checkTimeouts() method.

    ***************************************************************************/

    private AppendBuffer!(IExpiryRegistration) expired_registrations;

    /***************************************************************************

        
    
    ***************************************************************************/

    private bool checking_timeouts = false;
    
    /***************************************************************************

        Constructor.

    ***************************************************************************/

    protected this ( )
    {
        this.expiry_tree = new ExpiryTree;
        this.expiry_to_client = new ArrayMap!(IExpiryRegistration, Expiry);
        this.expired_registrations = new AppendBuffer!(IExpiryRegistration);
    }


    /***************************************************************************
        
        Tells the wall clock time time when the next client will expire.
        
        Returns:
            the wall clock time when the next client will expire as UNIX time
            in microseconds or ulong.max if no client is currently registered.
    
    ***************************************************************************/
    
    public ulong next_expiration_us ( )
    out (us)
    {
        debug
        {
            if (us < us.max)
            {
                Stderr("no timeout");
            }
            else
            {
                Stderr("total timeout: ")(us)("µs");
            }
            
            Stderr('\n').flush();
        }
    }
    body
    {
        return this.expiry_tree.length? this.expiry_tree.first : ulong.max;
    }
    
    /***************************************************************************
        
        Tells the time left until the next client will expire.
        
        Returns:
            the time left until next client will expire in microseconds or
            ulong.max if no client is currently registered. 0 indicates that
            there are timed out clients that have not yet been notified and
            unregistered.
    
    ***************************************************************************/

    public ulong us_left ( )
    {
        if (this.expiry_tree.length)
        {
            ulong next_expiration_us = this.expiry_tree.first,
                  now                = this.now;
            
            return next_expiration_us > now? next_expiration_us - now : 0;
        }
        else
        {
            return ulong.max;
        }
    }
    
    /***************************************************************************

        Returns:
            the number of registered clients.
    
    ***************************************************************************/

    public size_t pending ( )
    {
        return this.expiry_tree.length;
    }
    
    /***************************************************************************
        
        Returns the current wall clock time. Calls gettimeofday() each time by
        default; may be overridden to use a more efficient implementation, e.g.
        using the IntervalClock.
        
        Returns:
            the current wall clock time as UNIX time value in microseconds.

    ***************************************************************************/
    
    public ulong now ( )
    {
        timeval tv;
        gettimeofday(&tv, null);
        return tv.tv_sec * 1000_000UL + tv.tv_usec;
    }
    
    /***************************************************************************
    
        Checks for expired clients. For any expired client its timeout() method
        is called, then it is unregistered.
        
        This method should be called when the timeout set by setTimeout() has
        expired.
        
        Returns:
            the number of expired clients.
        
    ***************************************************************************/
    
    public uint checkTimeouts ( )
    {
        this.expired_registrations.clear();
        
        debug
        {
            Stderr("--------------------- checkTimeouts at ");
            this.printTime();
        }
        
        try
        {
            ulong previously_next = this.next_expiration_us;
            
            bool pending;
            
            try 
            {
                this.checking_timeouts = true;
                
                foreach (expiry, expire_time; this.expiry_tree.lessEqual(this.now))
                {
                    IExpiryRegistration registration = this.expiry_to_client[expiry];
        
                    registration.timeout();
                    
                    this.expired_registrations ~= registration;
                }
            }
            finally
            {
                this.checking_timeouts = false;
                
                pending = this.expiry_tree.length != 0;
                
                if (pending)
                {
                    this.setTimeout_(previously_next);
                }
            }
            
            return this.expired_registrations.length;
        }
        finally foreach (ref registration; this.expired_registrations[])
        {
            registration.unregister();
            registration = null;
        }
    }

    /***************************************************************************

        Registers registration and sets the timeout for its client.
        
        Params:
            registration = IExpiryRegistration instance to register
            timeout_us   = timeout in microseconds from now
            
        Returns:    
            expiry token: required for unregister(); the "key" member is the
            wall clock time of expiration as UNIX time in microseconds.
    
    ***************************************************************************/
    
    protected Expiry register ( IExpiryRegistration registration, ulong timeout_us )
    {
        ulong t = this.now + timeout_us;
              
        ulong previously_next = this.next_expiration_us;
        
        debug
        {
            Stderr("----------- registered ")(registration.n)(" at ");
            this.printTime();
        }
        
        Expiry expiry = this.expiry_tree.add(t);
        this.expiry_to_client.put(expiry, registration);
        
        this.setTimeout_(previously_next);
        
        return expiry;
    }
    
    /***************************************************************************
    
        Unregisters the IExpiryRegistration instance corresponding to expiry.
        
        Params:
            expiry = expiry token returned by register() when registering the
                     IExpiryRegistration instance to unregister
        
        In:
            Must not be called from within timeout().
        
        Throws:
            Exception if no IExpiryRegistration instance corresponding to expiry
            is currently registered.
        
    ***************************************************************************/
    
    protected void unregister ( Expiry expiry )
    in
    {
        assert (!this.checking_timeouts, "attempted to unregister from within timeout()");
    }
    body
    {
        if (expiry)
        {
            ulong previously_next = this.next_expiration_us;
            
            try try            
            {
                this.expiry_to_client.remove(expiry);
            }
            finally
            {
                this.expiry_tree.remove(expiry);
            }
            finally
            {
                this.setTimeout_(previously_next);
            }
        }
    }

    /***************************************************************************
    
        Called when the overall timeout needs to be set or changed.
        
        Params:
            next_expiration_us = wall clock time when the first client times
                                    out so that checkTimeouts() must be called.
        
    ***************************************************************************/

    protected void setTimeout ( ulong next_expiration_us ) { }
    
    /***************************************************************************
    
        Called when the last client has been unregistered so that the timer may
        be disabled.
        
    ***************************************************************************/

    protected void stopTimeout ( ) { }
    
    /***************************************************************************

        Calls setTimeout() or stopTimeout() if required.
        
        Params:
            previously_next = next expiration time before a client was
                                 registered/unregistered
        
    ***************************************************************************/

    private void setTimeout_ ( ulong previously_next )
    {
        if (this.expiry_tree.length)
        {
            ulong next_now = this.expiry_tree.first;
            
            if (next_now != previously_next)
            {
                this.setTimeout(next_now);
            }
        }
        else
        {
            this.stopTimeout();
        }
    }
    
    /***************************************************************************

        TODO: Remove debugging output.
        
    ***************************************************************************/

    debug:
    
    /***************************************************************************

        Prints the current wall clock time.
        
    ***************************************************************************/

    void printTime (  )
    {
        this.printTime(this.now);
    }
    
    /***************************************************************************

        Prints t.
        
        Params:
            t = wall clock time as UNIX time in microseconds.
        
    ***************************************************************************/

    static void printTime ( ulong t )
    {
        time_t s  = cast (time_t) (t / 1_000_000);
        uint   us = cast (uint)   (t % 1_000_000);
        
        char* str = ctime(&s);
        
        Stderr(str[0 .. strlen(str) - 1])('.')(us)('\n').flush();
    }
}