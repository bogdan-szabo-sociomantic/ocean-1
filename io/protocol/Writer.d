/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Oct 2004: Initial release      
                        Dec 2006: Outback release
        
        author:         Kris 

*******************************************************************************/

module ocean.io.protocol.Writer;

public  import  tango.io.model.IFile,
                tango.io.model.IConduit;

private import  tango.io.stream.Buffered;

private import  ocean.io.protocol.Protocol;

public  import  ocean.io.protocol.model.IWriter;

//version = TRACE;

version ( TRACE )
{
	private import tango.util.log.Trace;
}



/*******************************************************************************

        Writer base-class. Writers provide the means to append formatted 
        data to an IBuffer, and expose a convenient method of handling a
        variety of data types. In addition to writing native types such
        as integer and char[], writers also process any class which has
        implemented the IWritable interface (one method).

        All writers support the full set of native data types, plus their
        fundamental array variants. Operations may be chained back-to-back.

        Writers support a Java-esque put() notation. However, the Tango style
        is to place IO elements within their own parenthesis, like so:

        ---
        write (count) (" green bottles");
        ---

        Note that each written element is distict; this style is affectionately
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

        // write data types out
        write (c) (i) (j) (d);

        // read them back again
        read (c) (i) (j) (d);


        // same thing again, but using put() syntax instead
        write.put(c).put(i).put(j).put(d);
        read.get(c).get(i).get(j).get(d);
        ---

        Writers may also be used with any class implementing the IWritable
        interface, along with any struct implementing an equivalent function.

*******************************************************************************/

class Writer : IWriter
{     
        // the buffer associated with this writer. Note that this
        // should not change over the lifetime of the reader, since
        // it is assumed to be immutable elsewhere 
        package OutputBuffer            output;
        
        package Protocol.ArrayWriter    arrays;
        package Protocol.Writer         elements;

        // end of line sequence
        package char[]                  eol = FileConst.NewlineString;


        /***********************************************************************
        
                Construct a Writer on the provided Protocol

        ***********************************************************************/

        this (Protocol protocol)
        {
                output = protocol.bout;
                elements = &protocol.write;
                arrays = &protocol.writeArray;
        }

        /***********************************************************************
        
                Construct a Writer on the given OutputStream. We do our own
                protocol handling, equivalent to the NativeProtocol.

        ***********************************************************************/

        this ( OutputStream stream )
        {
       		this.attachStream(stream);
       		this();
        }

        /***********************************************************************
        
			Constructor without an output stream.
			
			This constructor used in the case where the output stream doesn't
			exist at the point when the Writer is constructed. An output stream
			can be attached later using the attachStream method, below.
	
	    ***********************************************************************/

        this ( )
        {
        	arrays = &writeArray;
            elements = &writeElement;
        }

        /***********************************************************************
        
			Attaches an output stream to this Writer.
	
			Attempts to use an upstream output buffer if one exists.
	
			Params:
				stream = output stream to connect to
				
	    ***********************************************************************/

        public void attachStream ( OutputStream stream )
        {
        	assert(stream.output, "ASSERT: ocean.io.protocol.Writer.attachStream ( OutputStream ) - passed OutputStream must have a conduit attached");
        	this.output = BufferedOutput.create (stream);
        }

        /***********************************************************************
        
                Emit a newline
                
        ***********************************************************************/

        IWriter newline ()
        {  
                return put (eol);
        }

        /***********************************************************************
        
                set the newline sequence
                
        ***********************************************************************/

        IWriter newline (char[] eol)
        {  
                this.eol = eol;
                return this;
        }

        /***********************************************************************
        
                Flush the output of this writer and return a chaining ref

        ***********************************************************************/

        public IWriter flush ()
        {  
                output.flush;
                return this;
        }

        /***********************************************************************
        
                Flush this writer. This is a convenience method used by
                the "whisper" syntax.
                
        ***********************************************************************/

        public IWriter put () 
        {
                return flush;
        }

        /***********************************************************************
        
                Write via a delegate to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (IWriter.Closure dg) 
        {
                dg (this);
                return this;
        }

        /***********************************************************************
        
                Write a class to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (IWritable x) 
        {
                if (x is null)
                    output.conduit.error ("Writer.put :: attempt to write a null IWritable object");

                return put (&x.write);
        }

        /***********************************************************************
        
                Write a boolean value to the current buffer-position    
                
        ***********************************************************************/

        public IWriter put (bool x)
        {
                elements (&x, x.sizeof, Protocol.Type.Bool);
                return this;
        }

        /***********************************************************************
        
                Write an unsigned byte value to the current buffer-position     
                                
        ***********************************************************************/

        public IWriter put (ubyte x)
        {
                elements (&x, x.sizeof, Protocol.Type.UByte);
                return this;
        }

        /***********************************************************************
        
                Write a byte value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (byte x)
        {
                elements (&x, x.sizeof, Protocol.Type.Byte);
                return this;
        }

        /***********************************************************************
        
                Write an unsigned short value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (ushort x)
        {
                elements (&x, x.sizeof, Protocol.Type.UShort);
                return this;
        }

        /***********************************************************************
        
                Write a short value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (short x)
        {
                elements (&x, x.sizeof, Protocol.Type.Short);
                return this;
        }

        /***********************************************************************
        
                Write a unsigned int value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (uint x)
        {
                elements (&x, x.sizeof, Protocol.Type.UInt);
                return this;
        }

        /***********************************************************************
        
                Write an int value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (int x)
        {
                elements (&x, x.sizeof, Protocol.Type.Int);
                return this;
        }

        /***********************************************************************
        
                Write an unsigned long value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (ulong x)
        {
                elements (&x, x.sizeof, Protocol.Type.ULong);
                return this;
        }

        /***********************************************************************
        
                Write a long value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (long x)
        {
                elements (&x, x.sizeof, Protocol.Type.Long);
                return this;
        }

        /***********************************************************************
        
                Write a float value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (float x)
        {
                elements (&x, x.sizeof, Protocol.Type.Float);
                return this;
        }

        /***********************************************************************
        
                Write a double value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (double x)
        {
                elements (&x, x.sizeof, Protocol.Type.Double);
                return this;
        }

        /***********************************************************************
        
                Write a real value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (real x)
        {
                elements (&x, x.sizeof, Protocol.Type.Real);
                return this;
        }

        /***********************************************************************
        
                Write a char value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (char x)
        {
                elements (&x, x.sizeof, Protocol.Type.Utf8);
                return this;
        }

        /***********************************************************************
        
                Write a wchar value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (wchar x)
        {
                elements (&x, x.sizeof, Protocol.Type.Utf16);
                return this;
        }

        /***********************************************************************
        
                Write a dchar value to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (dchar x)
        {
                elements (&x, x.sizeof, Protocol.Type.Utf32);
                return this;
        }

        /***********************************************************************
        
                Write a boolean array to the current buffer-position     
                                
        ***********************************************************************/

        public IWriter put (bool[] x)
        {
                arrays (x.ptr, x.length * bool.sizeof, Protocol.Type.Bool);
                return this;
        }

        /***********************************************************************
        
                Write a byte array to the current buffer-position     
                                
        ***********************************************************************/

        public IWriter put (byte[] x)
        {
                arrays (x.ptr, x.length * byte.sizeof, Protocol.Type.Byte);
                return this;
        }

        /***********************************************************************
        
                Write an unsigned byte array to the current buffer-position     
                                
        ***********************************************************************/

        public IWriter put (ubyte[] x)
        {
                arrays (x.ptr, x.length * ubyte.sizeof, Protocol.Type.UByte);
                return this;
        }

        /***********************************************************************
        
                Write a short array to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (short[] x)
        {
                arrays (x.ptr, x.length * short.sizeof, Protocol.Type.Short);
                return this;
        }

        /***********************************************************************
        
                Write an unsigned short array to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (ushort[] x)
        {
                arrays (x.ptr, x.length * ushort.sizeof, Protocol.Type.UShort);
                return this;
        }

        /***********************************************************************
        
                Write an int array to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (int[] x)
        {
                arrays (x.ptr, x.length * int.sizeof, Protocol.Type.Int);
                return this;
        }

        /***********************************************************************
        
                Write an unsigned int array to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (uint[] x)
        {
                arrays (x.ptr, x.length * uint.sizeof, Protocol.Type.UInt);
                return this;
        }

        /***********************************************************************
        
                Write a long array to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (long[] x)
        {
                arrays (x.ptr, x.length * long.sizeof, Protocol.Type.Long);
                return this;
        }

        /***********************************************************************
         
                Write an unsigned long array to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (ulong[] x)
        {
                arrays (x.ptr, x.length * ulong.sizeof, Protocol.Type.ULong);
                return this;
        }

        /***********************************************************************
        
                Write a float array to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (float[] x)
        {
                arrays (x.ptr, x.length * float.sizeof, Protocol.Type.Float);
                return this;
        }

        /***********************************************************************
        
                Write a double array to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (double[] x)
        {
                arrays (x.ptr, x.length * double.sizeof, Protocol.Type.Double);
                return this;
        }

        /***********************************************************************
        
                Write a real array to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (real[] x)
        {
                arrays (x.ptr, x.length * real.sizeof, Protocol.Type.Real);
                return this;
        }

        /***********************************************************************
        
                Write a char array to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (char[] x) 
        {
                arrays (x.ptr, x.length * char.sizeof, Protocol.Type.Utf8);
                return this;
        }

        /***********************************************************************
        
                Write a wchar array to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (wchar[] x) 
        {
                arrays (x.ptr, x.length * wchar.sizeof, Protocol.Type.Utf16);
                return this;
        }

        /***********************************************************************
        
                Write a dchar array to the current buffer-position
                
        ***********************************************************************/

        public IWriter put (dchar[] x)
        {
                arrays (x.ptr, x.length * dchar.sizeof, Protocol.Type.Utf32);
                return this;
        }

        /***********************************************************************
        
        	Gets the output buffer
        
        ***********************************************************************/

        public OutputBuffer outputBuffer ( )
        {
        	return this.output;
        }

        /***********************************************************************
        
                Dump array content into the buffer. Note that the default
                behaviour is to prefix with the array byte count 

        ***********************************************************************/

        private void writeArray (void* src, uint bytes, Protocol.Type type)
        {
        	version ( TRACE ) Trace.formatln("Writer.writeArray {}", bytes);
            put (bytes);
            writeElement (src, bytes, type);
        }

        /***********************************************************************
        
                Dump content into the buffer

        ***********************************************************************/

        private void writeElement (void* src, uint bytes, Protocol.Type type)
        {
        	version ( TRACE ) Trace.formatln("Writer.writeElement {}", bytes);
            output.append (src [0 .. bytes]);
        }
}


