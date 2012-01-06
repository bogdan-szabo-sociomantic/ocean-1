/*******************************************************************************

    Download state change notification struct.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        January 2012: Initial release

    authors:        Gavin Norman

*******************************************************************************/

module ocean.net.client.curl.process.NotificationInfo;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.ContextUnion;

private import ocean.net.client.curl.process.ExitStatus;



/*******************************************************************************

    Download notification struct which is passed to the notification delegate.
    Provides convenient methods to test a few common exit statuses of a curl
    process.

*******************************************************************************/

public struct NotificationInfo
{
    /***************************************************************************

        Type of notification.

    ***************************************************************************/

    public enum Type
    {
        Queued,
        Started,
        Finished
    }

    public Type type;


    /***************************************************************************

        User-specified context of the download.

    ***************************************************************************/

    public ContextUnion context;


    /***************************************************************************

        Url being downloaded.

    ***************************************************************************/

    public char[] url;


    /***************************************************************************

        Exit status of download process (only set when type == Finished).

    ***************************************************************************/

    public ExitStatus status;


    /***************************************************************************

        Tells whether the notification indicates that the download has finished
        successfully.

        Returns:
            true if the download process has finished, and if the exit status
            indicates no error

    ***************************************************************************/

    public bool succeeded ( )
    {
        return this.type == Type.Finished && this.status == ExitStatus.OK;
    }


    /***************************************************************************

        Tells whether the notification indicates that the download has timed
        out.

        Returns:
            true if the download process has finished, and if the exit status
            indicates that a timeout occurred

    ***************************************************************************/

    public bool timed_out ( )
    {
        return this.type == Type.Finished
            && this.status == ExitStatus.OperationTimeout;
    }
}

