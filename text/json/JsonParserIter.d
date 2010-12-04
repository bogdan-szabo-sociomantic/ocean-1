/******************************************************************************
    
    Iterating JSON parser
    
    copyright:      Copyright (c) 2010 sociomantic labs. 
                    All rights reserved.
    
    version:        September 2010: initial release
    
    authors:        David Eckardt, Gavin Norman
    
    Extends Tango's JsonParser by iteration and token classification facilities.

    Includes methods to extract the values of named entities.

    Named entity extraction usage example:

    ---

        char[] json = "{"object":{"cost":12.34,"sub":{"cost":56.78}}}";

        scope parser = new JsonParserIter();
        parser.reset(json);

        auto val = parser.nextNamed("cost");
        assert(val == "12.34");

        val = parser.nextNamed("cost");
        assert(val == "56.78");

    ---

 ******************************************************************************/

module ocean.text.json.JsonParserIter;

/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.text.json.JsonParser;

private import tango.core.Traits;

private import Integer = tango.text.convert.Integer;

private import Float = tango.text.convert.Float;

debug private import tango.util.log.Trace;



/******************************************************************************/

class JsonParserIter : JsonParser!(char)
{
    /**************************************************************************

        Import the Token enum into this namespace
    
     **************************************************************************/

    public alias typeof (super).Token Token;
    
    /**************************************************************************

        TokenClass enum
        "Other" is for tokens that stand for themselves
    
     **************************************************************************/

    public enum TokenClass
    {
        Other = 0,
        ValueType,
        Container,
    }
    
    /**************************************************************************

        Token to TokenClass association
    
     **************************************************************************/

    private static TokenClass[Token] token_class;
    
    /**************************************************************************

        Token nesting difference values
    
     **************************************************************************/

    private static int[Token]        nestings;
    
    /**************************************************************************

        Static constructor
        Populates associative arrays
    
     **************************************************************************/

    static this ( )
    {
        this.token_class =
        [
            Token.Empty:       TokenClass.Other,
            Token.Name:        TokenClass.Other, 
            Token.String:      TokenClass.ValueType, 
            Token.Number:      TokenClass.ValueType,
            Token.True:        TokenClass.ValueType, 
            Token.False:       TokenClass.ValueType, 
            Token.Null:        TokenClass.ValueType,
            Token.BeginObject: TokenClass.Container, 
            Token.BeginArray:  TokenClass.Container, 
            Token.EndObject:   TokenClass.Container,
            Token.EndArray:    TokenClass.Container
        ];
        
        this.nestings =
        [
            Token.BeginObject: +1, 
            Token.BeginArray:  +1, 
            Token.EndObject:   -1,
            Token.EndArray:    -1
        ];
        
        this.token_class.rehash;
        this.nestings.rehash;
    }
    
    /**************************************************************************

        Returns:
            the token class to which token belongs to
            
        Throws:
            Exception if token is unknown
    
     **************************************************************************/

    static public TokenClass tokenClass ( Token token )
    {
        TokenClass* tocla = token in this.token_class;
        
        if (!tocla) throw new Exception("unknown token");
        
        return *tocla;
    }
    
    
    /**************************************************************************
        
        Returns the nesting level difference caused by token.
        
        Params:
            token = token to get nesting level difference
        
        Returns:
            +1 if token is BeginObject or BeginArray,
            -1 if token is EndObject or EndArray,
             0 otherwise
    
     **************************************************************************/

    static public int nesting ( Token token )
    {
        int* level = token in this.nestings;
        
        return level? *level : 0;
    }
    
    /**************************************************************************
    
        Returns the nesting level difference caused by the current token.
        
        Returns:
            +1 if the current token is BeginObject or BeginArray,
            -1 if the current token is EndObject or EndArray,
             0 otherwise
    
     **************************************************************************/

    public int nesting ( )
    {
        return this.nesting(super.type);
    }
    
    /**************************************************************************

        Returns:
            the token class to which the current token (super.type()) belongs to
    
     **************************************************************************/

    public TokenClass tokenClass ( )
    {
        return this.tokenClass(super.type);
    }
    
    /**************************************************************************

        Steps to the next token in the current JSON content.
        
        Returns:    
            type of next token or Token.Empty if there is no next one
    
     **************************************************************************/

    public Token nextType ( )
    {
        return super.next()? super.type : Token.Empty;
    }
    
    /**************************************************************************

        Resets the instance and sets the input content (convenience wrapper for
        super.reset()).
        
        Params:
            content = new JSON input content to parse
        
        Returns:    
            this instance
    
     **************************************************************************/

    public typeof (this) opCall ( char[] content )
    {
        super.reset(content);
        
        return this;
    }
    
    /**************************************************************************

        'foreach' iteration over values in the current content
    
     **************************************************************************/

    public int opApply ( int delegate ( ref char[] value ) dg )
    {
        int result = 0;
        
        do
        {
            char[] value = super.value;
            result = dg(value);
        }
        while (!result && super.next())
            
        return result;
    }

    /**************************************************************************

        'foreach' iteration over type/value pairs in the current content
    
     **************************************************************************/

    public int opApply ( int delegate ( ref Token type, ref char[] value ) dg )
    {
        return this.opApply((ref char[] value)
                            {
                                Token type = super.type;
                                return dg(type, value);
                            });
    }


    /**************************************************************************

        Iterates over the json string looking for the named element and
        returning the value of the following element.

        Note that the search takes place from the current iteration position,
        and all iterations are cumulative. The iteration position is reset using
        the 'reset' method (in super).

        Params:
            name = name to search for

        Returns:
            value of element after the named element
    
     **************************************************************************/

    public char[] nextNamed ( char[] name )
    {
        return this.nextNamedValue(name, ( Token token ) { return true; });
    }


    /**************************************************************************

        Iterates over the json string looking for the named element and
        returning the value of the following element if it is a boolean. If the
        value is not boolean the search continues.

        Note that the search takes place from the current iteration position,
        and all iterations are cumulative. The iteration position is reset using
        the 'reset' method (in super).
    
        Params:
            name = name to search for
    
        Returns:
            boolean value of element after the named element
    
     **************************************************************************/

    public bool nextNamedBool ( char[] name )
    {
        return this.nextNamedValue(name, ( Token token ) { return token == Token.True || token == Token.False; }) == "true";
    }


    /**************************************************************************

        Iterates over the json string looking for the named element and
        returning the value of the following element if it is a string. If the
        value is not a string the search continues.
    
        Note that the search takes place from the current iteration position,
        and all iterations are cumulative. The iteration position is reset using
        the 'reset' method (in super).
    
        Params:
            name = name to search for
    
        Returns:
            value of element after the named element
    
     **************************************************************************/

    public char[] nextNamedString ( char[] name )
    {
        return this.nextNamedValue(name, ( Token token ) { return token == Token.String; });
    }

    
    /**************************************************************************

        Iterates over the json string looking for the named element and
        returning the value of the following element if it is a number. If the
        value is not a number the search continues.
    
        Note that the search takes place from the current iteration position,
        and all iterations are cumulative. The iteration position is reset using
        the 'reset' method (in super).

        Template params:
            T = numerical type to return
    
        Params:
            name = name to search for
    
        Returns:
            numerical value of element after the named element

        Throws:
            if the value is not valid number
    
     **************************************************************************/

    public T nextNamedNumber ( T ) ( char[] name )
    {
        T ret;
        auto string = this.nextNamedValue(name, ( Token token ) { return token == Token.Number; });

        static if ( isRealType!(T) )
        {
            ret = Float.toFloat(string);
        }
        else static if ( isIntegerType!(T) )
        {
            ret = Integer.toLong(string);
        }
        else
        {
            static assert(false, typeof(this).stringof ~ ".nextNamedNumber - template type must be numerical, not " ~ T.stringof);
        }

        return ret;
    }


    /**************************************************************************

        Iterates over the json string looking for the named element and
        returning the value of the following element if its type matches the
        requirements of the passed delegate.
    
        Note that the search takes place from the current iteration position,
        and all iterations are cumulative. The iteration position is reset using
        the 'reset' method (in super).
    
        Params:
            name = name to search for
            type_match_dg = delegate which receives the type of the element
                following a correctly named value, and decides whether this is
                the value to be returned
    
        Returns:
            value of element after the named element
    
     **************************************************************************/

    private char[] nextNamedValue ( char[] name, bool delegate ( Token ) type_match_dg )
    {
        bool got_name;
        foreach ( type, value; this )
        {
            if ( got_name )
            {
                if ( type_match_dg(type) )
                {
                    return value;
                }
                else
                {
                    got_name = false;
                }
            }

            if ( type == Token.Name && value == name )
            {
                got_name = true;
            }
        }

        return "";
    }
}

