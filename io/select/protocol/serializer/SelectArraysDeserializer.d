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
            LzoChunkCompressor lzo;

            char[][] arrays_received;
            
            SelectArraysDeserializer get;
            
            this ( )
            {
                this.lzo = new LzoChunkCompressor;
                this.get = new SelectArraysDeserializer(this.lzo.decompressor);
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

private import ocean.io.select.protocol.serializer.SelectDeserializer;

private import ocean.io.compress.lzo.LzoChunkCompressor;

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

    The class handles several types of deserialization:

        1. Simple arrays.
        2. Lzo compressed arrays (split into a series of chunks).
        3. Forwarding previously lzo compressed (chunked) arrays. 

    Note: Although sending to the output delegate will always succeed (as it's
    just a delegate which receives the array to process), on the other hand,
    reading from the input buffer must be interruptable / resumable, as we may
    have to read half variables.

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
    
    
    /***************************************************************************
    
        Array buffer used to deserialize into.
    
    ***************************************************************************/

    private void[] array;


    /***************************************************************************

        Cursor indicating how many bytes have been read into this.array.

    ***************************************************************************/

    private ulong array_read_cursor;


    /***************************************************************************
    
        Array buffer used to build up the complete array which is sent to the
        output delegate. This array may be formed of several individual array
        chunks (which are received one at a time into this.array).
    
    ***************************************************************************/

    private void[] output_array;


    /***********************************************************************
    
        LzoChunk decompressor.
    
    ***********************************************************************/

    protected LzoChunkCompressor.Decompressor lzo;


    /***************************************************************************

        Abstract class used to deserialize an array.

        Different types of array deserializer are required depending on the
        content of the array received and the setting of the decompress member.

    ***************************************************************************/

    abstract private class ArrayDeserializer
    {
        /***********************************************************************

            Receives and handles a chunk of an array.
            
            Params:
                input = array chunk to handle
                output = output array to write into

            Returns:
                true if one or more further array chunks need to be read to
                complete the output array

        ***********************************************************************/

        abstract public bool receive ( void[] input, ref void[] output );
    }


    /***************************************************************************

        Deserializer used when simply receiving an array.

    ***************************************************************************/

    private class SimpleArrayDeserializer : ArrayDeserializer
    {
        public bool receive ( void[] input, ref void[] output )
        {
            output.copy(input);
            return false;
        }
    }


    /***************************************************************************

        Deserializer used when forwarding an array which has been lzo compressed
        and is thus split into chunks. Chunks must be read and appended to the
        output array, with their lengths prepended (thus replicating the stream
        of chunks as read) until the stop chunk is reached.
    
    ***************************************************************************/

    private class ChunkedArrayDeserializer : ArrayDeserializer
    {
        public bool receive ( void[] input, ref void[] output )
        {
            LzoChunkCompressor.Decompressor.Header header;
            auto payload = header.read(input);

            ubyte[size_t.sizeof] chunk_length; // using ubyte as cannot define static void array
            *(cast(size_t*)chunk_length.ptr) = input.length;

            output.append(cast(void[])chunk_length, input);

            return header.type != header.type.Stop;
        }
    }


    /***************************************************************************

        Deserializer used when decompressing an array which has been lzo
        compressed and is thus split into chunks. Chunks must be read and the
        decompressed data appended to the output array, until the stop chunk is
        reached.
    
    ***************************************************************************/

    private class DecompressingArrayDeserializer : ArrayDeserializer
    {
        /***********************************************************************

            Receives and handles a chunk of an array.
            
            Params:
                input = array chunk to handle
                output = output array to write into
    
            Returns:
                true if one or more further array chunks need to be read to
                complete the output array
    
        ***********************************************************************/

        public bool receive ( void[] input, ref void[] output )
        {
            LzoChunkCompressor.Decompressor.Header header;
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
        
        protected void[] uncompress ( LzoChunkCompressor.Decompressor.Header header, void[] payload, void[] whole_chunk )
        {
            switch ( header.type )
            {
                case header.Type.Start:
                    return [];
                break;
    
                case header.Type.LZO1X:
                    return this.outer.lzo.decompress(whole_chunk);
                break;
        
                case header.Type.None:
                    return payload;
                break;
        
                case header.Type.Stop:
                    return [];
                break;
    
                default:
                    assert(false, typeof(this).stringof ~ ".uncompress - invalid chunk type");
            }
        }
    }


    /***************************************************************************

        Deserializer instances.
    
    ***************************************************************************/

    private SimpleArrayDeserializer simple_deserializer;
    private ChunkedArrayDeserializer chunked_deserializer;
    private DecompressingArrayDeserializer decompress_deserializer;


    /***************************************************************************

        Reference to the deserializer instance currently being used.
    
    ***************************************************************************/

    private ArrayDeserializer deserializer;


    /***************************************************************************
    
        Constructor
        
    ***************************************************************************/
    
    public this ( LzoChunkCompressor.Decompressor lzo )
    {
        this.lzo = lzo;

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

        Deserializes array(s):

            1. An array is deserialized from the input buffer.
            2. The array is processed - which may include decompression.
            3. If the received array was only one chunk of a larger array,
               return to step 1. Otherwise send the complete array to the
               output delegate.
            4. The finishing condition is checked (using the super class),
               return to step 1 if not finished.

        Params:
            output = output delegate
            input = input data buffer
            cursor = global cursor

        Returns:
            true if the input buffer is empty and needs to be refilled

    ***************************************************************************/

    public bool transmitArrays ( OutputDg output, void[] input, ref ulong cursor )
    {
        size_t input_array_cursor;

        do
        {
            with ( State ) switch ( this.state )
            {
                case Initial:
                    this.output_array.length = 0;

                    this.nextArray(); // get ready to receive first array

                    this.state = GetFirstArray;
                break;

                case GetFirstArray:
                    auto io_wait = this.getArray(this.array, input, cursor, input_array_cursor);
                    if ( io_wait ) return true;

                    if ( this.lzo.isStartChunk(this.array) )
                    {
                        this.deserializer = super.compress_decompress
                            ? this.decompress_deserializer
                            : this.chunked_deserializer;
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


    /***************************************************************************

        Deserializes an array from the input buffer.

        Params:
            array = array to read into
            input = input data buffer
            cursor = global cursor
            input_array_cursor = position through input buffer 
    
        Returns:
            true if the input buffer is empty and needs to be refilled

    ***************************************************************************/

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


    /***************************************************************************

        Called when a new array is ready to be deserialized. Resets the output
        array cursor.
    
    ***************************************************************************/
    
    private void nextArray ( )
    {
        this.array_read_cursor = 0;
    }


    /***************************************************************************

        Resets to initial state. Called by super.reset().
    
    ***************************************************************************/

    override protected void reset_()
    {
        this.array.length = 0;
        this.output_array.length = 0;
        this.array_read_cursor = 0;
        
        this.state = State.Initial;
    }
}

