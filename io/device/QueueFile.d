/******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        July 2004: Initial release      
                        May 2008:  FIFO release
                        
        author:         Thomas Nicolai

*******************************************************************************/

module  ocean.io.device.QueueFile;

private import  tango.io.FilePath, tango.io.device.File;

private import  tango.util.log.model.ILogger;

private import  tango.net.cluster.model.IChannel;


version ( QueueTrace )
{
	private import tango.util.log.Trace;
	private import Integer = tango.text.convert.Integer;
	private import Float = tango.text.convert.Float;
}


/******************************************************************************

        QueueFile

        QueueFile implements a persitent FIFO queue to push and pop 
        a large quantity of data to/from. Each item in the queue 
        consists of the data itself and a message header.
        
        What follows is an example on how to use this QueueFile
        implementation:
        
        ---
        import tango.util.log.Log, 
               tango.util.log.AppendConsole;
        
        auto log = Log.getLogger("queue.persist");
        auto appender = new AppendConsole;
        
        log.add(appender);
        
        auto queue = new QueueFile (log, "foo.bar", 1024);
        
        // insert some data, and retrieve it again
        auto text = "this is a test";
        
        queue.push (text);
        auto item = queue.pop ();
        
        assert (item == text);
        queue.close;
        
        ---

        TODO        truncate method to reduce file size
                    after remaping (if we have to much
                    free space wasted at the queues rear)
                    
                    check the rear of the queue in the
                    isDirty method too not only the front

                    Using FileMap/mmap in the future
                    instead of seeks
        ---
        
******************************************************************************/

class QueueFile
{
    
        /**********************************************************************
         
                Message Header
        
        **********************************************************************/    
    
        struct Header                           // 16 bytes
        {
                uint    size,                   // size of the current chunk
                        prior;                  // size of the prior chunk
                ushort  check;                  // simpe header checksum
                ubyte   pad;                    // how much padding applied?
                byte[5] unused;                 // future use
        }

        /**********************************************************************
        
                Queue Implementation

        **********************************************************************/  
        
        private ILogger         log;            // logging target
        private char[]          name;           // name
        private long            limit,          // max file size
                                insert,         // rear insert position of queue (push)
                                first,          // front position of queue (pop)       
                                items;          // number of items in the queue
        private void[]          buffer;         // read buffer
        private Header          current;        // top-of-stack info
        private File            conduit;        // the file itself
        private IChannel        channel_;       // the channel we're using
        
        /**********************************************************************

                Constructor (Channel)
                
                param: logger instance
                param: cluster channel
                param: max queue size (bytes)
                param: initial queue size on start (bytes)
                
        **********************************************************************/

        this (ILogger log, IChannel channel, uint max, uint min=1024*1024)
        {
                this (log, channel.name~".queue", max, min);
                channel_ = channel;
        }

        /**********************************************************************
            
                Constructor (Name)
                                
                param: logger instance
                param: name(file path) of queue
                param: max queue size (bytes)
                param: initial queue size on start (bytes)
                
                Create or open existing persistent queue with the given
                name. Be aware that opening a large queue file might
                take some time to find the front and rear of the queue.
                Moreover, the remapping (flushing) needs some time too.
                
                Note: No file locking needs to be done as this 
                is already done by File.
                
        **********************************************************************/

        this (ILogger log, char[] name, uint max, uint min=1024*1024)
        {
               Header chunk;

               this.log  = log;
               this.name = name;
               limit     = max;
               buffer    = new void [1024 * 8];
               conduit   = new File (name, File.ReadWriteOpen);
               
               auto length = conduit.length;
               
               if (length is 0)
               {
                       // initialize file with min length
                       min = (min + buffer.length - 1) / buffer.length;
                       
                       log.trace ("initializing queue '{}' to {} KB", name, (min * buffer.length)/1024);
                      
                       while (min-- > 0)
                               write (buffer.ptr, buffer.length);
                       
                       conduit.seek (0);
               }
               else
               {
                       // find front and rear position of queue
                       while (insert < length)
                       {
                               // get a header
                               read (&chunk, chunk.sizeof);
                            
                               // end of queue?
                               if (chunk.size)
                               {
                                       if (checksum(chunk) != chunk.check)
                                       {
                                               log.error ("Invalid header located in queue '{}': truncating after item {}", name, items);
                                               break;
                                       }
                                   
                                       if (chunk.prior == 0)
                                       {
                                               first = insert;
                                               items = 0;
                                       }
                                       
                                       ++items;
                                       
                                       current = chunk;
                                       insert = insert + chunk.size + chunk.sizeof;
                                       
                                       conduit.seek (insert);
                               }
                               else
                                       break;
                       }
                       
                       log.trace ("initializing queue '{}' [ queue front pos = {} queue rear pos = {} items = {}]", name, first, insert, items);
                       
                       remap();
               }
        }
        
        /**********************************************************************

                Close queue

        **********************************************************************/

        final void close ()
        {
                if (conduit)
                        conduit.detach;
                
                conduit = null;
        }
        
        /**********************************************************************

                Returns number of items in the queue

        **********************************************************************/

        final uint size ()
        {
                return items;
        }
        
        /**********************************************************************

                Returns cluster channel

        **********************************************************************/

        final IChannel channel ()
        {
                return channel_;
        }
        
        /**********************************************************************

                Returns queue status
                
                The queue is dirty if more than 50% of the front 
                of the queue is wasted and not used.

        **********************************************************************/

        final bool isDirty ()
        {
                if ( first > 0 && (limit/first) < 2)
                    return true;
                
                return false;
        }
        
        /**********************************************************************

		        Returns true if queue is full (items >= limit)
		
		**********************************************************************/
		
		final bool isFull ()
		{
		        return items >= limit;
		}

        /**********************************************************************

                Free wasted blocks at the queue front

        **********************************************************************/

        final synchronized void flush ()
        {
                 remap();
        }
        
        /**********************************************************************

                Push item to the rear of the queue
    
        **********************************************************************/

        final synchronized bool push (void[] data)
        {
                if (data.length is 0)
                    conduit.error ("invalid zero length content");

                // check if queue is full and try to remap queue
                if (insert > limit )
                {
                        if ( !remap )
                        {
                                log.trace ("queue '{}' full with {} items", name, items);
                                return false;
                        }
                }
                
                conduit.seek(insert);
                
                Header chunk = void;

                // pad the output to 4 byte boundary, so  
                // that each header is aligned
                chunk.prior = current.size;
                chunk.size  = ((data.length + 3) / 4) * 4;
                chunk.pad   = cast(ubyte) (chunk.size - data.length);
                chunk.check = checksum (chunk);
                
                write (&chunk, chunk.sizeof); // write queue message header
                write (data.ptr, chunk.size); // write data
                
                // update refs
                insert = insert + chunk.sizeof + chunk.size;
                
                current = chunk;
                
                // write a zero header to indicate eof
                conduit.seek(insert);
                Header zero;
                write (&zero, zero.sizeof);
                
                ++items;
                
                return true;
        }

        /**********************************************************************

                Pop item from the front of the queue
                
        **********************************************************************/

        final synchronized void[] pop ()
        {
                Header chunk = void;

                if (insert)
                {
                   if (first < insert)
                   {
                       // seek to front position of queue
                       conduit.seek (first);
                       
                       // reading header & data of chunk (queue front)
                       read (&chunk, chunk.sizeof);
                       auto content = read (chunk, chunk.pad); 
                       
                       // update next chunk prior size to zero
                       if (items > 1)
                       {
                               // updating front seek position to next chunk
                               first = first + chunk.sizeof + chunk.size;
                               
                               conduit.seek (first);
    
                               read (&chunk, chunk.sizeof);
                               
                               chunk.prior = 0;
                               chunk.check = checksum (chunk);
                               
                               conduit.seek(first);
                               
                               write (&chunk, chunk.sizeof); // update message header
                       }
                       else if (items == 1)
                       {
                               // reset queue
                               conduit.seek (first = insert = 0);
    
                               Header zero;
                               write (&zero, zero.sizeof);
                       }
                       
                       --items;
                       
                       return content;
                   }
                   else
                   {
                       // no element left in queue (reset first and insert to zero)
                       insert = first = 0;
                       
                       // do we need to reset the whole file
                   }
                }
                    
                return null;
        }
        
        /**********************************************************************
                
                Read header.

        **********************************************************************/

        private final void[] read (inout Header hdr, uint pad=0)
        {
                auto len = hdr.size - pad;

                // make buffer big enough
                if (buffer.length < len)
                    buffer.length = len;

                read (buffer.ptr, len);
                
                return buffer [0 .. len];
        }
        
        /**********************************************************************

                Read data.
                
        **********************************************************************/

        private final void read (void* data, uint len)
        {
                auto input = conduit.input;

                for (uint i; len > 0; len -= i, data += i)
                     if ((i = input.read (data[0..len])) is conduit.Eof)
                          conduit.error ("QueueFile.read :: Eof while reading");
        }
        
        /**********************************************************************
                
                Write data.
                
        **********************************************************************/

        private final void write (void* data, uint len)
        {
                auto output = conduit.output;

                for (uint i; len > 0; len -= i, data += i)
                     if ((i = output.write (data[0..len])) is conduit.Eof)
                          conduit.error ("QueueFile.write :: Eof while writing");
        }
        
        /**********************************************************************
                
                Create checksum.
                
        **********************************************************************/

        private static ushort checksum (inout Header hdr)
        {
                uint i = hdr.pad;
                
                i = i ^ hdr.size  ^ (hdr.size >> 16);
                i = i ^ hdr.prior ^ (hdr.prior >> 16);
                
                return cast(ushort) i;
        }
        
        /**********************************************************************
        
                Remap file.
        
                Remapping the queue file. If the insert position 
                reaches EOF and the first chunk at the queues front 
                is not at seek position 0 we can remap the file 
                from size = [first..insert] to [0..size]. Returns
                true if remap could free some file space.
                
        **********************************************************************/
        
        private final bool remap ()
        {
            log.trace ("Thinking about remapping queue '{}'", name);

            uint i, pos;
//            auto buffer = new void[16];
//            if (first == 0 || first < buffer.sizeof)

            // I think this works better (Gavin)
			if (first == 0 || first < limit / 4)
			{
				return false;
			}

            this.logSeekPositions("Old seek positions");
                    
            auto input = conduit.input;
            auto output = conduit.output;
            
            while ((first + pos) < insert && i !is conduit.Eof)
            {
                    // seek to read position
                    conduit.seek(first + pos);
                    i = input.read (buffer);
                    
                    if ( i !is conduit.Eof )
                    {
                            // seek to write position
                            conduit.seek(pos);
                            output.write (buffer[0..i]);
                            
                            pos += i;
                    }
            }
            
            conduit.seek(insert = insert - first);
            first = 0;
            
            // write zero header to indicate Eof
            Header zero;
            write (&zero, zero.sizeof);
            
            this.logSeekPositions("Remapping done, new seek positions");

            return true;
        }


        /***********************************************************************
         * 
         * Outputs the queue's current seek positions to the log.
         * 
         * If compiled as the QueueTrace version, also outputs a message to
         * Trace.
         * 
         * Params:
         *     str = message to prepend to seek positions output 
         */

        protected void logSeekPositions ( char[] str )
        {
	        version ( QueueTrace )
	        {
	        	Trace.format("\nRemapping {} ", this.name);
	        	this.traceSeekPositions(true);
	        }
	
	        log.trace ("{} [ front = {} rear = {} ]", str, first, insert);
        }


        version ( QueueTrace )
        {
        	/*******************************************************************
        	 * 
        	 * Internal character buffer, used repeatedly for string formatting
        	 */

        	protected char[] trace_buf;

        	
        	/*******************************************************************
        	 * 
        	 * Prints the queue's current seek positions to Trace.
        	 * 
        	 * Params:
        	 *     show_pcnt = show seek positions as a % o the queue's total
        	 *     		size
        	 *     nl = output a newline after the seek positions info
        	 */

        	public void traceSeekPositions ( bool show_pcnt, bool nl = true )
        	{
        		this.trace_buf = "";
        		this.formatSeekPositions(this.trace_buf, show_pcnt, nl);
        		Trace.format(this.trace_buf).flush;
        	}
        	

        	/*******************************************************************
        	 *
        	 * Format a string with the queue's current start and end seek
        	 * positions.
        	 * 
        	 * Params:
        	 *     buf = string buffer to be written into
        	 *     show_pcnt = show seek positions as a % o the queue's total
        	 *     		size
        	 *     nl = write a newline after the seek positions info
        	 */        	

        	public void formatSeekPositions ( ref char[] buf, bool show_pcnt, bool nl = true )
        	{
        		float first_pcnt = 100.0 * (cast(float) this.first / cast(float) this.limit);
        		float insert_pcnt = 100.0 * (cast(float) this.insert / cast(float) this.limit);

        		if ( show_pcnt )
        		{
        			buf ~= "[" ~ Integer.toString(this.first) ~ " (" ~ Float.toString(first_pcnt) ~ "%).."
    				~ Integer.toString(this.insert) ~ " (" ~ Float.toString(insert_pcnt) ~ "%)]";
        		}
        		else
        		{
        			buf ~= "[" ~ Integer.toString(this.first) ~ ".." ~ Integer.toString(this.insert) ~ "]";
        		}

    			if ( this.isFull() )
    			{
    				buf ~= "F";
    			}

    			if ( this.isDirty() )
    			{
    				buf ~= "D";
    			}

    			if ( nl )
        		{
        			buf ~= "\n";
        		}
        	}
        }
}


/******************************************************************************

        QueueFile Test

******************************************************************************/

version (QueueFile)
{
        import  tango.time.StopWatch;

        import  tango.util.log.Log, 
                tango.util.log.AppendConsole;

        void main (char[][] args)
        {
                auto log = Log.getLogger("queue.persist");
                auto appender = new AppendConsole;
                
                log.add(appender);
                
                auto z = new QueueFile (log, "foo.bar", 30 * 1024 * 1024);
                
                pushTimer (z);
                
                z.close;
        }

        void pushTimer (QueueFile z)
        {
                StopWatch w;
                char[200] test;
                
                popAll(z);
                w.start;
                
                for (int i=10_000; i--;)
                     z.push(test);
                
                z.log.info ("{} push/s", 10_000/w.stop);
                
                popAll(z);
        }

        void push (QueueFile z)
        {
                z.push ("one");
                z.push ("two");
                z.push ("three");
                z.push ("four");
                z.push ("five");
                z.push ("six");
                z.push ("seven");
                z.push ("eight");
                z.push ("nine");
                z.push ("ten");
                z.push ("eleven");
        }

        void popAll(QueueFile z)
        {        
                uint i;
                StopWatch w;

                w.start;
                
                while (z.pop !is null) ++i;
                
                z.log.info ("{}, {} pop/s",i, i/w.stop);
        }       
}
