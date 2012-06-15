/*******************************************************************************

    TimeoutManager using a pool of ExpiryRegistration instances.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman, David Eckardt
    
    To use the timeout manager, create an ExpiryPoolTimeoutManager subclass
    capable of these two things:
        1. It implements setTimeout() to set a timer that expires at the wall
           clock time that is passed to setTimeout() as argument.
        2. When the timer is expired, it calls checkTimeouts().

    Objects that can time out, the so-called timeout clients, must implement
    ITimeoutClient. To register a client call getRegistration() and pass the
    object and the timeout value. When checkTimeouts() is called, it calls the
    timeout() method of each timed out object.
    
    Link with:
        -Llibebtree.a

*******************************************************************************/

module time.timeout.ExpiryPoolTimeoutManager;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.timeout.TimeoutManager;
private import ocean.io.select.timeout.ExpiryRegistry;
private import ocean.io.select.timeout.model.ITimeoutClient;

private import ocean.core.ObjectPool: PoolItem, ObjectPoolImpl;

/******************************************************************************/

abstract class ExpiryPoolTimeoutManager : TimeoutManager
{
    /***************************************************************************
    
        ExpiryRegistration object pool item
    
    ***************************************************************************/

    public class ExpiryRegistration : IExpiryRegistration, PoolItem
    {
        /***********************************************************************
        
            Index used by the hosting object pool.
        
        ***********************************************************************/

        private uint pool_index;
        
        /***********************************************************************
        
            Constructor
        
        ***********************************************************************/

        public this ( )
        {
            super(this.outer.new TimeoutManagerInternal);
        }
        
        public override bool unregister ( )
        {
            try
            {
                return super.unregister();
            }
            finally 
            {
                super.client = null;
                this.outer.pool.recycle(this);
            }
        }
        
        /***********************************************************************
        
            Sets the timeout for the client and registers it with the timeout
            manager. On timeout the client will automatically be unregistered.
            The client must not already be registered.
            
            Params:
                timeout_us = timeout in microseconds from now. 0 is ignored.
                
            Returns:
                true if registered or false if timeout_us 0.
                
            In:
                The client must not already be registered.
            
        ***********************************************************************/
        
        public typeof (this) register ( ITimeoutClient client, ulong timeout_us )
        {
            super.client = client;
            super.register(timeout_us);
            
            return this;
        }
        
        /***********************************************************************
        
            Memorizes n.
            
            Params:
                n = value to memorize
            
        ***********************************************************************/
        
        void object_pool_index ( uint n )
        {
            this.pool_index = n;
        }
        
        /***********************************************************************
        
            Returns the value that was previously passed as parameter to 
            object_pool_index(uint). It is guaranteed that object_pool_index(uint)
            is called before this method.
            
            Returns:
                the value that was previously passed as parameter to
                object_pool_index(uint)
        
        ***********************************************************************/
        
        uint object_pool_index ( )
        {
            return this.pool_index;
        }
    }

    private ObjectPoolImpl pool;
    
    this ( )
    {
        this.pool = new ObjectPoolImpl;
    }
    
    public ExpiryRegistration getRegistration ( ITimeoutClient client, ulong timeout_us )
    {
        return (cast (ExpiryRegistration) this.pool.get(this.new ExpiryRegistration)).register(client, timeout_us);
    }
}

