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

        3. The class is not thread-safe, as it makes use of an internal string
           buffer during number -> string conversions.

*******************************************************************************/

module text.json.Jsonizer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import Array = ocean.core.Array;

private import tango.core.Array;

private import Integer = tango.text.convert.Integer;

private import Float = tango.text.convert.Float;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Jsonizable interface - a class which can be jsonized

*******************************************************************************/

interface Jsonizable
{
    void jsonize ( Char ) ( ref Char[] json );
}



/*******************************************************************************

    Jsonizer class template.

    All methods are static.

    Template params:
        Char = character type of output array

    Simple usage example:
    
    ---

        char[] json;
        alias Jsonizer!(typeof(json)) Jsonize;

        Jsonize.open(json);

        Jsonize.append(json, "a number", 23);
        Jsonize.append(json, "a float", 23.23);
        Jsonize.append(json, "a string", "hello");

        Jsonize.close(json);
        
        Trace.formatln("JSON = {}", json);

    ---

    Json array usage example:

    ---

        char[] json;
        alias Jsonizer!(typeof(json)) Jsonize;

        Jsonize.open(json);

        char[][] urls = ["http://www.google.com", "http://www.sociomantic.com"];
        Jsonize.appendArray(json, "urls", urls);
        
        Jsonize.close(json);
        
        Trace.formatln("JSON = {}", json);

    ---

    Json object usage example:

    ---

        char[] json;
        alias Jsonizer!(typeof(json)) Jsonize;

        class AClass : Jsonizable
        {
            uint id;
            char[] name;
            
            public void jsonize ( Char ) ( ref Char[] json )
            {
                Jsonize.append(json, this.id);
                Jsonize.append(json, this.name);
            }
        }

        scope an_object = new AClass();

        Jsonize.open(json);

        Jsonize.append(json, "my object", an_object);

        Jsonize.close(json);
        
        Trace.formatln("JSON = {}", json);

    ---

*******************************************************************************/

class Jsonizer ( Char )
{
    /***************************************************************************

        Private constructor - prevents instantiation

    ***************************************************************************/

    private this ( )
    {
    }

static:

    /***************************************************************************

        String buffer, used for number -> string conversions
    
    ***************************************************************************/

    private Char[] value;


    /***************************************************************************

        Opens a json string by appending a { to it
        
        Params:
            json = json string to append to
    
    ***************************************************************************/

    public void open ( ref Char[] json )
    {
        Array.append(json, "{");
    }


    /***************************************************************************

        Closes a json string by appending a } to it
    
        Params:
            json = json string to append to

        Throws:
            asserts that json string is open
    
    ***************************************************************************/

    public void close ( ref Char[] json )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".close - cannot close a json string which is not open");
    }
    body
    {
        if ( json[$-1] == '{' )
        {
            Array.append(json, "}");
        }
        else
        {
            json[$ - 1] = '}'; // overwrite final ,
        }
    }


    /***************************************************************************

        Appends a named item to a json string.
        
        Params:
            json = json string to append to
            name = name of item
            item = item to append
    
        Throws:
            asserts that json string is open

    ***************************************************************************/

    public void append ( T ) ( ref Char[] json, Char[] name, T item )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".append - cannot append to a json string which is not open");
    }
    body
    {
        static if ( is(T == float) || is(T == double) )
        {
            Array.append(json, `"`, name, `":`, floatToString(item), `,`);
        }
        else static if ( is(T == ubyte) || is(T == byte) || is(T == uint) || is(T == int) || is(T == ulong) || is(T == long) )
        {
            Array.append(json, `"`, name, `":`, intToString(item), `,`);
        }
        else static if ( is(T == Char[]) )
        {
            Array.append(json, `"`, name, `":"`, item, `",`);
        }
        else static if ( is(T : Jsonizable ) )
        {
            Array.append(json, `"`, name, `":`);
            open(json);
            object.jsonize(json);
            close(json);
            Array.append(json, `,`);
        }
        else static assert( false, typeof(this).stringof ~
            ".append - can only jsonize floats, ints, strings or Jsonizable objects, not " ~ T.stringof );
    }


    /***************************************************************************

        Appends a named object to a json string.
        
        Appends the object's name and the opening and closing braces to the
        json string, so the delegate only needs to write the object's internals.
    
        Template params:
            T = type of object to append
        
        Params:
            json = json string to append to
            name = name of object
            object = object to append
            jsonize = delegate to jsonize the passed object
    
        Throws:
            asserts that json string is open
    
    ***************************************************************************/

    public void append ( T ) ( ref Char[] json, Char[] name, T object, void delegate ( ref Char[], ref T ) jsonize )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".append - cannot append to a json string which is not open");
    }
    body
    {
        Array.append(json, `"`, name, `":`);
        open(json);
        jsonize(json, object);
        close(json);
        Array.append(json, `,`);
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

    public void appendArray ( T ) ( ref Char[] json, Char[] name, T[] array )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".appendArray - cannot append to a json string which is not open");
    }
    body
    {
        Array.append(json, `"`, name, `":[`);
        foreach ( e; array )
        {
            append(json, e);
        }
        json.length = json.length - 1; // cut off final ,
        Array.append(json, `],`);
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
    
    public void appendArrayIndexed ( T ) ( ref Char[] json, Char[] name, size_t count, T delegate ( size_t index ) get_element )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".appendArrayIndexed - cannot append to a json string which is not open");
    }
    body
    {
        Array.append(json, `"`, name, `":[`);
        for ( size_t i; i < count; i++ )
        {
            append(json, get_element(i));
        }
        json.length = json.length - 1; // cut off final ,
        Array.append(json, `],`);
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

    public void appendObjectArray ( T ) ( ref Char[] json, Char[] name, T[] array, void delegate ( ref Char[], ref T ) jsonize )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".appendObjectArray - cannot append to a json string which is not open");
    }
    body
    {
        Array.append(json, `"`, name, `":[`);
        foreach ( e; array )
        {
            appendObject(json, e, jsonize);
        }
        json.length = json.length - 1; // cut off final ,
        Array.append(json, `],`);
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
    
    public void appendObjectArrayIndexed ( ref Char[] json, Char[] name, size_t count, void delegate (ref Char[] json, size_t index ) append_element )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".appendObjectArrayIndexed - cannot append to a json string which is not open");
    }
    body
    {
        Array.append(json, `"`, name, `":[`);
        for ( size_t i; i < count; i++ )
        {
            Array.append(json, `{`);
            append_element(json, i);
            json.length = json.length - 1; // cut off final ,
            Array.append(json, `},`);
        }
        json.length = json.length - 1; // cut off final ,
        Array.append(json, `],`);
    }


    /***************************************************************************

        Appends an unnamed item to a json string. Used by the appendArray
        method.
        
        Params:
            json = json string to append to
            item = item to append
    
        Throws:
            asserts that json string is open
    
    ***************************************************************************/

    private void append ( T ) ( ref Char[] json, T item )
    {
        static if ( is(T == float) || is(T == double) )
        {
            Array.append(json, floatToString(item), `,`);
        }
        else static if ( is(T == ubyte) || is(T == byte) || is(T == uint) || is(T == int) || is(T == ulong) || is(T == long) )
        {
            Array.append(json, intToString(item), `,`);
        }
        else static if ( is(T == Char[]) )
        {
            Array.append(json, `"`, item, `",`);
        }
        else static if ( is(T : Jsonizable ) )
        {
            open(json);
            item.jsonize(json);
            close(json);
            Array.append(json, `,`);
        }
        else static assert( false, typeof(this).stringof ~
            ".append - can only jsonize floats, ints, strings or Jsonizable objects, not " ~ T.stringof );
    }


    /***************************************************************************

        Appends an unnamed object to a json string. Used by the
        appendObjectArray method.
    
        Template params:
            T = type of object to append
        
        Params:
            json = json string to append to
            object = object to append
            jsonize = delegate to jsonize the passed object
    
        Throws:
            asserts that json string is open
    
    ***************************************************************************/

    private void appendObject ( T ) ( ref Char[] json, T object, void delegate ( ref Char[], ref T ) jsonize )
    {
        open(json);
        jsonize(json, object);
        close(json);
        Array.append(json, `,`);
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
    
        Template params:
            T = type of value
        
        Params:
            n = value to convert
    
        Returns:
            string conversion of n
    
    ***************************************************************************/
    
    private Char[] floatToString ( T ) ( T n )
    {
        value.length = 20;
        value = Float.format(value, n);
        return value;
    }
}

