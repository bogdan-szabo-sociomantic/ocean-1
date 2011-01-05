/*******************************************************************************

    Class for get array forwarding. Receives arrays from a data input buffer,
    possibly decompresses compressed data, and forwards to an output destination
    (a stream buffer, delegate, etc).

    Gets single arrays, lists of arrays and lists of pairs.
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
                    January 2011: Unified / simplified version
    
    authors:        Gavin Norman

    Usage example:
    
    ---

        import ocean.core.Array;

        import ocean.io.select.protocol.serializer.SelectArraysDeserializer;

        class AsyncReceiver
        {
            char[][] arrays_received;
            
            SelectArraysDeserializer get;
            
            this ( )
            {
                this.get = new SelectArraysDeserializer();
            }

            void reset ( )
            {
                this.arrays_received.length = 0;

                const bool decompress = true;

                this.get.arrayList(decompress);
            }

            bool asyncReceive ( void[] input, ref ulong cursor )
            {
                return this.get.transmitArrays(&this.receiveArrays, input, cursor);
            }

            void receiveArrays ( char[] array )
            {
                if ( array.length )
                {
                    this.arrays_received.appendCopy(array);
                }
                else
                {
                    // received end of list terminator
                }
            }
        }

    ---

*******************************************************************************/

module ocean.io.select.protocol.serializer.SelectArraysDeserializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import ocean.io.select.protocol.serializer.model.ISelectArraysTransmitter;

private import ocean.io.select.protocol.serializer.chunks.dest.model.IChunkDest;

private import ocean.io.select.protocol.serializer.SelectDeserializer;

private import ocean.io.compress.lzo.LzoChunk;

private import ocean.io.compress.lzo.LzoHeader;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Alias for an output delegate which is called when an array has been
    deserialized.

*******************************************************************************/

public alias void delegate ( char[] ) OutputDg;



/*******************************************************************************

    Array deserialization class.

    Asynchronously gets arrays from an input buffer, and sends them to an output
    delegate.

    The class handles several types of serialization:

        1. Simple arrays.
        2. Lzo compressed arrays (split into a series of chunks).
        3. Forwarding previously lzo compressed (chunked) arrays. 

    Note: Although reading from the input delegate will always succeed (as it's
    just a delegate which provides the array to process), on the other hand,
    writing to the output buffer must be interruptable / resumable, as we may
    have to write half variables.

    
    Gets arrays from the input buffer, using an instance of ChunkDeserializer,
    and sends them to output destination (an instance of a class derived from
    IChunkDest).

    Note: Writing to the output device will always succeed (as it's either a
    variable in memory or a socket, which will block until the data is
    sent).
    
    On the other hand, reading from the input buffer must be interruptable /
    resumable, as we may have to read half variables.

*******************************************************************************/

class SelectArraysDeserializer : ISelectArraysTransmitter!(OutputDg)
{
    /***************************************************************************
    
        Processing state
    
    ***************************************************************************/
    
    enum State
    {
        Initial,
        GetFirstArray,
        HandleArray,
        GetNextArray,
        TransmitArray,
        Finished
    }

    private State state;
    
    
    // TODO
    private void[] array;


    private ulong array_read_cursor;



    abstract private class ArrayDeserializer
    {
        // return true to get more arrays before calling the output delegate
        abstract public bool receive ( void[] input, ref void[] output );
    }

    private class SimpleArrayDeserializer : ArrayDeserializer
    {
        // return true to get more arrays before calling the output delegate
        public bool receive ( void[] input, ref void[] output )
        {
            Trace.formatln("[*] got array");
            output.copy(input);
            return false;
        }
    }


    private class ChunkedArrayDeserializer : ArrayDeserializer
    {
        // return true to get more arrays before calling the output delegate
        public bool receive ( void[] input, ref void[] output )
        {
            Trace.formatln("[*] got array chunk");

            LzoHeader!(false) header;
            auto payload = header.read(input);

            ubyte[size_t.sizeof] chunk_length; // using ubyte as cannot define static void array
            *(cast(size_t*)chunk_length.ptr) = input.length;
            
            output ~= chunk_length;
            output ~= input;

            return header.type != header.type.Stop;
        }
    }


    private class DecompressingArrayDeserializer : ArrayDeserializer
    {
        /***********************************************************************
        
            LzoChunk instance (decompressor) & working buffer.
        
        ***********************************************************************/
        
        protected LzoChunk!(false) lzo;
        
        protected void[] lzo_buffer;


        this ( )
        {
            this.lzo = new LzoChunk!(false);
            this.lzo_buffer = new void[1024];
        }
        
        ~this ( )
        {
            delete this.lzo;
            delete this.lzo_buffer;
        }

        // return true to get more arrays before calling the output delegate
        public bool receive ( void[] input, ref void[] output )
        {
            Trace.formatln("[*] got array chunk - decompressing");

            LzoHeader!(false) header;
            auto payload = header.read(input);

            auto uncompressed = this.uncompress(header, payload, input);
            output ~= uncompressed;

            return header.type != header.type.Stop;
        }

        /***********************************************************************
        
            Decompresses content from an array.
        
            Params:
                header = compression header
                payload = possibly compressed payload
                whole_chunk = array containing header + payload
            
            Returns:
                decompressed payload
        
        ***********************************************************************/
        
        protected void[] uncompress ( LzoHeader!(false) header, void[] payload, void[] whole_chunk )
        {
            switch ( header.type )
            {
                case header.Type.Start:
                    Trace.formatln("[*] Start chunk");
                    return [];
                break;
    
                case header.Type.LZO1X:
                    Trace.formatln("[*] Uncompressing chunk");
                    this.lzo.uncompress(whole_chunk, this.lzo_buffer);
                    return this.lzo_buffer;
                break;
        
                case header.Type.None:
                    Trace.formatln("[*] Not compressed chunk");
                    return payload;
                break;
        
                case header.Type.Stop:
                    Trace.formatln("[*] Stop chunk");
                    return [];
                break;
    
                default:
                    Trace.formatln("Bad chunk type: {:X}", header.type);
                    assert(false, typeof(this).stringof ~ ".uncompress - invalid chunk type");
            }
        }
    }


    private SimpleArrayDeserializer simple_deserializer;
    private ChunkedArrayDeserializer chunked_deserializer;
    private DecompressingArrayDeserializer decompress_deserializer;

    private ArrayDeserializer deserializer;


    /***************************************************************************
    
        Constructor
        
    ***************************************************************************/
    
    public this ( )
    {
        this.simple_deserializer = new SimpleArrayDeserializer();
        this.chunked_deserializer = new ChunkedArrayDeserializer();
        this.decompress_deserializer = new DecompressingArrayDeserializer();
    }


    /***************************************************************************
        
        Destructor

    ***************************************************************************/
    
    ~this ( )
    {
        delete this.simple_deserializer;
        delete this.chunked_deserializer;
        delete this.decompress_deserializer;
    }


    /***************************************************************************
    
        Receives and processes a list of arrays:
            1. An array is read from the input buffer.
            2. The array is processed.
            3. Check the finishing condition, and return to step 1 if not
               finished.
            4. Call the terminateList() method when finished.
    
        Params:
            output    = output data device (stream / buffer)
            data      = input buffer
            cursor    = position through input buffer
            finish_dg = delegate for finishing condition
    
        Returns:
            true if the input buffer is empty and needs to be refilled
    
    ***************************************************************************/

    // TODO: rename these methods to transmitArrays, unify in base class with
    // protected methods to getArray amd transmitArray
    
    private void[] output_array;

    public bool transmitArrays ( OutputDg output, void[] input, ref ulong cursor )
    {
        size_t input_array_cursor;

        do
        {
            with ( State ) switch ( this.state )
            {
                case Initial:
                    this.output_array.length = 0;

                    this.nextArray();

                    this.state = GetFirstArray;
                break;

                case GetFirstArray:
                    auto io_wait = this.getArray(this.array, input, cursor, input_array_cursor);
                    if ( io_wait ) return true;
                    
                    if ( super.isLzoStartChunk!(false)(this.array) )
                    {
                        if ( super.compress_decompress )
                        {
                            this.deserializer = this.decompress_deserializer;
                        }
                        else
                        {
                            this.deserializer = this.chunked_deserializer;
                        }
                        Trace.formatln("[*] got start chunk");
                    }
                    else
                    {
                        this.deserializer = this.simple_deserializer;
                    }

                    this.state = HandleArray;
                break;

                case HandleArray:
                    auto more_arrays = this.deserializer.receive(this.array, this.output_array);

                    this.nextArray(); // get ready to receive next array

                    this.state = more_arrays ? GetNextArray : TransmitArray;
                break;

                case GetNextArray:
                    auto io_wait = this.getArray(this.array, input, cursor, input_array_cursor);
                    if ( io_wait ) return true;
                    
                    this.state = HandleArray;
                break;

                case TransmitArray:
                    output(cast(char[])this.output_array);

                    auto last_array = super.terminator.finishedArray(this.output_array);
                    this.state = last_array ? Finished : Initial;
                break;
            }
        }
        while ( this.state != State.Finished );

        return false;
    }


    /***********************************************************************

        Called when a new array is ready to be deserialized.
    
        Resets the output array cursor, then calls startArray_() (which can
        be overridden by derived classes to add any additional reset
        behaviour needed).
    
    ***********************************************************************/
    
    private void nextArray ( )
    {
        this.array_read_cursor = 0;
    }
    
    private bool getArray ( ref void[] array, void[] input, ref ulong cursor, ref size_t input_array_cursor )
    {
        auto start = this.array_read_cursor;
        auto io_wait = SelectDeserializer.receive(array, input[input_array_cursor..$], this.array_read_cursor);
    
        // Update cursor
        auto consumed = this.array_read_cursor - start;
        cursor += consumed;
        input_array_cursor += consumed;
    
        return io_wait;
    }


    override protected void reset_()
    {
        this.array.length = 0;
        this.output_array.length = 0;
        this.array_read_cursor = 0;
        
        this.state = State.Initial;
    }
}

