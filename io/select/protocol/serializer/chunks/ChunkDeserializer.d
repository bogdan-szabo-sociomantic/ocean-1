/*******************************************************************************

    Array chunk deserializer. Receives chunked arrays from the dht node.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman
    
*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.ChunkDeserializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.SelectDeserializer;

private import ocean.io.compress.lzo.LzoChunk;

private import ocean.io.compress.lzo.LzoHeader;

debug private import tango.util.log.Trace;



/*******************************************************************************

    ChunkDeserializer - receives a series of arrays from a data input buffer.
    Checks whether each received array is compressed, and reads the compressed
    data chunk by chunk, decompressing it.

*******************************************************************************/

class ChunkDeserializer
{
    /***************************************************************************
    
        LzoChunk instance, header & buffer
        
    ***************************************************************************/
    
    private LzoChunk!(false) lzo;
    
    private LzoHeader!(false) header;
    
    private void[] lzo_buffer;
    
    
    /***************************************************************************
    
        Array buffer - builds up a complete array, possibly over multiple calls
        of the getNextArray() or readArray() methods.
        
    ***************************************************************************/

    private void[] array_buf;


    /***************************************************************************
    
        Chunk buffer - builds up an array chunk, possibly over multiple calls
        of the getNextArray() or readArray() methods.
        
    ***************************************************************************/

    private void[] chunk_buf;


    /***************************************************************************
    
        Position through reading an array from the data input buffer (stored as
        the array deserialization can be interrupted)
    
    ***************************************************************************/
    
    private ulong array_read_cursor;
    
    
    /***************************************************************************
    
        Position through data input buffer. We need to keep track of this in
        order to handle the case where an input buffer contains multiple arrays.
    
    ***************************************************************************/
    
    private ulong data_buffer_cursor;


    /***************************************************************************
    
        Flag to tell whether we're in the middle of reading a chunked
        (compressed) array.
        
    ***************************************************************************/

    private bool reading_chunked_array;


    /***************************************************************************
    
        Constructor
        
    ***************************************************************************/
    
    public this ( )
    {
        this.lzo = new LzoChunk!(false);
        this.lzo_buffer = new void[1024];
    }
    
    
    /***************************************************************************
    
        Destructor
        
    ***************************************************************************/
    
    public ~this ( )
    {
        delete this.lzo;
        delete this.lzo_buffer;
    }
    
    
    /***************************************************************************
    
        Resets the internal state between runs.
    
    ***************************************************************************/
    
    public void reset ( )
    {
        this.reading_chunked_array = false;
        
        this.array_read_cursor = 0;
        this.data_buffer_cursor = 0;

        this.chunk_buf.length = 0;
        this.array_buf.length = 0;
    }


    /***************************************************************************

        Indicates that the data input buffer has been re-populated.
    
    ***************************************************************************/
    
    public void newBuffer ( )
    {
        this.data_buffer_cursor = 0;
    }


    /***************************************************************************

        Reads an array chunk from the data buffer, decompresses it if necessary,
        and repeats until a complete array has been read in.
        
        Params:
            data = input buffer
            cursor = position through read operation

        Returns:
            true if the input buffer is empty and needs to be refilled, false
            when a complete array has been read
    
    ***************************************************************************/

    public bool getNextArray ( void[] data, ref ulong cursor )
    {
        bool finished;

        do
        {
            if ( this.reading_chunked_array )
            {
                auto io_wait = this.readArray(data, cursor);
                if ( io_wait )
                {
                    return true;
                }

                finished = this.processArrayChunk();
                if ( finished )
                {
                    this.reading_chunked_array = false;
                }
                this.nextChunk();
            }
            else
            {
                auto io_wait = this.readArray(data, cursor);
                if ( io_wait )
                {
                    return true;
                }

                if ( this.isStartChunk() )
                {
                    this.nextArray();
                    this.reading_chunked_array = true;
                    // loop around to read next chunk
                }
                else
                {
                    this.array_buf.length = this.chunk_buf.length;
                    this.array_buf[] = this.chunk_buf[];
                    finished = true;
                }
            }
        } while ( !finished );

        return false;
    }


    /***************************************************************************

        Indicates that the read array has been processed, and that the state
        should be reset ready to read another array.
    
    ***************************************************************************/

    public void nextArray ( )
    {
        this.array_buf.length = 0;
        this.chunk_buf.length = 0;
        this.array_read_cursor = 0;
    }

    /***************************************************************************
    
        Returns:
            the array buffer
    
    ***************************************************************************/
    
    public void[] array ( )
    {
        return this.array_buf;
    }


    /***************************************************************************

        Reads an array from the input buffer.

        Params:
            data = input buffer
            cursor = position through read operation

        Returns:
            true if the input buffer is empty and needs to be refilled, false
            when a complete array has been read

    ***************************************************************************/

    protected bool readArray ( void[] data, ref ulong cursor )
    {
        auto start = this.array_read_cursor;
        auto io_wait = SelectDeserializer.receive(this.chunk_buf, data[this.data_buffer_cursor..$], this.array_read_cursor);
    
        // Update cursor
        auto consumed = this.array_read_cursor - start;
        cursor += consumed;
        this.data_buffer_cursor += consumed;

        return io_wait;
    }


    /***************************************************************************
    
        Checks whether an array is a compressed start header. If it is then a
        series of compressed content chunks is expected. If it isn't then the
        array is simply forwarded to the output device.
    
        Params:
            array = array to process
            output = output device
    
    ***************************************************************************/
    
    protected bool isStartChunk ( )
    {
        return this.chunk_buf.length && this.header.tryReadStart(this.chunk_buf);
    }
    
    
    /***************************************************************************

        Handles a compressed content chunk. If it's a stop chunk then a complete
        chunked array has been received and rebuilt. Otherwise the chunk is
        decompressed and forwarded to the output device.

        Returns:
            true if the chunk is a stop header (ie the end of the current array)

    ***************************************************************************/
    
    protected bool processArrayChunk ( )
    in
    {
        assert(this.header.tryRead(this.chunk_buf), typeof(this).stringof ~ ".processArrayChunk - invalid chunk header");
    }
    body
    {
        auto payload = this.header.read(this.chunk_buf);

        if ( this.header.type == this.header.type.Stop )
        {
            return true;
        }

        auto uncompressed = this.uncompress(this.header, payload, this.chunk_buf);
        this.array_buf ~= uncompressed;

        return false;
    }


    /***************************************************************************

        Done with current chunk, ready to read the next.
    
    ***************************************************************************/
    
    protected void nextChunk ( )
    {
        this.chunk_buf.length = 0;
        this.array_read_cursor = 0;
    }


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
            case header.Type.LZO1X:
                this.lzo.uncompress(whole_chunk, this.lzo_buffer);
                return this.lzo_buffer;
            break;
    
            case header.Type.None:
                return payload;
            break;
    
            default:
                assert(false, typeof(this).stringof ~ ".uncompress - invalid chunk type");
        }
    }
}

