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
        const k_is_static_array = true;

        alias Kelement[] Kref;
    }
    else
    {
        const k_is_static_array = false;

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

        Do not modify the key in-place.

        If K or V (or both) are a static array, a dynamic array slice is passed
        to dg. Do not do a 'ref' iteration over static array keys or values.
        To obtain a pointer to the static array key or value currently iterating
        over, use the .ptr of the iteration variable.

        Example: Consider a map that stores char[5] values with hash_t keys.

        ---
            foreach (ref key, val; map)
            {
                // typeof(key) is hash_t. A pointer to the key can be obtained
                // using &key.

                // typeof(val) is char[], val is a dynamic array slice
                // referencing the value in the map. A pointer to the value can
                // be obtained using val.ptr.
            }
        ---

        Params:
            dg      = iteration delegate
            element = bucket element

        Returns:
            passes through the return type of dg.

     **************************************************************************/

    int iterate ( Dg dg, ref Element element )
    {
        static if (k_is_static_array)
        {
            Kref key = element.key;

            Kref* key_ptr = &key;
        }
        else
        {
            K* key = &element.key;

            alias key key_ptr;
        }

        scope (success)
        {
            assert (*key_ptr == element.key,
                    "attempted to change the key during iteration");
        }

        static if (is (V == void))
        {
            return dg(*key_ptr);
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

            return dg(*key_ptr, val);
        }
        else
        {
            return dg(*key_ptr, *cast (V*) element.val.ptr);
        }
    }
}
