/*******************************************************************************

    Composes a normal queue and writes anything that doesn't fit to file.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        January 2012: Initial release

    authors:        Mathias Baumann

*******************************************************************************/

module ocean.util.container.queue.FlexibleFileQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.container.queue.model.IByteQueue;

private import ocean.util.container.queue.model.IQueueInfo;

private import ocean.util.container.queue.FlexibleRingQueue;

private import ocean.util.log.Trace;

private import tango.io.stream.Buffered,
               tango.io.device.File,
               Filesystem = tango.io.Path;
   


public class FlexibleFileQueue : IByteQueue
{
    /***************************************************************************

        Header for queue items

    ***************************************************************************/    

    private struct Header
    {
        size_t length;
        
        static Header* fromSlice ( void[] slice )
        {
            return cast(Header*) slice.ptr;
        }
    }

    /***************************************************************************

        Buffer used to support ubyte[] push ( size_t )

    ***************************************************************************/    
    
    private ubyte[] slice_push_buffer;
    
    /***************************************************************************
    
        Queue

    ***************************************************************************/
    
    private IByteQueue queue;
    
    /***************************************************************************
    
        Path to write to

    ***************************************************************************/
    
    private char[] path;
    
    /***************************************************************************
    
        External file that is being written to

    ***************************************************************************/
    
    private File file_out;
        
    /***************************************************************************
    
        External file that is being read from

    ***************************************************************************/
    
    private File file_in;
    
    /***************************************************************************
    
        Buffered output stream to write to the file

    ***************************************************************************/
    
    private BufferedOutput ext_out;
        
    /***************************************************************************
    
        Buffered input stream to write to the file

    ***************************************************************************/
    
    private BufferedInput ext_in;
    
    /***************************************************************************
    
        Unread bytes in the file

    ***************************************************************************/
        
    private size_t bytes_in_file;
    
    /***************************************************************************
    
        Unread items in the file

    ***************************************************************************/
        
    private size_t items_in_file;
    
    /***************************************************************************
    
        Constructor
        
        Params:
            path  = path to the file that will be used to swap the queue
            queue = queue implementation that will be used
             
    ***************************************************************************/
    
    public this ( char[] path, IByteQueue queue )
    {
        this.queue = queue;
        this.path  = path.dup;
        
        /+if ( Filesystem.exists(this.path) )
        {
            this.openExternal();
        }+/
    }
    
    
    /***************************************************************************
    
        Pushes an item into the queue.
    
        Params:
            item = data item to push
    
        Returns:
            true if the item was pushed successfully, false if it didn't fit

    ***************************************************************************/
    
    public bool push ( ubyte[] item )
    {     
        this.handleSliceBuffer();

        if ( item.length == 0 ) return false;
        
        if ( this.file_out is null && this.queue.willFit(item.length) )
        {
            return this.queue.push(item);
        }
        else
        {
            return this.externalPush(item);
        }   
    }
        
    
    /***************************************************************************
    
        Reserves space for an item of <size> bytes on the queue but doesn't
        fill the content. The caller is expected to fill in the content using
        the returned slice. 
    
        Params:
            size = size of the space of the item that should be reserved
    
        Returns:
            slice to the reserved space if it was successfully reserved, 
            else null

    ***************************************************************************/
    
    public ubyte[] push ( size_t size )
    {        
        this.handleSliceBuffer();
        
        if ( this.file_out is null && this.queue.willFit(size) ) 
        {
            return this.queue.push(size);
        }
        else
        {
            this.slice_push_buffer.length = size;
        
            return this.slice_push_buffer;
        }
    }
    
    /***************************************************************************

        Pops an item from the queue.
    
        Returns:
            item popped from queue, may be null if queue is empty

    ***************************************************************************/

    public ubyte[] pop ( )
    {
        try if ( this.file_out is null ) 
        {
            return this.queue.pop();
        }
        else
        {
            if ( this.queue.length() > 0 )
            {
                return this.queue.pop();
            }
            else
            {
                try this.ext_out.flush();
                catch ( Exception e )
                {
                    Trace.formatln("## ERROR: Can't flush file buffer: {}", e.msg);
                    return this.queue.pop();
                }
                
                this.ext_in.compress();
                auto readable = this.ext_in.readable;
                auto bytes = this.ext_in.populate();
                
                if ( (bytes == 0 || bytes == File.Eof) && 
                     readable == 0)
                {
                    this.closeExternal();

                    return this.queue.pop();
                }
                
                Header* h;
                
                while ( this.ext_in.readable() >= Header.sizeof )
                {
                    h = Header.fromSlice(this.ext_in.slice(Header.sizeof, false));
                    
                    if ( h.length + Header.sizeof <= this.ext_in.readable() )
                    {
                        this.ext_in.skip(Header.sizeof);
                        this.ext_in.fill(this.queue.push(h.length));
                        
                        this.items_in_file -= 1;
                        this.bytes_in_file -= Header.sizeof + h.length;
                    }
                    else break;
                }
                
                return this.queue.pop();
            }
        }
        catch ( Exception e )
        {
            Trace.formatln("## ERROR: Failsafe catch triggered by exception: {}",
                           e.msg);
        }
    }
         
     
    /***************************************************************************

        Finds out whether the provided number of bytes will fit in the queue.

        Due to the file swap, we have unlimited space, so always return true.

        Params:
            bytes = size of item to check 

        Returns:
            always true

    ***************************************************************************/

    public bool willFit ( size_t bytes )
    {
        return true;
    }


    /***************************************************************************
    
        Returns:
            total number of bytes used by queue (used space + free space)
    
    ***************************************************************************/
    
    public ulong total_space ( )
    {
        return queue.total_space();
    }
    
    
    /***************************************************************************
    
        Returns:
            number of bytes stored in queue
    
    ***************************************************************************/
    
    public ulong used_space ( )
    {
        return queue.used_space() + this.bytes_in_file;
    }    
    
    
    /***************************************************************************
    
        Returns:
            number of bytes free in queue
    
    ***************************************************************************/
    
    public ulong free_space ( )
    {
        if ( this.bytes_in_file ) return 0; 
            
        return queue.free_space();
    }
    
       
    /***************************************************************************
    
        Returns:
            the number of items in the queue
    
    ***************************************************************************/
    
    public uint length ( )
    {
        return queue.length() + this.items_in_file;
    }
        
    
    /***************************************************************************
    
        Tells whether the queue is empty.
    
        Returns:
            true if the queue is empty
    
    ***************************************************************************/
    
    public bool is_empty ( )
    {
        return queue.is_empty() && this.items_in_file == 0;
    }
    
        
    /***************************************************************************
    
        Deletes all items
                
    ***************************************************************************/
        
    public void clear ( )
    {
        this.queue.clear();
        this.items_in_file = this.bytes_in_file = 0;
        this.ext_in.clear();
        this.ext_out.clear();
        this.closeExternal();
    }
    
        
    /***************************************************************************
    
        Pushes the buffered slice from a previous slice-push operation
                
    ***************************************************************************/
        
    private void handleSliceBuffer ( )
    {
        if ( this.slice_push_buffer.length != 0 )
        {
            if ( this.file_out is null && 
                 this.queue.willFit(this.slice_push_buffer.length) )
            {
                this.queue.push(this.slice_push_buffer);
                this.slice_push_buffer.length = 0;
            }
            else
            {
                this.file_out is null && this.openExternal();
                
                this.externalPush(this.slice_push_buffer);
                this.slice_push_buffer.length = 0;
            }
        }
    }
        
    
    /***************************************************************************
    
        Pushes item into file
        
        Params:
            item = data to push
            
        Returns:
            true when write was successful, else false
        
    ***************************************************************************/
        
    private bool externalPush ( ubyte[] item )
    {
        try 
        {
            this.file_out is null && this.openExternal();

            ubyte[] header = (cast(ubyte*)&Header(item.length))[0 .. Header.sizeof];

            this.ext_out.write(header);
            this.ext_out.write(item);
            
            this.bytes_in_file += Header.sizeof + item.length;
            this.items_in_file += 1;
            
            return true;
        }
        catch ( Exception e )
        {
            Trace.formatln("## ERROR: Exception happened while writing to disk: {}", e.msg);
            return false;
        }
    }
    
        
    /***************************************************************************
    
        Opens and allocates the files and associated buffers
    
    ***************************************************************************/
    
    private void openExternal ( )
    {
        this.file_out = new File(this.path, File.WriteCreate);
        this.file_in  = new File(this.path, File.ReadExisting);
        
        this.ext_out = new BufferedOutput(this.file_out);        
        this.ext_in  = new BufferedInput(this.file_in, this.queue.total_space());
    }
    
        
    /***************************************************************************
    
        Closes and deallocates all the files and related buffers 
    
    ***************************************************************************/
        
    private void closeExternal ( )
    in
    {
        assert ( this.ext_in.readable() == 0, "Still unread data in input buffer" );
        assert ( this.bytes_in_file == 0 , "Still bytes in the file");
        assert ( this.items_in_file == 0 , "Still items in the file");
    }
    body
    {
        this.ext_in.close();
        this.ext_out.close();
        this.file_out.close();
        this.file_in.close();
        
        delete this.ext_in;
        delete this.ext_out;
        delete this.file_out;
        delete this.file_in;
        
        this.ext_in = null, this.ext_out = null, 
        this.file_out = null, this.file_in = null;
        
        Filesystem.remove(this.path);
    }
}