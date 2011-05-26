module ocean.core.ConcatBuffer;


class ConcatBuffer ( T )
{
    private T[] buffer;
    private size_t write_pos;

    public this ( size_t len = 0 )
    {
        this.buffer.length = len;
    }

    T[] add ( T[] data )
    {
        if ( this.write_pos + data.length > this.buffer.length )
        {
            this.buffer = new T[this.buffer.length + data.length];
            this.write_pos = 0;
        }

        auto end = this.write_pos + data.length;
        this.buffer[this.write_pos .. end] = data[];
        this.write_pos = end;
    }

    void clear ( )
    {
        this.write_pos = 0;
    }
}


class SlicedBuffer ( T ) : ConcatBuffer!(T)
{
    private T[][] slices;

    public this ( size_t len = 0 )
    {
        super(len);
    }

    override public T[] add ( T[] data )
    {
        auto slice = super.add(data);
        this.slices ~= slice;
        return slice;
    }

    override public void clear ( )
    {
        super.clear;
        this.slices.length = 0;
    }

    public size_t length ( )
    {
        return this.slices.length;
    }

    public T[] opIndex ( size_t index )
    {
        return this.slices[index];
    }

    public int opApply ( int delegate ( ref T[] ) dg )
    {
        int res;

        foreach ( slice; this.slices )
        {
            res = dg(slice);

            if ( res ) break;
        }

        return res;
    }
}


