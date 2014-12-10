/******************************************************************************

    Fiber that can register select clients in a dispatcher, optimizing
    re-registrations and event changes.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt, Gavin Norman

    MessageFiber that includes a select dispatcher and memorizes the last client
    it has registered to optimize registrations by skipping unnecessary
    register() or unregister() calls.

 ******************************************************************************/

module ocean.io.select.fiber.SelectFiber;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.core.MessageFiber;

import ocean.io.select.client.model.ISelectClient;
import ocean.io.select.client.model.ISelectClientInfo;

import ocean.io.select.EpollSelectDispatcher;

debug ( SelectFiber) import tango.util.log.Trace;


/******************************************************************************/

public class SelectFiber : MessageFiber
{
    /**************************************************************************

        Epoll instance to use

     **************************************************************************/

    public EpollSelectDispatcher epoll;

    /**************************************************************************

        Currently registered select client

     **************************************************************************/

    private ISelectClient current = null;

    /**************************************************************************

        Constructor

        Params:
            coroutine = fiber coroutine

     **************************************************************************/

    this ( EpollSelectDispatcher epoll, void delegate ( ) coroutine )
    {
        this.epoll = epoll;

        super(coroutine);
    }

    /**************************************************************************

        Constructor

        Params:
            routine = fiber coroutine
            sz      = fiber stack size

     **************************************************************************/

    this ( EpollSelectDispatcher epoll, void delegate ( ) coroutine, size_t sz )
    {
        this.epoll = epoll;

        super(coroutine, sz);
    }

    /**************************************************************************

        Registers client in epoll and sets client to the current client.

        Params:
            client = select client to register

        Returns:
            true if an epoll registration was actually added or modified or
            false if the client's I/O device was already registered with the
            same event.

     **************************************************************************/

    public bool register ( ISelectClient client )
    in
    {
        assert(client !is null);
    }
    body
    {
        debug ( SelectFiber) Trace.formatln("{}.register fd {}:",
                typeof(this).stringof, client.fileHandle);

        if ( this.current is null )
        {
            debug ( SelectFiber) Trace.formatln("   Register new {}", client);

            this.epoll.register(this.current = client);

            return true;
        }
        else
        {
            if ( this.current.fileHandle == client.fileHandle )
            {
                if ( this.current.events != client.events )
                {
                    debug ( SelectFiber)
                    {
                        Trace.formatln("   Changing event registration {}",
                            this.current);
                        Trace.formatln("   Register {}", client);
                    }

                    this.epoll.changeClient(this.current, client);

                    this.current = client;

                    return true;
                }
                else
                {
                    debug ( SelectFiber)
                    {
                        Trace.formatln("   Leaving registered {}", this.current);
                    }

                    // As there is not way to modify a registration with the
                    // timeout manager, it is necessary to call unregistered(),
                    // then registered() even if this.current and client are
                    // identical. This ensures that, even if the epoll
                    // registration doesn't need to be updated, that the timeout
                    // timeout registration is updated correctly.

                    this.current.unregistered();
                    client.registered();

                    return false;
                }
            }
            else
            {
                debug ( SelectFiber) Trace.formatln("   Unregister {}",
                    this.current);

                this.epoll.unregister(this.current);

                debug ( SelectFiber) Trace.formatln("   Register {}", client);

                this.epoll.register(this.current = client);

                return true;
            }
        }
    }

    /**************************************************************************

        Unegisters the current client from epoll and clears it, if any.

        Returns:
            true if the current client was unregistered or false if there was
            no current client.

     **************************************************************************/

    public bool unregister ( )
    {
        if ( this.current !is null )
        {
            debug ( SelectFiber) Trace.formatln("{}.unregister fd {}",
                    typeof(this).stringof, this.current.fileHandle);

            this.epoll.unregister(this.current);
            this.current = null;

            return true;
        }
        else
        {
            return false;
        }
    }

    /**************************************************************************

        Checks if client is identical to the current client.
        Note that the client instance is compared, not the client conduit,
        file descriptor or events.

        Params:
            client = client to compare for identity with the current client,
                     pass null to check if there is no current client.

        Returns:
            true if client is the current client or false otherwise.

     **************************************************************************/

    public bool isRegistered ( ISelectClient client )
    {
        return this.current is client;
    }

    /**************************************************************************

        Clears the current client; usually called from the client finalizer.

        Note that the client does not need to be unregistered here, as the epoll
        selector always unregisters the client after calling its finalizer.

        Returns:
            true if there actually was a current client or false otherwise.

     **************************************************************************/

    public bool clear ( )
    {
        scope (success) this.current = null;

        return this.current !is null;
    }

    /**************************************************************************

        Returns:
            informational interface to currently registered client (null if no
            client is registered)

     **************************************************************************/

    public ISelectClientInfo registered_client ( )
    {
        return this.current;
    }
}


