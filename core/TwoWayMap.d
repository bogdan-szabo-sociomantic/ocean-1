/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs.
                    All rights reserved.

    version:        February 2011: initial release

    authors:        Gavin Norman

    A struct template which implements a two-way mapping between items of two
    types, including opIn_r, opIndex and opIndexAssign methods which
    automatically update the mappings both ways.

    It is designed to have the same interface as a standard associative array.

*******************************************************************************/

module ocean.core.TwoWayMap;



struct TwoWayMap ( A, B )
{
    /***************************************************************************

        Associative arrays which store the mappings.
    
    ***************************************************************************/

    private B[A] a_to_b;
    private A[B] b_to_a;


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

