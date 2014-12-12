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
        ser.serialize(output, data);

    ---

*******************************************************************************/

module ocean.io.serialize.StringStructSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Array;

import ocean.io.serialize.StructSerializer;

import tango.text.convert.Format;

import tango.text.convert.Layout;

import tango.core.Traits;



/*******************************************************************************

    String struct serializer

    Template params:
        Char = character type of output string

*******************************************************************************/

public class StringStructSerializer ( Char )
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

        format string for displaying an item of type floating point

    ***************************************************************************/

    private const char[] fp_format;


    /***************************************************************************

        Constructor, sets the maximum number of decimal digits to show for
        floating point types.

        Params:
            fp_dec_to_display = maximum number of decimal digits to show for
                                floating point types.

    ***************************************************************************/

    public this ( size_t fp_dec_to_display = 2 )
    {
        this.fp_format = "{}{} {} : {:.";
        Format.format(this.fp_format, "{}", fp_dec_to_display);
        this.fp_format ~= "}\n";
    }


    /***************************************************************************

        Convenience method to serialize a struct.

        Template params:
            T = type of struct to serialize

        Params:
            output = string to serialize struct data to
            item = struct to serialize

    ***************************************************************************/

    public void serialize ( T ) ( ref Char[] output, ref T item )
    {
        StructSerializer!(true).serialize(&item, this, output);
    }


    /***************************************************************************

        Called at the start of struct serialization - outputs the name of the
        top-level object.

        Params:
            output = string to serialize struct data to
            name = name of top-level object

    ***************************************************************************/

    public void open ( ref Char[] output, char[] name )
    {
        Layout!(Char).format(output, "{}struct {}:\n", this.indent, name);
        this.increaseIndent();
    }


    /***************************************************************************

        Called at the end of struct serialization

        Params:
            output = string to serialize struct data to
            name = name of top-level object

    ***************************************************************************/

    public void close ( ref Char[] output, char[] name )
    {
        this.decreaseIndent();
    }


    /***************************************************************************

        Appends a named item to the output string.

        Note: the main method to use from the outside is the first serialize()
        method above. This method is for the use of the StructSerializer.

        Template params:
            T = type of item

        Params:
            output = string to serialize struct data to
            item = item to append
            name = name of item

    ***************************************************************************/

    public void serialize ( T ) ( ref Char[] output, ref T item, char[] name )
    {
        // TODO: temporary support for unions by casting them to ubyte[]
        static if ( is(T == union) )
        {
            Layout!(Char).format(output, "{}union {} {} : {}\n", this.indent, T.stringof, name, (cast(ubyte*)&item)[0..item.sizeof]);
        }
        else static if ( isFloatingPointType!(T) )
        {
            Layout!(Char).format(output, this.fp_format, this.indent, T.stringof, name, item);
        }
        else
        {
            Layout!(Char).format(output, "{}{} {} : {}\n", this.indent, T.stringof, name, item);
        }
    }


    /***************************************************************************

        Called before a sub-struct is serialized.

        Params:
            output = string to serialize struct data to
            name = name of struct item

    ***************************************************************************/

    public void openStruct ( ref Char[] output, char[] name )
    {
        Layout!(Char).format(output, "{}struct {}:\n", this.indent, name);
        this.increaseIndent();
    }


    /***************************************************************************

        Called after a sub-struct is serialized.

        Params:
            output = string to serialize struct data to
            name = name of struct item

    ***************************************************************************/

    public void closeStruct ( ref Char[] output, char[] name )
    {
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

    public void serializeArray ( T ) ( ref Char[] output, char[] name, T[] array )
    {
        Layout!(Char).format(output, "{}{}[] {} (length {}): {}\n", this.indent, T.stringof, name, array.length, array);
    }


    /***************************************************************************

        Called before a struct array is serialized.

        Template params:
            T = base type of array

        Params:
            output = string to serialize struct data to
            name = name of struct item
            array = array to append

    ***************************************************************************/

    public void openStructArray ( T ) ( ref Char[] output, char[] name, T[] array )
    {
        Layout!(Char).format(output, "{}{}[] {} (length {}):\n", this.indent, T.stringof, name, array.length);
        this.increaseIndent();
    }


    /***************************************************************************

        Called after a struct array is serialized.

        Template params:
            T = base type of array

        Params:
            output = string to serialize struct data to
            name = name of struct item
            array = array to append

    ***************************************************************************/

    public void closeStructArray ( T ) ( ref Char[] output, char[] name, T[] array )
    {
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

