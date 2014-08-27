/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        24/08/2012: Initial release

    authors:        Gavin Norman

    Classes used by the EpollSelectDispatcher to manage the set of registered
    clients.

*******************************************************************************/

module ocean.io.select.selector.RegisteredClients;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.client.model.ISelectClient;

private import ocean.util.container.map.Set;




/*******************************************************************************

    Base class for a set of registered clients, with methods to add & remove
    clients, and to tell how many clients are currently registered. When a
    client is added or removed from the set its registered() or
    unergistered() method, respectively, is called automatically.

*******************************************************************************/

public abstract class IRegisteredClients
{
    /***************************************************************************

        Adds a client to the set of registered clients. Calls the client's
        registered() method, then calls the abstract add_() method.

        Params:
            client = client to add

    ***************************************************************************/

    final public void opAddAssign ( ISelectClient client )
    {
        debug ( ISelectClient ) Trace.formatln("{} :: Registered", client);
        client.registered();
        this.add_(client);
    }

    abstract protected void add_ ( ISelectClient client );

    /***************************************************************************

        Removes a client from the set of registered clients. Calls the client's
        unregistered() method, then calls the abstract remove_() method.

        Params:
            client = client to remove

    ***************************************************************************/

    final public void opSubAssign ( ISelectClient client )
    {
        debug ( ISelectClient ) Trace.formatln("{} :: Unregistered", client);
        client.unregistered();
        this.remove_(client);
    }

    abstract protected void remove_ ( ISelectClient client );

    /***************************************************************************

        Returns:
            the number of clients currently registered

    ***************************************************************************/

    abstract public size_t length ( );
}


/*******************************************************************************

    Class to keep track of how many clients are registered.

*******************************************************************************/

public final class ClientCount : IRegisteredClients
{
    /***************************************************************************

        Number of clients registered.

    ***************************************************************************/

    private size_t count;

    /***************************************************************************

        Adds a client to the set.

        Params:
            c = client to add

    ***************************************************************************/

    protected void add_ ( ISelectClient c )
    {
        this.count++;
    }

    /***************************************************************************

        Removes a client from the set.

        Params:
            c = client to remove

    ***************************************************************************/

    protected void remove_ ( ISelectClient c )
    {
        this.count--;
    }

    /***************************************************************************

        Returns:
            the number of clients currently registered

    ***************************************************************************/

    public size_t length ( )
    {
        return this.count;
    }
}


/*******************************************************************************

    Class to keep track of a set of registered clients, including the
    capacity to iterate over them. This class is used only in debug builds,
    where it is useful to be able to tell exactly which clients are registered.

*******************************************************************************/

public final class ClientSet : IRegisteredClients
{
    /***************************************************************************

        Set of clients.

    ***************************************************************************/

    static private class Clients : Set!(ISelectClient)
    {
        /***********************************************************************

            Estimated maximum number of clients, used by the super class to
            determine the number of buckest in the set.

        ***********************************************************************/

        const max_clients_estimate = 1000;

        /***********************************************************************

            Private constructor, prevents instantiation from the outside.

        ***********************************************************************/

        private this ( )
        {
            super(this.max_clients_estimate);
        }

        /***********************************************************************

            Hashing function, required by super class. Determines which set
            bucket is responsible for the specified client.

            Params:
                c = client to get hash for

            Returns:
                hash for client (the class reference is used)

        ***********************************************************************/

        public hash_t toHash ( ISelectClient c )
        {
            return cast(hash_t)cast(void*)c;
        }
    }

    private Clients clients;

    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.clients = new Clients;
    }

    /***************************************************************************

        Adds a client to the set.

        Params:
            c = client to add

    ***************************************************************************/

    public void add_ ( ISelectClient c )
    {
        this.clients.put(c);
    }

    /***************************************************************************

        Removes a client from the set.

        Params:
            c = client to remove

    ***************************************************************************/

    public void remove_ ( ISelectClient c )
    {
        this.clients.remove(c);
    }

    /***************************************************************************

        Returns:
            the number of clients currently registered

    ***************************************************************************/

    public size_t length ( )
    {
        return this.clients.bucket_info.length;
    }

    /***************************************************************************

        foreach operator over registered clients.

    ***************************************************************************/

    public int opApply ( int delegate ( ref ISelectClient ) dg )
    {
        int res;
        foreach ( client; this.clients )
        {
            res = dg(client);
            if ( res ) break;
        }
        return res;
    }
}

