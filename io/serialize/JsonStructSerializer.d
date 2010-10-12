/*******************************************************************************

    Serializer, to be used with the StructSerializer, which dumps a struct into
    a json string.
    
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

    The (formatted) output of the above is:

        {
            "Data": {
                "ids": [
                    {
                        "name": "hi",
                        "id": 23
                    },
                    {
                        "name": "hello",
                        "id": 17
                    }
                ],
                "name": "",
                "count": 0,
                "money": 0.00
            }
        }

*******************************************************************************/

module ocean.io.serialize.JsonStructSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import ocean.text.json.Jsonizer;

private import tango.core.Traits : isCharType;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Json struct serializer
    
    Template params:
        Char = character type of output string
        ThreadSafe = if true, the class creates its own private instance of the
                     Jsonizer class. Otherwise it uses a shared global instance.

*******************************************************************************/

class JsonStructSerializer ( Char, bool ThreadSafe = false )
{
    static assert ( isCharType!(Char), typeof(this).stringof ~ " - this class can only handle {char, wchar, dchar}, not " ~ Char.stringof );


    /***************************************************************************

        Convenience alias for the json encoder
    
    ***************************************************************************/

    private alias Jsonizer!(Char) Json;

    
    /***************************************************************************

        Jsonizer object (either created internally, or just a reference to the
        global Jsonizer instance - see Jsonizer.opCall)
    
    ***************************************************************************/

    private Json json;


    /***************************************************************************

        Constructor. Creates the local Jsonizer object, if needed.
    
    ***************************************************************************/

    public this ( )
    {
        static if ( ThreadSafe )
        {
            this.json = new Json();
        }
        else
        {
            this.json = Json(); // use global static instance
        }
    }

    
    /***************************************************************************

        Destructor. Destroys the local Jsonizer, if one was created.

    ***************************************************************************/

    ~this ( )
    {
        static if ( ThreadSafe )
        {
            delete this.json;
        }
    }


    /***************************************************************************

        Called at the start of struct serialization - opens the json string with
        a {
        
        Params:
            output = string to serialize json data to
            name = name of top-level object
    
    ***************************************************************************/

    void open ( ref Char[] output, Char[] name  )
    {
        this.json.open(output, name);
    }


    /***************************************************************************

        Called at the end of struct serialization - closes the json string with
        a }
    
        Params:
            output = string to serialize json data to
            name = name of top-level object
    
    ***************************************************************************/

    void close ( ref Char[] output, Char[] name  )
    {
        this.json.close(output, name);
    }


    /***************************************************************************

        Appends a named element to the json string
    
    ***************************************************************************/

    void serialize ( T ) ( ref Char[] output, ref T item, Char[] name )
    {
        this.json.add(output, name, item);
    }

    
    /***************************************************************************

        Appends a struct to the json string (as a named object)
    
    ***************************************************************************/

    void serializeStruct ( ref Char[] output, Char[] name, void delegate ( ) serialize_struct )
    {
        this.json.addObject(output, name, serialize_struct);
    }

    
    /***************************************************************************

        Appends a named array to the json string
    
    ***************************************************************************/

    void serializeArray ( T ) ( ref Char[] output, T[] array, Char[] name )
    {
        static if ( is(T == char) )
        {
            this.json.add(output, name, array);
        }
        else
        {
            this.json.addArray(output, name, array);
        }
    }

    
    /***************************************************************************

        Appends a named array of structs to the json string, as an array of
        unnamed objects.
    
    ***************************************************************************/

    void serializeStructArray ( T ) ( ref Char[] output, Char[] name, T[] array, void delegate ( ref T ) serialize_element )
    {
        this.json.addObjectArray(output, name, array, serialize_element);
    }
}

