/*******************************************************************************

    Manages an I/O event loop with automatic handler invocation and
    unregistration.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        David Eckardt, Gavin Norman

    The EpollSelectDispatcher class wraps a Tango EpollSelector and uses
    ISelectClient instances for Select I/O event registration, unregistration
    and event handler invocation. An I/O event loop is provided that runs while
    there are select event registrations. This loop automatically invokes the
    registered handlers; via the return value each handler may indicate that it
    wishes to be unregistered. After the ISelectClient instance has been
    unregistered, its finalize() method is invoked.

    If a handler throws an Exception, it is caught, the ISelectClient containing
    that handler is unregistered immediately and finalize() is invoked.
    Exceptions thrown by the ISelectClient's finalize() methods are also caught.

*******************************************************************************/

module ocean.io.select.EpollSelectDispatcher;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.select.selector.IEpollSelectDispatcherInfo;
import ocean.io.select.client.model.ISelectClient;

import ocean.io.select.selector.model.ISelectedKeysHandler;

import ocean.io.select.selector.SelectedKeysHandler,
       ocean.io.select.selector.TimeoutSelectedKeysHandler,
       ocean.io.select.selector.EpollException;

import ocean.io.select.client.SelectEvent;

import ocean.io.select.selector.RegisteredClients;

import ocean.core.Array : copy;

import ocean.util.container.AppendBuffer;

import ocean.time.timeout.model.ITimeoutManager;

import ocean.sys.Epoll;

import tango.stdc.stdlib: bsearch, qsort;

import tango.stdc.errno: errno, EINTR, ENOENT, EEXIST, ENOMEM, EINVAL;

debug ( ISelectClient ) import tango.util.log.Trace;

/*******************************************************************************

    EpollSelectDispatcher

*******************************************************************************/

public class EpollSelectDispatcher : IEpollSelectDispatcherInfo
{
    /***************************************************************************

        Event alias used internally

     **************************************************************************/

    alias ISelectClient.Event Event;

    /***************************************************************************

        Set of registered clients.

     **************************************************************************/

    private IRegisteredClients registered_clients;

    /**************************************************************************

         Default maximum number of file descriptors for which events can be
         reported with one epoll_wait() call.

     **************************************************************************/

    public const uint DefaultMaxEvents = 16;

    /**************************************************************************

         true if the timeout feature is enabled.

     **************************************************************************/

    public bool timeout_enabled ( )
    {
        return this._timeout_enabled;
    }

    private bool _timeout_enabled;

    /***************************************************************************

        Wrapped Epoll file handle

     **************************************************************************/

    private Epoll epoll;

    /***************************************************************************

        Reused list of events.

     **************************************************************************/

    private epoll_event_t[] events;

    /***************************************************************************

        Re-usable exceptions

     **************************************************************************/

    private EpollException e;

    /***************************************************************************

        Timeout manager instance; null disables the timeout feature.

     **************************************************************************/

    private ITimeoutManager timeout_manager;

    /***************************************************************************

        Event which is triggered when the shutdown() method is called.

     **************************************************************************/

    private SelectEvent shutdown_event;

    /***************************************************************************

        Flag which the eventLoop checks for exit status. Set to true when the
        shutdown event fires (via calling the shutdown() method).

     **************************************************************************/

    private bool shutdown_triggered;

    /***************************************************************************

        Flag set to true when the eventLoop() method is called, and to false
        when it exits. Used to assert that the event loop is not started from
        within itself.

     **************************************************************************/

    private bool in_event_loop;

    version ( EpollCounters )
    {
        /***********************************************************************

            Struct containing counters to track stats about the selector.

        ***********************************************************************/

        private struct Counters
        {
            ulong selects;
            ulong timeouts;
        }

        private Counters counters;
    }

    /***************************************************************************

        Client handler.

     **************************************************************************/

    private const ISelectedKeysHandler handle;

    /***************************************************************************

        Constructor

        Params:
            timeout_manager = timeout manager instance (null disables the
                              timeout feature)
            size            = value that provides a hint for the maximum amount
                              of conduits that will be registered
            max_events      = value that provides a hint for the maximum amount
                              of conduit events that will be returned in the
                              selection set per call to select.

        Throws:
            EpollException on error obtaining a new epoll instance.

     **************************************************************************/

    public this ( ITimeoutManager timeout_manager = null, uint max_events = DefaultMaxEvents )
    {
        debug ( ISelectClient )
        {
            this.registered_clients = new ClientSet;
        }
        else
        {
            this.registered_clients = new ClientCount;
        }

        this.e = new EpollException;

        if (this.epoll.create() < 0)
        {
            throw this.e("error creating epoll object", __FILE__, __LINE__);
        }

        this.timeout_manager = timeout_manager;

        this._timeout_enabled = timeout_manager !is null;

        this.shutdown_event = new SelectEvent(&this.shutdownTrigger);

        this.events            = new epoll_event_t[max_events];

        this.handle = this.timeout_enabled?
            new TimeoutSelectedKeysHandler(&this.unregister, this.e, this.timeout_manager, max_events) :
            new SelectedKeysHandler(&this.unregister, this.e);
    }

    /***************************************************************************

        Constructor; disables the timeout feature.

        Params:
            size            = value that provides a hint for the maximum amount
                              of conduits that will be registered
            max_events      = value that provides a hint for the maximum amount
                              of conduit events that will be returned in the
                              selection set per call to select.

     **************************************************************************/

    public this ( uint max_events )
    {
        this(null, max_events);
    }

    /***************************************************************************

        Destructor.

     **************************************************************************/

    ~this ( )
    {
        with (this.epoll) if (fd >= 0)
        {
            close();
        }
    }

    /***************************************************************************

        Adds or modifies a client registration.

        To change the client of a currently registered conduit when several
        clients share the same conduit, use changeClient().

        Important note: client is stored in a memory location not managed by the
        D runtime memory manager (aka Garbage Collector). Therefore it is
        important that the caller makes sure client is stored somewhere visible
        to the GC (in a class variable, for example) so it won't get garbage
        collected and deleted.

        Params:
            client = client to register, please make sure it is stored somewhere
                     visible to the garbage collector

        Returns:
            true if everything worked as expected or false if the client was
            unexpectedly unregistered as it happens when its file descriptor is
            closed.

        Throws:
            EpollException on error.

     **************************************************************************/

    public bool register ( ISelectClient client )
    {
        try if (client.is_registered)
        {
            scope (failure)
            {
                this.registered_clients -= client;
            }

            return this.modify(client);
        }
        else
        {
            if (this.epoll.ctl(epoll.CtlOp.EPOLL_CTL_ADD, client.fileHandle,
                client.events, client))
            {
                throw this.e("error adding epoll registration", __FILE__, __LINE__);
            }

            this.registered_clients += client;

            return true;
        }
        catch (Exception e)
        {
            debug ( ISelectClient )
            {
                Trace.formatln("{} :: Error during register: '{}' @{}:{}",
                    client, e.msg, e.file, e.line);
            }
            throw e;
        }
    }

    /***************************************************************************

       Removes a client registration. Does not fail/throw if the client is not
       registered.

       Params:
            client = client to unregister

       Returns:
            0 if everything worked as expected or the error code (errno) as a
            warning on minor errors, that is, everything except ENOMEM (out of
            memory) and EINVAL (invalid epoll file descriptor or epoll_ctl()
            opcode).
            ENOENT is a minor error that happens regularly when the client was
            unexpectedly unregistered as it happens when its file descriptor is
            closed.

        Throws:
            EpollException on the fatal errors ENOMEM and EINVAL.

     **************************************************************************/

    public int unregister ( ISelectClient client )
    {
        try if (client.is_registered)
        {
            scope (success)
            {
                this.registered_clients -= client;
            }

            if (!this.epoll.ctl(epoll.CtlOp.EPOLL_CTL_DEL, client.fileHandle,
                client.events, client))
            {
                return 0;
            }
            else
            {
                int errnum = .errno;

                switch (errnum)
                {
                    default:
                        return errnum;

                    case ENOMEM, EINVAL:
                        throw this.e(errnum, "error removing epoll client", __FILE__, __LINE__);
                }
            }
        }
        else
        {
            return false;
        }
        catch (Exception e)
        {
            debug ( ISelectClient )
            {
                Trace.formatln("{} :: Error during unregister: '{}' @{}:{}",
                    client, e.msg, e.file, e.line);
            }
            throw e;
        }
    }

    /**************************************************************************

        Changes the clients of a registered conduit from current to next.

        - current and next are expected to share the the same file descriptor
          (conduit file handle),
        - current is expected to be registered while next is expected not to be
          registered. It is tolerated if current is unexpectedly unregistered
          as it happens when its file descriptor is closed.

       Important note: next is stored in a memory location not managed by the
       D runtime memory manager (aka Garbage Collector). Therefore it is
       important that the caller makes sure next is stored somewhere visible
       to the GC (in a class variable, for example) so it won't get garbage
       collected and deleted.

       Params:
            current = currently registered client to be unregistered
            next    = currently unregistered client to be registered, please
                      make sure it is stored somewhere visible to the garbage
                      collector

       Returns:
            true if everything worked as expected or false if current is
            unexpectedly unregistered as it happens when its file descriptor is
            closed.

        Throws:
            EpollException on error.

        In:
            - current and next must have the the same file descriptor,
            - current.is_registered must be true,
            - next.is_registered must be false.

     **************************************************************************/

    public bool changeClient ( ISelectClient current, ISelectClient next )
    in
    {
        debug ( ISelectClient )
        {
            if (current.fileHandle != next.fileHandle)
            {
                Trace.formatln("Error during changeClient: current.fileHandle != next.fileHandle");
            }

            if (!current.is_registered)
            {
                Trace.formatln("Error during changeClient: !current.is_registered");
            }

            if (next.is_registered)
            {
                Trace.formatln("Error during changeClient: next.is_registered");
            }
        }

        assert (current.fileHandle == next.fileHandle,
                typeof (this).stringof ~ ".changeClient: clients are expected to share the same file descriptor");
        assert (current.is_registered,
                typeof (this).stringof ~ ".changeClient: current client is expected to be registered");
        assert (!next.is_registered,
                typeof (this).stringof ~ ".changeClient: next client is expected not to be registered");
    }
    body
    {
        assert (current !is next); // should be impossible since current.is_registered != next.is_registered

        try
        {
            scope (success)
            {
                debug ( ISelectClient )
                {
                    Trace.formatln("Changed clients for fd:");
                    Trace.formatln("  Replaced {}", current);
                    Trace.formatln("  with     {}", next);
                }

                this.registered_clients -= current;
                this.registered_clients += next;
            }

            return this.modify(next);
        }
        catch (Exception e)
        {
            debug ( ISelectClient )
            {
                Trace.formatln("Error during changeClient: '{}' @{}:{}",
                    e.msg, e.file, e.line);
            }
            throw e;
        }
    }

    /**************************************************************************

        IEpollSelectDispatcherInfo interface method.

        Returns:
            the number of clients registered with the select dispatcher

     **************************************************************************/

    public size_t num_registered ( )
    {
        return this.registered_clients.length;
    }

    version ( EpollCounters )
    {
        /***********************************************************************

            Returns:
                the number of select calls (epoll_wait()) since the instance was
                created (or since the ulong counter wrapped)

        ***********************************************************************/

        public ulong selects ( )
        {
            return this.counters.selects;
        }


        /***********************************************************************

            Returns:
                the number of select calls (epoll_wait()) which exited due to a
                timeout (as opposed to a client firing) since the instance was
                created (or since the ulong counter wrapped)

        ***********************************************************************/

        public ulong timeouts ( )
        {
            return this.counters.timeouts;
        }


        /***********************************************************************

            Resets the counters returned by selects() and timeouts().

        ***********************************************************************/

        public void resetCounters ( )
        {
            this.counters = this.counters.init;
        }
    }

    /**************************************************************************

        Modifies the registration of client using EPOLL_CTL_MOD.
        More precisely, the events of the current registration of
        client.fileHandle are set to client.events and the registration
        attachment is set to client.

        If this fails with ENOENT, which means, client.fileHandle turned
        out not to be registered, a new registration of the client is created
        using EPOLL_CTL_ADD. This fallback is intended only to be used when a
        file descriptor is unexpectedly unregistered as it happens when it is
        closed.

        Params:
            client = client to set the conduit registration to

       Returns:
            true if everything worked as expected or false if
            client.fileHandle turned out not to be registered so that
            a new registration was added.

        Throws:
            EpollException on error.

     **************************************************************************/

    private bool modify ( ISelectClient client )
    {
        if (!this.epoll.ctl(epoll.CtlOp.EPOLL_CTL_MOD, client.fileHandle,
            client.events, client))
        {
            return false;
        }
        else
        {
            int errnum = .errno;

            if (errnum == ENOENT)
            {
                if (!this.epoll.ctl(epoll.CtlOp.EPOLL_CTL_ADD, client.fileHandle,
                    client.events, client))
                {
                    return true;
                }
                else
                {
                    throw this.e("error adding epoll registration "
                                 "after modification resulted in ENOENT",
                                 __FILE__, __LINE__);
                }
            }
            else
            {
                throw this.e(errnum, "error modifying epoll registration", __FILE__, __LINE__);
            }
        }
    }

    /**************************************************************************

        Sets a timeout manager expiry registration to client if the timeout
        feature is enabled. This must be done exactly once for each select
        client that should be able to time out.
        If the timeout feature is disabled, nothing is done.

        Params:
            client = client to set timeout manager expiry registration

        Returns:
            true on success or false if the timeout feature is disabled.

     **************************************************************************/

    public bool setExpiryRegistration ( ISelectClient client )
    {
        if (this._timeout_enabled)
        {
            client.expiry_registration = this.timeout_manager.getRegistration(client);
            return true;
        }
        else
        {
            return false;
        }
    }

    /***************************************************************************

        Causes the event loop to exit before entering the next wait cycle.

        Note that after calling shutdown() the select dispatcher is left in an
        invalid state, where register() and unregister() calls will cause seg
        faults and further calls to eventLoop() will exit immediately.
        (See TODO in eventLoop().)

     **************************************************************************/

    public void shutdown ( )
    {
        this.register(this.shutdown_event);
        this.shutdown_event.trigger();
    }

    /***************************************************************************

        While there are clients registered, repeatedly waits for registered
        events to happen, invokes the corresponding event handlers of the
        registered clients and unregisters the clients if they desire so.

     **************************************************************************/

    public void eventLoop ( )
    in
    {
        assert (!this.in_event_loop, "Event loop has already been started.");
    }
    body
    {
        this.in_event_loop = true;
        scope ( exit ) this.in_event_loop = false;

        while ( this.registered_clients.length && !this.shutdown_triggered )
        {
            this.select();
        }
    }

    /***************************************************************************

        Executes an epoll select.

        Returns:
            the number of epoll keys for which an event was reported.

     **************************************************************************/

    protected uint select ( )
    {
        debug ( ISelectClient )
        {
            Trace.formatln("{}.select ({} clients registered):",
                typeof(this).stringof, this.registered_clients.length);
            size_t i;
            foreach ( client; cast(ClientSet)this.registered_clients )
            {
                Trace.formatln("   {,3}: {}", i++, client);
            }
        }

        while (true /* actually while epoll_wait is interrupted by a signal */)
        {
            ulong us_left = (this.timeout_manager !is null)
                            ? timeout_manager.us_left
                            : ulong.max;

            // Note that timeout_manager.us_left can be ulong.max, too.

            bool have_timeout = us_left < us_left.max;

            // have_timeout is true if a timeout is specified, no matter if
            // epoll_wait actually timed out or not (this is indicated by
            // n == 0).

            int n = this.epoll.wait(this.events, have_timeout? cast (int) this.usToMs(us_left) : -1);
            version ( EpollCounters ) this.counters.selects++;

            if (n >= 0)
            {
                debug ( ISelectClient ) if ( !n )
                {
                    Trace.formatln("{}.select: timed out after {}microsec",
                            typeof(this).stringof, us_left);
                }

                version ( EpollCounters ) if ( n == 0 ) this.counters.timeouts++;

                auto selected_set = events[0 .. n];

                this.handle(selected_set);

                return n;
            }
            else
            {
                int errnum = .errno;

                if (errnum != EINTR)
                {
                    throw this.e(errnum, "error waiting for epoll events", __FILE__, __LINE__);
                }
            }
        }
    }

    /***************************************************************************

        Called when the shutdown event fires (via a call to the shutdown()
        method). Sets the shutdown flag, ensuring that the event loop will exit,
        regardless of whether there are any clients still registered.

        Returns:
            true to stay registered in the selector

     **************************************************************************/

    private bool shutdownTrigger ( )
    {
        this.shutdown_triggered = true;

        return true;
    }

    /***************************************************************************

        Converts a microseconds value to milliseconds for use in select().
        It is crucial that this conversion always rounds up. Otherwise the
        timeout manager might not find a timed out client after select() has
        reported a timeout.

        Params:
            us = time value in microseconds

        Returns:
            nearest time value in milliseconds that is not less than us.

     **************************************************************************/

    private static ulong usToMs ( ulong us )
    {
        ulong ms = us / 1000;

        return ms + ((us - ms * 1000) != 0);
    }
}

