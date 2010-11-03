/*******************************************************************************

    Serializer, to be used with the StructSerializer, which dumps a struct to
    Trace.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        October 2010: Initial release
    
    authors:        Gavin Norman

    Serializer, to be used with the StructSerializer in
    ocean.io.serialize.StructSerializer, which dumps a struct to Trace.

    Usage example (in conjunction with ocean.io.serialize.StructSerializer):
    
    ---

        // Example struct to serizlie to Trace
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
        char[] xml;

        // Set up some data in a struct
        Data data;
        test.ids = [Data.Id("hi", 23), Data.Id("hello", 17)];

        // Create serializer object
        scope ser = new TraceStructSerializer!(char)();

        // Dump struct to string via serializer
        StructSerializer.dump(&data, ser, dummy);

        // Output resulting json
        Trace.formatln("Xml = {}", xml);

    ---

*******************************************************************************/

module ocean.io.serialize.TraceStructSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.util.log.Trace;



/*******************************************************************************

    Trace struct serializer
    
*******************************************************************************/

class TraceStructSerializer
{
    /***************************************************************************

        Indentation size
    
    ***************************************************************************/

    private const indent_size = 3;


    /***************************************************************************

        Indentation level string - filled with spaces.
    
    ***************************************************************************/

    private char[] indent;


    /***************************************************************************

        Called at the start of struct serialization - opens the xml string with
        the required xml header and the open tag of the top-level object.

        Params:
            output = string to serialize xml data to
            name = name of top-level object
    
    ***************************************************************************/

    void open ( char[] name )
    {
        Trace.formatln("Struct {}:", name);
        this.increaseIndent();
    }


    /***************************************************************************

        Called at the end of struct serialization - closes the xml string with
        a close tag for the top-level object
    
        Params:
            output = string to serialize xml data to
            name = name of top-level object

    ***************************************************************************/

    void close ( char[] name )
    {
    }


    /***************************************************************************

        Appends a named item to the xml string

        Template params:
            T = type of item
        
        Params:
            output = string to serialize xml data to
            item = item to append
            name = name of item
    
    ***************************************************************************/

    void serialize ( T ) ( ref T item, char[] name )
    {
        Trace.formatln("{}{} ({}): {}", this.indent, name, T.stringof, item);
    }


    /***************************************************************************

        Appends a struct to the xml string (as a named object)
    
        Params:
            output = string to serialize xml data to
            name = name of struct item
            serialize_struct = delegate which is expected to call further
                methods of this class in order to serialize the struct's
                contents

    ***************************************************************************/

    void serializeStruct ( char[] name, void delegate ( ) serialize_struct )
    {
        Trace.formatln("{}{}:", this.indent, name);
        this.increaseIndent();
        serialize_struct();
        this.decreaseIndent();
    }

    
    /***************************************************************************

        Appends a named array to the xml string

        Template params:
            T = base type of array
    
        Params:
            output = string to serialize xml data to
            array = array to append
            name = name of array item

    ***************************************************************************/

    void serializeArray ( T ) ( T[] array, char[] name )
    {
        Trace.formatln("{}{} ({}[], length {}): {}", this.indent, name, T.stringof, array.length, array);
    }

    
    /***************************************************************************

        Appends a named array of structs to the xml string, as an array of
        indexed objects.
    
        Template params:
            T = base type of array
    
        Params:
            output = string to serialize xml data to
            array = array to append
            name = name of struct item
            serialize_element = delegate which is expected to call further
                methods of this class in order to serialize each struct's
                contents

    ***************************************************************************/

    void serializeStructArray ( T ) ( char[] name, T[] array, void delegate ( ref T ) serialize_element )
    {
        Trace.formatln("{}{} ({}[], length {}):", this.indent, name, T.stringof, array.length);
        this.increaseIndent();

        foreach ( i, item; array )
        {
            serializeStruct("element", { serialize_element(item); });
        }

        this.decreaseIndent();
    }


    /***************************************************************************

        Increases the indentation level.
    
    ***************************************************************************/

    private void increaseIndent ( )
    {
        this.indent.length = this.indent.length + indent_size;
        this.indent[] = ' ';
    }
    

    /***************************************************************************

        Decreases the indentation level.
    
    ***************************************************************************/

    private void decreaseIndent ( )
    in
    {
        assert(this.indent.length >= indent_size, typeof(this).stringof ~ ".decreaseIndent - indentation cannot be decreased");
    }
    body
    {
        this.indent.length = this.indent.length - indent_size;
        this.indent[] = ' ';
    }
}

