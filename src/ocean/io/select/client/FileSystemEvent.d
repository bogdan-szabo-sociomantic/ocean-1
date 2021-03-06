/*******************************************************************************

    File system event which can be registered with the
    EpollSelectDispatcher. The implementation uses inotify internally, see
    ocean.sys.Inotify and http://man7.org/linux/man-pages/man7/inotify.7.html

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.client.FileSystemEvent;





import ocean.core.Verify;
import ocean.sys.Inotify;
import core.stdc.string;
import core.sys.linux.sys.inotify;

import core.sys.posix.unistd;

import ocean.io.select.EpollSelectDispatcher;
import ocean.io.select.client.model.ISelectClient: ISelectClient;
import ocean.core.Buffer;
import ocean.core.SmartUnion;
import ocean.transition;


/*******************************************************************************

    Flags to be passed to FileSystemEvent.watch

*******************************************************************************/

enum FileEventsEnum : uint
{
    /* Supported events suitable for MASK parameter of INOTIFY_ADD_WATCH.  */
    IN_ACCESS           = 0x00000001,   /* File was accessed.  */
    IN_MODIFY           = 0x00000002,   /* File was modified.  */
    IN_ATTRIB           = 0x00000004,   /* Metadata changed.  */
    IN_CLOSE_WRITE      = 0x00000008,   /* Writtable file was closed.  */
    IN_CLOSE_NOWRITE    = 0x00000010,   /* Unwrittable file was closed.  */
    IN_CLOSE            = 0x00000018,   /* Close. */
    IN_OPEN             = 0x00000020,   /* File was opened.  */
    IN_MOVED_FROM       = 0x00000040,   /* File was moved from X.  */
    IN_MOVED_TO         = 0x00000080,   /* File was moved to Y.  */
    IN_MOVE             = 0x000000c0,   /* Moves.  */
    IN_CREATE           = 0x00000100,   /* Subfile was created.  */
    IN_DELETE           = 0x00000200,   /* Subfile was deleted.  */
    IN_DELETE_SELF      = 0x00000400,   /* Self was deleted.  */
    IN_MOVE_SELF        = 0x00000800,   /* Self was moved.  */

    /* Events sent by the kernel.  */
    IN_UMOUNT           = 0x00002000,   /* Backing fs was unmounted.  */
    IN_Q_OVERFLOW       = 0x00004000,   /* Event queued overflowed  */
    IN_IGNORED          = 0x00008000,   /* File was ignored  */

    /* Special flags.  */
    IN_ONLYDIR          = 0x01000000,   /* Only watch the path if it is a directory.  */
    IN_DONT_FOLLOW      = 0x02000000,   /* Do not follow a sym link.  */
    IN_MASK_ADD         = 0x20000000,   /* Add to the mask of an already existing watch.  */
    IN_ISDIR            = 0x40000000,   /* Event occurred against dir.  */
    IN_ONESHOT          = 0x80000000,   /* Only send event once.  */

    IN_ALL_EVENTS       = 0x00000fff,   /* All events which a program can wait on.  */
}

class FileSystemEvent : ISelectClient
{
    import ocean.core.Buffer;

    /***************************************************************************

        Alias for event handler delegate.

    ***************************************************************************/

    // TODO: this is deprecated. Remove in the next major
    public alias void delegate ( char[] path, uint event ) Handler;


    /***************************************************************************

        Structure carrying only path and event.

    ***************************************************************************/

    public struct FileEvent
    {
        cstring path;
        uint event;
    }


    /***************************************************************************

        Structure carrying path, name and event, representing event that happened
        on a file in a watched directory.

    ***************************************************************************/

    public struct DirectoryFileEvent
    {
        cstring path;
        cstring name;
        uint event;
    }


    /***************************************************************************

        Union of possible events that could happen.

    ***************************************************************************/

    public union EventUnion
    {
        FileEvent file_event;
        DirectoryFileEvent directory_file_event;
    }


    /***************************************************************************

        SmartUnion alias for the possible events that could happen.

    ***************************************************************************/

    public alias SmartUnion!(EventUnion) RaisedEvent;


    /***************************************************************************

        Alias for the notifier delegate that receives the event as a smart union.

    ***************************************************************************/

    public alias void delegate ( RaisedEvent ) Notifier;


    /***************************************************************************

        Inotify wrapper

    ***************************************************************************/

    private Inotify fd;


    /***************************************************************************

        Event handler delegate, specified in the constructor and called whenever
        a watched file system event fires.

    ***************************************************************************/

    // TODO: this is deprecated. Remove in the next major
    private Handler handler;


    /***************************************************************************

        Event notifier delegate, specified in the constructor and called whenever
        a watched file system event fires, passing the SmartUnion describing the
        event.

    ***************************************************************************/

    private Notifier notifier;


    /***************************************************************************

        Associative array which maps inotify "watch descriptor" against "path".
        When a watch is performed in inotify, a new entry is created in this array.
        On the other hand, every unwatch implies the removal of the entry.

        Note: The array will never have 2 entries with same path. When same path
        is provided to watch, the existing "watch descriptor" is re-used
        See inotify manual for further details.

    ***************************************************************************/

    private char[][uint] watched_files;


    /***********************************************************************

        Constructor. Creates a custom event and hooks it up to the provided
        event handler.

        Params:
            handler = event handler

    ***********************************************************************/

    deprecated ("Please use this(Notifier) instead")
    public this ( Handler handler )
    {
        this();
        this.handler = handler;
    }


    /***********************************************************************

        Constructor. Creates a custom event and hooks it up to the provided
        event notifier which in addition accepts the name field.

        Params:
            notifier = event notifier

    ***********************************************************************/

    public this ( Notifier notifier )
    {
        this();
        this.notifier = notifier;
    }


    /***************************************************************************

        Constructor. Initializes a custom event.

    ***************************************************************************/

    private this ()
    {
        this.fd = new Inotify;
    }


    /***********************************************************************

        Replace the handle delegate

        Params:
            handler = event handler

    ***********************************************************************/

    deprecated ("Please use setNotifier(Notifier) instead")
    public void setHandler ( Handler handler )
    {
        this.handler = handler;
    }


    /***********************************************************************

        Replace the notifier delegate

        Params:
            notifier = event notifier

    ***********************************************************************/

    public void setNotifier ( Notifier notifier )
    {
        this.notifier = notifier;
    }


    /***********************************************************************

        Required by ISelectable interface.

        Returns:
            file descriptor used to manage custom event

    ***********************************************************************/

    public override Handle fileHandle ( )
    {
        return this.fd.fileHandle;
    }


    /***************************************************************************

        Returns:
            the epoll events to register for.

    ***************************************************************************/

    public override Event events ( )
    {
        return Event.EPOLLIN;
    }


    /***************************************************************************

        Adds or updates the events being watched for the specified path. The
        handler delegate previously specified will be called when one of the
        watched events occurs.

        params:
            path   = File path to watch (directories are also supported)
            events = Inotify events that will be watched (flags)

        Throws:
            upon failure during addition of new file to watch

    ***************************************************************************/

    public void watch ( char[] path, FileEventsEnum events )
    {
        //Attention: Existing wd is returned if path is being watched
        uint wd = this.fd.addWatch(path, events);

        if ( auto existing_path = wd in this.watched_files )
        {
            verify(*existing_path == path);
        }
        else
        {
            this.watched_files[wd] = path;
        }
    }


    /***************************************************************************

        Stops watching the specified path. The handler delegate will no longer
        be called when events on this path occur.

        Returns:
            True, if path was successfully removed
            False, the path was not found in the list of watched paths

        Throws:
            upon failure when removing the watch of a file

    ***************************************************************************/

    public bool unwatch ( char[] path )
    {
        bool removed = false;

        foreach ( wd, wd_path; this.watched_files )
        {
            if ( wd_path == path )
            {
                this.fd.rmWatch(wd);
                this.watched_files.remove(wd);
                removed = true;
                break;
            }
        }

        return removed;
    }


    /***************************************************************************

        Event handler, invoked by the epoll select dispatcher.

        Params:
            event = event(s) reported by epoll

        Returns:
            true to stay registered in epoll or false to unregister.

    ***************************************************************************/

    public override bool handle ( Event event )
    {
        foreach ( ev; this.fd.readEvents() )
        {
            verify(ev.mask != typeof(ev.mask).init);

            auto path = ev.wd in this.watched_files;
            if (path is null)
                continue;

            if (this.handler)
                this.handler(*path , ev.mask);

            if (this.notifier)
            {
                RaisedEvent event_info;

                if (ev.len > 0)
                {
                    auto name_ptr = cast(char*)&ev.name;
                    auto name = name_ptr[0..strlen(name_ptr)];
                    event_info.directory_file_event = DirectoryFileEvent(*path,
                            name, ev.mask);
                }
                else
                {
                    event_info.file_event = FileEvent(*path, ev.mask);
                }

                this.notifier(event_info);
            }
        }

        return true;
    }

}
