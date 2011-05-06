module ocean.net.http2.IndexableParams;

template IndexStructFields ( T )
{
    static assert (is (typeof (*this) == struct), "IndexableParams: need to be mixed into a struct");
    
    static assert (is (typeof (this.ids) : char[][]), "IndexableParams: need " ~
                   typeof (*this).stringof ~ ".ids of type char[][]");
    
    static assert (this.ids.length == typeof (this.tupleof).length);
    
    private static uint[char[]] _field_indices;
    
    private static size_t[(typeof (this.tupleof)).length] _field_offsets;
    
    int opApply ( int delegate ( ref size_t i, ref char[] id ) dg )
    {
        int result = 0;
        
        foreach (i, id; this._field_indices)
        {
            result = dg(i, id);
            
            if (result) break;
        }
        
        return result;
    }
    
    T* opIn_r ( char[] id )
    {
        size_t* field_index = id in this._field_indices;
        
        T* field = field_index? *field_index in *this : null;
        
        assert (field || !field_index);
        
        return field;
    }
    
    T* opIn_r ( uint i )
    {
        return (i < this._field_indices.length)? this.getField(this._field_offsets[i]) : null;
    }
    
    T opIndexAssign ( char[] value, char[] id )
    {
        return *this.getField(this._field_offsets[this._field_indices[id]]) = value;
    }
    
    typeof (this) reset ( )
    {
        for (size_t i = 0; i < typeof (this.tupleof).length; i++)
        {
            *this.getField(i) = T.init;
        }
        
        return this;
    }
    
    static this ( )
    {
        typeof (this) instance;
        
        foreach (i, S; typeof (instance.tupleof))
        {
            static assert (is (T == S), "IndexableParams: " ~
                           instance.tupleof[i].stringof ~ " is not of type " ~
                           T.stringof ~ " (it is " ~ S.stringof ~ ")");
            
            this._field_offsets[i]           = instance.tupleof[i].offsetof;
            this._field_indices[this.ids[i]] = i;
        }
    }
    
    private T* getField ( size_t offset )
    in
    {
        assert (offset < (*this).sizeof);
    }
    body
    {
        return cast (T*) ((cast (void*) this) + offset);
    }
}
