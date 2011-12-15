/******************************************************************************

    URI query parameter parser

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        David Eckardt
    
    - QueryParams splits an URI query parameter list into key/value pairs.
    - QueryParamSet parses an URI query parameter list and memorizes the values
      corresponding to keys in a list provided at instantiation.
    
 ******************************************************************************/

module ocean.net.util.QueryParams;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.net.util.ParamSet;

private import ocean.text.util.SplitIterator: ChrSplitIterator;

private import ocean.core.AppendBuffer;

/******************************************************************************/

class QueryParams
{
    /**************************************************************************

        Option to trim off whitespace of  
    
     **************************************************************************/

    public bool trim_whitespace = true;
    
    /**************************************************************************

        Split iterators to split the parameter list into entries and each entry
        into a key/value pair
    
     **************************************************************************/

    private const ChrSplitIterator split_paramlist,
                                   split_param;
    
    /**************************************************************************

        Constructor
    
     **************************************************************************/

    public this ( char element_delim, char keyval_delim )
    {
        with (this.split_paramlist = new ChrSplitIterator)
        {
            delim             = element_delim;
            collapse          = true;
        }
        
        with (this.split_param = new ChrSplitIterator)
        {
            delim             = keyval_delim;
            include_remaining = false;
        }
    }
    
    /**************************************************************************

        Sets the URI query string to parse
        
        Params:
            query = query string to parse
            
        Returns:
            this instance
        
     **************************************************************************/

    public typeof (this) set ( char[] query )
    {
        this.split_paramlist.reset(query);
        
        return this;
    }
    
    /**************************************************************************

        'foreach' iteration over the URI query parameter list items, each one
        split into a key/value pair. key and value slice the string passed to
        query() so DO NOT MODIFY THEM. (You may, however, modify their content;
        this will actually modify the string passed to query().)
        value may be empty if the last character of a query parameter is '='. 
        If a query parameter does not contain a '=', value will be null.
    
     **************************************************************************/

    public int opApply ( int delegate ( ref char[] key, ref char[] value ) ext_dg )
    {
        auto dg = this.trim_whitespace?
                    (ref char[] key, ref char[] value)
                    {
                        char[] tkey = split_param.trim(key),
                               tval = split_param.trim(value);
                        return ext_dg(tkey, tval);
                    } :
                    ext_dg; 
        
        return this.split_paramlist.opApply((ref char[] param)
        {
            char[] value = null;
            
            foreach (key; this.split_param.reset(param))
            {
                value = this.split_param.remaining;
                
                return dg(key, value);
            }
            
            assert (!this.split_param.n);
            
            return dg(param, value);
        });
    }
}

/******************************************************************************/

class QueryParamSet: ParamSet
{
    /**************************************************************************
    
        QueryParams instance
    
     **************************************************************************/

    private const QueryParams query_params;
    
    /**************************************************************************
    
        Constructor
        
        Params:
            keys = parameter keys of interest (case-insensitive)
    
     **************************************************************************/

    public this ( char element_delim, char keyval_delim, char[][] keys ... )
    {
        super.addKeys(keys);
        
        super.rehash();
        
        this.query_params = new QueryParams(element_delim, keyval_delim);
    }
    
    /**************************************************************************
    
        Parses query and memorizes the values corresponding to the keys provided
        to the constructor. query will be sliced. 
        
        Params:
            query = query string to parse
    
     **************************************************************************/

    public void parse ( char[] query )
    {
        super.reset();
        
        foreach (key, val; this.query_params.set(query))
        {
            super.set(key, val);
        }
    }
    
    deprecated protected void add ( char[] key, char[] val ) { }
}

class ListQueryParamSet: QueryParamSet
{
    public const IAppendBufferReader!(Element) elements;
    
    private const AppendBuffer!(Element) elements_;
    
    /**************************************************************************
    
        Constructor
        
        Params:
            keys = parameter keys of interest (case-insensitive)
    
     **************************************************************************/

    public this ( char element_delim, char keyval_delim, char[][] keys ... )
    {
        super(element_delim, keyval_delim, keys);
        
        this.elements = this.elements_ = new AppendBuffer!(Element);
    }
    
    protected override void add ( char[] key, char[] val )
    {
        this.elements_ ~= Element(key, val);
    }
    
    final protected override void reset_ ( )
    {
        this.elements_.clear();
        
        this.reset__();
    }
    
    protected void reset__ ( ) { }
}

/******************************************************************************/

unittest
{
    scope qp = new QueryParams(';', '=');
    
    assert (qp.trim_whitespace);
    
    {
        uint i = 0;
        
        foreach (key, val; qp.set(" Die Katze = tritt ;\n\tdie= Treppe;krumm.= "))
        {
            switch (i++)
            {
                case 0:
                    assert (key == "Die Katze");
                    assert (val == "tritt");
                    break;
                case 1:
                    assert (key == "die");
                    assert (val == "Treppe");
                    break;
                case 2:
                    assert (key == "krumm.");
                    assert (!val.length);
                    break;
            }
        }
    }
    
    {
        qp.trim_whitespace = false;
        
        uint i = 0;
        
        foreach (key, val; qp.set(" Die Katze = tritt ;\n\tdie= Treppe;krumm.= "))
        {
            switch (i++)
            {
                case 0:
                    assert (key == " Die Katze ");
                    assert (val == " tritt ");
                    break;
                case 1:
                    assert (key == "\n\tdie");
                    assert (val == " Treppe");
                    break;
                case 2:
                    assert (key == "krumm.");
                    assert (val == " ");
                    break;
            }
        }
    }
}