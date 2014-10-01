/*******************************************************************************

    Copyright:      Copyright (C) 2014 sociomantic labs. All rights reserved

    Handles a set of selected epoll keys and handles registered select clients
    that timed out.

*******************************************************************************/

module ocean.io.select.selector.TimeoutSelectedKeysHandler;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.selector.SelectedKeysHandler,
               ocean.io.select.selector.EpollException;

private import ocean.sys.Epoll: epoll_event_t;

private import ocean.io.select.client.model.ISelectClient;

private import ocean.time.timeout.model.ITimeoutManager,
               ocean.time.timeout.model.ITimeoutClient;

private import ocean.util.container.AppendBuffer: AppendBuffer;

private import tango.stdc.stdlib: bsearch, qsort;

/******************************************************************************/

class TimeoutSelectedKeysHandler: SelectedKeysHandler
{
    /***************************************************************************

        Timeout manager instance to obtain the timed out clients.

     **************************************************************************/

    private const ITimeoutManager timeout_manager;

    /***************************************************************************

        Re-usable set of timed out clients. opCall() populates this list with
        the timed out clients as reported by timeout_manager, unregisters and
        finalizes all timed out clients, then handles the selected keys that are
        not in the list.

     **************************************************************************/

    private alias AppendBuffer!(ISelectClient) TimedOutClientList;

    private const TimedOutClientList timed_out_clients;

    /***************************************************************************

        Constructor.

        Params:
            unregister      = callback delegate to remove a client registration,
                              must be available during the lifetime of this
                              instance
            e               = exception to keep and throw if an error event was
                              reported for a selected key
            timeout_manager = timeout manager to obtain the timed out clients in
                              handle()
            num_clients     = an estimate of the number of clients that will be
                              registered. Used to preallocate the list of timed
                              out clients

    ***************************************************************************/

    public this ( UnregisterDg unregister, EpollException e,
                  ITimeoutManager timeout_manager, uint num_clients = 0 )
    {
        super(unregister, e);

        this.timeout_manager = timeout_manager;
        this.timed_out_clients = new TimedOutClientList(num_clients);
    }

    /***************************************************************************

        Handles the clients in selected_set that did not time out, then reports
        a timeout to the timed out clients and unregisters them.

        Note that any timed out clients will *not* be handled, even if they have
        an event fired. Instead they are finalized with status = timeout and
        unregistered.

        Params:
            selected_set = the result list of epoll_wait()

    ***************************************************************************/

    public override void opCall ( epoll_event_t[] selected_set )
    {
        if (this.timeout_manager.us_left < timeout_manager.us_left.max)
        {
            this.timeout_manager.checkTimeouts((ITimeoutClient timeout_client)
            {
                auto client = cast (ISelectClient)timeout_client;

                assert (client !is null, "timeout client is not a select client");

                debug ( ISelectClient )
                    Trace.formatln("{} :: Client timed out, unregistering", client);

                this.timed_out_clients ~= client;

                return true;
            });

            auto timed_out_clients = this.timed_out_clients[];

            if (timed_out_clients.length)
            {
                /*
                 * Handle the clients in the selected set that didn't time out.
                 * To do so, look up every timed out client in the selected set
                 * using bsearch and handle it if it didn't time.
                 * Using bsearch requires the list to be sorted.
                 */

                qsort(timed_out_clients.ptr, timed_out_clients.length,
                      timed_out_clients[0].sizeof, &cmpPtr!(false));

                foreach (key; selected_set)
                {
                    ISelectClient client = cast (ISelectClient) key.data.ptr;

                    assert (client !is null);

                    if (!bsearch(cast (void*) client, timed_out_clients.ptr,
                                 timed_out_clients.length, timed_out_clients[0].sizeof, &cmpPtr!(true)))
                    {
                        this.handleSelectedKey(key);
                    }
                }

                foreach ( client; this.timed_out_clients[] )
                {
                    this.unregisterAndFinalize(client, client.FinalizeStatus.Timeout);
                }

                this.timed_out_clients.clear();

                /*
                 * The selected set and the timed out clients are handled:
                 * We're done.
                 */

                return;
            }

            /*
             * No client timed out: Handle the selected set normally.
             */
        }

        super.opCall(selected_set);
    }

    /***************************************************************************

        Compares the pointer referred to by a_ to that referred to by b_.

        Template params:
            searching = false: a_ points to the pointer to compare (called from
                        qsort()), true: a_ is the pointer to compare (called
                        from bsearch).

        Params:
            a_ = either the pointer (searching = true) or a pointer to the
                 pointer (searching = false) to compare against the pointer
                 pointed to by b_
            b_ = pointer to the pointer to compare against a_ or the pointer a_
                 points to

        Returns:
            a value greater 0 if a_ compares greater than b_, a value less than
            0 if less or 0 if a_ and b_ compare equal.

    ***************************************************************************/

    extern (C) private static int cmpPtr ( bool searching ) ( void* a_, void* b_ )
    {
        static if (searching)
        {
            alias a_ a;
        }
        else
        {
            void* a = *cast (void**) a_;
        }

        void* b = *cast (void**) b_;

        return (a >= b)? a > b : -1;
    }
}
