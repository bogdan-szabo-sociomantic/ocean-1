/******************************************************************************
    
    Iterating JSON parser
    
    copyright:      Copyright (c) 2010 sociomantic labs. 
                    All rights reserved.
    
    version:        September 2010: initial release
    
    authors:        David Eckardt
    
    Extends Tango's JsonParser by iteration and token classification facilities
    
 ******************************************************************************/

module ocean.text.json.JsonParserIter;

/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.text.json.JsonParser;

/******************************************************************************/

class JsonParserIter : JsonParser!(char)
{
    /**************************************************************************

        Import the Token enum into this namespace
    
     **************************************************************************/

    alias typeof (super).Token Token;
    
    /**************************************************************************

        TokenClass enum
        "Other" is for tokens that stand for themselves
    
     **************************************************************************/

    enum TokenClass
    {
        Other = 0,
        ValueType,
        Container
    }
    
    /**************************************************************************

        Token to TokenClass association
    
     **************************************************************************/

    private static TokenClass[Token] token_class;
    
    /**************************************************************************

        Static constructor
        Populates this.token_class
    
     **************************************************************************/

    static this ( )
    {
        this.token_class[Token.Empty]       = TokenClass.Other;
        this.token_class[Token.Name]        = TokenClass.Other; 
        this.token_class[Token.String]      = TokenClass.ValueType; 
        this.token_class[Token.Number]      = TokenClass.ValueType;
        this.token_class[Token.BeginObject] = TokenClass.Container; 
        this.token_class[Token.EndObject]   = TokenClass.Container;
        this.token_class[Token.BeginArray]  = TokenClass.Container; 
        this.token_class[Token.EndArray]    = TokenClass.Container; 
        this.token_class[Token.True]        = TokenClass.ValueType; 
        this.token_class[Token.False]       = TokenClass.ValueType; 
        this.token_class[Token.Null]        = TokenClass.ValueType;
        
        this.token_class.rehash;
    }
    
    /**************************************************************************

        Returns:
            the token class to which token belongs to
            
        Throws:
            Exception if token is unknown
    
     **************************************************************************/

    static TokenClass tokenClass ( Token token )
    {
        TokenClass* tocla = token in this.token_class;
        
        if (!tocla) throw new Exception("unknown token");
        
        return *tocla;
    }
    
    /**************************************************************************

        Returns:
            the token class to which the current token (super.type()) belongs to
    
     **************************************************************************/

    TokenClass tokenClass ( )
    {
        return this.tokenClass(super.type);
    }
    
    /**************************************************************************

        Steps to the next token in the current JSON content.
        
        Returns:    
            type of next token or Token.Empty if there is no next one
    
     **************************************************************************/

    Token nextType ( )
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

    typeof (this) opCall ( char[] content )
    {
        super.reset(content);
        
        return this;
    }
    
    /**************************************************************************

        'foreach' iteration over values in the current content
    
     **************************************************************************/

    int opApply ( int delegate ( ref char[] value ) dg )
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

    int opApply ( int delegate ( ref Token type, ref char[] value ) dg )
    {
        return this.opApply((ref char[] value)
                            {
                                Token type = super.type;
                                return dg(type, value);
                            });
    }
}