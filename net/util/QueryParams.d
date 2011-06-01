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

/******************************************************************************/

class QueryParams
{
    /**************************************************************************

        Split iterators to split the parameter list into entries and each entry
        into a key/value pair
    
     **************************************************************************/

    private ChrSplitIterator split_paramlist;
    private ChrSplitIterator split_param;
    
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

    public int opApply ( int delegate ( ref char[] key, ref char[] value ) dg )
    {
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

    private QueryParams query_params;
    
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

    public typeof (this) parse ( char[] query )
    {
        foreach (key, val; this.query_params.set(query))
        {
            super.set(key, val);
        }
        
        return this;
    }
}
