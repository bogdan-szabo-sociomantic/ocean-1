/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Oct 2004: Initial release      
                        Dec 2006: Outback release
        
        author:         Kris

*******************************************************************************/

module ocean.io.protocol.Reader;

public  import  tango.io.model.IConduit;

private import  tango.io.stream.Buffered;

private import  ocean.io.protocol.Protocol;

public  import  ocean.io.protocol.model.IReader;

//version = TRACE;

version ( TRACE )
{
	private import tango.util.log.Trace;
}



/*******************************************************************************

        Reader base-class. Each reader operates upon an IBuffer, which is
        provided at construction time. Readers are simple converters of data,
        and have reasonably rigid rules regarding data format. For example,
        each request for data expects the content to be available; an exception
        is thrown where this is not the case. If the data is arranged in a more
        relaxed fashion, consider using IBuffer directly instead.

        All readers support the full set of native data types, plus a full
        selection of array types. The latter can be configured to produce
        either a copy (.dup) of the buffer content, or a slice. See classes
        HeapCopy, BufferSlice and HeapSlice for more on this topic. Applications
        can disable memory management by configuring a Reader with one of the
        binary oriented protocols, and ensuring the optional protocol 'prefix'
        is disabled.

        Readers support Java-esque get() notation. However, the Tango
        style is to place IO elements within their own parenthesis, like
        so:
        
        ---
        int count;
        char[] verse;
        
        read (verse) (count);
        ---

        Note that each element read is distict; this style is affectionately
        known as "whisper". The code below illustrates basic operation upon a
        memory buffer:
        
        ---
        auto buf = new Buffer (256);

        // map same buffer into both reader and writer
        auto read = new Reader (buf);
        auto write = new Writer (buf);

        int i = 10;
        long j = 20;
        double d = 3.14159;
        char[] c = "fred";

        // write data using whisper syntax
        write (c) (i) (j) (d);

        // read them back again
        read (c) (i) (j) (d);


        // same thing again, but using put() syntax instead
        write.put(c).put(i).put(j).put(d);
        read.get(c).get(i).get(j).get(d);
        ---

        Note that certain protocols, such as the basic binary implementation, 
        expect to retrieve the number of array elements from the source. For
        example: when reading an array from a file, the number of elements 
        is read from the file also, and the configurable memory-manager is
        invoked to provide the array space. If content is not arranged in
        such a manner you may read array content directly either by creating
        a Reader with a protocol configured to sidestep array-prefixing, or
        by accessing buffer content directly (via the methods exposed there)
        e.g.

        ---
        void[10] data;
                
        reader.buffer.fill (data);
        ---

        Readers may also be used with any class implementing the IReadable
        interface, along with any struct implementing an equivalent method
        
*******************************************************************************/

class Reader : IReader
{       
        // the buffer associated with this reader. Note that this
        // should not change over the lifetime of the reader, since
        // it is assumed to be immutable elsewhere 
        protected InputBuffer             input;         

        // memory-manager for array requests
        private Allocator               memory;
        private Protocol.Allocator      allocator_;

        // the assigned serialization protocol
        private Protocol.ArrayReader    arrays;
        private Protocol.Reader         elements;


        /***********************************************************************
        
                Construct a Reader upon the provided stream. We do our own
                protocol handling, equivalent to the NativeProtocol. Array
                allocation is supported via the heap

        ***********************************************************************/

        this ( InputStream stream )
        {
       		this.attachStream(stream);
       		this();
        }

        /***********************************************************************
        
			Constructor without an input stream.
			
			This constructor used in the case where the input stream doesn't
			exist at the point when the Reader is constructed. An input stream
			can be attached later using the attachStream method, below.

        ***********************************************************************/

        this ( )
        {
        	allocator_ = &allocate;
            elements   = &readElement;
            arrays     = &readArray;
        }

        /***********************************************************************
        
			Attaches an input stream to this Reader.

			Attempts to use an upstream input buffer if one exists.

			Params:
				stream = input stream to connect to
				
        ***********************************************************************/

        public void attachStream ( InputStream stream )
        {
        	assert(stream.input, "ASSERT: ocean.io.protocol.Reader.attachStream ( InputStream ) - passed InputStream must have a conduit attached");
        	this.input = BufferedInput.create (stream);
        }

        /***********************************************************************

                Construct Reader on the provided protocol. This configures
                the IO conversion to be that of the protocol, but allocation
                of arrays is still handled by the heap
                
        ***********************************************************************/

        this (Protocol protocol)
        {
                allocator_ = &allocate;
                elements   = &protocol.read;
                arrays     = &protocol.readArray;
                input      = protocol.bin;
        }

        /***********************************************************************

                Set the array allocator, and protocol, for this Reader. See
                method allocator() for more info
                
        ***********************************************************************/

        this (Allocator allocator)
        {
                this (allocator.protocol);
                allocator_ = &allocator.allocate;
        }

        /***********************************************************************       
        
                Get the allocator to use for array management. Arrays are
                generally allocated by the IReader, via configured managers.
                A number of Allocator classes are available to manage memory
                when reading array content. Alternatively, the application
                may obtain responsibility for allocation by selecting one of
                the NativeProtocol deriviatives and setting 'prefix' to be
                false. The latter disables internal array management.

                Gaining access to the allocator can expose some additional
                controls. For example, some allocators benefit from a reset
                operation after each data 'record' has been processed.

                By default, an IReader will allocate each array from the 
                heap. You can change that by constructing the Reader
                with an Allocator of choice. For instance, there is a
                BufferSlice which will slice an array directly from
                the buffer where possible. Also available is the record-
                oriented HeaoSlice, which slices memory from within
                a pre-allocated heap area, and should be reset by the client
                code after each record has been read (to avoid unnecessary
                growth). 

                See module tango.io.protocol.Allocator for more information

        ***********************************************************************/

        final Allocator allocator ()
        {
                return memory;
        }

        /***********************************************************************
        
                Extract a readable class from the current read-position
                
        ***********************************************************************/

        final IReader get (IReader.Closure dg) 
        {
                dg (this);
                return this;
        }

        /***********************************************************************
        
                Extract a readable class from the current read-position
                
        ***********************************************************************/

        final IReader get (IReadable x) 
        {
                if (x is null)
                    input.conduit.error ("Reader.get :: attempt to read a null IReadable object");

                return get (&x.read);
        }

        /***********************************************************************

                Extract a boolean value from the current read-position  
                
        ***********************************************************************/

        final IReader get (inout bool x)
        {
                elements (&x, x.sizeof, Protocol.Type.Bool);
                return this;
        }

        /***********************************************************************

                Extract an unsigned byte value from the current read-position   
                                
        ***********************************************************************/

        final IReader get (inout ubyte x) 
        {       
                elements (&x, x.sizeof, Protocol.Type.UByte);
                return this;
        }

        /***********************************************************************
        
                Extract a byte value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout byte x)
        {
                elements (&x, x.sizeof, Protocol.Type.Byte);
                return this;
        }

        /***********************************************************************
        
                Extract an unsigned short value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout ushort x)
        {
                elements (&x, x.sizeof, Protocol.Type.UShort);
                return this;
        }

        /***********************************************************************
        
                Extract a short value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout short x)
        {
                elements (&x, x.sizeof, Protocol.Type.Short);
                return this;
        }

        /***********************************************************************
        
                Extract a unsigned int value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout uint x)
        {
                elements (&x, x.sizeof, Protocol.Type.UInt);
                return this;
        }

        /***********************************************************************
        
                Extract an int value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout int x)
        {
                elements (&x, x.sizeof, Protocol.Type.Int);
                return this;
        }

        /***********************************************************************
        
                Extract an unsigned long value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout ulong x)
        {
                elements (&x, x.sizeof, Protocol.Type.ULong);
                return this;
        }

        /***********************************************************************
        
                Extract a long value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout long x)
        {
                elements (&x, x.sizeof, Protocol.Type.Long);
                return this;
        }

        /***********************************************************************
        
                Extract a float value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout float x)
        {
                elements (&x, x.sizeof, Protocol.Type.Float);
                return this;
        }

        /***********************************************************************
        
                Extract a double value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout double x)
        {
                elements (&x, x.sizeof, Protocol.Type.Double);
                return this;
        }

        /***********************************************************************
        
                Extract a real value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout real x)
        {
                elements (&x, x.sizeof, Protocol.Type.Real);
                return this;
        }

        /***********************************************************************
        
                Extract a char value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout char x)
        {
                elements (&x, x.sizeof, Protocol.Type.Utf8);
                return this;
        }

        /***********************************************************************
        
                Extract a wide char value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout wchar x)
        {
                elements (&x, x.sizeof, Protocol.Type.Utf16);
                return this;
        }

        /***********************************************************************
        
                Extract a double char value from the current read-position
                
        ***********************************************************************/

        final IReader get (inout dchar x)
        {
                elements (&x, x.sizeof, Protocol.Type.Utf32);
                return this;
        }

        /***********************************************************************

                Extract an boolean array from the current read-position   
                                
        ***********************************************************************/

        final IReader get (inout bool[] x) 
        {
                return loadArray (cast(void[]*) &x, bool.sizeof, Protocol.Type.Bool);
        }

        /***********************************************************************

                Extract an unsigned byte array from the current read-position   
                                
        ***********************************************************************/

        final IReader get (inout ubyte[] x) 
        {
                return loadArray (cast(void[]*) &x, ubyte.sizeof, Protocol.Type.UByte);
        }

        /***********************************************************************
        
                Extract a byte array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout byte[] x)
        {
                return loadArray (cast(void[]*) &x, byte.sizeof, Protocol.Type.Byte);
        }

        /***********************************************************************
        
                Extract an unsigned short array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout ushort[] x)
        {
                return loadArray (cast(void[]*) &x, ushort.sizeof, Protocol.Type.UShort);
        }

        /***********************************************************************
        
                Extract a short array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout short[] x)
        {
                return loadArray (cast(void[]*) &x, short.sizeof, Protocol.Type.Short);
        }

        /***********************************************************************
        
                Extract a unsigned int array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout uint[] x)
        {
                return loadArray (cast(void[]*) &x, uint.sizeof, Protocol.Type.UInt);
        } 

        /***********************************************************************
        
                Extract an int array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout int[] x)
        {
                return loadArray (cast(void[]*) &x, int.sizeof, Protocol.Type.Int);
        }

        /***********************************************************************
        
                Extract an unsigned long array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout ulong[] x)
        {
                return loadArray (cast(void[]*) &x, ulong.sizeof, Protocol.Type.ULong);
        }

        /***********************************************************************
        
                Extract a long array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout long[] x)
        {
                return loadArray (cast(void[]*) &x,long.sizeof, Protocol.Type.Long);
        }

        /***********************************************************************
        
                Extract a float array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout float[] x)
        {
                return loadArray (cast(void[]*) &x, float.sizeof, Protocol.Type.Float);
        }

        /***********************************************************************
        
                Extract a double array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout double[] x)
        {
                return loadArray (cast(void[]*) &x, double.sizeof, Protocol.Type.Double);
        }

        /***********************************************************************
        
                Extract a real array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout real[] x)
        {
                return loadArray (cast(void[]*) &x, real.sizeof, Protocol.Type.Real);
        }

        /***********************************************************************
        
                Extract a char array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout char[] x)
        {
                return loadArray (cast(void[]*) &x, char.sizeof, Protocol.Type.Utf8);
        }

        /***********************************************************************
        
                Extract a wchar array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout wchar[] x)
        {
                return loadArray (cast(void[]*) &x, wchar.sizeof, Protocol.Type.Utf16);
        }

        /***********************************************************************
        
                Extract a dchar array from the current read-position
                
        ***********************************************************************/

        final IReader get (inout dchar[] x)
        {
                return loadArray (cast(void[]*) &x, dchar.sizeof, Protocol.Type.Utf32);
        }


        
        /***********************************************************************
        
        ***********************************************************************/

        private IReader loadArray (void[]* x, uint width, Protocol.Type type)
        {
                *x = arrays (x.ptr, x.length * width, type, allocator_) [0 .. $/width];
                return this;
        }
        
        /***********************************************************************

        ***********************************************************************/

        private void[] allocate (Protocol.Reader reader, uint bytes, Protocol.Type type)
        {
                return reader ((new void[bytes]).ptr, bytes, type);
        }

        /***********************************************************************

        ***********************************************************************/

        private void[] readElement (void* dst, uint bytes, Protocol.Type type)
        {
        	version ( TRACE ) Trace.formatln("Reader.readElement... (trying to read {} bytes from buffer pos {})", bytes, (cast(BufferedInput)input).position);

        	auto content = dst[0 .. bytes];
	        this.fill(content, true);

	        version ( TRACE ) Trace.formatln("   read {} bytes", bytes);

	        return content;
        }

        /***********************************************************************

			Fills the provided array with data from the input buffer.

			Copied from BufferedInput, as it's not accessible, but seems
			necessary for the desired behaviour of the Reader.
			
        ***********************************************************************/

        protected size_t fill ( void[] dst, bool exact = false )
        {
            size_t len = 0;

            while ( len < dst.length )
            {
                size_t i = this.input.read (dst[len .. $]);
                if ( i is IOStream.Eof )
                {
                	if ( exact && len < dst.length )
                	{
                		this.input.conduit.error("Reader - end of flow while reading");
                	}
                    return (len > 0) ? len : IOStream.Eof;
                }
                len += i;
            }
            return len;
        }

        /***********************************************************************

        ***********************************************************************/

        private void[] readArray (void* dst, uint bytes, Protocol.Type type, Protocol.Allocator alloc)
        {
        	version ( TRACE ) Trace.formatln("Reader.readArray");
            readElement (&bytes, bytes.sizeof, Protocol.Type.UInt);
            if ( bytes )
            {
            	auto ret = alloc (&readElement, bytes, type);
            	version ( TRACE ) Trace.formatln("Reader.readArray DONE - {}", ret.length);
            	return ret;
            }
            else
            {
            	version ( TRACE ) Trace.formatln("Reader.readArray DONE - []");
            	return [];
            }
        }
}

