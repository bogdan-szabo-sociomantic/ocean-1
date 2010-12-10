/*******************************************************************************

    Array chunk serializer abstract base class. Used by PutArrays.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman
    
*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.model.IChunkSerializer;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.SelectSerializer;

debug private import tango.util.log.Trace;



/*******************************************************************************

    IChunkSerializer abstract class.
    
    Accepts and processes array chunks one at a time, writing to an output data
    buffer.

    Derived classes must implement the processChunk() method, which must do the
    actual writing to the output buffer, including any specialised processing
    such as writing headers or compressing data.
    
*******************************************************************************/

abstract class IChunkSerializer
{
    /***************************************************************************

        Enum of termination modes for lists. Derived classes may have different
        behaviour depending on the type of list being processesed.

    ***************************************************************************/

    enum ListTerminationMode
    {
        None,
        List,
        PairList
    }

    /***************************************************************************
    
        Abstract method to write a chunk to the output buffer
    
        Params:
            chunk = chunk to serialize
            array_total_length = total length of whole array (may be >
                chunk.length, if chunk is only a part of a whole array)
            last_chunk_in_array = true when this is thel last chunk in an array
            data = output buffer
            cursor = output buffer cursor
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    abstract public bool processChunk ( void[] chunk, size_t array_total_length,
                                        bool last_chunk_in_array, void[] data, ref ulong cursor );


    /***************************************************************************
    
        Abstract method to write a terminator for a list of arrays.
    
        Params:
            data = output buffer
            cursor = output buffer cursor
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    abstract public bool terminate ( ListTerminationMode termination_mode, ref void[] data, ref ulong cursor );


    /***************************************************************************
    
        Position through array being serialized
    
    ***************************************************************************/
    
    protected ulong write_value_cursor;
    
    
    /***************************************************************************
    
        Position in output data buffer being written to
    
    ***************************************************************************/
    
    protected ulong data_buffer_cursor;


    /***************************************************************************
    
        Resets internals
    
    ***************************************************************************/

    public void reset ( )
    {
        this.data_buffer_cursor = 0;
        this.write_value_cursor = 0;
    }


    /***************************************************************************
    
        Writes a value to the data buffer.
    
        Template params:
            T = type of value to write
    
        Params:
            item = item to write
            data = output buffer
            cursor = write cursor
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    protected bool write ( T ) ( T item, ref void[] data, ref ulong cursor )
    {
        return this.updateWriteCursors(cursor, SelectSerializer.send(item, data[this.data_buffer_cursor..$], this.write_value_cursor));
    }
    
    
    /***************************************************************************
    
        Writes an array (including prepended length) to the data buffer.
    
        Template params:
            T = element type of array to write
    
        Params:
            array = array to write
            data = output buffer
            cursor = write cursor
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    protected bool writeArray ( T ) ( T[] array, ref void[] data, ref ulong cursor )
    {
        return this.updateWriteCursors(cursor, SelectSerializer.send(array, data[this.data_buffer_cursor..$], this.write_value_cursor));
    }
    
    
    /***************************************************************************
    
        Writes an array (without prepending the length) to the data buffer.
    
        Template params:
            T = element type of array to write
    
        Params:
            array = array to write
            data = output buffer
            cursor = write cursor
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    protected bool writeArrayWithoutLength ( T ) ( T[] array, ref void[] data, ref ulong cursor )
    {
        return this.updateWriteCursors(cursor, SelectSerializer.sendArrayWithoutLength(array, data[this.data_buffer_cursor..$], this.write_value_cursor));
    }
    
    
    /***************************************************************************
    
        Tracks how much data has been consumed by a send function, and updates
        the internal write cursors.
    
        Params:
            cursor = write cursor
            send_dg = delegate to evaluate which sends something and updates
                        this.write_value_cursor
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    protected bool updateWriteCursors ( ref ulong cursor, lazy bool send_dg )
    {
        auto start = this.write_value_cursor;
        auto io_wait = send_dg();
    
        auto consumed = this.write_value_cursor - start;
        cursor += consumed;
    
        if ( io_wait )
        {
            this.data_buffer_cursor = 0;
        }
        else
        {
            this.data_buffer_cursor += consumed;
        }
    
        return io_wait;
    }
}

