/*******************************************************************************

    Serializer, to be used with the StructSerializer, which dumps a struct into
    a json string.
    
    in ocean.io.serialize.StructSerializer.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        October 2010: Initial release
    
    authors:        Gavin Norman

    Serializer, to be used with the StructSerializer in
    ocean.io.serialize.StructSerializer, which dumps a struct into a json
    string.

    Usage example (in conjunction with ocean.io.serialize.StructSerializer):
    
    ---

        // Example struct to serialize into json
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

        // Output string buffer
        char[] json;

        // Set up some data in a struct
        Data data;
        test.ids = [Data.Id("hi", 23), Data.Id("hello", 17)];

        // Create serializer object
        scope ser = new JsonStructSerializer!(char)();

        // Dump struct to string via serializer
        StructSerializer.dump(&data, ser, json);

        // Output resulting json
        Trace.formatln("Json = {}", json);

    ---

*******************************************************************************/

module ocean.io.serialize.JsonStructSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.text.json.Jsonizer;

private import tango.core.Traits : isCharType;



/*******************************************************************************

    Json struct serializer
    
    Template params:
        Char = character type of output string

*******************************************************************************/

class JsonStructSerializer ( Char )
{
    static assert ( isCharType!(Char), typeof(this).stringof ~ " - this class can only handle {char, wchar, dchar}, not " ~ Char.stringof );


    /***************************************************************************

        Convenience alias for the json encoder
    
    ***************************************************************************/

    private alias Jsonizer!(Char) Json;


static:

    /***************************************************************************

        Called at the start of struct serialization - opens the json string with
        a {
    
    ***************************************************************************/

    void open ( ref Char[] output )
    {
        Json.open(output);
    }


    /***************************************************************************

        Called at the end of struct serialization - closes the json string with
        a }
    
    ***************************************************************************/

    void close ( ref Char[] output )
    {
        Json.close(output);
    }


    /***************************************************************************

        Appends a named element to the json string
    
    ***************************************************************************/

    void serialize ( T ) ( ref Char[] output, ref T item, char[] name )
    {
        Json.append(output, name, item);
    }

    
    /***************************************************************************

        Appends a struct to the json string (as a named object)
    
    ***************************************************************************/

    void serializeStruct ( ref Char[] output, Char[] name, void delegate ( ) serialize_struct )
    {
        Json.appendObject(output, name, serialize_struct);
    }

    
    /***************************************************************************

        Appends a named array to the json string
    
    ***************************************************************************/

    void serializeArray ( T ) ( ref Char[] output, T[] array, Char[] name )
    {
        static if ( is(T == char) )
        {
            Json.append(output, name, array);
        }
        else
        {
            Json.appendArray(output, name, array);
        }
    }

    
    /***************************************************************************

        Appends a named array of structs to the json string, as an array of
        unnamed objects.
    
    ***************************************************************************/

    void serializeStructArray ( T ) ( ref Char[] output, Char[] name, T[] array, void delegate ( ref T ) serialize_element )
    {
        Json.appendObjectArray(output, name, array, serialize_element);
    }
}

