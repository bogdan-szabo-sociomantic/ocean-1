/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Mar 2004: Initial release
                        Dec 2006: Outback release
                        May 2010: Memory version (static, random access)

        authors:        Kris Bell / Gavin Norman

		A static (non-expanding) memory buffer implementing the Conduit abstract
		base class, as well as InputBuffer, OutputBuffer and Conduit.Seek.

		Adapted from tango.io.device.Conduit and tango.io.device.Array.
		
		tango.io.device.Array implements a memory array which always appends
		new data to the end.
		
		The Memory conduit is random access - data can be read from or written
		to the seek position.

*******************************************************************************/

module ocean.io.device.Memory;



/*******************************************************************************

	Imports

*******************************************************************************/

private import tango.core.Exception;

private import tango.io.device.Conduit;



/*******************************************************************************

	C memcpy

*******************************************************************************/

extern (C)
{
        protected void * memcpy (void *dst, void *src, size_t);
}



/*******************************************************************************

	Memory class

*******************************************************************************/

class Memory : Conduit, InputBuffer, OutputBuffer, Conduit.Seek
{
        protected void[]  data;                 // the raw data buffer
        protected size_t  index;                // current read / write position
        protected size_t  last_write_pos;		// maximum written position

        protected static char[] overflow  = "output buffer is full";
        protected static char[] underflow = "input buffer is empty";
        protected static char[] eofRead   = "end-of-flow while reading";
        protected static char[] eofWrite  = "end-of-flow while writing";


        /***********************************************************************

		        Ensure the buffer remains valid between method calls
		
		***********************************************************************/
		
		invariant
		{
	        assert (this.index >= 0);
	        assert (this.index <= this.data.length);
		}

        /***********************************************************************

			Allocates a memory buffer of the specified capacity.
			
			Params:
				capacity = size in bytes of the memory array

		***********************************************************************/
		
        public this ( uint capacity )
		{
            this.assign(new ubyte[capacity]);
			super();
		}
		
        /***********************************************************************

		        Construct a buffer
		
		        Params:
		        	data = the backing array to buffer within
		
		        Remarks:
		        Prime a buffer with an application-supplied array. All content
		        is considered valid for reading, and thus there is no writable
		        space initially available.
		
		***********************************************************************/
		
        public this (void[] data)
		{
        	assign(data);
		}


		/***********************************************************************
		
		        Clean up when collected. See method detach()
		
		***********************************************************************/
		
        public ~this ()
		{
		        this.detach;
		}
		
        /***********************************************************************

		        Reset the buffer content with the passed array.
		
		        Params:
		        data =  the backing array to buffer within. All content
		                is considered valid
		
		        Returns:
		        the buffer instance
		
		***********************************************************************/
		
		public Memory assign (void[] data)
		{
	        this.data = data;
			
	        // reset to start of input
	        this.index = 0;
	        this.last_write_pos = 0;
	        return this;
		}
		

		/***********************************************************************
		
		        Return the name of this conduit
		
		***********************************************************************/
		
		public char[] toString ()
		{
			return "<memory>";
		}
		             
		/***********************************************************************
		
		        Return a preferred size for buffering conduit I/O
		
		***********************************************************************/
		
		public size_t bufferSize ()
		{
            return data.length;
		}
		
		/***********************************************************************
		
		        Read from conduit into a target array. The provided dst 
		        will be populated with content from the conduit's seek position.
		
		        Returns the number of bytes read, which may be less than
		        requested in dst. Eof is returned whenever an end-of-flow 
		        condition arises.
		
		***********************************************************************/
		
		public size_t read (void[] dst)
		{
			size_t ret;

			uint read_len = dst.length;
			if ( this.index + read_len > this.data.length )
			{
				ret = IConduit.Eof;
			}
			else
			{
				dst[0..$] = this.data[this.index..this.index + read_len];
				this.index += read_len;
				ret = read_len;
			}

            return ret;
		}
		
		/***********************************************************************
		
		        Write to conduit from a source array. The provided src
		        content will be written to the conduit's seek position.
		
		        Returns the number of bytes written from src, which may
		        be less than the quantity provided. Eof is returned when 
		        an end-of-flow condition arises.
		
		***********************************************************************/
		
		public size_t write (void [] src)
		{
			size_t ret;

			uint write_len = src.length;
			if ( this.index + write_len > this.data.length )
			{
				ret = IConduit.Eof;
			}
			else
			{
				memcpy(&data[index], src.ptr, write_len);
				this.index += write_len;
				ret = write_len;
				if(this.index < this.last_write_pos)
				{
					this.last_write_pos = this.index;
				}
			}

            return ret;
		}
		
		/***********************************************************************
		
		        Disconnect this conduit. Note that this may be invoked
		        both explicitly by the user, and implicitly by the GC.
		        Be sure to manage multiple detachment requests correctly:
		        set a flag, or sentinel value as necessary
		
		***********************************************************************/
		
		public void detach ()
		{
		}

		/***********************************************************************
		
		        Seek on this stream.
		
		***********************************************************************/
		
		long seek (long offset, Anchor anchor = Anchor.Begin)
		{
			long limit = cast(long) this.data.length;
            if (offset > limit)
            {
                offset = limit;
            }

            switch (anchor)
            {
               case Anchor.End:
                    this.index = cast(size_t) (limit - offset);
                    break;

               case Anchor.Begin:
            	   this.index = cast(size_t) offset;
                    break;

               case Anchor.Current:
                    long o = cast(size_t) (this.index + offset);
                    if (o < 0)
                        o = 0;
                    if (o > cast(long) limit)
                        o = limit;
                    this.index = cast(size_t) o;
               default:
                    break;
            }
            return this.index;
		}
		
        /***********************************************************************
        
                Return a void[] read of the buffer from start to end, where
                end is exclusive

        ***********************************************************************/

        public void[] opSlice (size_t start, size_t end)
        {
                assert (start <= this.data.length && end <= this.data.length  && start <= end);
                return this.data [start .. end];
        }

        /***********************************************************************

                Retrieve all content from the seek position to the last written
                position.

                Returns:
                a void[] read of the buffer

                Remarks:
                Return a void[] read of the buffer, from the current position
                up to the limit of valid content. The content remains in the
                buffer for future extraction.

        ***********************************************************************/

        public void[] slice ()
        {
                return this.data [index .. this.last_write_pos];
        }

        /***********************************************************************

                Access buffer content

                Params:
                size =  number of bytes to access
                eat =   whether to consume the content or not

                Returns:
                the corresponding buffer slice when successful, or
                null if there's not enough data available (Eof; Eob).

                Remarks:
                Slices data. The specified number of bytes is
                read from the buffer, and marked as having been read
                when the 'eat' parameter is set true. When 'eat' is set
                false, the seek position is not adjusted.

                Note that the slice cannot be larger than the size of
                the buffer - use method read(void[]) instead where you
                simply want the content copied. 
                
                Note also that the slice should be .dup'd if you wish to
                retain it.

        ***********************************************************************/

        public void[] slice (size_t size, bool eat = true)
        {
                if (this.index + size > this.data.length)
                {
                	this.error(underflow);
                }

                auto i = this.index;
                if (eat)
                {
                	this.index += size;
                }
                return this.data [i .. i + size];
        }

        /***********************************************************************

		        Iterator support
		
		        Params:
		        scan = the delagate to invoke with the current content
		
		        Returns:
		        Returns true if a token was isolated, false otherwise.
		
		        Remarks:
		        Upon success, the delegate should return the byte-based
		        index of the consumed pattern (tail end of it). Failure
		        to match a pattern should be indicated by returning an
		        IConduit.Eof
		
		        Note that additional iterator and/or reader instances
		        will operate in lockstep when bound to a common buffer.
		
		***********************************************************************/
		
		public bool next (size_t delegate (void[]) scan)
		{
		        return reader (scan) != IConduit.Eof;
		}

        /***********************************************************************

		        Write into this buffer
		
		        Params:
		        dg = the callback to provide buffer access to
		
		        Returns:
		        Returns whatever the delegate returns.
		
		        Remarks:
		        Exposes the raw data buffer at the current seek position,
		        The delegate is provided with a void[] representing space
		        available within the buffer from the current seek position to
		        the end.
		
		        The delegate should return the appropriate number of bytes
		        if it writes valid content, or IConduit.Eof on error. The seek
		        position is advanced by the number of bytes written.
		
		***********************************************************************/
		
		public size_t writer (size_t delegate (void[]) dg)
		{
		        auto count = dg (this.data [this.index..$]);
		
		        if (count != IConduit.Eof)
		        {
		           this.index += count;
		        }
		        return count;
		}
		
		/***********************************************************************
		
		        Read directly from this buffer
		
		        Params:
		        dg = callback to provide buffer access to
		
		        Returns:
		        Returns whatever the delegate returns.
		
		        Remarks:
		        Exposes the raw data buffer at the current seek position. The
		        delegate is provided with a void[] representing the available
		        data, and should return zero to leave the current seek position
		        intact.
		
		        If the delegate consumes data, it should return the number of
		        bytes consumed; or IConduit.Eof to indicate an error. The seek
		        position is advanced by the number of bytes read by the delegate.
		
		***********************************************************************/

		public size_t reader (size_t delegate (void[]) dg)
		{
		        auto count = dg (this.data [this.index..this.last_write_pos]);
		
		        if (count != IConduit.Eof)
		        {
		           this.index += count;
		        }
		        return count;
		}

        /***********************************************************************

		        Append content
		
		        Params:
		        src = the content to _append
		        length = the number of bytes in src
		
		        Returns a chaining reference if all content was written.
		        Throws an IOException indicating eof or eob if not.
		
		        Remarks:
		        Append an array to this buffer
		
		***********************************************************************/
		
		public Memory append (void[] src)
		{
				this.seek(this.last_write_pos);
				if (write(src) is Eof)
				{
		            error (overflow);
				}
		        return this;
		}

        /***********************************************************************

                Cast to a target type without invoking the wrath of the
                runtime checks for misalignment. Instead, we truncate the
                array length

        ***********************************************************************/

        private static T[] convert(T)(void[] x)
        {
                return (cast(T*) x.ptr) [0 .. (x.length / T.sizeof)];
        }
}


