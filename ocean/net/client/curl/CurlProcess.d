/*******************************************************************************

    Url download functionality using a set of child processes running curl.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        January 2012: Initial release

    authors:        Gavin Norman

    Usage example:

    ---

        import ocean.io.Stdout;
        import ocean.net.client.curl.CurlProcess;
        import ocean.io.select.EpollSelectDispatcher;

        // Create epoll selector instance.
        auto epoll = new EpollSelectDispatcher;

        // Create a curl downloads instance which can process a maximum of 10
        // downloads in parallel.
        const max_downloads = 10;
        auto curl = new CurlDownloads(epoll, max_downloads);

        // Initialise some downloads, one with authorization.
        curl.assign(curl.download("http://www.google.com"));
        curl.assign(curl.download("http://www.wikipedia.org"));
        curl.assign(
            curl.download("http://www.zalando.de/var/export/display_zalando_de.csv")
            .authorize("zalando-user", "dewE23#f4"));

        // Handle arriving data.
        epoll.eventLoop;

    ---

    TODO: the structure of this client is very similar to the swarm clients. It
    could perhaps be integrated, if it were either moved to swarm, or if the
    core of swarm were moved to ocean. Not sure which would make more
    sense. Two great benefits of integration would be a common interface and a
    base of shared code (leading to greater stability and wider functionality in
    all sharing clients).

    It'd require the creation of a client base class which did not assume the
    existence of a multi-node structure (this makes no sense in the context of
    curl, which can download from any number of different urls). This would
    probably be a nice thing to do though, and would make the creation of
    further such fully-featured clients much easier in the future.

*******************************************************************************/

module ocean.net.client.curl.CurlProcess;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.net.client.curl.CurlProcessSingle;

private import ocean.net.client.curl.process.DownloadSetup;
private import ocean.net.client.curl.process.ExitStatus;
private import ocean.net.client.curl.process.NotificationInfo;

private import ocean.core.ContextUnion;

private import ocean.core.ObjectPool;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.io.serialize.StructSerializer;

private import ocean.util.container.queue.FlexibleRingQueue;

debug private import ocean.io.Stdout;



/*******************************************************************************

    Class encapsulating a set of one or more parallel url downloads using curl.
    The maximum number of parallel downloads is set in the constructor. When all
    downloads are busy, any further downloads which are assigned will simply be
    ignored.

*******************************************************************************/

public abstract class CurlDownloads
{
    /***************************************************************************

        Local type aliases.

    ***************************************************************************/

    public alias ContextUnion Context;

    public alias .NotificationInfo NotificationInfo;

    public alias .ExitStatus ExitStatus;


    /***************************************************************************

        Curl process which downloads a url. Class derived in order to allow it
        to be used in a Pool. The pool (in the outer class) needs to be notified
        when a download has finished, so that it can be recycled.

    ***************************************************************************/

    private class CurlDownloadProcess : CurlProcess
    {
        /***********************************************************************

            Object pool index -- allows the construction of a pool of objects of
            this type.

        ***********************************************************************/

        public uint object_pool_index;


        /***********************************************************************

            Constructor.

        ***********************************************************************/

        public this ( )
        {
            super(this.outer.epoll);
        }


        /***********************************************************************

            Called when the process has finished. Calls the super method for the
            standard behaviour, and also notifies the outer class that this
            download can be recycled.

            Params:
                exited_ok = if true, the process exited normally and the
                    exit_code parameter is valid. Otherwise the process exited
                    abnormally, and exit_code will be 0.
                exit_code = the process' exit code, if exited_ok is true.
                    Otherwise 0.

        ***********************************************************************/

        override protected void finished ( bool exited_ok, int exit_code )
        {
            super.finished(exited_ok, exit_code);

            this.outer.downloadFinished(this);
        }
    }


    /***************************************************************************

        Maximum number of concurrent download processes.

    ***************************************************************************/

    public const size_t max;


    /***************************************************************************

        Pool of download processes.

    ***************************************************************************/

    private alias Pool!(CurlDownloadProcess) DownloadPool;

    private const DownloadPool downloads;


    /***************************************************************************

        Epoll selector used by processes. Passed as a reference to the
        constructor.

    ***************************************************************************/

    private const EpollSelectDispatcher epoll;


    /***************************************************************************

        Flag which is set when downloads are suspended using the supsend()
        method. Reset by resume(). When suspended_ is true, no new downloads may
        be assigned.

    ***************************************************************************/

    private bool suspended_;


    /***************************************************************************

        Constructor.

        Params:
            epoll = epoll dispatcher to use
            max = maximum number of concurrent download processes

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, size_t max )
    {
        this.epoll = epoll;
        this.max = max;

        this.downloads = new DownloadPool;
    }


    /***************************************************************************

        Sets up a DownloadSetup struct describing a new download. Any desired
        methods of the struct should be called (to configure optional download
        settings), and it should be passed to the assign() method to start the
        download.

        Params:
            url = url to download
            receive_dg = delegate which will be called when data is received
                from the url
            error_dg = delegate which will be called when error messages are
                sent from curl
            finished_dg = delegate which will be called when the download
                process finishes

        Returns:
            DownloadSetup struct to be passed to assign

    ***************************************************************************/

    public DownloadSetup download ( char[] url, CurlReceiveDg receive_dg,
            CurlReceiveDg error_dg, CurlNotificationDg finished_dg )
    {
        return DownloadSetup(url, receive_dg, error_dg, finished_dg);
    }


    /***************************************************************************

        Assigns a new download as described by a DownloadSetup struct.

        Two versions of this method exist, accepting either a DownloadSetup
        struct, or a pointer to such a struct.

        Params:
            setup = DownloadSetup struct describing a new download

        Returns:
            true if the download was started, or false if all download processes
            are busy or suspended

    ***************************************************************************/

    public bool assign ( DownloadSetup* setup )
    {
        return this.assign(*setup);
    }

    public bool assign ( DownloadSetup setup )
    {
        if ( this.all_busy || this.suspended_ )
        {
            return false;
        }

        auto dl = this.downloads.get(new CurlDownloadProcess);
        dl.start(setup);

        return true;
    }


    /***************************************************************************

        Returns:
            the number of currently active downloads

    ***************************************************************************/

    public size_t num_busy ( )
    {
        return this.downloads.num_busy;
    }


    /***************************************************************************

        Returns:
            true if all download processes are busy

    ***************************************************************************/

    public bool all_busy ( )
    {
        return this.num_busy == this.max;
    }


    /***************************************************************************

        Suspends all active downloads.

    ***************************************************************************/

    public void suspend ( )
    {
        if ( this.suspended_ )
        {
            return;
        }

        this.suspended_ = true;

        scope active_downloads = this.downloads.new BusyItemsIterator;
        foreach ( dl; active_downloads )
        {
            dl.suspend;
        }
    }


    /***************************************************************************

        Returns:
            true if downloads are suspended

    ***************************************************************************/

    public bool suspended ( )
    {
        return this.suspended_;
    }


    /***************************************************************************

        Resumes any suspended downloads.

    ***************************************************************************/

    public void resume ( )
    {
        if ( !this.suspended_ )
        {
            return;
        }

        this.suspended_ = false;

        scope active_downloads = this.downloads.new BusyItemsIterator;
        foreach ( dl; active_downloads )
        {
            dl.resume;
        }
    }


    /***************************************************************************

        Called when a download process finishes. Recycles the download to the
        pool.

        Params:
            process = download process which has just finished

    ***************************************************************************/

    protected void downloadFinished ( CurlDownloadProcess process )
    {
        this.downloads.recycle(process);
    }
}


/*******************************************************************************

    Expands the CurlDownloads class with a downloads queue. When all downloads
    are busy, any further downloads which are assigned will be pushed into the
    queue and processed when one of the active download processes becomes free.

*******************************************************************************/

public class QueuedDownloads : CurlDownloads
{
    /***************************************************************************

        Queue used to store downloads which are assigned when all download
        processes are busy or when downloading is suspended.

    ***************************************************************************/

    private const FlexibleByteRingQueue queue;


    /***************************************************************************

        Constructor.

        Params:
            epoll = epoll dispatcher to use
            max = maximum number of concurrent download processes
            queue_size = maximum size of download queue (in bytes)

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, size_t max, size_t queue_size )
    {
        super(epoll, max);

        this.queue = new FlexibleByteRingQueue(queue_size);
    }


    /***************************************************************************

        Assigns a new download as described by a DownloadSetup struct. If all
        downloads in the pool are currently busy, the download will be queued.

        Two versions of this method exist, accepting either a DownloadSetup
        struct, or a pointer to such a struct.

        Params:
            setup = DownloadSetup struct describing a new download

        Returns:
            true if the download was started or queued, or false if there was no
            space in the queue

    ***************************************************************************/

    override public bool assign ( DownloadSetup* setup )
    {
        return this.assign(*setup);
    }

    override public bool assign ( DownloadSetup setup )
    {
        if ( this.all_busy || this.suspended_ )
        {
            auto length = StructSerializer!().length(&setup);

            auto target = this.queue.push(length);
            if ( target is null )
            {
                return false; 
            }

            StructSerializer!().dump(&setup, target);

            auto notification_dg = setup.notification_dg();
            notification_dg(NotificationInfo(NotificationInfo.Type.Queued,
                        setup.context, setup.url));

            return true;
        }

        auto dl = this.downloads.get(new CurlDownloadProcess);
        dl.start(setup);

        return true;
    }


    /***************************************************************************

        Returns:
            the number of queued downloads

    ***************************************************************************/

    public size_t num_queued ( )
    {
        return this.queue.length;
    }


    /***************************************************************************

        Called when a download process finishes. Recycles the download to the
        pool (by calling the super method), and pops the next request from the
        queue, if one is waiting.

        Params:
            process = download process which has just finished

    ***************************************************************************/

    override protected void downloadFinished ( CurlDownloadProcess process )
    {
        super.downloadFinished(process);

        assert(this.downloads.num_idle > 0);

        // pop from queue
        if ( !this.queue.isEmpty )
        {
            auto serialized_setup = this.queue.pop;

            auto dl = this.downloads.get(new CurlDownloadProcess);
            dl.start(serialized_setup);
        }
    }
}

