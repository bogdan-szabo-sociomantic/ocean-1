/*******************************************************************************

    Serializer, to be used with the StructSerializer, which dumps a struct into
    an xmlstring.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        October 2010: Initial release
    
    authors:        Gavin Norman

    Serializer, to be used with the StructSerializer in
    ocean.io.serialize.StructSerializer, which dumps a struct into an xml
    string.


    Usage example (in conjunction with ocean.io.serialize.StructSerializer):
    
    ---

        // Example struct to serialize into xml
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
        scope ser = new XmlStructSerializer!(char)();

        // Dump struct to string via serializer
        StructSerializer.dump(&data, ser, xml);

        // Output resulting json
        Trace.formatln("Xml = {}", xml);

    ---

    The (formatted) output of the above is:

    <?xml version="1.0" encoding="UTF-8" ?>
    <Data>
        <ids>
            <element n="0"><
                name>hi</name>
                <id>23</id>
            </element>
            <element n="1">
                <name>hello</name>
                <id>17</id>
            </element>
        </ids>
        <name></name>
        <count>0</count>
        <money>nan</money>
    </Data>

*******************************************************************************/

module io.serialize.XmlStructSerializer;

private import ocean.core.Array;

private import tango.core.Array;

private import tango.core.Traits;

private import Integer = tango.text.convert.Integer;

private import Float = tango.text.convert.Float;



/*******************************************************************************

    Xml struct serializer
    
    Template params:
        Char = character type of output string

*******************************************************************************/

class XmlStructSerializer ( Char )
{
    static assert ( isCharType!(Char), typeof(this).stringof ~ " - this class can only handle {char, wchar, dchar}, not " ~ Char.stringof );

    /***************************************************************************

        Internal string buffers
    
    ***************************************************************************/

    private Char[] element_name, buf;


    /***************************************************************************

        Called at the start of struct serialization - opens the xml string with
        the required xml header and the open tag of the top-level object.

        Params:
            output = string to serialize xml data to
            name = name of top-level object
    
    ***************************************************************************/

    void open ( ref Char[] output, Char[] name )
    {
        output.append(`<?xml version="1.0" encoding="UTF-8" ?>`, "<", name, ">");
    }


    /***************************************************************************

        Called at the end of struct serialization - closes the xml string with
        a close tag for the top-level object
    
        Params:
            output = string to serialize xml data to
            name = name of top-level object

    ***************************************************************************/

    void close ( ref Char[] output, Char[] name )
    {
        output.append("</", name, ">");
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

    void serialize ( T ) ( ref Char[] output, ref T item, Char[] name )
    {
        openEntity(output, name);

        static if ( is(T == Char[]) )
        {
            output.append(item);
        }
        else static if ( isIntegerType!(T) )
        {
            buf.length = 20;
            output.append(Integer.format(buf, item));
        }
        else static if ( isRealType!(T) )
        {
            buf.length = 20;
            output.append(Float.format(buf, item));
        }
        else static if ( is(T == bool) )
        {
            output.append(item ? "true" : "false");
        }
        else static assert( false, typeof(this).stringof ~
                ".serialize - can only serizlies floating point, integer, bool or string types, not " ~ T.stringof );

        closeEntity(output, name);
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

    void serializeStruct ( ref Char[] output, Char[] name, void delegate ( ) serialize_struct )
    {
        openEntity(output, name);
        
        serialize_struct();

        closeEntity(output, name);
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

    void serializeArray ( T ) ( ref Char[] output, T[] array, Char[] name )
    {
        static if ( is(T == char) )
        {
            serialize(output, array, name);
        }
        else
        {
            openEntity(output, name);

            static if ( is(T U : U[]) && !is(U == Char) )
            {
                foreach ( e; array )
                {
                    serializeArray(output, e, "sub_elements");
                }
            }
            else
            {
                foreach ( i, item; array )
                {
                    element_name.length = 0;
                    buf.length = 20;
                    element_name.append(`element n="`, Integer.format(buf, i), `"`);

                    serialize(output, item, element_name);
                }
            }

            closeEntity(output, name);
        }
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

    void serializeStructArray ( T ) ( ref Char[] output, Char[] name, T[] array, void delegate ( ref T ) serialize_element )
    {
        openEntity(output, name);

        foreach ( i, item; array )
        {
            element_name.length = 0;
            buf.length = 20;
            element_name.append(`element n="`, Integer.format(buf, i), `"`);

            serializeStruct(output, element_name, { serialize_element(item); });
        }

        closeEntity(output, name);
    }


    /***************************************************************************

        Appends the open tag for a named element to the xml string
        
        Params:
            output = string to serialize xml data to
            name = name of entity
    
    ***************************************************************************/
    
    private void openEntity ( ref Char[] output, Char[] name )
    {
        output.append("<", name, ">");
    }
    
    
    /***************************************************************************
    
        Appends the close tage for a named element to the xml string. Anything
        after the first space in the element name is discarded. (This makes it
        easy to pass the same string to openEntity and closeEntity, and have
        xml parameters stripped out in the close tag.)
        
        Params:
            output = string to serialize xml data to
            name = name of entity
    
    ***************************************************************************/
    
    private void closeEntity ( ref Char[] output, Char[] name )
    {
        auto space = name.find(' ');
        output.append("</", name[0..space], ">");
    }
}

