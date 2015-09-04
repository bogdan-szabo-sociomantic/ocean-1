/*******************************************************************************

    Interface for the timeout manager expiry registration object used in the
    ISelectClient.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2011: Initial release

    author:         David Eckardt

    The reason for these interfaces is to avoid requiring an application to be
    linked against the libebtree, which is required by TimeoutManager and
    ExpiryRegistration, when it uses a library module that supports a timeout
    functionality as an optional feature.
    Therefore, library modules that support a timeout functionality as an
    optional feature should always use these interfaces and not import
    TimeoutManager/ExpiryRegistration.

*******************************************************************************/

module ocean.time.timeout.model.IExpiryRegistration;


/*******************************************************************************

    Imports

*******************************************************************************/

import tango.transition;
import ocean.time.timeout.model.ITimeoutClient;

/*******************************************************************************

    General timeout manager expiry registration object interface

*******************************************************************************/

interface IExpiryRegistration
{
    /***************************************************************************

        Sets the timeout for the client and registers it with the timeout
        manager. On timeout the client will automatically be unregistered.
        The client must not currently be registered.

        Params:
            timeout_us = timeout in microseconds from now. 0 is ignored.

        Returns:
            true if registered or false if timeout_us is 0.

    ***************************************************************************/

    bool register ( ulong timeout_us );

    /***************************************************************************

        Unregisters the current client.
        If a client is currently not registered, nothing is done.
        It depends from the implementation whether the client remains
        associated to this registration or not.

        Must not be called from within timeout().

        Returns:
            true on success or false if no client was registered.

    ***************************************************************************/

    bool unregister ( );

    /***************************************************************************

        Returns:
            true if the client has timed out or false otherwise.

    ***************************************************************************/

    bool timed_out ( );

    /***************************************************************************

        Invoked by the timeout manager when the client times out. Invokes the
        timeout() method of the current client.

        Returns:
            the current client which has been notified about its timeout.

    ***************************************************************************/

    ITimeoutClient timeout ( );

    /***************************************************************************

        Identifier string for debugging.

    ***************************************************************************/

    debug cstring id ( );
}
