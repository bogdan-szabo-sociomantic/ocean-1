/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs.
                    All rights reserved.

    version:        February 2011: initial release

    authors:        Gavin Norman

    A struct template which implements a two-way mapping between items of two
    types, including opIn_r, opIndex and opIndexAssign methods which
    automatically update the mappings both ways.

    It is designed to have the same interface as a standard associative array.

	TODO: if remove() or clear() methods are required, use ArrayMap instead of
    associative array. (Another advantage would be that the copy array flag
    could be used.)

    Usage example:

    ---

        import ocean.core.TwoWayMap;

        TwoWayMap!(char[], uint) map;

        map["one"] = 1;
        map["two"] = 2;
        map["three"] = 3;
        map.rehash;

        assert(map[1] == "one");
        assert(map["three"] == 3);

    ---

*******************************************************************************/

module ocean.core.TwoWayMap;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Exception;

private import tango.core.Array : find;

private import tango.core.Traits : isAssocArrayType;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Template to create a two way map from an associative array type.

    Template params:
        T = associative array map type

*******************************************************************************/

template TwoWayMap ( T )
{
    static if ( isAssocArrayType!(T) )
    {
        public alias TwoWayMap!(typeof(T.init.values[0]), typeof(T.init.keys[0])) TwoWayMap;
    }
    else
    {
        static assert(false, "'" ~ T.stringof ~ "' isn't an associative array type, cannot create two way map");
    }
}



/*******************************************************************************

    Two way map struct template

    Template params:
        A = key type
        B = value type
        Indexed = true to include methods for getting the index of keys or
            values in the internal arrays

    Note: 'key' and 'value' types are arbitrarily named, as the mapping goes
    both ways. They are just named this way for convenience and to present the
    same interface as the standard associative array.

*******************************************************************************/

struct TwoWayMap ( A, B, bool Indexed = false )
{
    /***************************************************************************

        Type aliases.

    ***************************************************************************/

    public alias A KeyType;

    public alias B ValueType;


    /***************************************************************************

        Associative arrays which store the mappings.

    ***************************************************************************/

    private B[A] a_to_b;
    private A[B] b_to_a;


    /***************************************************************************

        Optional indices for mapped items.

    ***************************************************************************/

    static if ( Indexed )
    {
        private size_t[A] a_to_index; // A to index in a_to_b.keys
        private size_t[B] b_to_index; // B to index in a_to_b.values
    }


    /***************************************************************************

        Invariant checking that the length of both mappings should always be
        identical, and that the indices of mapped items are consistent.

    ***************************************************************************/

    invariant
    {
        assert(this.a_to_b.length == this.b_to_a.length);

        static if ( Indexed )
        {
            foreach ( a, b; this.a_to_b )
            {
                assert(this.a_to_index[a] == this.b_to_index[b]);
            }
        }
    }


    /***************************************************************************

        Assigns a set of mappings from an associative array.

        Params:
            assoc_array = associative array to assign

    ***************************************************************************/

    public void opAssign ( B[A] assoc_array )
    {
        this.a_to_b = assoc_array;
        foreach ( a, b; this.a_to_b )
        {
            this.b_to_a[b] = a;
        }

        static if ( Indexed )
        {
            this.updateIndices();
        }
    }
    
    public void opAssign ( A[B] assoc_array )
    {
        this.b_to_a = assoc_array;
        foreach ( b, a; this.b_to_a )
        {
            this.a_to_b[a] = b;
        }

        static if ( Indexed )
        {
            this.updateIndices();
        }
    }


    /***************************************************************************

        Adds a mapping.

        Params:
            a = item to map to
            b = item to map to

    ***************************************************************************/

    public void opIndexAssign ( A a, B b )
    out
    {
        static if ( Indexed )
        {
            assert(this.a_to_index[a] < this.a_to_b.keys.length);
            assert(this.b_to_index[b] < this.a_to_b.values.length);
        }
    }
    body
    {
        this.a_to_b[a] = b;
        this.b_to_a[b] = a;

        static if ( Indexed )
        {
            this.updateIndices();
        }
    }

    public void opIndexAssign ( B b, A a )
    out
    {
        static if ( Indexed )
        {
            assert(this.a_to_index[a] < this.a_to_b.keys.length);
            assert(this.b_to_index[b] < this.a_to_b.values.length);
        }
    }
    body
    {
        this.a_to_b[a] = b;
        this.b_to_a[b] = a;

        static if ( Indexed )
        {
            this.updateIndices();
        }
    }


    /***************************************************************************

        Rehashes the mappings.

    ***************************************************************************/

    public void rehash ( )
    {
        this.a_to_b.rehash;
        this.b_to_a.rehash;

        static if ( Indexed )
        {
            this.updateIndices();
        }
    }


    /***************************************************************************

        opIn_r operator - performs a lookup of an item A in the map
        corresponding to an item B.

        Params:
            b = item to look up

        Returns:
            item of type A corresponding to specified item of type B, or null if
            no mapping exists
    
    ***************************************************************************/

    public A* opIn_r ( B b )
    {
        return b in this.b_to_a;
    }


    /***************************************************************************

        opIn_r operator - performs a lookup of an item B in the map
        corresponding to an item A.
    
        Params:
            a = item to look up
    
        Returns:
            item of type B corresponding to specified item of type A, or null if
            no mapping exists

    ***************************************************************************/

    public B* opIn_r ( A a )
    {
        return a in this.a_to_b;
    }


    /***************************************************************************

        opIndex operator - performs a lookup of an item A in the map
        corresponding to an item B.

        Params:
            b = item to look up

        Throws:
            as per the normal opIndex operator over an associative array

        Returns:
            item of type A corresponding to specified item of type B

    ***************************************************************************/

    public A opIndex ( B b )
    {
        return this.b_to_a[b];
    }


    /***************************************************************************

        opIndex operator - performs a lookup of an item B in the map
        corresponding to an item A.
    
        Params:
            a = item to look up
    
        Throws:
            as per the normal opIndex operator over an associative array
    
        Returns:
            item of type B corresponding to specified item of type A

    ***************************************************************************/

    public B opIndex ( A a )
    {
        return this.a_to_b[a];
    }


    /***************************************************************************

        Returns:
            number of items in the map
    
    ***************************************************************************/

    public size_t length ( )
    {
        return this.a_to_b.length;
    }


    /***************************************************************************

        Returns:
            dynamic array containing all map elements of type A

    ***************************************************************************/

    public A[] keys ( )
    {
        return this.a_to_b.keys;
    }


    /***************************************************************************

        Returns:
            dynamic array containing all map elements of type B

    ***************************************************************************/

    public B[] values ( )
    {
        return this.a_to_b.values;
    }


    /***************************************************************************

        foreach iterator over the mapping.

    ***************************************************************************/

    public int opApply ( int delegate ( ref A a, ref B b ) dg )
    {
        int res;
        foreach ( a, b; this.a_to_b )
        {
            res = dg(a, b);
        }
        return res;
    }


    /***************************************************************************

        foreach iterator over the mapping, including each value's index.

    ***************************************************************************/

    static if ( Indexed )
    {
        public int opApply ( int delegate ( ref size_t index, ref A a, ref B b ) dg )
        {
            int res;
            foreach ( a, b; this.a_to_b )
            {
                auto index = this.indexOf(a);
                assert(index);
    
                res = dg(*index, a, b);
            }
            return res;
        }
    }


    /***************************************************************************

        Gets the index of an element of type A in the list of all elements of
        type A.

        Params:
            a = element to look up

        Returns:
            pointer to the index of an element of type A in this.a_to_b.keys, or
            null if the element is not in the map

    ***************************************************************************/

    static if ( Indexed )
    {
        public size_t* indexOf ( A a )
        {
            auto index = a in this.a_to_index;
            assertEx(index, typeof(this).stringof ~ ".indexOf - element not present in map");
            return index;
        }
    }


    /***************************************************************************

        Gets the index of an element of type B in the list of all elements of
        type B.

        Params:
            b = element to look up

        Returns:
            pointer to the index of an element of type B in this.a_to_b.values,
            or null if the element is not in the map
    
    ***************************************************************************/
    
    static if ( Indexed )
    {
        public size_t* indexOf ( B b )
        {
            auto index = b in this.b_to_index;
            assertEx(index, typeof(this).stringof ~ ".indexOf - element not present in map");
            return index;
        }
    }


    /***************************************************************************

        Updates the index arrays when the mapping is altered.

    ***************************************************************************/

    static if ( Indexed )
    {
        private void updateIndices ( )
        {
            foreach ( a, b; this.a_to_b )
            {
                this.a_to_index[a] = this.a_to_b.keys.find(a);
                this.b_to_index[b] = this.a_to_b.values.find(b);
            }
        }
    }
}

