/******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    Collection of common utilities built on top of (de)serializer

*******************************************************************************/

module ocean.util.serialize.contiguous.Util;

/******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.serialize.contiguous.Contiguous,
               ocean.util.serialize.contiguous.Serializer,
               ocean.util.serialize.contiguous.Deserializer;

private import ocean.core.Test;

/*******************************************************************************

    Copies struct data to other chunk and adjusts all internal pointers
    to reference new buffer.

    Params:
        src = source struct (must be already contiguous)
        dst = target struct chunk to copy data to. Will grow if current
            length is smaller than src.data.length

    Returns:
        `dst` by value

    Throws:
        DeserializationException if src is not well-formed

/******************************************************************************/

public Contiguous!(S) copy(S) ( Contiguous!(S) src, ref Contiguous!(S) dst )
{
    Deserializer.deserialize!(S)(src.data, dst);
    return dst;
}

/*******************************************************************************

    Deep copies any struct to its contigous representation. Effectively does
    serialization and deserialization in one go.

    Params:
        src = any struct instance
        dst = contigous struct to be filled with same values as src

    Returns:
        `dst` by value

*******************************************************************************/

public Contiguous!(S) copy(S) ( ref S src, ref Contiguous!(S) dst )
{
    Serializer.serialize!(S)(src, dst.data);
    dst = Deserializer.deserialize!(S)(dst.data);
    return dst;
}

unittest
{
    struct Test
    {
        int[] arr;
    }

    Test t; t.arr = [ 1, 2, 3 ];

    Contiguous!(Test) one, two;

    copy(t, one);

    test!("==")(one.ptr.arr, t.arr);
    one.enforceIntegrity();

    copy(one, two);

    test!("==")(two.ptr.arr, t.arr);
    two.enforceIntegrity();
}
