/*******************************************************************************

    File-based queue implementation.

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
    
        Size of the file read buffer. It is not possible to push items which are
        larger than this buffer size.

    ***************************************************************************/
        
    private size_t size;
    
    /***************************************************************************

        Constructor

        Params:
            path  = path to the file that will be used to swap the queue
            size = size of file read buffer (== maximum item size)

    ***************************************************************************/

    public this ( char[] path, size_t size )
    {
        this.path  = path.dup;
        this.size  = size;
        
        if ( Filesystem.exists(this.path) )
        {
            Filesystem.remove(this.path);
        }
    }
    
    
    /***************************************************************************
    
        Pushes an item into the queue.
    
        Params:
            item = data item to push
    
        Returns:
            true if the item was pushed successfully, false if it didn't fit

    ***************************************************************************/
    
    public bool push ( ubyte[] item )
    in
    {
        assert ( item.length <= this.size, 
                 "Read buffer too small to process this item"); 
    }
    body
    {     
        this.handleSliceBuffer();

        if ( item.length == 0 ) return false;
        
        return this.filePush(item);         
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
        
        this.slice_push_buffer.length = size;
    
        return this.slice_push_buffer;    
    }
    
    
    /***************************************************************************

        Reads an item from the queue.
        
        Params:
            eat = whether to remove the item from the queue
    
        Returns:
            item read from queue, may be null if queue is empty

    ***************************************************************************/

    private ubyte[] getItem ( bool eat = true )
    {
        this.handleSliceBuffer();
        
        if ( this.bytes_in_file == 0 && this.ext_out !is null )
        {
            this.closeExternal();
            return null;
        }
        
        if ( this.bytes_in_file > 0 ) try
        {
            try this.ext_out.flush();
            catch ( Exception e )
            {
                Trace.formatln("## ERROR: Can't flush file buffer: {}", e.msg);
                return null;
            }
            
            Header h;
            
            if ( this.ext_in.readable() <= Header.sizeof && this.fill() == 0 )
            {
                return null;
            }
            
            h = *Header.fromSlice(this.ext_in.slice(Header.sizeof, false));
            
            assert ( h.length < this.size, "Unrealistic size" );
            
            if ( h.length + Header.sizeof > this.ext_in.readable() && 
                 this.fill() == 0 )
            {
                return null;
            }
            
            if ( eat )
            {
                this.items_in_file -= 1;
                this.bytes_in_file -= Header.sizeof + h.length;
            }
            
            return cast(ubyte[]) this.ext_in.slice(Header.sizeof + h.length, 
                                                   eat)[Header.sizeof .. $];
        }
        catch ( Exception e )
        {
            Trace.formatln("## ERROR: Failsafe catch triggered by exception: {} ({}:{})",
                           e.msg, e.file, e.line);
        }
        
        return null;
    }
          
    
    /***************************************************************************

        Popps the next element
        
    ***************************************************************************/
       
    public ubyte[] pop ( )
    {
        return this.getItem(); 
    }
      
    
    /***************************************************************************

        Returns the element that would be popped next, without poppin it
        
    ***************************************************************************/
       
    public ubyte[] peek ( )
    {
        return this.getItem(false); 
    }
     
    
    /***************************************************************************

        Fills the read buffer
        
        Returns:
            How many new bytes were read from the file

    ***************************************************************************/
       
    private size_t fill ( )
    {
        this.ext_in.compress();
        
        auto bytes    = this.ext_in.populate();
        auto readable = this.ext_in.readable;
        
        if ( (bytes == 0 || bytes == File.Eof) && 
             readable == 0)
        {
            this.closeExternal();
            return 0;
        }    
        
        return bytes;
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
        return 0;
    }
    
    
    /***************************************************************************
    
        Returns:
            number of bytes stored in queue
    
    ***************************************************************************/
    
    public ulong used_space ( )
    {
        return this.bytes_in_file + this.slice_push_buffer.length;
    }    
    
    
    /***************************************************************************
    
        Returns:
            number of bytes free in queue
    
    ***************************************************************************/
    
    public ulong free_space ( )
    {
        return 0;
    }
    
       
    /***************************************************************************
    
        Returns:
            the number of items in the queue
    
    ***************************************************************************/
    
    public uint length ( )
    {
        return this.items_in_file + (this.slice_push_buffer.length > 0 ? 1 : 0);
    }
        
    
    /***************************************************************************
    
        Tells whether the queue is empty.
    
        Returns:
            true if the queue is empty
    
    ***************************************************************************/
    
    public bool is_empty ( )
    {
        return this.items_in_file == 0 && this.slice_push_buffer.length == 0;
    }
    
        
    /***************************************************************************
    
        Deletes all items
                
    ***************************************************************************/
        
    public void clear ( )
    {
        this.items_in_file = this.bytes_in_file = 0;
        this.slice_push_buffer.length = 0;
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
            this.file_out is null && this.openExternal();
            
            this.filePush(this.slice_push_buffer);
            this.slice_push_buffer.length = 0;
        }
    }
        
    
    /***************************************************************************
    
        Pushes item into file
        
        Params:
            item = data to push
            
        Returns:
            true when write was successful, else false
        
    ***************************************************************************/
        
    private bool filePush ( ubyte[] item )
    in
    {
        assert ( item.length < this.size, "Pushed item will not fit read buffer");
    }
    body
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
        this.ext_in  = new BufferedInput(this.file_in, this.size);
    }
    
        
    /***************************************************************************
    
        Closes and deallocates all the files and related buffers 
    
    ***************************************************************************/
        
    private void closeExternal ( )
    in
    {
        assert ( this.ext_in.readable() == 0, 
                 "Still unread data in input buffer" );
        
        assert ( this.bytes_in_file - this.ext_in.readable() == 0 , 
                 "Still bytes in the file");
        
        assert ( this.items_in_file - this.ext_in.readable() == 0 , 
                 "Still items in the file");
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