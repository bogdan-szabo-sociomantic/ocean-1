/*******************************************************************************

    TODO

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.select.timeout.ExpiryRegistry;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.db.ebtree.EBTree;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Alias for a list of expiry registrations (a BTree storing the 64-bit expiry
    times as a number of microseconds since the unix epoch start).

*******************************************************************************/

public alias EBTree!(ulong) ExpiryList;


/*******************************************************************************

    Alias for a single item in a list of expiry registrations.

*******************************************************************************/

public alias ExpiryList.Node* ExpiryItem;


/*******************************************************************************

    Interface for a registry of expiry times.

*******************************************************************************/

public interface IExpiryRegistry
{
    public void reregister ( ref ExpiryRegistration client );
}


/*******************************************************************************

    Struct storing a reference to an expiry time registry and an item in the
    registry. An instance of this struct should be owned by each client which is
    to be registered with the expiry time registry.

*******************************************************************************/

public struct ExpiryRegistration
{
    /***************************************************************************

        Reference to an expiry time registry, used when it's necessary to
        re-register an expiry registration.

    ***************************************************************************/

    public IExpiryRegistry registry;


    /***************************************************************************

        Reference to an expiry time item in the registry.

    ***************************************************************************/

    public ExpiryItem item;


    /***************************************************************************

        Flag telling whether this item is active or not. If it's not active then
        it won't be added to the expiry time registry.

    ***************************************************************************/

    public bool active;


    /***************************************************************************

        Timeout in microseconds. When this item is registered, its expiry time
        is calculated as the time now + this timeout.

    ***************************************************************************/

    public ExpiryList.KeyType timeout;


    /***************************************************************************

        Resets all values.

    ***************************************************************************/

    public void clear ( )
    {
        this.registry = null;
        this.item = null;
        this.timeout = 0;
        this.active = false;
    }


    /***************************************************************************

        Sets the timeout.

        Params:
            timeout = timeout duration in microseconds

    ***************************************************************************/

    public void setTimeout ( ExpiryList.KeyType timeout )
    {
        this.active = true;
        this.timeout = timeout;

        this.reregister();
    }


    /***************************************************************************

        Clears the timeout.

    ***************************************************************************/

    public void disableTimeout ( )
    {
        this.active = false;
        this.timeout = 0;

        this.reregister();
    }


    /***************************************************************************

        Tells whether this struct contains a registration.

        Returns:
            true if this struct contains a registration

    ***************************************************************************/

    public bool registered ( )
    {
        return this.item !is null;
    }


    /***************************************************************************

        Re-registers this struct with the expiry registry, if it is already
        registered.

    ***************************************************************************/

    private void reregister ( )
    {
        if ( this.registered )
        {
            assert(this.registry !is null, typeof(*this).stringof ~ ".setTimeout: expiry registry reference is null");

            this.registry.reregister(*this);
        }
    }
}

