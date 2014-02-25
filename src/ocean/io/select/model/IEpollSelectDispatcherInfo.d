/*******************************************************************************

    Copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    Version:        2013-06-04: Initial release

    Authors:        Gavin Norman

    Informational interface to an EpollSelectDispatcher instance.

*******************************************************************************/

module ocean.io.select.model.IEpollSelectDispatcherInfo;



public interface IEpollSelectDispatcherInfo
{
    /***************************************************************************

        Returns:
            the number of currently registered clients

    ***************************************************************************/

    size_t num_registered ( );


    version ( EpollCounters )
    {
        /***********************************************************************

            Returns:
                the number of select calls (epoll_wait()) since the instance was
                created (or since the ulong counter wrapped)

        ***********************************************************************/

        ulong selects ( );


        /***********************************************************************

            Returns:
                the number of select calls (epoll_wait()) which exited due to a
                timeout (as opposed to a client firing) since the instance was
                created (or since the ulong counter wrapped)

        ***********************************************************************/

        ulong timeouts ( );


        /***********************************************************************

            Resets the counters returned by selects() and timeouts().

        ***********************************************************************/

        void resetCounters ( );
    }
}

