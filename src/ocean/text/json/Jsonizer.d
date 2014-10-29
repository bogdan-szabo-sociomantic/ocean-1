/*******************************************************************************

    Functions to create json strings.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        October 2010: Initial release

    authors:        Gavin Norman

    Notes:

        1. This module only encodes json strings, it does not decode (see
           tango.text.json.Json for a decoder)

        2. The json encoder in this module works in a fairly different way to
           the tango equivalent, as it allows a json string to be opened and
           elements to be appended gradually. (The tango version expects all
           elements to be added at once.)

        3. The class uses an internal string buffer for number -> string
           conversion. If thread-safety is not required, a single global
           (static) instance of the class can be accessed via the opCall method.

        4. An automatic json struct serializer exists in
           ocean.io.serialize.JsonStructSerializer

*******************************************************************************/

module ocean.text.json.Jsonizer;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Array;

import tango.core.Array;

import tango.core.Traits : isRealType, isIntegerType;

import tango.math.IEEE : isNaN;

import Integer = tango.text.convert.Integer;

import Float = tango.text.convert.Float;



/*******************************************************************************

    Jsonizable interface - a class which can be jsonized

*******************************************************************************/

interface Jsonizable
{
    void jsonize ( Char ) ( ref Char[] json );
}



/*******************************************************************************

    Jsonizer class template.

    Template params:
        Char = character type of output array

    Simple usage example:

    ---

        char[] json;
        alias Jsonizer!(typeof(json)) Jsonize;

        Jsonize().open(json);

        Jsonize().append(json, "a number", 23);
        Jsonize().append(json, "a float", 23.23);
        Jsonize().append(json, "a string", "hello");

        Jsonize().close(json);

        Stdout.formatln("JSON = {}", json);

    ---

    Json array usage example:

    ---

        char[] json;
        alias Jsonizer!(typeof(json)) Jsonize;

        Jsonize().open(json);

        char[][] urls = ["http://www.google.com", "http://www.sociomantic.com"];
        Jsonize().appendArray(json, "urls", urls);

        Jsonize().close(json);

        Stdout.formatln("JSON = {}", json);

    ---

    Jsonizable object usage example:

    ---

        char[] json;
        alias Jsonizer!(typeof(json)) Jsonize;

        class AClass : Jsonizable
        {
            uint id;
            char[] name;

            public void jsonize ( Char ) ( ref Char[] json )
            {
                Jsonize().append(json, this.id);
                Jsonize().append(json, this.name);
            }
        }

        scope an_object = new AClass();

        Jsonize().open(json);

        Jsonize().append(json, "my object", an_object);

        Jsonize().close(json);

        Stdout.formatln("JSON = {}", json);

    ---

    Json nested struct (with delegates) usage example:

    ---

        char[] json;

        struct Id
        {
            uint id;
            char[] name;
        }

        struct Record
        {
            Id id;
            char[] name;
            uint total;
        }

        Record a_record;

        with ( Jsonizer!(char) )
        {
            open(json);

            append(json, "record", a_record, ( ref char[] json, ref Record record ) {
                append(json, "id", record.id, ( ref char[] json, ref Id id ) {
                    append(json, "id", id.id);
                    append(json, "name", id.name);
                });
                append(json, "name", record.name);
                append(json, "total", record.total);
            });

            close(json);
        }

        Stdout.formatln("JSON = {}", json);

    ---

*******************************************************************************/

class Jsonizer ( Char )
{
    /***************************************************************************

        String buffer, used for number -> string conversions

    ***************************************************************************/

    private Char[] value;


    /***************************************************************************

        Opens a json string by appending a { to it, and optionally opens a named
        top-level object.

        Params:
            json = json string to append to
            name = name of top-level object

    ***************************************************************************/

    public void open ( ref Char[] json, Char[] name = "" )
    {
        if ( name.length )
        {
            json.append(`{"`, name, `":{`);
        }
        else
        {
            json.append("{");
        }
    }


    /***************************************************************************

        Closes a json string by appending a } to it. If a named top-level object
        was appened by open(), an extra } is appended here to close it.

        Params:
            json = json string to append to
            name = name of top-level object

        Throws:
            asserts that json string is open

    ***************************************************************************/

    public void close ( ref Char[] json, Char[] name = "" )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".close - cannot close a json string which is not open");
    }
    body
    {
        json.length = json.length - 1; // cut off final ,

        if ( name.length )
        {
            json.append("}}");
        }
        else
        {
            json.append("}");
        }
    }


    /***************************************************************************

        Appends a named item to a json string.

        Template params:
            T = type of object to add

        Params:
            json = json string to append to
            name = name of item
            item = item to append

        Throws:
            asserts that json string is open and that the type of the object is
            supported

    ***************************************************************************/

    public void add ( T ) ( ref Char[] json, Char[] name, T item )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".add - cannot append to a json string which is not open");
    }
    body
    {
        static if ( isRealType!(T) )
        {
            json.append(`"`, name, `":`, floatToString(item), `,`);
        }
        else static if ( isIntegerType!(T) || is(T == bool) )
        {
            json.append(`"`, name, `":`, intToString(item), `,`);
        }
        else static if ( is(T == Char[]) )
        {
            json.append(`"`, name, `":"`, item, `",`);
        }
        else static if ( is(T : Jsonizable ) )
        {
            openSub(json, "{", name);
            object.jsonize(json);
            closeSub(json, "},", "{");
        }
        else static assert( false, typeof(this).stringof ~
            ".add - can only jsonize floats, bools, ints, strings or Jsonizable objects, not " ~ T.stringof );
    }


    /***************************************************************************

        Appends a named object to a json string.

        Appends the object's name and the opening and closing braces to the
        json string, so the delegate only needs to write the object's internals.

        Params:
            json = json string to append to
            name = name of object
            jsonize = delegate to jsonize the object

        Throws:
            asserts that json string is open

    ***************************************************************************/

    public void addObject ( ref Char[] json, Char[] name, void delegate ( ) jsonize )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".addObject - cannot append to a json string which is not open");
    }
    body
    {
        openSub(json, "{", name);
        jsonize();
        closeSub(json, "},", "{");
    }


    /***************************************************************************

        Appends a named array to a json string.

        Arrays of integers, floats, strings and Jsonizable objects can be
        appended.

        Template params:
            T = type of array element to append

        Params:
            json = json string to append to
            name = name of array
            array = array to append

        Throws:
            asserts that json string is open

    ***************************************************************************/

    public void addArray ( T ) ( ref Char[] json, Char[] name, T[] array )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".addArray - cannot append to a json string which is not open");
    }
    body
    {
        openSub(json, "[", name);
        foreach ( e; array )
        {
            addUnnamed(json, e);
        }
        closeSub(json, "],", "[");
    }


    /***************************************************************************

        Appends a named array of objects to a json string, with a delegate to do
        the actual writing of each element to the string.

        Each element in the array is wrapped with {}, as an (unnamed) object.

        Template params:
            T = type of array element to append

        Params:
            json = json string to append to
            name = name of array
            array = array to append
            jsonize = delegate to jsonize the passed objects

        Throws:
            asserts that json string is open

    ***************************************************************************/

    public void addObjectArray ( T ) ( ref Char[] json, Char[] name, T[] array, void delegate ( ref T ) jsonize )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".addObjectArray - cannot append to a json string which is not open");
    }
    body
    {
        openSub(json, "[", name);
        foreach ( e; array )
        {
            openSub(json, "{");
            jsonize(e);
            closeSub(json, "},", "{");
        }
        closeSub(json, "],", "[");
    }


    /***************************************************************************

        Appends a named array to a json string.

        The array is not passed directly, rather the number of items in the
        array plus a delegate to write items by index are given.

        Params:
            json = json string to append to
            name = name of array
            count = number of elements in the array
            get_element = delegate to get an indexed element

        Throws:
            asserts that json string is open

    ***************************************************************************/

    public void addArrayIndexed ( T ) ( ref Char[] json, Char[] name, size_t count, T delegate ( size_t index ) get_element )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".addArrayIndexed - cannot append to a json string which is not open");
    }
    body
    {
        openSub(json, "[", name);
        for ( size_t i; i < count; i++ )
        {
            addUnnamed(json, get_element(i));
        }
        closeSub(json, "],", "[");
    }


    /***************************************************************************

        Appends a named array of objects to a json string.

        The array is not passed directly, rather the number of items in the
        array plus a delegate to write items by index are given.

        Each element in the array is wrapped with {}, as an (unnamed) object.

        Params:
            json = json string to append to
            name = name of array
            count = number of elements in the array
            append_element = delegate to append an element to the json string

        Throws:
            asserts that json string is open

    ***************************************************************************/

    public void addObjectArrayIndexed ( ref Char[] json, Char[] name, size_t count, void delegate ( size_t index ) append_element )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".addObjectArrayIndexed - cannot append to a json string which is not open");
    }
    body
    {
        openSub(json, "[", name);
        for ( size_t i; i < count; i++ )
        {
            openSub(json, "{");
            append_element(i);
            closeSub(json, "},", "{");
        }
        closeSub(json, "],", "[");
    }


    /***************************************************************************

        Opens a sub-structure.

        Params:
            json = json string to append to
            opener = string to open with
            name = optional name of sub-structure

        Throws:
            asserts that json string is open

    ***************************************************************************/

    private void openSub ( ref Char[] json, Char[] opener, Char[] name = "" )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".openSub - cannot close a json string which is not open");
    }
    body
    {
        if ( name.length )
        {
            json.append(`"`, name, `":`, opener);
        }
        else
        {
            json.append(opener);
        }
    }


    /***************************************************************************

        Closes a sub-structure.

        Params:
            json = json string to append to
            closer = string to close with

        Throws:
            asserts that json string is open

    ***************************************************************************/

    private void closeSub ( ref Char[] json, Char[] closer, Char[] opener )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".closeSub - cannot close a json string which is not open");
        assert(json.length >= opener.length, typeof(this).stringof ~ ".closeSub - the specified opener hasn't been added to the json string");
    }
    body
    {
        if ( opener.length && json[$ - opener.length .. $] == opener )
        {
            json.append(closer);
        }
        else
        {
            json.length = json.length - 1; // cut off final ,
            json.append(closer);
        }
    }


    /***************************************************************************

        Appends an unnamed item to a json string. Used by the appendArray
        methods.

        Template params:
            T = type of object to add

        Params:
            json = json string to append to
            item = item to append

        Throws:
            asserts that json string is open and that the type of the object is
            supported

    ***************************************************************************/

    private void addUnnamed ( T ) ( ref Char[] json, T item )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".addUnnamed - cannot append to a json string which is not open");
    }
    body
    {
        static if ( isRealType!(T) )
        {
            json.append(floatToString(item), `,`);
        }
        else static if ( isIntegerType!(T) || is(T == bool) )
        {
            json.append(intToString(item), `,`);
        }
        else static if ( is(T == Char[]) )
        {
            json.append(`"`, item, `",`);
        }
        else static if ( is(T : Jsonizable ) )
        {
            openSub(json);
            item.jsonize(json);
            closeSub(json, "},", "{");
        }
        else static assert( false, typeof(this).stringof ~
            ".addUnnamed - can only jsonize floats, bools, ints, strings or Jsonizable objects, not " ~ T.stringof );
    }


    /***************************************************************************

        Returns:
            true if the passed json string is open

    ***************************************************************************/

    private bool isOpen ( Char[] json )
    {
        const Char[] valid_ends = "{[,";
        return json.length && valid_ends.contains(json[$-1]);
    }


    /***************************************************************************

        Converts an integer to a string, using the internal 'value' member.

        Template params:
            T = type of value

        Params:
            n = value to convert

        Returns:
            string conversion of n

    ***************************************************************************/

    private Char[] intToString ( T ) ( T n )
    {
        value.length = 20;
        value = Integer.format(value, n);
        return value;
    }


    /***************************************************************************

        Converts a float to a string, using the internal 'value' member.

        Note: NaN values are serialized as 0.0

        Template params:
            T = type of value

        Params:
            n = value to convert

        Returns:
            string conversion of n

    ***************************************************************************/

    private Char[] floatToString ( T ) ( T n )
    {
        if ( isNaN(n) )
        {
            n = 0.0;
        }
        value.length = 20;
        value = Float.format(value, n);
        return value;
    }


    /***************************************************************************

        Returns:
            global static instance of this class

    ***************************************************************************/

    public static Jsonizer!(Char) opCall ( )
    {
        return getStaticInstance();
    }


    /***************************************************************************

        Static destructor. Deletes the shared instance.

    ***************************************************************************/

    static ~this ( )
    {
        delete static_instance;
    }


    /***************************************************************************

        Static global instance

    ***************************************************************************/

    private static Jsonizer!(Char) static_instance;


    /***************************************************************************

        Returns:
            gloab lstatic instance, created if necessary

    ***************************************************************************/

    private static Jsonizer!(Char) getStaticInstance ( )
    {
        if ( !static_instance )
        {
            static_instance = new Jsonizer!(Char);
        }

        return static_instance;
    }
}

