/*******************************************************************************

    Copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    Version:        2013-07-19: Initial release

    Authors:        Gavin Norman

    Informational (i.e. non-destructive) interface to an ISelectClient.

*******************************************************************************/

module ocean.io.select.client.model.ISelectClientInfo;



/*******************************************************************************

    Imports

*******************************************************************************/

import tango.transition;

import tango.io.model.IConduit: ISelectable;

import ocean.sys.Epoll;



public interface ISelectClientInfo
{
    /**************************************************************************

        Returns:
            I/O device instance (file descriptor under linux)

     **************************************************************************/

    ISelectable.Handle fileHandle ( );


    /**************************************************************************

        Returns:
            bitfield of events which the client should be registered for

     **************************************************************************/

    Epoll.Event events ( );


    /***************************************************************************

        Returns:
            I/O timeout value of client in microseconds. A value of 0 means that
            no timeout is set for this client

    ***************************************************************************/

    ulong timeout_value_us ( );


    /***************************************************************************

        Returns:
            true if this client has timed out or false otherwise

    ***************************************************************************/

    bool timed_out ( );


    /**************************************************************************

        Returns true if the client's file handle is registered with epoll for
        the events specified with the client reference as attachment. Returns
        false if the client's file handle is not registered with epoll or, when
        multiple instances of the implementing class share the same file handle,
        if it is registered with another instance.

        Note that the returned value can be true by mistake when epoll
        unexpectedly unregistered the file descriptor as it happens when the
        file descriptor is closed (e.g. on error). However, the returned value
        cannot be true by mistake.

        Returns:
            true if the client's file handle is registered with epoll for the
            events specified with the client reference as attachment

     **************************************************************************/

    bool is_registered ( );


    /**************************************************************************

        Returns an identifier string of this instance. Defaults to the name of
        the class, but may be overridden if more detailed information is
        required.

        Returns:
             identifier string of this instance

     **************************************************************************/

    debug cstring id ( );


    /***************************************************************************

        Returns a string describing this client, for use in debug messages.

        Returns:
            string describing client

    ***************************************************************************/

    debug istring toString ( );
}
