module ocean.net.util.QueryParams;

private import ocean.net.util.ParamSet;

private import ocean.text.util.Split: SplitChr;

class QueryParamSet: ParamSet
{
    private QueryParams query_params;
    
    public this ( char[][] keys ... )
    {
        super(keys);
        
        this.query_params = new QueryParams;
    }
    
    public typeof (this) parse ( char[] query )
    {
        foreach (key, val; this.query_params.set(query))
        {
            super.set(key, val);
        }
        
        return this;
    }
}

class QueryParams
{
    private SplitChr split_paramlist;
    private SplitChr split_param;
    
    public this ( )
    {
        with (this.split_paramlist = new SplitChr)
        {
            delim             = '&';
            collapse          = true;
        }
        
        with (this.split_param = new SplitChr)
        {
            delim             = '=';
            collapse          = true;
            include_remaining = false;
        }
    }
    
    public typeof (this) set ( char[] query )
    {
        this.split_paramlist.reset(query);
        
        return this;
    }
    
    public int opApply ( int delegate ( ref char[] key, ref char[] val ) dg )
    {
        return this.split_paramlist.opApply((ref char[] param)
        {
            char[] value = "";
            
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
