/*******************************************************************************

    Deserializer, to be used with the StructSerializer, which loads the members
    of a struct from a json string.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        October 2010: Initial release
    
    authors:        Gavin Norman

    Deserializer, to be used with the StructSerializer in
    ocean.io.serialize.StructSerializer, which loads the members of a struct
    from a json string.

    Usage example (in conjunction with ocean.io.serialize.StructSerializer):

    ---

        // Example struct to deserialize from json
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

        // Input string
        char[] json = "{"Data":{"ids":[{"name":"hello", "id":23}, {"name":"hi", "id":17}], "name":"monty", "count":112, "money":123.456}}";

        // Set up struct to read into
        Data data;

        // Create serializer object
        scope deser = new JsonStructDeserializer!(char)();

        // Load struct from string via deserializer
        StructSerializer.load(&data, deser, json);

    ---

*******************************************************************************/

module io.serialize.JsonStructDeserializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import tango.core.Traits : isCharType, isRealType, isIntegerType, isStaticArrayType;

private import Float = tango.text.convert.Float;

private import Integer = tango.text.convert.Integer;

private import tango.text.json.JsonParser;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Json struct deserializer
    
    Template params:
        Char = character type of input string

*******************************************************************************/

class JsonStructDeserializer ( Char )
{
    static assert ( isCharType!(Char), typeof(this).stringof ~ " - this class can only handle {char, wchar, dchar}, not " ~ Char.stringof );


    /***************************************************************************

        Convenience alias for json parser
    
    ***************************************************************************/

    private alias JsonParser!(Char) Parser;


    /***************************************************************************

        Json parser instance
    
    ***************************************************************************/

    private Parser parser;


    /***************************************************************************

        Constructor. Creates json parser.
    
    ***************************************************************************/

    public this ( )
    {
        this.parser = new Parser();
    }


    /***************************************************************************

        Destructor. Deletes json parser.
    
    ***************************************************************************/

    ~this ( )
    {
        delete this.parser;
    }


    /***************************************************************************

        Called at the start of struct deserialization - checks that the json
        string opens with a {, then the name of the top-level object (the struct
        being deserialized), then another {.
        
        Params:
            json = string to deserialize json data from
            name = name of top-level object
    
    ***************************************************************************/

    public void open ( Char[] json, Char[] name )
    {
        this.parser.reset(json);

        this.checkToken(Parser.Token.BeginObject);
        this.checkName(name);
        this.checkToken(Parser.Token.BeginObject);
    }


    /***************************************************************************

        Called at the end of struct deserialization - checks that the json
        string closes with two {'s - one to close the top-level object, and one
        to close the json string.
        
    ***************************************************************************/

    public void close ( )
    {
        this.checkToken(Parser.Token.EndObject);
        this.checkToken(Parser.Token.EndObject);
    }


    /***************************************************************************

        Reads a named variable from the json string.

        Template params:
            T = type of variable to deserialize

        Params:
            output = variable to deserialize into
            name = expected name of the variable (optional)
        
    ***************************************************************************/

    public void deserialize ( T ) ( ref T output, Char[] name = "" )
    {
        if ( name.length )
        {
            this.checkName(name);
        }

        static if ( isRealType!(T) )
        {
            assert(this.parser.type() == Parser.Token.Number, typeof(this).stringof ~ ".deserialize - invalid token type in json string, expected Number (float)");
            output = Float.toFloat(this.parser.value());
        }
        else static if ( isIntegerType!(T) )
        {
            assert(this.parser.type() == Parser.Token.Number, typeof(this).stringof ~ ".deserialize - invalid token type in json string, expected Number (integer)");
            output = Integer.toLong(this.parser.value());
        }
        else static if ( is(T == bool) )
        {
            assert(this.parser.type() == Parser.Token.Number, typeof(this).stringof ~ ".deserialize - invalid token type in json string, expected Number (bool)");
            assert(this.parser.value() == "0" || this.parser.value() == "1", typeof(this).stringof ~ ".deserialize - invalid bool value in json string");
            output = this.parser.value() == "1";
        }
        else static assert( false, typeof(this).stringof ~
            ".deserialize - can only dejsonize floats, bools or ints, not " ~ T.stringof );

        this.parser.next();
    }


    /***************************************************************************

        Reads a named struct from the json string.

        Checks that the json string contains the struct's name, then an opening
        {, then deserializes its contents, then checks for the closing }.

        Template params:
            T = type of struct to deserialize
    
        Params:
            output = struct to deserialize into
            name = expected name of the struct
            deserialize_struct = delegate to perform the deserialization
        
    ***************************************************************************/

    public void deserializeStruct ( T ) ( ref T output, Char[] name, void delegate ( ) deserialize_struct )
    {
        this.checkName(name);
        this.checkToken(Parser.Token.BeginObject);

        deserialize_struct();

        this.checkToken(Parser.Token.EndObject);
    }


    /***************************************************************************

        Reads a named array from the json string.
    
        Checks that the json string contains the array's name, then an opening
        [, then deserializes its contents one element at a time until the
        closing ] is encountered.
    
        Multi-dimensional arrays are deserialized as arrays of json objects,
        where each sub-object has two values:
        
            * index = integer value giving index in array
            * elements = sub-array of elements
        
        In this way, arrays of arbitrary dimension can be recursively
        deserialized.
    
        Template params:
            T = element type of array to deserialize
    
        Params:
            output = array to deserialize into
            name = expected name of the array
        
    ***************************************************************************/

    public void deserializeArray ( T ) ( ref T[] output, Char[] name )
    {
        static if ( is(T == Char) )
        {
            this.checkName(name);
            output.copy(this.parser.value());
            this.parser.next();
        }
        else
        {
            this.checkName(name);
            this.checkToken(Parser.Token.BeginArray);

            output.length = 0;
            size_t index;

            while ( this.parser.type() != Parser.Token.EndArray )
            {
                output.length = index + 1;

                static if ( is(T == Char[]) )
                {
                    output[index].copy(this.parser.value());
                    this.parser.next();
                }
                else static if ( is(T U : U[]) )
                {
                    this.checkToken(Parser.Token.BeginObject);

                    this.checkName("index");
                    assert(Integer.toLong(this.parser.value()) == index);
                    this.parser.next(); // skip index value

                    static if ( isStaticArrayType!(U) )
                    {
                        this.deserializeStaticArray(output[index], "elements");
                    }
                    else
                    {
                        this.deserializeArray(output[index], "elements");       // recursive call
                    }

                    this.checkToken(Parser.Token.EndObject);
                }
                else
                {
                    this.deserialize(output[index]);
                }

                index++;
            }

            this.checkToken(Parser.Token.EndArray);
        }
    }


    /***************************************************************************

        Reads a named array of fixed length from the json string.
    
        Checks that the json string contains the array's name, then an opening
        [, then deserializes its contents one element at a time until the array
        is full. Then the closing ] is expected.
    
        Multi-dimensional arrays are deserialized as arrays of json objects,
        where each sub-object has two values:
        
            * index = integer value giving index in array
            * elements = sub-array of elements
        
        In this way, arrays of arbitrary dimension can be recursively
        deserialized.
    
        Template params:
            T = element type of array to deserialize
    
        Params:
            output = array to deserialize into
            name = expected name of the array
        
    ***************************************************************************/

    public void deserializeStaticArray ( T ) ( T[] output, Char[] name )
    {
        static if ( is(T == Char) )
        {
            this.checkName(name);
            this.copyStaticString(output, this.parser.value());
            this.parser.next();
        }
        else
        {
            this.checkName(name);
            this.checkToken(Parser.Token.BeginArray);

            foreach ( index, ref T element; output )
            {
                static if ( is(T == Char[]) )
                {
                    this.copyStaticString(element, this.parser.value());
                    this.parser.next();
                }
                else static if ( is(T U : U[]) )
                {
                    this.checkToken(Parser.Token.BeginObject);

                    this.checkName("index");
                    assert(Integer.toLong(this.parser.value()) == index);
                    this.parser.next(); // skip index value

                    static if ( isStaticArrayType!(U) )
                    {
                        this.deserializeStaticArray(element, "elements");       // recursive call
                    }
                    else
                    {
                        this.deserializeArray(element, "elements");
                    }

                    this.checkToken(Parser.Token.EndObject);
                }
                else
                {
                    this.deserialize(element);
                }
            }

            this.checkToken(Parser.Token.EndArray);
        }
    }


    /***************************************************************************

        Reads a named array of structs from the json string.

        Checks that the json string contains the array's name, then an opening
        [, then deserializes its contents one element at a time until the
        closing ] is encountered.

        Each element is deserialized by checking for its opening {,
        deserializing its contents, then checking for its closing }.
    
        Template params:
            T = element type of array to deserialize
    
        Params:
            output = array to deserialize into
            name = expected name of the array
            deserialize_element = delegate to deserialize a single array element
        
    ***************************************************************************/

    public void deserializeStructArray ( T ) ( ref T[] output, Char[] name, void delegate ( ref T ) deserialize_element )
    {
        this.checkName(name);
        this.checkToken(Parser.Token.BeginArray);

        output.length = 0;

        while ( this.parser.type() != Parser.Token.EndArray )
        {
            output.length = output.length + 1;

            this.checkToken(Parser.Token.BeginObject);

            deserialize_element(output[$-1]);

            this.checkToken(Parser.Token.EndObject);
        }

        this.checkToken(Parser.Token.EndArray);
    }


    /***************************************************************************

        Copies a string into a static char[].

        Params:
            dest = string to copy to
            src = string to copy from

        Throws:
            asserts that the destination and source are the same length

    ***************************************************************************/

    private void copyStaticString ( Char[] dest, Char[] src )
    in
    {
        assert(src.length == dest.length, typeof(this).stringof ~ ".copyStaticString - trying to copy a string of the wrong length");
    }
    body
    {
        dest[] = src[];
    }

    
    /***************************************************************************

        Checks whether an expected token is next in the json string. If the
        token is found, the json parser is advanced to the next token.

        Params:
            token = type of token expected

        Throws:
            asserts that the expected token is found
        
    ***************************************************************************/

    private void checkToken ( Parser.Token token )
    {
        assert(this.parser.type() == token,
                typeof(this).stringof ~ ".checkToken - invalid token type in json string, expected token number " ~ Integer.toString(token) ~
                ", got token number " ~ Integer.toString(this.parser.type()));
        this.parser.next();
    }


    /***************************************************************************

        Checks whether the next token in the json string is a name token with
        the expected value. If the name token is found, the json parser is
        advanced to the next token.

        Params:
            token = type of token expected
            name = (optional) expected name of token

    ***************************************************************************/

    private void checkName ( Char[] name )
    {
        assert(this.parser.type() ==  Parser.Token.Name && this.parser.value() == name,
                typeof(this).stringof ~ ".checkName - name '" ~ name ~ "' expected, got '" ~ this.parser.value() ~ "'");
        this.parser.next();
    }
}

