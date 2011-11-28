/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        August 2011: Initial release

    authors:        Mathias Baumann

*******************************************************************************/

module ocean.io.device.AsyncFileEpoll;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.event.SelectEvent;

private import ocean.io.select.EpollSelectDispatcher;

debug import ocean.util.log.Trace;

private import tango.stdc.posix.time : timespec;

private import tango.stdc.posix.unistd;

private import tango.sys.Common;

private import tango.stdc.stringz;



/*******************************************************************************

    Template that adds a padding when mixed in, so that type + padding = size
    
    Template Params:
        Type = Type who will be used to calculate the needed padding
        size = size that is needed

*******************************************************************************/

template Pad ( Type, uint size ) 
{
    static assert ( Type.sizeof <= size );
    static if (size - Type.sizeof > 0)
    {
        byte[size - Type.sizeof] padding;
    }
}

extern (C)
{
    enum 
    {
        IO_CMD_PREAD   = 0,
        IO_CMD_PWRITE  = 1,
        
        IO_CMD_FSYNC   = 2,
        IO_CMD_FDSYNC  = 3,
        
        IO_CMD_POLL    = 5,
        IO_CMD_NOOP    = 6,
        IO_CMD_PREADV  = 7,
        IO_CMD_PWRITEV = 8,
    }
    
    struct sockaddr;
    struct Io_iocb_sockaddr
    {
        sockaddr* addr;
    }
    
    struct Io_iocb_poll
    {
        int events, padding;
    }
    
    struct iovec;
    struct Io_iocb_vector
    {
        iovec* vec;
        int nr;
        long offset;
    }   
    
    struct Io_iocb_common
    {
        void *buf; mixin Pad!(void*, 8);
        
        size_t nbytes; mixin Pad!(size_t, 8);
        
        long offset;
        long pad3;
        uint flags;
        uint resfd;
    }
    
    static assert (Io_iocb_common.sizeof == 40);
        
    struct Iocb
    {
        void* data; mixin Pad!(void*, 8);
        uint key, padding2;
        
        short aio_lio_opcode;
        short aio_reqprio;
        int aio_fildes;
        
        union U
        {
            Io_iocb_common c;
            Io_iocb_vector v;
            Io_iocb_poll poll;
            Io_iocb_sockaddr saddr;
        }
        
        U u;
    }
    
    static assert (Iocb.sizeof == 64);
    
    struct Io_context;
    
    struct Io_event
    {
        void* data; mixin Pad!(void*, 8);
        Iocb* obj;  mixin Pad!(Iocb*, 8);
        
        size_t res; mixin Pad!(size_t, 8);
        size_t res2; mixin Pad!(size_t, 8);
    }    
    
    int io_getevents ( Io_context* ctx_id, int min_nr, int nr, Io_event* events,
                       timespec* timeout );    
    int io_setup ( uint nr_events, Io_context** );
    int io_submit ( Io_context* ctx_id, int nr, Iocb ** iocbpp );
    int io_queue_wait ( Io_context* ctx, void* );
    int io_queue_init ( int maxevents, Io_context** ctx );
    
    void io_set_eventfd ( Iocb* iocb, int eventfd )
    {
        iocb.u.c.flags |= (1 << 0);
        iocb.u.c.resfd  = eventfd;
    }
    
    void *memset(void *s, int c, size_t n);

    void io_prep_pread ( Iocb *iocb, int fd, void *buf, size_t count, long
                         offset )
    {
        memset(iocb, 0, Iocb.sizeof);

        with (*iocb)
        {
            aio_fildes = fd;
            aio_lio_opcode = IO_CMD_PREAD;
            aio_reqprio = 0;
            u.c.buf = buf;
            u.c.nbytes = count;
            u.c.offset = offset;
        }
    }
    
    void io_prep_pwrite ( Iocb *iocb, int fd, void *buf, size_t count, long
                          offset )
    {
        memset(iocb, 0, Iocb.sizeof);

        with (*iocb)
        {
            aio_fildes = fd;
            aio_lio_opcode = IO_CMD_PWRITE;
            aio_reqprio = 0;
            u.c.buf = buf;
            u.c.nbytes = count;
            u.c.offset = offset;
        }
    }    
}

class AsyncFileContext
{    
    private EpollSelectDispatcher epoll;
    
       /***********************************************************************

            Fits into 32 bits ...

    ***********************************************************************/

     align(1) struct Style
    {
            Access          access;                 /// Access rights.
            Open            open;                   /// How to open.
          //  Share           share;                  /// How to share.
    }

    /***********************************************************************

    ***********************************************************************/

    enum Access
                            {
                            Read      = O_RDONLY,       /// Is readable.
                            Write     = O_WRONLY,       /// Is writable.
                            ReadWrite = O_RDWR,       /// Both.
                            }

    /***********************************************************************

    ***********************************************************************/

    enum Open               {
                            Exists = 0,                 /// Must exist.
                            Create = O_CREAT | O_TRUNC, /// Create or truncate.
                            Sedate = O_CREAT,           /// Create if necessary.
                            Append = O_APPEND | O_CREAT,/// Create if necessary.
                            New    = O_CREAT | O_EXCL,  /// Can't exist.
                            };

    /***********************************************************************

    **********************************************************************

    enum Share : ubyte      {
                            None = F_WRLCK,             /// No sharing.
                            Read = F_RDLCK,             /// Shared reading.
                            ReadWrite,             /// Open for anything.
                            };*/

    /***********************************************************************

        Read an existing file.

    ***********************************************************************/

    const Style ReadExisting = {Access.Read, Open.Exists};

    /***********************************************************************

        Read an existing file.

    **********************************************************************

    const Style ReadShared = {Access.Read, Open.Exists, Share.Read};*/ 

    /***********************************************************************

        Write on an existing file. Do not create.

    ***********************************************************************/

    const Style WriteExisting = {Access.Write, Open.Exists};

    /***********************************************************************

            Write on a clean file. Create if necessary.

    ***********************************************************************/

    const Style WriteCreate = {Access.Write, Open.Create};

    /***********************************************************************

            Write at the end of the file.

    ***********************************************************************/

    const Style WriteAppending = {Access.Write, Open.Append};

    /***********************************************************************

            Read and write an existing file.

    ***********************************************************************/

    const Style ReadWriteExisting = {Access.ReadWrite, Open.Exists};

    /***********************************************************************

            Read &amp; write on a clean file. Create if necessary.

    ***********************************************************************/

    const Style ReadWriteCreate = {Access.ReadWrite, Open.Create};

    /***********************************************************************

            Read and Write. Use existing file if present.

    ***********************************************************************/

    const Style ReadWriteOpen = {Access.ReadWrite, Open.Sedate};
        
    private class AsyncFile
    {   
        const O_DIRECT    = 00040000;
        const O_LARGEFILE = 0x8000;
        
        public alias void delegate ( State, ubyte[] ) FileDG;
        
        struct State
        {
            Style style;
            size_t offset;
            int error;
        }
        
        private int fd;
        private SelectEvent event_fd;
        private Iocb iocb;
        private Style style;
        private FileDG file_dg;
        
        public this ( char[] file_path, FileDG file_dg, Style style )
        {
            this.file_dg = file_dg;
                             
            char[512] zero = void;                      
            
            auto name     = toStringz (file_path, zero);            
            this.fd       = .open(name, style.open | style.access,
                                 O_DIRECT | O_LARGEFILE);
            
            if (this.fd < 0) throw new Exception("Couldn't open file");
            
            this.style    = style;            
            this.event_fd = new SelectEvent(&this.handler);
            
            this.outer.epoll.register(this.event_fd);             
        }
        
        public void read ( ubyte[] buffer, size_t offset = 0, 
                           bool submit = true )
        {
            io_prep_pread(&this.iocb, this.fd, buffer.ptr, buffer.length, offset);
            io_set_eventfd(&this.iocb, this.event_fd.fileHandle);
            
            if ( submit )
            {
                Trace.formatln("Read request fired");
                Iocb* fake_list = &this.iocb;
                int ret = io_submit(this.outer.io_context, 1, &fake_list);
                
                if (ret < 1) throw new Exception("io_submit failed");
            }
            else
            {
                this.outer.queue_request(&this.iocb);
            }
        }
        
        public void write ( ubyte[] buffer, size_t offset = 0, 
                            bool submit = true )
        {
            io_prep_pwrite(&this.iocb, this.fd, buffer.ptr, buffer.length, offset);
            io_set_eventfd(&this.iocb, this.event_fd.fileHandle);
            
            if ( submit )
            {
                Iocb* fake_list = &this.iocb;
                int ret = io_submit(this.outer.io_context, 1, &fake_list);
                
                if (ret < 0) throw new Exception("io_submit failed");
            }
            else
            {
                this.outer.queue_request(&this.iocb);
            }
        }
        
        public bool handler ( )
        {
            Trace.formatln("handler called");
            Io_event[10] events;
            int ret;
            
            do
            {
                ret = io_getevents(this.outer.io_context, 1, 10, events.ptr, 
                                   null);
                
                if (ret <  0)
                {
                    
                    //        fromStringz(strerror(-ret)), ret).flush;
            
                    throw new Exception("io_getevents error");                
                }
                
                foreach (event; events[0 .. ret])
                {
                    State state = State(this.style, event.obj.u.c.offset, 
                                        event.res2);
                    
                    if (event.res2 != 0)
                    {
                        this.file_dg(state, null);
                    }
                    else
                    {
                        this.file_dg(state, 
                                     (cast(ubyte*)event.obj.u.c.buf) 
                                     [0 .. event.res]);
                    }
                }
            }
            while (ret > 0)
                
            return true;
        }        
    }  
        
    private Io_context* io_context;
    public alias AsyncFile.State State;
    private Iocb*[] events;
    
    private size_t used;
    
    
    public this ( EpollSelectDispatcher epoll, uint events )
    {   
        int ret = io_setup(events, &io_context);
        
        if ( ret < 0 )
        {
            throw new Exception("io_setup failed");
            // fromStringz(strerror(-ret))
        }
        
        this.events = new Iocb*[events];
        
        this.epoll = epoll;
    }
    
    public AsyncFile open ( char[] file_path, AsyncFile.FileDG file_dg, 
                            Style style = ReadExisting )
    {
        return new AsyncFile(file_path, file_dg, style);
    }
    
    public void submit ( )
    {
        if ( this.used > 0 )
        {
            int ret = io_submit(io_context, this.used, events.ptr);
            
            if (ret < 0)
                throw new Exception("io_submit failed");
            
            this.used = 0;
        }
    }   
    
    private void queue_request ( Iocb* iocb )
    {
        if ( used < this.events.length )
        {
            this.events[used++] = iocb;
        }
        else
        {
            throw new Exception("Event queue full");
        }   
    }    
}


