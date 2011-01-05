/*******************************************************************************

    Class for array put forwarding. Receives arrays one by one from a delegate
    and writes them to a data output buffer (possibly with compression).

    Puts single arrays, lists of arrays and lists of pairs.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        August 2010: Initial release
                    January 2011: Unified / simplified version

    authors:        Gavin Norman

    Usage example:
    
    ---
    
        import ocean.io.select.protocol.serializer.SelectArraysSerializer;

        class AsyncSender
        {
            static const arrays_to_send = ["hello", "world", "yes"];
            
            size_t array_index;

            SelectArraysSerializer put;
            
            this ( )
            {
                this.put = new SelectArraysSerializer();
            }

            void reset ( )
            {
                this.array_index = 0;

                const bool compress = true;

                this.put.arrayList(compress);
            }

            bool asyncSend ( void[] output, ref ulong cursor )
            {
                return this.put.transmitArrays(&this.provideArrays, output, cursor);
            }

            char[] provideArrays ( )
            {
                if ( this.array_index < arrays_to_send.length )
                {
                    return arrays_to_send[this.array_index++];
                }
                else
                {
                    return ""; // list terminator
                }
            }
        }

    ---

*******************************************************************************/

module ocean.io.select.protocol.serializer.SelectArraysSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.model.ISelectArraysTransmitter;

private import ocean.io.select.protocol.serializer.SelectSerializer;

private import ocean.io.compress.lzo.LzoHeader,
               ocean.io.compress.lzo.LzoChunk;

private import tango.math.Math: min;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Alias for an input delegate which provides the array(s) to be serialized.

*******************************************************************************/

public alias char[] delegate ( ) InputDg;



/*******************************************************************************

    Array serialization class.
    
    Gets arrays from an input delegate, and asynchronously serializes them to an
    output buffer.
    
    The class handles several types of serialization:

        1. Simple arrays.
        2. Lzo compressed arrays (split into a series of chunks).
        3. Forwarding previously lzo compressed (chunked) arrays. 

    Note: Although reading from the input delegate will always succeed (as it's
    just a delegate which provides the array to process), on the other hand,
    writing to the output buffer must be interruptable / resumable, as we may
    have to write half variables.

*******************************************************************************/

class SelectArraysSerializer : ISelectArraysTransmitter!(InputDg)
{
    /***************************************************************************
    
        Processing state.
    
    ***************************************************************************/
    
    enum State
    {
        GetArray,   // get next array from delegate
        TransmitArray,  // sending a simple non-chunked array
        Finished
    }
    
    private State state;


    /***************************************************************************
    
        Array currently being processed, received from input delegate.
    
    ***************************************************************************/

    private char[] array;


    /***************************************************************************

        Abstract class used to serialize an array.
        
        Different types of array serializer are required depending on the
        content of the array received and the setting of the compress member.
    
    ***************************************************************************/

    abstract private class ArraySerializer
    {
        /***********************************************************************

            Internal cursor which pages through the input array. This cursor is
            required as the send() method (below) may be called multiple times
            during the serialization of a single array, so we need to keep track
            of how far we've got. The global cursor (which is passed to send()
            as a reference) tracks the *total* progress through *all* arrays
            (and other data) being serialized.
    
        ***********************************************************************/
    
        private ulong input_array_cursor;


        /***********************************************************************

            Serializes an array.

            Params:
                array = array to write
                data = output buffer
                cursor = global write cursor
                output_array_cursor = write position in current output buffer

            Returns:
                true if the output buffer is full and needs to be flushed
    
        ***********************************************************************/

        abstract public bool send ( void[] array, void[] output, ref ulong cursor, ref size_t output_array_cursor );


        /***********************************************************************

            Called when a new array is ready to be serialized.

            Resets the input array cursor, then calls startArray_() (which can
            be overridden by derived classes to add any additional reset
            behaviour needed).

        ***********************************************************************/

        final public void startArray ( )
        {
            this.input_array_cursor = 0;
            this.startArray_();
        }

        protected void startArray_ ( )
        {
        }


        /***********************************************************************

            Writes an array (including prepended length) to the data buffer.

            Params:
                array = array to write
                output = output buffer
                cursor = global write cursor
                output_array_cursor = write position in current output buffer

            Returns:
                true if the output buffer is full and needs to be flushed

        ***********************************************************************/

        protected bool serializeArray ( void[] array, ref void[] output, ref ulong cursor, ref size_t output_array_cursor )
        {
            auto start = this.input_array_cursor;
            auto io_wait = SelectSerializer.send(array, output[output_array_cursor..$], this.input_array_cursor);

            auto consumed = this.input_array_cursor - start;
            cursor += consumed;

            if ( io_wait )
            {
                // Next time this method is called the output buffer will have
                // been flushed, so we need to write at the beginning of it.
                output_array_cursor = 0;
            }
            else
            {
                // Serialization of current array has finished.
                // Start at the beginning of the next array next time this method is called.
                this.input_array_cursor = 0;
                output_array_cursor += consumed;
            }

            return io_wait;
        }
    }


    /***************************************************************************

        Serializer used when simply sending an array.
    
    ***************************************************************************/

    private class SimpleArraySerializer : ArraySerializer
    {
        public bool send ( void[] array, void[] output, ref ulong cursor, ref size_t output_array_cursor )
        {
            return super.serializeArray(array, output, cursor, output_array_cursor);
        }
    }


    /***************************************************************************

        Serializer used when forwarding an array containing data which is
        already chunked as a result of lzo compression. In this case we need to
        split the array into its constituent chunks and send them each
        separately. (Otherwise the array is sent as a whole, and interpreted as
        a whole by the receiver, which isn't what we want.)
    
    ***************************************************************************/

    private class ChunkedArraySerializer : ArraySerializer
    {
        /***********************************************************************

            Internal state.
    
        ***********************************************************************/

        enum State
        {
            StartChunk,
            SendChunk,
            Finished
        }

        private State state;
        

        /***********************************************************************

            Position (in input array) of the start of the next chunk to send.

        ***********************************************************************/

        private size_t chunk_pos;


        /***********************************************************************

            Current chunk being sent.
    
        ***********************************************************************/

        private void[] chunk;


        /***********************************************************************

            startArray_() override which resets the state and chunk position.
    
        ***********************************************************************/

        override protected void startArray_ ( )
        {
            this.state = State.StartChunk;
            this.chunk_pos = 0;
        }


        /***********************************************************************

            Sends a chunked array one chunk at a time. Each chunk is prepended
            with its length, which is required for it to be correctly
            deserialized at the other end.
    
            Params:
                array = array to write
                output = output buffer
                cursor = global write cursor
                output_array_cursor = write position in current output buffer

            Returns:
                true if the output buffer is full and needs to be flushed

        ***********************************************************************/

        public bool send ( void[] array, void[] output, ref ulong cursor, ref size_t output_array_cursor )
        {
            do
            {
                with ( State ) switch ( this.state )
                {
                    case StartChunk:
                        auto chunk_length = *(cast(size_t*)(array.ptr + this.chunk_pos));
                        this.chunk_pos += size_t.sizeof;
                        this.chunk = array[this.chunk_pos .. this.chunk_pos + chunk_length];
                        this.chunk_pos += chunk_length;

                        this.state = SendChunk;
                    break;

                    case SendChunk:
                        auto io_wait = super.serializeArray(this.chunk, output, cursor, output_array_cursor);
                        if ( io_wait ) return true;

                        this.state = this.chunk_pos < array.length ? StartChunk : Finished;
                    break;
                }
            }
            while ( this.state != State.Finished );

            return false;
        }
    }


    /***************************************************************************

        Serializer used when sending an array which needs to be lzo compressed.
        The array is split into one or more chunks, which are compressed
        individually, and the sent as a series of chunks. At least 3 chunks will
        always be sent: a start chunk, one or more compressed content chunks,
        an end chunk. The chunks are serialized as separate arrays.
    
    ***************************************************************************/

    private class CompressingArraySerializer : ArraySerializer
    {
        /***********************************************************************

            Internal state.

        ***********************************************************************/
        
        enum State
        {
            InitStartChunk,
            WriteStartChunk,
            ExtractChunk,
            WriteChunk,
            InitEndChunk,
            WriteEndChunk,
            Finished
        }
        
        private State state;


        /***********************************************************************
        
            LzoChunk instance (compressor) & working buffer.
        
        ***********************************************************************/
        
        protected LzoChunk!() lzo;
        
        protected void[] lzo_buffer;


        /***********************************************************************
        
            Lzo chunk header.
        
        ***********************************************************************/

        private LzoHeader!() chunk_header;


        /***********************************************************************
        
            Current chunk being processed (slice into input array).
        
        ***********************************************************************/

        private void[] chunk;


        /***********************************************************************
        
            Compressed chunk - slice into this.lzo_biffer.
        
        ***********************************************************************/

        private void[] compressed_chunk;


        /***********************************************************************
        
            Chunking cursor through input array.
        
        ***********************************************************************/

        private size_t chunk_pos;


        /***********************************************************************
        
            Maximum amount of input data per chunk.
        
        ***********************************************************************/

        private const size_t ChunkSize = 1024;


        /***********************************************************************
        
            Constructor.
        
        ***********************************************************************/
        
        public this ( )
        {
            this.lzo = new LzoChunk!();
            this.lzo_buffer = new void[1024];
        }
        
        
        /***********************************************************************
        
            Destructor.
        
        ***********************************************************************/
        
        public ~this ( )
        {
            delete this.lzo;
            delete this.lzo_buffer;
        }


        /***********************************************************************

            startArray_() override which resets the state and chunk cursor.

        ***********************************************************************/

        override protected void startArray_ ( )
        {
            this.state = State.InitStartChunk;
            this.chunk_pos = 0;
        }


        /***********************************************************************

            Sends an array as a series of compressed chunks.

            Params:
                array = array to write
                output = output buffer
                cursor = global write cursor
                output_array_cursor = write position in current output buffer

            Returns:
                true if the output buffer is full and needs to be flushed

        ***********************************************************************/

        public bool send ( void[] array, void[] output, ref ulong cursor, ref size_t output_array_cursor )
        {
            do
            {
                with ( State ) switch ( this.state )
                {
                    case InitStartChunk:
                        this.chunk_header.start(array.length);

                        this.state = WriteStartChunk;
                    break;

                    case WriteStartChunk:
                        auto io_wait = super.serializeArray(this.chunk_header.data_without_length(), output, cursor, output_array_cursor);
                        if ( io_wait ) return true;

                        this.state = ExtractChunk;
                    break;

                    case ExtractChunk:
                        this.getNextChunk(this.chunk, array);
                        this.compressed_chunk = this.compress(this.chunk);

                        this.state = WriteChunk;
                    break;

                    case WriteChunk:
                        auto io_wait = super.serializeArray(this.compressed_chunk, output, cursor, output_array_cursor);
                        if ( io_wait ) return true;

                        this.state = this.chunk_pos < array.length ? ExtractChunk : InitEndChunk;
                    break;

                    case InitEndChunk:
                        this.chunk_header.stop();
                        this.state = WriteEndChunk;
                    break;

                    case WriteEndChunk:
                        auto io_wait = super.serializeArray(this.chunk_header.data_without_length(), output, cursor, output_array_cursor);
                        if ( io_wait ) return true;

                        this.state = Finished;
                    break;
                }
            }
            while ( this.state != State.Finished );

            return false;
        }


        /***********************************************************************
        
            Pulls the next chunk from the array being processed, updating the
            chunk cursor.

            Params:
                chunk = string to be set to the next chunk
                source = array to read chunk from
        
        ***********************************************************************/

        private void getNextChunk ( ref void[] chunk, void[] source )
        {
            auto remaining = source.length - this.chunk_pos;
            auto len = min(remaining, ChunkSize);

            chunk = source[this.chunk_pos .. this.chunk_pos + len];
            this.chunk_pos += len;
        }


        /***********************************************************************

            Compresses data.

            Params:
                data = data to be compressed

            Returns:
                compressed data, with its initial 4 bytes stripped off (this is
                the total size of the compressed data chunk, written by the lzo
                compressor - it's rewritten by the protocol writer, so we strip
                it here).

        ***********************************************************************/

        protected void[] compress ( void[] data )
        {
            this.lzo.compress(data, this.lzo_buffer);
            return this.lzo_buffer[size_t.sizeof .. $];                         // slice off the chunk size, as the protocol will rewrite it
        }
    }


    /***************************************************************************

        Serializer instances.

    ***************************************************************************/

    private ChunkedArraySerializer chunked_serializer;
    private CompressingArraySerializer compress_serializer;
    private SimpleArraySerializer simple_serializer;


    /***************************************************************************

        Reference to the serializer instance currently being used.
    
    ***************************************************************************/

    private ArraySerializer serializer;


    /***************************************************************************
    
        Constructor
        
    ***************************************************************************/
    
    public this ( )
    {
        this.chunked_serializer = new ChunkedArraySerializer();
        this.compress_serializer = new CompressingArraySerializer();
        this.simple_serializer = new SimpleArraySerializer();
    }


    /***************************************************************************
    
        Destructor
        
    ***************************************************************************/
    
    ~this ( )
    {
        delete this.chunked_serializer;
        delete this.compress_serializer;
        delete this.simple_serializer;
    }


    /***************************************************************************
    
        Serializes array(s):

            1. An array is read from the input delegate.
            2. The array is serialized (by an instance of a class derived from
               ArraySerializer).
            3. The finishing condition is checked (using the super class),
               return to step 1 if not finished.

        Params:
            input     = input delegate
            data      = output buffer
            cursor    = position through output buffer

        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/

    public bool transmitArrays ( InputDg input, void[] output, ref ulong cursor )
    {
        size_t output_array_cursor;

        do
        {
            with ( State ) switch ( this.state )
            {
                case GetArray:
                    this.array = input();

                    if ( this.isLzoStartChunk!(true)(this.array) )              // already compressed
                    {
                        this.serializer = this.chunked_serializer;
                    }
                    else
                    {
                        this.serializer = super.compress_decompress ? this.compress_serializer : this.simple_serializer; 
                    }

                    this.serializer.startArray();

                    this.state = TransmitArray;
                break;

                case TransmitArray:
                    auto io_wait = this.serializer.send(this.array, output, cursor, output_array_cursor);
                    if ( io_wait ) return true;

                    auto last_array = super.terminator.finishedArray(this.array);
                    this.state = last_array ? Finished : GetArray;
                break;
            }
        }
        while ( this.state != State.Finished );

        return false;
    }


    /***************************************************************************

        Resets to initial state. Called by super.reset().
    
    ***************************************************************************/

    override protected void reset_ ( )
    {
        this.state = State.GetArray;
    }
}

