/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        09/07/2012: Initial release

    authors:        Gavin Norman, David Eckardt

    Utility template to implement Map.opApply()/Set.opApply(), working around
    the problem that opApply() cannot have static array parameters because 'ref'
    is forbidden for static arrays. The solution is to use dynamic arrays
    instead and pass an array slice to to the 'foreach' loop body delegate.

*******************************************************************************/

module ocean.util.container.map.model.MapIterator;

private import ocean.util.container.map.model.Bucket;

/******************************************************************************

    opApply wrapper to work around the problem that it isn't possible to have a
    static array opApply() argument because 'ref' is not allowed with a static
    array. Instead, the wrapper slices the argument and passes the slice to the
    'foreach' body.

    If the value type is 'void', the iteration delegate will only have a key
    argument.

    Template params:
        V = value type; 'void' indicates that there are no values at all.
        K = key type

 ******************************************************************************/

template MapIterator ( V, K = hash_t )
{
    /**************************************************************************

        Kref type alias definition: A dynamic array of the base type of K if K
        is a static array or K itself otherwise.

     **************************************************************************/

    static if (is (K Kelement : Kelement[]) && !is (K == Kelement[]))
    {
        alias Kelement[] Kref;
    }
    else
    {
        alias K Kref;
    }

    /**************************************************************************

        Alias definitions of the Vref, the bucket element and the delegate type.

        Vref is
            - a dynamic array of the base type of V if V is a static array,
            - not defined at all if V is 'void'
            - V itself otherwise.

        The delegate complies to the opApply() iteration delegate and iterates
        over Kref only if V is 'void' or over Kref and Vref otherwise.

     **************************************************************************/

    static if (is (V == void))
    {
        const v_is_static_array = false;

        alias int delegate ( ref Kref ) Dg;

        alias Bucket!(cast (size_t) 0, K).Element Element;
    }
    else
    {
        static if (is (V Velement : Velement[]) && !is (V == Velement[]))
        {
            alias Velement[] Vref;

            const v_is_static_array = true;
        }
        else
        {
            alias V Vref;

            const v_is_static_array = false;
        }

        alias int delegate ( ref Kref, ref Vref ) Dg;

        alias Bucket!(V.sizeof, K).Element Element;
    }

    /**************************************************************************

        Invokes dg with the key and, unless V is 'void', the value of element.

        If K or V (or both) are a static array, a dynamic array slice is passed
        to dg and an assertion makes sure that dg didn't attempt to change the
        array length.

        Params:
            dg      = iteration delegate
            element = bucket element

        Returns:
            passes through the return type of dg.

     **************************************************************************/

    int iterate ( Dg dg, ref Element element )
    {
        Kref key = element.key;

        scope (success)
        {
            assert (key == element.key,
                    "attempted to change the key during iteration");
        }

        static if (is (V == void))
        {
            return dg(key);
        }
        else static if (v_is_static_array)
        {
            Vref val = *cast (V*) element.val.ptr;

            size_t vlen = val.length;

            scope (success)
            {
                assert (val.length == vlen,
                        "attempted to change the length of a static array "
                        "during iteration");
            }

            return dg(key, val);
        }
        else
        {
            return dg(key, *cast (V*) element.val.ptr);
        }
    }
}
