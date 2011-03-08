/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs.
                    All rights reserved.

    version:        February 2011: initial release

    authors:        Gavin Norman

    A struct template which implements a two-way mapping between items of two
    types, including opIn_r, opIndex and opIndexAssign methods which
    automatically update the mappings both ways.

    It is designed to have the same interface as a standard associative array.

    TODO: opApply
	TODO: use ArrayMap instead of associative array, if remove() or clear()
 		  methods are required. (Another advantage would be that the copy array
          flag could be used.)

*******************************************************************************/

module ocean.core.TwoWayMap;



struct TwoWayMap ( A, B )
{
    /***************************************************************************

        Type aliases.
    
    ***************************************************************************/

    public alias A TypeA;

    public alias B TypeB;


    /***************************************************************************

        Associative arrays which store the mappings.
    
    ***************************************************************************/

    private B[A] a_to_b;
    private A[B] b_to_a;


    /***************************************************************************

        Invariant checking that the length of both mappings should always be
        identical.

    ***************************************************************************/

    invariant
    {
        assert(this.a_to_b.length == this.b_to_a.length);
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
    }
    
    public void opAssign ( A[B] assoc_array )
    {
        this.b_to_a = assoc_array;
        foreach ( b, a; this.b_to_a )
        {
            this.a_to_b[a] = b;
        }
    }


    /***************************************************************************

        Adds a mapping.

        Params:
            a = item to map to
            b = item to map to

    ***************************************************************************/

    public void opIndexAssign ( A a, B b )
    {
        this.a_to_b[a] = b;
        this.b_to_a[b] = a;
    }

    public void opIndexAssign ( B b, A a )
    {
        this.a_to_b[a] = b;
        this.b_to_a[b] = a;
    }

    
    /***************************************************************************

        Rehashes the mappings.

    ***************************************************************************/

    public void rehash ( )
    {
        this.a_to_b.rehash;
        this.b_to_a.rehash;
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
}

