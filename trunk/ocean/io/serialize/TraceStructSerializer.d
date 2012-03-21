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

private import ocean.util.log.Trace;



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
        StructSerializer!().serialize(&item, this);
        Trace.formatln("{}", this.string).flush();
    }


    /***************************************************************************
    
        Called at the start of struct serialization -- outputs the name of the
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
    
        Called before a sub-struct is serialized.
    
        Params:
            name = name of struct item
    
    ***************************************************************************/

    void openStruct ( char[] name )
    {
        super.openStruct(this.string, name);
    }


    /***************************************************************************
    
        Called after a sub-struct is serialized.
    
        Params:
            name = name of struct item
    
    ***************************************************************************/

    void closeStruct ( char[] name )
    {
        super.closeStruct(this.string, name);
    }
    
    
    /***************************************************************************
    
        Writes a named array to Trace
    
        Template params:
            T = base type of array
    
        Params:
            array = array to append
            name = name of array item
    
    ***************************************************************************/
    
    void serializeArray ( T ) ( char[] name, T[] array )
    {
        super.serializeArray(this.string, name, array);
    }
    
    
    /***************************************************************************
    
        Called before a struct array is serialized.

        Template params:
            T = base type of array
    
        Params:
            name = name of struct item
            array = array to append

    ***************************************************************************/

    void openStructArray ( T ) ( char[] name, T[] array )
    {
        super.openStructArray(this.string, name, array);
    }


    /***************************************************************************
    
        Called after a struct array is serialized.
    
        Template params:
            T = base type of array
    
        Params:
            name = name of struct item
            array = array to append
    
    ***************************************************************************/

    void closeStructArray ( T ) ( char[] name, T[] array )
    {
        super.closeStructArray(this.string, name, array);
    }
}

