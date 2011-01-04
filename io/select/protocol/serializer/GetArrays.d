/*******************************************************************************

    Class for get array forwarding. Receives arrays from a data input buffer,
    possibly decompresses compressed data, and forwards to an output destination
    (a stream buffer, delegate, etc).

    Gets single arrays, lists of arrays and lists of pairs.
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman

    TODO: usage example

*******************************************************************************/

module ocean.io.select.protocol.serializer.GetArrays;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.dest.model.IChunkDest;

private import ocean.io.select.protocol.serializer.SelectDeserializer,
               ocean.io.select.protocol.serializer.ArrayTransmitTerminator;

private import ocean.io.compress.lzo.LzoChunk;

private import ocean.io.compress.lzo.LzoHeader;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Get arrays class.

    Gets arrays from the input buffer, using an instance of ChunkDeserializer,
    and sends them to output destination (an instance of a class derived from
    IChunkDest).

    Note: Writing to the output device will always succeed (as it's either a
    variable in memory or a socket, which will block until the data is
    sent).
    
    On the other hand, reading from the input buffer must be interruptable /
    resumable, as we may have to read half variables.

*******************************************************************************/

//TODO: change name to ArraysSelectDeserializer

class GetArrays
{
    // TODO
    public bool decompress;


    // TODO
    public alias void delegate ( char[] ) OutputDg;


    /***************************************************************************
    
        Processing state
    
    ***************************************************************************/
    
    enum State
    {
        GetArray,
        ProcessArrayChunk,
        GetNextChunk,
        Finished
    }

    private State state;
    
    
    /***************************************************************************

        Terminator instances.
    
    ***************************************************************************/
    
    private SingleArrayTerminator single_array_terminator;
    private SinglePairTerminator single_pair_terminator;
    private ArrayListTerminator array_list_terminator;
    private PairListTerminator pair_list_terminator;
    
    
    /***************************************************************************
    
        Reference to the terminator instance currently being used.
    
    ***************************************************************************/
    
    private Terminator terminator;


    /***************************************************************************

        Count of complete arrays processed. Each chunked array counts as one.
    
    ***************************************************************************/
    
//    private uint arrays_processed;


    /***************************************************************************

        Has a list terminator (null string) been read? Used by isNullPair().

    ***************************************************************************/

//    private bool got_first_terminator;


    /***************************************************************************
    
        Constructor
        
    ***************************************************************************/
    
    public this ( )
    {
        this.lzo = new LzoChunk!(false);
        this.lzo_buffer = new void[1024];

        this.single_array_terminator = new SingleArrayTerminator();
        this.single_pair_terminator = new SinglePairTerminator();
        this.array_list_terminator = new ArrayListTerminator();
        this.pair_list_terminator = new PairListTerminator();
    }


    /***************************************************************************
        
        Destructor

    ***************************************************************************/
    
    ~this ( )
    {
        delete this.lzo;
        delete this.lzo_buffer;

        delete this.single_array_terminator;
        delete this.single_pair_terminator;
        delete this.array_list_terminator;
        delete this.pair_list_terminator;
    }


    /***************************************************************************
    
        Resets the internal state between runs.
        
    ***************************************************************************/
    
//    public void reset ( )
//    {
//        this.state = State.GetArray;
//
////        this.arrays_processed = 0;
////        this.got_first_terminator = false;
//
////        this.deserializer.reset();
//    }
    
    
    /***************************************************************************
    
        Receives and processes a single array
        
        Params:
            output    = output data device (stream / buffer)
            data      = input buffer
            cursor    = position through input buffer
    
        Returns:
            true if the input buffer is empty and needs to be refilled
    
    ***************************************************************************/

    // TODO: replace finish_dgs with a termination mode enum - it's simpler

    public void getSingleArray ( )
    {
        this.terminator = this.single_array_terminator;
        this.terminator.reset();
        this.state = State.GetArray;

//        return this.processArrayList(output, data, cursor, &this.isEndOfFirstArray);
    }
    
    
    /***************************************************************************
    
        Receives and processes a pair

        Params:
            output = data output device (stream / buffer)
            data = input buffer
            cursor = position through input buffer
    
        Returns:
            true if the input buffer is empty and needs to be refilled
    
    ***************************************************************************/
    
    public void getPair ( )
    {
        this.terminator = this.single_pair_terminator;
        this.terminator.reset();
        this.state = State.GetArray;

//        return this.processArrayList(output, data, cursor, &this.isEndOfFirstPair);
    }


    /***************************************************************************
    
        Receives and processes a list of arrays
        
        Params:
            output    = output data device (stream / buffer)
            data      = input buffer
            cursor    = position through input buffer
    
        Returns:
            true if the input buffer is empty and needs to be refilled
    
    ***************************************************************************/
    
    public void getArrayList ( )
    {
        this.terminator = this.array_list_terminator;
        this.terminator.reset();
        this.state = State.GetArray;

//        return this.processArrayList(output, data, cursor, &this.isNull);
    }
    
    
    /***************************************************************************
    
        Receives and processes a list of pairs
        
        Params:
            output    = output data device (stream / buffer)
            data      = input buffer
            cursor    = position through input buffer
    
        Returns:
            true if the input buffer is empty and needs to be refilled
    
    ***************************************************************************/
    
    public void getPairList ( )
    {
        this.terminator = this.pair_list_terminator;
        this.terminator.reset();
        this.state = State.GetArray;

//        return this.processArrayList(output, data, cursor, &this.isEndOfNullPair);
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

    // TODO: maybe restructure the internals of processArrayList to work with classes like this:

/*    abstract class ArrayDeserializer
    {
        // returns true to receive more arrays
        public bool receive ( void[] array, OutputDg output );
    }


    class SimpleArrayDeserializer : ArrayDeserializer
    {
        // returns true to receive more arrays
        public bool receive ( void[] array, OutputDg output )
        {
            output(cast(char[])array);
            return false;
        }
    }


    class CompressingArrayDeserializer : ArrayDeserializer
    {
        // returns true to receive more arrays
        public bool receive ( void[] array, OutputDg output )
        {
            return true; // TODO
        }
    }
*/
    private void[] array_buf, chunked_array_buf;

    public bool deserializeArrays ( OutputDg output, void[] input, ref ulong cursor )
    {
        size_t input_array_cursor;
//        this.newInputBuffer();

        do
        {
            with ( State ) switch ( this.state )
            {
                case GetArray:
                    auto io_wait = this.getArray(this.array_buf, input, cursor, input_array_cursor);
                    if ( io_wait ) return true;

                    if ( this.isStartChunk(this.array_buf) )
                    {
                        Trace.formatln("[*] got start chunk");
                        this.state = ProcessArrayChunk;
                    }
                    else
                    {
                        Trace.formatln("[*] got complete array: '{}'", cast(char[])this.array_buf);
                        output(cast(char[])this.array_buf);

                        auto last_array = this.terminator.finishedArray(this.array_buf);
                        this.state = last_array ? Finished : GetArray;
                        this.nextArray();

//                        this.state = finish_dg(this.array_buf) ? Finished : GetArray;
//                        this.nextArray();
                    }
                break;

                case ProcessArrayChunk:
                    Trace.formatln("[*] got array chunk");
                    auto end_chunk = this.processArrayChunk(this.array_buf, this.chunked_array_buf);
                    if ( end_chunk )
                    {
                        Trace.formatln("[*] got complete chunked array");
                        output(cast(char[])this.chunked_array_buf);
                        auto last_array = this.terminator.finishedArray(this.chunked_array_buf);
                        this.state = last_array ? Finished : GetArray;
                        this.nextArray();

//                        this.state = finish_dg(this.chunked_array_buf) ? Finished : GetArray;
                    }
                    else
                    {
                        Trace.formatln("[*] next chunk");
                        this.state = GetNextChunk;
                        this.nextArrayChunk();
                    }
                break;

                case GetNextChunk:
                    auto io_wait = this.getArray(this.array_buf, input, cursor, input_array_cursor);
                    if ( io_wait ) return true;

                    this.state = ProcessArrayChunk;
                break;
            }
        }
        while ( this.state != State.Finished );

        return false;
    }

    private void nextArray ( )
    {
//        this.arrays_processed++;
        this.array_buf.length = 0;
        this.chunked_array_buf.length = 0;
        this.array_read_cursor = 0;
    }

    private void nextArrayChunk ( )
    {
        this.array_buf.length = 0;
        this.array_read_cursor = 0;
    }

    private ulong array_read_cursor;

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


    private bool isStartChunk ( void[] array )
    {
        LzoHeader!(false) header;
        return array.length && header.tryReadStart(array);
    }


    private bool processArrayChunk ( void[] array_chunk, ref void[] complete_array )
    {
        Trace.formatln("[*] processArrayChunk: {:X2}", array_chunk);

        LzoHeader!(false) header;
        auto payload = header.read(array_chunk);

        if ( decompress )
        {
            auto uncompressed = this.uncompress(header, payload, array_chunk);
            complete_array ~= uncompressed;
        }
        else
        {
            ubyte[size_t.sizeof] chunk_length; // using ubyte as cannot define static void array
            *(cast(size_t*)chunk_length.ptr) = array_chunk.length;
            
            complete_array ~= chunk_length;
            complete_array ~= array_chunk;
        }

        return header.type == header.type.Stop;
    }

    /***************************************************************************
    
        LzoChunk instance, header & buffer
        
    ***************************************************************************/

    private LzoChunk!(false) lzo;

    private void[] lzo_buffer;

    /***************************************************************************
    
        Decompresses an array, if necessary.
    
        Params:
            header = compression header
            payload = possibly compressed payload
            whole_chunk = array containing header + payload
        
        Returns:
            decompressed payload
    
    ***************************************************************************/
    
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

