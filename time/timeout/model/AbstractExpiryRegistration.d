/*******************************************************************************

    Hosts a ITimeoutClient with a timeout value to be managed by the
    TimeoutManager.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman, David Eckardt

*******************************************************************************/

module ocean.time.timeout.model.AbstractExpiryRegistration;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.time.timeout.model.ITimeoutClient,
               ocean.time.timeout.model.IExpiryRegistration;

debug private import tango.io.Stdout;

/*******************************************************************************

    The EBTree import and aliases should be in the TimeoutManager module and are
    here only to work around DMD's flaw of supporting mutual module imports.
    
    TODO: Move to the TimeoutManager module when DMD is fixed.

*******************************************************************************/

private import ocean.db.ebtree.EBTree;

alias EBTree!(ulong) ExpiryTree;

alias ExpiryTree.Node* Expiry;

/*******************************************************************************

    Struct storing a reference to an expiry time registry and an item in the
    registry. An instance of this struct should be owned by each client which is
    to be registered with the expiry time registry.

*******************************************************************************/

abstract class AbstractExpiryRegistration : ITimeoutClient
{
    /***************************************************************************

        Enables access of TimeoutManager internals.
    
    ***************************************************************************/

    interface ITimeoutManagerInternal
    {
        /***********************************************************************

            Registers registration and sets the timeout.
            
            Params:
                registration = IExpiryRegistration instance to register
                timeout_us   = timeout in microseconds from now
                
            Returns:    
                expiry token: required for unregister(); "key" member reflects
                the expiration wall clock time.
        
        ***********************************************************************/
    
        Expiry register ( AbstractExpiryRegistration registration, ulong timeout_us );
        
        /***********************************************************************
    
            Unregisters IExpiryRegistration instance corresponding to expiry.
            
            Params:
                expiry = expiry token returned by register() when registering
                         the IExpiryRegistration instance to unregister
            
            In:
                Must not be called from within timeout().
            
        ***********************************************************************/
    
        void unregister ( Expiry expiry );
        
        /***********************************************************************
    
            Returns:
                the current wall clock time as UNIX time in microseconds.
        
        ***********************************************************************/
    
        ulong now ( );
    }
    
    /***************************************************************************

        Timeout client: Object that times out after register() has been called
        when the time interval passed to register() has expired.
        
        The client instance is set by a subclass. The subclass must make sure
        that a client instance is set before it calls register(). It may reset
        the client instance to null after it has called unregister() (even if
        unregister() throws an exception).
        
    ***************************************************************************/
    
    protected ITimeoutClient client = null;
    
    /***************************************************************************

        Reference to an expiry time item in the registry; this is the key
        returned from register() and passed to unregister().
        The expiry item is null if and only if the client is registered with the
        timeout manager. 
        
    ***************************************************************************/
    
    private Expiry expiry = null;
    
    /***************************************************************************

        Object providing access to a timeout manager instance to
        register/unregister a client with that timeout manager.
    
    ***************************************************************************/

    private ITimeoutManagerInternal mgr;
    
    /***************************************************************************

        "Timed out" flag: set by timeout() and cleared by register().
    
    ***************************************************************************/

    private bool timed_out_ = false;
    
    /***************************************************************************

        Instance identifier
    
    ***************************************************************************/

    debug uint n;
    
    /***************************************************************************
    
        Makes sure we have a client while registered.
    
    ***************************************************************************/

    invariant ( )
    {
        assert (this.client !is null || this.expiry is null, "client required when registered");
    }

    /***************************************************************************
    
        Constructor
        
        Params:
            mgr = object providing access to a timeout manager instance to
                  register/unregister a client with that timeout manager.
    
    ***************************************************************************/

    protected this ( ITimeoutManagerInternal mgr )
    {
        this.mgr = mgr;
        
        debug
        {
            static uint N = 0;
            this.n = ++N;
        }
    }
    
    /***************************************************************************

        Unregisters the current client.
        If a client is currently not registered, nothing is done.
        
        The subclass may reset the client instance to null after it has called
        this method (even if it throws an exception).
        
        Returns:
            true on success or false if no client was registered.
        
        In:
            Must not be called from within timeout().
        
    ***************************************************************************/
    
    public bool unregister ( )
    {
        if (this.expiry) try
        {
            debug Stderr("*** " ~ typeof (this).stringof ~ ".unregister ")(this.n)('\n').flush();
            
            this.mgr.unregister(this.expiry);
            
            return true;
        }
        finally
        {
            this.expiry = null;
        }
        else
        {
            return false;
        }
    }
    
    /***************************************************************************

        Returns:
            the client timeout wall clock time as UNIX time in microseconds, if
            a client is currently registered, or ulong.max otherwise.
        
    ***************************************************************************/

    public ulong expires ( )
    {
        return this.expiry? this.expiry.key : ulong.max;
    }
    
    /***************************************************************************

        Returns:
            the number of microseconds left until timeout from now, if a client
            is currently registered, or long.max otherwise. A negative value
            indicates that the client has timed out but was not yet
            unregistered.
        
    ***************************************************************************/

    public long us_left ( )
    in
    {
        assert (this.expiry, "not registered");
    }
    body
    {
        return this.expiry? this.expiry.key - this.mgr.now : long.max;
    }
    
    /***************************************************************************

        Invokes the timeout() method of the client.
        
        Should only be called from inside the timeout manager.
        
        In:
            A client must be registered.
        
    ***************************************************************************/

    public void timeout ( )
    in
    {
        assert (this.expiry !is null, "timeout - no client");                   // The invariant makes sure that
    }                                                                           // this.client !is null if this.expiry !is null.
    body
    {
        debug Stderr("*** " ~ typeof (this).stringof ~ ".timeout ")(this.n)('\n').flush();
        
        this.timed_out_ = true;
        
        this.client.timeout();
    }
    
    /***************************************************************************

        Returns:
            true if the client has timed out or false otherwise.
    
    ***************************************************************************/

    public bool timed_out ( )
    {
        return this.timed_out_;
    }
    
    /***************************************************************************

        Returns:
            true if the client is registered or false otherwise
    
    ***************************************************************************/
    
    public bool registered ( )
    {
        return this.expiry !is null;
    }
    
    /***************************************************************************

        Sets the timeout for the client and registers it with the timeout
        manager. On timeout the client will automatically be unregistered.
        The client must not already be registered.
        
        The subclass must make sure that a client instance is set before it
        calls this method. It may reset the client instance to null after it has
        called unregister() (even if unregister() throws an exception).
        
        Params:
            timeout_us = timeout in microseconds from now. 0 is ignored.
            
        Returns:
            true if registered or false if timeout_us is 0.
            
        In:
            - this.client must not be null.
            - The client must not already be registered.
    
    ***************************************************************************/

    protected bool register ( ulong timeout_us )
    in
    {
        assert (this.expiry is null, "already registered");
        assert (this.client !is null, "client required to register");
    }
    body
    {
        debug
        {
            Stderr("*** " ~ typeof (this).stringof ~ ".register ")(this.n)(": ");
            scope (exit) Stderr(timeout_us? " µs" : " no timeout")('\n').flush();
        }
        
        this.timed_out_ = false;
        
        if (timeout_us)
        {
            debug Stderr(timeout_us);
            
            this.expiry = this.mgr.register(this, timeout_us);
            
            return true;
        }
        else
        {
            return false;
        }
    }
}
