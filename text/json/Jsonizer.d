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

*******************************************************************************/

module text.json.Jsonizer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

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

        Jsonize.appendInteger(json, "a number", 23);
        Jsonize.appendFloat(json, "a float", 23.23);
        Jsonize.appendString(json, "a string", "hello");

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
                Jsonize.appendInteger(json, this.id);
                Jsonize.appendString(json, this.name);
            }
        }

        scope an_object = new AClass();

        Jsonize.open(json);

        Jsonize.appendObject(json, "my object", an_object);

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
        json.append("{");
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
            json.append("}");
        }
        else
        {
            json[$ - 1] = '}'; // overwrite final ,
        }
    }


    /***************************************************************************

        Appends a named integer to a json string.
        
        Params:
            json = json string to append to
            name = name of integer
            n = integer to append
    
        Throws:
            asserts that json string is open
    
    ***************************************************************************/

    public void appendInteger ( ref Char[] json, Char[] name, uint n )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".appendInteger - cannot append to a json string which is not open");
    }
    body
    {
        value.length = 20;
        value = Integer.format(value, n);
        json.append(`"`, name, `":`, value, `,`);
    }


    /***************************************************************************

        Appends a named float to a json string.
        
        Params:
            json = json string to append to
            name = name of float
            n = float to append
    
        Throws:
            asserts that json string is open
    
    ***************************************************************************/

    public void appendFloat ( ref Char[] json, Char[] name, float n )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".appendFloat - cannot append to a json string which is not open");
    }
    body
    {
        value.length = 20;
        value = Float.format(value, n);
        json.append(`"`, name, `":`, value, `,`);
    }


    /***************************************************************************

        Appends a named string to a json string.
        
        Params:
            json = json string to append to
            name = name of string
            string = string to append
    
        Throws:
            asserts that json string is open
    
    ***************************************************************************/

    public void appendString ( ref Char[] json, Char[] name, Char[] string )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".appendString - cannot append to a json string which is not open");
    }
    body
    {
        json.append(`"`, name, `":"`, string, `",`);
    }


    /***************************************************************************

        Appends a named Jsonizable object to a json string.
    
        Template params:
            T = type of object to append
        
        Params:
            json = json string to append to
            name = name of object
            object = object to append
    
        Throws:
            asserts that json string is open
    
    ***************************************************************************/
    
    public void appendObject ( T : Jsonizable ) ( ref Char[] json, Char[] name, T object )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".appendObject - cannot append to a json string which is not open");
    }
    body
    {
        json.append(`"`, name, `":`);
        open(json);
        object.jsonize(json);
        close(json);
        json.append(`,`);
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

    public void appendObject ( T ) ( ref Char[] json, Char[] name, T object, void delegate ( ref Char[], ref T ) jsonize )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".appendObject - cannot append to a json string which is not open");
    }
    body
    {
        json.append(`"`, name, `":`);
        open(json);
        jsonize(json, object);
        close(json);
        json.append(`,`);
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
        json.append(`"`, name, `":[`);
        foreach ( e; array )
        {
            static if ( is(T == float) )
            {
                appendFloat(json, e);
            }
            else static if ( is(T == uint) )
            {
                appendInteger(json, e);
            }
            else static if ( is(T == Char[]) )
            {
                appendString(json, e);
            }
            else static if ( is(T : Jsonizable ) )
            {
                appendObject(json, e);
            }
            else static assert( false, typeof(this).stringof ~
                ".appendArray - can only jsonize floats, uints, strings or Jsonizable objects, not " ~ T.stringof );
        }
        json.length = json.length - 1; // cut off final ,
        json.append(`],`);
    }


    /***************************************************************************

        Appends a named array of objects to a json string, with a delegate to do
        the actual writing of each element to the string.

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
        json.append(`"`, name, `":[`);
        foreach ( e; array )
        {
            appendObject(json, e, jsonize);
        }
        json.length = json.length - 1; // cut off final ,
        json.append(`],`);
    }


    /***************************************************************************

        Appends an unnamed integer to a json string. Used by the appendArray
        method.
        
        Params:
            json = json string to append to
            n = integer to append
    
    ***************************************************************************/
    
    private void appendInteger ( ref Char[] json, uint n )
    {
        value.length = 20;
        value = Integer.format(value, n);
        json.append(value, `,`);
    }


    /***************************************************************************

        Appends an unnamed float to a json string. Used by the appendArray
        method.
        
        Params:
            json = json string to append to
            n = float to append
    
    ***************************************************************************/

    private void appendFloat ( ref Char[] json, float n )
    {
        value.length = 20;
        value = Float.format(value, n);
        json.append(value, `,`);
    }


    /***************************************************************************

        Appends an unnamed string to a json string. Used by the appendArray
        method.
        
        Params:
            json = json string to append to
            string = string to append
    
    ***************************************************************************/

    private void appendString ( ref Char[] json, Char[] string )
    {
        json.append(`"`, string, `",`);
    }


    /***************************************************************************

        Appends an unnamed Jsonizable object to a json string. Used by the
        appendArray method.

        Template params:
            T = type of object to append
        
        Params:
            json = json string to append to
            object = object to append
    
        Throws:
            asserts that json string is open
    
    ***************************************************************************/
    
    private void appendObject ( T : Jsonizable ) ( ref Char[] json, T object )
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".appendObject - cannot append to a json string which is not open");
    }
    body
    {
        open(json);
        object.jsonize(json);
        close(json);
        json.append(`,`);
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
    in
    {
        assert(isOpen(json), typeof(this).stringof ~ ".appendObject - cannot append to a json string which is not open");
    }
    body
    {
        open(json);
        jsonize(json, object);
        close(json);
        json.append(`,`);
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
}

