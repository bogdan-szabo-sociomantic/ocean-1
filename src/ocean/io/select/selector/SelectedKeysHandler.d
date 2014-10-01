/*******************************************************************************

    Copyright:      Copyright (C) 2014 sociomantic labs. All rights reserved

    Handles a set of selected epoll keys. A selected epoll key is an event
    reported by epoll bundled with its context; the context is the ISelectClient
    object that contains the file descriptor and the event handler method.

*******************************************************************************/

module ocean.io.select.selector.SelectedKeysHandler;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.selector.model.ISelectedKeysHandler;

private import ocean.io.select.client.model.ISelectClient;

private import ocean.sys.Epoll;

private import ocean.io.select.selector.EpollException;

debug (ISelectClient) private import ocean.util.log.Trace;

/******************************************************************************/

class SelectedKeysHandler: ISelectedKeysHandler
{
    /***************************************************************************

       Type alias of a callback delegate to remove a client registration. Does
       not fail/throw if the client is not registered.

       Params:
            client = client to unregister

       Should return:
            0 if everything worked as expected or the error code (errno) as a
            warning on minor errors, that is, everything except ENOMEM (out of
            memory) and EINVAL (invalid epoll file descriptor or epoll_ctl()
            opcode).
            ENOENT is a minor error that happens regularly when the client was
            unexpectedly unregistered as it happens when its file descriptor is
            closed.

        Should throw:
            EpollException on the fatal errors ENOMEM and EINVAL.

    ***************************************************************************/

    public alias int delegate ( ISelectClient client ) UnregisterDg;

    /***************************************************************************

       Callback delegate to remove a client registration, see the description
       for the type alias above.

    ***************************************************************************/

    protected const UnregisterDg unregister;

    /***************************************************************************

        Exception to throw if an error event was reported for a selected key.

    ***************************************************************************/

    private const EpollException e;

    /***************************************************************************

        Constructor.

        Params:
            unregister = callback delegate to remove a client registration, must
                be available during the lifetime of this instance
            e = exception to keep and throw if an error event was reported for
                a selected key

    ***************************************************************************/

    public this ( UnregisterDg unregister, EpollException e )
    {
        this.unregister = unregister;
        this.e = e;
    }

    /***************************************************************************

        Handles the clients in selected_set.

        Params:
            selected_set = the result list of epoll_wait()

    ***************************************************************************/

    override public void opCall ( epoll_event_t[] selected_set )
    {
        foreach (key; selected_set)
        {
            this.handleSelectedKey(key);
        }
    }

    /***************************************************************************

        Handles key by calling its handle() method and unregisters it if the
        handle() call either returns false or throws an exception. In the latter
        case the exception thrown is reported to the client by calling its
        error() method.

        Params:
            key = an epoll key which contains a client to be handled and the
                  reported event

     **************************************************************************/

    final protected void handleSelectedKey ( epoll_event_t key )
    {
        ISelectClient client = cast (ISelectClient) key.data.ptr;

        debug ( ISelectClient )
        {
            Trace.format("{} :: Epoll firing with events ", client);
            foreach ( event, name; epoll_event_t.event_to_name )
            {
                if ( key.events & event )
                {
                    Trace.format("{}", name);
                }
            }
            Trace.formatln("");
        }

        // Only handle clients which are registered. Clients may have
        // already been unregistered (presumably deliberately), as a side-
        // effect of handling previous clients, so we don't unregister them
        // again or call their finalizers.
        if ( client.is_registered )
        {
            bool unregister_key = true,
                 error          = false;

            try
            {
                this.checkKeyError(client, key.events);

                unregister_key = !client.handle(key.events);

                debug ( ISelectClient ) if ( unregister_key )
                {
                    Trace.formatln("{} :: Handled, unregistering fd", client);
                }
                else
                {
                    Trace.formatln("{} :: Handled, leaving fd registered", client);
                }
            }
            catch (Exception e)
            {
                debug (ISelectClient)
                {
                    // FIXME: printing on separate lines for now as a workaround
                    // for a dmd bug with varargs
                    Trace.formatln("{} :: ISelectClient handle exception:", client);
                    Trace.formatln("    '{}'", e.msg);
                    Trace.formatln("    @{}:{}", e.file, e.line);
//                    Trace.formatln("{} :: ISelectClient handle exception: '{}' @{}:{}",
//                        client, e.msg, e.file, e.line);
                }

                this.clientError(client, key.events, e);
                error = true;
            }

            if (unregister_key)
            {
                this.unregisterAndFinalize(client,
                                           error? client.FinalizeStatus.Error :
                                                  client.FinalizeStatus.Success);
            }
        }
    }

    /***************************************************************************

        Checks if a selection key error has occurred by checking events and
        querying a socket error.

        Hangup states are not checked here, for the following reasons:
            1. The hangup event is not an error on its own and may be expected
               to happen, e.g. when short term connections are used. In that
               case it is also possible and expected that hangup combined with
               the read event when the remote closed the connection after having
               data sent, and that data have not been read from the socket yet.
            2. Experience shows that, when epoll reports a combination of read
               and hangup event, it will keep reporting that combination even if
               there are actually no data pending to read from the socket. In
               that case the only way of determining whether there are data
               pending is calling read() and comparing the return value against
               EOF. An application that relies on an exception thrown here will
               then run into an endless turbo event loop.
            3. Only the application knows whether hangup events are expected or
               exceptions. If it expects them, it may want its handler to be
               invoked which will not happen if checkKeyError() throws an
               exception. If it treats hangup events as exceptions, it will want
               an exception to be thrown even if it was combined with a read or
               write event.

        Params:
            client = client for which an event was reported
            events = reported events

        Throws:
            EpollException if events contains an error code. The exception
            thrown, which is an ErrnoIOException and an IOException, contains
            the errno code as reported by client.error_code.

     **************************************************************************/

    private void checkKeyError ( ISelectClient client, Epoll.Event events )
    {
        if (events & events.EPOLLERR)
        {
            throw this.e(client.error_code, "error event reported", __FILE__, __LINE__);
        }
    }

    /***************************************************************************

        Unregisters and finalizes a select client. Any errors which occur while
        calling the client's finalizer are caught and reported to the client's
        error() method (see clientError(), below).

        Params:
            client = client to finalize
            status = finalize status to report to the client (e.g. success or
                     error)

    ***************************************************************************/

    final protected void unregisterAndFinalize ( ISelectClient client,
                                           ISelectClient.FinalizeStatus status )
    {
        this.unregister(client);

        try
        {
            client.finalize(status);
        }
        catch ( Exception e )
        {
            debug (ISelectClient)
            {
                Trace.format("{} :: Error while finalizing client: '{}'",
                    client, e.msg);
                if ( e.line )
                {
                    Trace.format("@ {}:{}", e.file, e.line);
                }
                Trace.formatln("");
            }
            this.clientError(client, Epoll.Event.None, e);
        }
    }

    /***************************************************************************

        Called when an exception is thrown while handling a client (either the
        handle() or finalize() method).

        Calls the client's error() method, and in debug builds ouputs a message.

        Params:
            client = client which threw e
            events = epoll events which fired for client
            e      = exception thrown by client.handle() or client.finalize()

      **************************************************************************/

    private void clientError ( ISelectClient client, Epoll.Event events, Exception e )
    {
        debug (ISelectClient)
        {
            // FIXME: printing on separate lines for now as a workaround for a
            // dmd bug with varargs
            Trace.formatln("{} :: Error during handle:", client);
            Trace.formatln("    '{}'", e.msg);
//            Trace.format("{} :: Error during handle: '{}'",
//                client, e.msg);
            if ( e.line )
            {
                Trace.formatln("    @ {}:{}", e.file, e.line);
            }
        }

        client.error(e, events);
    }
}
