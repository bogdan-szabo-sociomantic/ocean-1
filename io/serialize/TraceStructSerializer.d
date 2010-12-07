/*******************************************************************************

    Serializer, to be used with the StructSerializer, which dumps a struct to
    Trace.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        October 2010: Initial release
    
    authors:        Gavin Norman

    Serializer, to be used with the StructSerializer in
    ocean.io.serialize.StructSerializer, which dumps a struct to Trace.
    
    The serializer uses the StringStructSerializer internally, and just writes
    the output strings to Trace.

    Usage example (in conjunction with ocean.io.serialize.StructSerializer):
    
    ---

        // Example struct to serialize to Trace
        struct Data
        {
            struct Id
            {
                char[] name;
                hash_t id;
            }

            Id[] ids;
            char[] name;
            uint count;
            float money;
        }

        // Set up some data in a struct
        Data data;
        test.ids = [Data.Id("hi", 23), Data.Id("hello", 17)];

        // Create serializer object
        scope ser = new TraceStructSerializer();

        // Dump struct to Trace via serializer
        ser.serialize(data);

    ---

*******************************************************************************/

module ocean.io.serialize.TraceStructSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.serialize.StructSerializer;
private import ocean.io.serialize.StringStructSerializer;

private import tango.util.log.Trace;



/*******************************************************************************

    Trace struct serializer

*******************************************************************************/

class TraceStructSerializer : StringStructSerializer!(char)
{
    /***************************************************************************

        String to receive serialized data
    
    ***************************************************************************/

    private char[] string;


    /***************************************************************************

        Convenience method to serialize a struct.
    
        Template params:
            T = type of struct to serialize
        
        Params:
            item = struct to serialize
    
    ***************************************************************************/
    
    void serialize ( T ) ( ref T item )
    {
        this.string.length = 0;
        StructSerializer.serialize(&item, this);
        Trace.formatln("{}", this.string).flush();
    }


    /***************************************************************************
    
        Called at the start of struct serialization - outputs the name of the
        top-level object.
    
        Params:
            name = name of top-level object
    
    ***************************************************************************/
    
    void open ( char[] name )
    {
        super.open(this.string, name);
    }
    
    
    /***************************************************************************
    
        Called at the end of struct serialization
    
        Params:
            name = name of top-level object
    
    ***************************************************************************/
    
    void close ( char[] name )
    {
        super.close(this.string, name);
    }
    
    
    /***************************************************************************
    
        Writes a named item to Trace
    
        Template params:
            T = type of item
        
        Params:
            item = item to append
            name = name of item
    
    ***************************************************************************/
    
    void serialize ( T ) ( ref T item, char[] name )
    {
        super.serialize(this.string, item, name);
    }
    
    
    /***************************************************************************
    
        Writes a struct to Trace
    
        Params:
            name = name of struct item
            serialize_struct = delegate which is expected to call further
                methods of this class in order to serialize the struct's
                contents
    
    ***************************************************************************/
    
    void serializeStruct ( char[] name, void delegate ( ) serialize_struct )
    {
        super.serializeStruct(this.string, name, serialize_struct);
    }
    
    
    /***************************************************************************
    
        Writes a named array to Trace
    
        Template params:
            T = base type of array
    
        Params:
            array = array to append
            name = name of array item
    
    ***************************************************************************/
    
    void serializeArray ( T ) ( T[] array, char[] name )
    {
        super.serializeArray(this.string, array, name);
    }
    
    
    /***************************************************************************
    
        Writes a named array of structs to Trace.
    
        Template params:
            T = base type of array
    
        Params:
            array = array to append
            name = name of struct item
            serialize_element = delegate which is expected to call further
                methods of this class in order to serialize each struct's
                contents
    
    ***************************************************************************/
    
    void serializeStructArray ( T ) ( char[] name, T[] array, void delegate ( ref T ) serialize_element )
    {
        super.serializeStructArray(this.string, name, array, serialize_element);
    }
}

