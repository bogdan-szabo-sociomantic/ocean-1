/*******************************************************************************

    Serializer, to be used with the StructSerializer, which dumps a struct to
    a string.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        November 2010: Initial release
    
    authors:        Gavin Norman
    
    Serializer, to be used with the StructSerializer in
    ocean.io.serialize.StructSerializer, which dumps a struct to a string.
    
    Usage example (in conjunction with ocean.io.serialize.StructSerializer):
    
    ---
    
        // Example struct to serialize
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
        scope ser = new StringStructSerializer!(char)();
        
        // A string buffer
        char[] output;
    
        // Dump struct to buffer via serializer
        ser.serialize(buffer, data);
    
    ---

*******************************************************************************/

module ocean.io.serialize.StringStructSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import ocean.io.serialize.StructSerializer;

private import tango.text.convert.Layout;

private import tango.core.Traits;



/*******************************************************************************

    String struct serializer

    Template params:
        Char = character type of output string

*******************************************************************************/

class StringStructSerializer ( Char )
{
    static assert ( isCharType!(Char), typeof(this).stringof ~ " - this class can only handle {char, wchar, dchar}, not " ~ Char.stringof );

    /***************************************************************************
    
        Indentation size
    
    ***************************************************************************/
    
    private const indent_size = 3;
    
    
    /***************************************************************************
    
        Indentation level string - filled with spaces.
    
    ***************************************************************************/
    
    private Char[] indent;
    
    
    /***************************************************************************
    
        Convenience method to serialize a struct.
    
        Template params:
            T = type of struct to serialize
        
        Params:
            output = string to serialize struct data to
            item = struct to serialize
    
    ***************************************************************************/
    
    void serialize ( T ) ( ref Char[] output, ref T item )
    {
        StructSerializer.serialize(&item, this, output);
    }
    
    
    /***************************************************************************
    
        Called at the start of struct serialization - outputs the name of the
        top-level object.
    
        Params:
            output = string to serialize struct data to
            name = name of top-level object
    
    ***************************************************************************/
    
    void open ( ref Char[] output, char[] name )
    {
        Layout!(char).instance().convert(( char[] s) { output.append(s); return s.length; },
                "{}struct {}:\n",
                this.indent, name);
        this.increaseIndent();
    }
    
    
    /***************************************************************************
    
        Called at the end of struct serialization
    
        Params:
            output = string to serialize struct data to
            name = name of top-level object
    
    ***************************************************************************/
    
    void close ( ref Char[] output, char[] name )
    {
        this.decreaseIndent();
    }
    
    
    /***************************************************************************
    
        Appends a named item to the output string
    
        Template params:
            T = type of item
        
        Params:
            output = string to serialize struct data to
            item = item to append
            name = name of item
    
    ***************************************************************************/
    
    void serialize ( T ) ( ref Char[] output, ref T item, char[] name )
    {
        Layout!(Char).instance().convert(( Char[] s) { output.append(s); return s.length; },
                "{}{} {} : {}\n",
                this.indent, T.stringof, name, item);
    }
    
    
    /***************************************************************************
    
        Appends a struct to the output string
    
        Params:
            output = string to serialize struct data to
            name = name of struct item
            serialize_struct = delegate which is expected to call further
                methods of this class in order to serialize the struct's
                contents
    
    ***************************************************************************/
    
    void serializeStruct ( ref Char[] output, char[] name, void delegate ( ) serialize_struct )
    {
        Layout!(Char).instance().convert(( Char[] s) { output.append(s); return s.length; },
                "{}struct {}:\n",
                this.indent, name);
        this.increaseIndent();
        serialize_struct();
        this.decreaseIndent();
    }
    
    
    /***************************************************************************
    
        Appends a named array to the output string
    
        Template params:
            T = base type of array
    
        Params:
            output = string to serialize struct data to
            array = array to append
            name = name of array item
    
    ***************************************************************************/
    
    void serializeArray ( T ) ( ref Char[] output, T[] array, char[] name )
    {
        Layout!(Char).instance().convert(( Char[] s) { output.append(s); return s.length; },
                "{}{}[] {} (length {}): {}\n",
                this.indent, T.stringof, name, array.length, array);
    }
    
    
    /***************************************************************************
    
        Appends a named array of structs to the output string, as an array of
        indexed objects.
    
        Template params:
            T = base type of array
    
        Params:
            output = string to serialize struct data to
            array = array to append
            name = name of struct item
            serialize_element = delegate which is expected to call further
                methods of this class in order to serialize each struct's
                contents
    
    ***************************************************************************/
    
    void serializeStructArray ( T ) ( ref Char[] output, char[] name, T[] array, void delegate ( ref T ) serialize_element )
    {
        Layout!(Char).instance().convert(( Char[] s) { output.append(s); return s.length; },
                "{}{}[] {} (length {}):\n",
                this.indent, T.stringof, name, array.length);
        this.increaseIndent();
    
        foreach ( i, item; array )
        {
            this.serializeStruct(output, T.stringof, { serialize_element(item); });
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

