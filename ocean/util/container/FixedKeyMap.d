/*******************************************************************************

    Map template with a fixed set of keys.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        November 2011: Initial release

    authors:        Gavin Norman

    Map template with a fixed set of keys. If an item is added whose key is not
    in the fixed set, an exception is thrown.

    Such a map can be faster than a standard hash map, as the fixed set of
    possible keys means that 

    Usage example:

    ---

        import ocean.util.container.FixedKeyMap;

        // Create map instance
        auto map = new FixedKeyMap!(char[], char[])("first", "second", "third");

        // Add and check an entry
        map["first"] = "hello";
        assert(map["first"] == "hello");

        // Example of adding an entry which will be rejected
        try
        {
            map["fifth"] = "should fail";
        }
        catch ( FixedKeyMapException e )
        {
            // expected
        }

        // Example of checking if a key is in the map (this does not throw an
        // exception if the key is not found)
        auto nine = "ninth" in map;

    ---

*******************************************************************************/

module ocean.util.container.FixedKeyMap;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array: copy, bsearch;

debug private import tango.io.Stdout;



/*******************************************************************************

    Fixed key map class template.

    Template params:
        K = mapping key type
        V = mapping value type

*******************************************************************************/

public class FixedKeyMap ( K, V )
{
    /***************************************************************************

        List of keys in mapping.

        The keys are set once (in the constructor) and sorted.

    ***************************************************************************/

    private K[] keys; // TODO: could be const?


    /***************************************************************************

        List of values in mapping. This list is always the same length as the
        keys array, and has the same ordering (i.e. the value in values[0] is
        associated with the key in keys[0]).

    ***************************************************************************/

    private V[] values; // TODO: could also be const?


    /***************************************************************************

        Exception instance

    ***************************************************************************/

    static public class FixedKeyMapException : Exception
    {
        public this ( )
        {
            super("");
            super.file = __FILE__;
        }

        public typeof(this) opCall ( char[] msg, long line )
        {
            super.msg = msg;
            super.file = __FILE__;
            return this;
        }
    }

    private const FixedKeyMapException exception;


    /***************************************************************************

        Constructor. The passed list of allowed keys is shallow copied into the
        keys class member.

        Params:
            keys = list of allowed keys

    ***************************************************************************/

    public this ( K[] keys )
    {
        this.keys.copy(keys);
        this.keys.sort;

        this.values.length = this.keys.length;

        this.exception = new FixedKeyMapException;
    }


    /***************************************************************************

        Returns:
            length of mapping (the number of keys)

    ***************************************************************************/

    public size_t length ( )
    {
        return this.keys.length;
    }


    /***************************************************************************

        Gets a value for a key.

        Params:
            key = key to look up

        Returns:
            value corresponding to key

        Throws:
            if key is not in map (see this.keyIndex)

    ***************************************************************************/

    public V opIndex ( K key )
    {
        return this.values[this.keyIndex(key)];
    }


    /***************************************************************************

        Sets a value for a key.

        Params:
            value = value to set
            key = key to set value for

        Throws:
            if key is not in map (see this.keyIndex)

    ***************************************************************************/

    public void opIndexAssign ( V value, K key )
    {
        this.values[this.keyIndex(key)] = value;
    }


    /***************************************************************************

        Checks whether a key is in the map, and returns a pointer to the
        corresponding value, or null if the key does not exist.

        Params:
            key = key to look up

        Returns:
            pointer to value corresponding to key, or null if key not in map

    ***************************************************************************/

    public V* opIn_r ( K key )
    {
        auto pos = this.keyIndex(key, false);
        auto found = pos < this.keys.length;

        return found ? &this.values[pos] : null;
    }


    /***************************************************************************

        foreach operator over keys in the map.

    ***************************************************************************/

    public int opApply ( int delegate ( ref K ) dg )
    {
        int res;
        foreach ( key; this.keys )
        {
            res = dg(key);
            if ( res ) break;
        }
        return res;
    }


    /***************************************************************************

        foreach operator over keys and values in the map.

    ***************************************************************************/

    public int opApply ( int delegate ( ref K, ref V ) dg )
    {
        int res;
        foreach ( i, key; this.keys )
        {
            res = dg(key, this.values[i]);
            if ( res ) break;
        }
        return res;
    }


    /***************************************************************************

        foreach operator over keys, values and indices in the map.

    ***************************************************************************/

    public int opApply ( int delegate ( ref size_t, ref K, ref V ) dg )
    {
        int res;
        foreach ( i, key; this.keys )
        {
            res = dg(i, key, this.values[i]);
            if ( res ) break;
        }
        return res;
    }


    /***************************************************************************

        Finds a key in the keys array.

        Params:
            key = key to look up
            throw_if_not_found = if true, an exception is thrown when looking up
                a key which isn't in the array

        Returns:
            index of key in array, or keys.length if throw_if_not_found is false
                and key is not found

        Throws:
            if throw_if_not_found is true and the key is not in the array

    ***************************************************************************/

    private size_t keyIndex ( K key, bool throw_if_not_found )
    {
        size_t pos;
        auto found = this.keys.bsearch(key, pos);

        if ( !found )
        {
            if ( throw_if_not_found )
            {
                throw this.exception("Key not in map", __LINE__);
            }
            else
            {
                pos = this.keys.length;
            }
        }

        return pos;
    }
}



unittest
{
    auto map = new FixedKeyMap!(char[], char[])("first", "second", "third");
    assert(("first" in map) is null);
    assert(("second" in map) is null);
    assert(("third" in map) is null);

    map["first"] = "hello";
    assert(("first" in map) !is null);
    assert(map["first"] == "world");
    assert(*("first" in map) == "hello");
    assert(map["first"] == "hello");

    map["first"] = "world";
    assert(("first" in map) !is null);
    assert(*("first" in map) == "world");
    assert(map["first"] == "world");

    bool caught;
    try
    {
        map["fifth"];
    }
    catch ( FixedKeyMapException e )
    {
        caught = true;
    }
    assert(caught);
}

