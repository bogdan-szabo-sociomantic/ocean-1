/*******************************************************************************

    Sorted map class, based on an elastic binary tree

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    authors:        Gavin Norman
    
    Fast, ordered, 32-bit key, 32-bit value map. The map is ordered by the key
    type, and all iterators return key->value pairs in key order.
    
    At present both the keys and values in the mapping are restricted to 32
    bits. This is sufficient for the storage of hash_t, time_t, pointers and
    object references (under a 32-bit compiler), so it's fairly flexible.

    Link with:
        -Llibebtree.a

    (The library can be found pre-compiled in ocean.db.ebtree.c.lib, or can be
    built by running 'make' inside ocean.db.ebtree.c.src.)

    Usage example:
    
    ---
    
        import ocean.db.ebtree.EBTreeMap;

        // Something to store in the map
        struct Value
        {
            int something;
            float whatever;
            char[] other_stuff;
        }

        // A bunch of mapped values.
        Value[] values;

        // Create a map, from a hash to a pointer to a Value struct
        auto map = new EBTreeMap!(hash_t, Value*);

        // Set values
        values.length = 100;
        ...

        // Add values to the map
        foreach ( i, v; values )
        {
            auto key = i;
            auto value = &v;
            map.add(key, value);
        }

        // Get the lowest value in the map
        auto lowest = map.first;
    
        // Get the highest value in the map
        auto lowest = map.last;
    
        // Iterate over all keys and values in the map, in key order
        foreach ( key, value; map )
        {
            // do something
        }

        // Empty the map
        map.clear;
    
    ---

*******************************************************************************/

module ocean.db.ebtree.EBTreeMap;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.ArrayMap;

private import ocean.db.ebtree.EBTree;

private import tango.stdc.time : time_t;

debug private import tango.util.log.Trace;



/*******************************************************************************

    EBTree ordered map class template. The map is ordered by the key type.

    Internally a 64-bit tree is used, with keys consisting of the bitwise
    concatenated mapping key and value (32-bits each). The key forms the highest
    32 bits of the tree node's key, where the value forms its lowest 32 bits.
    This ensures that the key nodes are sorted by the mapping keys.

    Template params:
        Key = type of keys stored in map (must be 32-bits)
        Value = type of values stored in map (must be 32-bits)
        KeyUnique = flag telling whether it's possible to store multiple entries
            in the map with the same key (the default). Note that for unique
            maps, a lookup operation is required each time an entry is added, to
            avoid adding duplicates.

*******************************************************************************/

class EBTreeMap ( Key, Value, bool KeyUnique = false )
{
    /***************************************************************************

        This alias.

    ***************************************************************************/

    private alias typeof(this) This;


    /***************************************************************************

        Check that the key and value types are 32-bits.
    
    ***************************************************************************/

    static if ( Key.sizeof != 4 )
    {
        static assert(false, This.stringof ~ ": only supports 32-bit types, not " ~ Key.stringof);
    }

    static if ( Value.sizeof != 4 )
    {
        static assert(false, This.stringof ~ ": only supports 32-bit types, not " ~ Value.stringof);
    }


    /***************************************************************************

        Struct defining a single entry in the map -- a key and a value. The key
        is always placed as the most significant bytes, so the tree is sorted in
        key order.

    ***************************************************************************/

    version ( BigEndian )
    {
        private struct MappingData
        {
            Key key;
            Value value;
        }
    }
    else version ( LittleEndian )
    {
        private struct MappingData
        {
            Value value;
            Key key;
        }
    }
    else
    {
        static assert(false, This.stringof ~ ": endianness version not found, cannot safely use this template");
    }


    /***************************************************************************

        Union for converting between the actual values which are stored in the
        EBTree (ulongs -- 64-bit integers) and the MappingData struct declared
        above.

    ***************************************************************************/

    private union NodeUnion
    {
        MappingData data;
        ulong integer;
    }


    /***************************************************************************

        EBTree and alias.

    ***************************************************************************/

    private alias EBTree!(ulong) Tree;
    private Tree tree;


    /***************************************************************************

        EBTree node alias.

    ***************************************************************************/

    public alias Tree.Node Mapping;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.tree = new Tree;
    }


    /***************************************************************************

        Adds a mapping.

        Note: this method is also aliased as put().

        Params:
            key = key
            value = value

        Returns:
            pointer to new mapping in tree

    ***************************************************************************/

    public Mapping* add ( Key key, Value value )
    {
        NodeUnion item;
        item.data.key = key;
        item.data.value = value;

        static if ( KeyUnique )
        {
            auto mapping = this.lookupMapping(key);
            if ( mapping is null )
            {
                return this.tree.add(item.integer);
            }
            else
            {
                return this.update(mapping, value);
            }
        }
        else
        {
            return this.tree.add(item.integer);
        }
    }

    public alias add put;


    /***************************************************************************

        Updates a mapping's value, given a mapping.

        Params:
            mapping = mapping to update
            value = new value

        Returns:
            pointer to updated mapping in tree
    
    ***************************************************************************/

    public Mapping* update ( Mapping* mapping, Value value )
    in
    {
        assert(mapping !is null, This.stringof ~ ".update: cannot update a null mapping");
    }
    body
    {
        NodeUnion item;
        item.integer = mapping.key;
        item.data.value = value;

        mapping.key = item.integer;

        return mapping;
    }


    /***************************************************************************

        Updates a mapping's key and value, given a mapping. If the mapping's
        key changes, it must be removed from and re-inserted into the tree to
        maintain the tree's sort order.

        Params:
            mapping = mapping to update
            key = new key
            value = new value

        Returns:
            pointer to updated mapping in tree

    ***************************************************************************/

    public Mapping* update ( Mapping* mapping, Key key, Value value )
    in
    {
        assert(mapping !is null, This.stringof ~ ".update: cannot update a null mapping");
    }
    body
    {
        NodeUnion item;
        item.integer = mapping.key;

        if ( key != item.data.key ) // Key has changed, map needs re-sorting
        {
            // Remove old mapping and add new one
            this.remove(mapping);

            return this.add(key, value);
        }
        else // Key same, don't need re-sort
        {
            // Update existing mapping
            item.data.value = value;

            mapping.key = item.integer;

            return mapping;
        }
    }


    /***************************************************************************

        Removes a mapping from the tree.
    
        Params:
            mapping = pointer to mapping to remove
    
    ***************************************************************************/

    public void remove ( Mapping* mapping )
    {
        this.tree.remove(mapping);
    }


    /***************************************************************************

        Removes all mappings.

    ***************************************************************************/

    public void clear ( )
    {
        this.tree.clear;
    }


    /***************************************************************************

        Returns:
            number of elements in the map

    ***************************************************************************/

    public size_t length ( )
    {
        return this.tree.length;
    }


    /***************************************************************************

        Gets the mapped value corresponding to a mapping in the tree.

        Params:
            mapping = pointer to mapping
    
        Returns:
            value of mapping

    ***************************************************************************/

    public Value mappingValue ( Mapping* mapping )
    in
    {
        assert(mapping !is null, This.stringof ~ ".getValue: cannot get a value from a null mapping");
    }
    body
    {
        NodeUnion item;
        item.integer = mapping.key;

        return item.data.value;
    }


    /***************************************************************************

        Gets the mapped key corresponding to a mapping in the tree.

        Params:
            mapping = pointer to mapping

        Returns:
            key of mapping

    ***************************************************************************/

    public Value mappingKey ( Mapping* mapping )
    in
    {
        assert(mapping !is null, This.stringof ~ ".getKey: cannot get a key from a null mapping");
    }
    body
    {
        NodeUnion item;
        item.integer = mapping.key;
    
        return item.data.key;
    }


    /***************************************************************************

        Gets the value mapped by the the specified key. Note that it is possible
        for multiple mappings to have the same key, in this case only the first
        value is returned.

        Note: this lookup is not especially efficient, as it involves a tree
        search.

        Params:
            key = key to look up

        Returns:
            value mapped to by key

        Throws:
            exception if key not found in map

    ***************************************************************************/

    public Value lookup ( Key key )
    {
        auto mapping = this.lookupMapping(key);
        if ( mapping is null )
        {
            throw new Exception(This.stringof ~ ".lookup: no mapping found");
        }

        NodeUnion item;
        item.integer = mapping.key;
        return item.data.value;
    }


    /***************************************************************************

        Gets the mapping for the specified key. Note that it is possible for
        multiple mappings to have the same key, in this case only the first is
        returned. Further mappings can be fetched using the mapping's next()
        method.

        Note: this lookup is not especially efficient, as it involves a tree
        search.

        Params:
            key = key to look up

        Returns:
            mapping containing key, can be null if key not found

    ***************************************************************************/

    public Mapping* lookupMapping ( Key key )
    {
        NodeUnion item;
        item.data.key = key;
        item.data.value = 0;

        auto mapping = this.tree.firstNodeGreaterEqual(item.integer);
        if ( mapping is null )
        {
            return null;
        }

        item.integer = mapping.key;
        if ( item.data.key == key )
        {
            return mapping;
        }
        else
        {
            return null;
        }
    }


    /***************************************************************************

        Gets the value corresponding to the lowest key in the map.

        Returns:
            value mapped to lowest key
    
        Throws:
            exception if map is empty
    
    ***************************************************************************/

    public Value first ( )
    {
        if ( this.length == 0 )
        {
            throw new Exception(This.stringof ~ ".first: map is empty");
        }

        NodeUnion item;
        item.integer = this.tree.first;

        return item.data.value;
    }


    /***************************************************************************

        Gets the value corresponding to the highest key in the map.

        Returns:
            value mapped to highest key

        Throws:
            exception if map is empty
    
    ***************************************************************************/

    public Value last ( )
    {
        if ( this.length == 0 )
        {
            throw new Exception(This.stringof ~ ".last: map is empty");
        }

        NodeUnion item;
        item.integer = this.tree.last;

        return item.data.value;
    }


    /***************************************************************************

        Gets the first mapping in the tree (which contains the lowest key).

        Returns:
            first mapping in tree, null if tree is empty

    ***************************************************************************/

    public Mapping* firstMapping ( )
    {
        return this.tree.firstNode;
    }


    /***************************************************************************

        Gets the last mapping in the tree (which contains the highest key).

        Returns:
            last mapping in tree, null if tree is empty

    ***************************************************************************/

    public Mapping* lastMapping ( )
    {
        return this.tree.lastNode;
    }


    /***************************************************************************

        foreach iterator over all keys in the map, in key order.
    
    ***************************************************************************/

    public int opApply ( int delegate ( ref Key key ) dg )
    {
        int ret;

        foreach ( tree_item; this.tree )
        {
            NodeUnion item;
            item.integer = tree_item;

            ret = dg(item.data.key);

            if ( ret ) break;
        }

        return ret;
    }


    /***************************************************************************

        foreach iterator over all values in the map, in key order.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Value value ) dg )
    {
        int ret;

        foreach ( tree_item; this.tree )
        {
            NodeUnion item;
            item.integer = tree_item;

            ret = dg(item.data.value);

            if ( ret ) break;
        }

        return ret;
    }


    /***************************************************************************

        foreach iterator over all keys & values in the map, in key order.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Key key, ref Value value ) dg )
    {
        int ret;

        foreach ( tree_item; this.tree )
        {
            NodeUnion item;
            item.integer = tree_item;

            ret = dg(item.data.key, item.data.value);

            if ( ret ) break;
        }

        return ret;
    }


    /***************************************************************************

        foreach iterator over all mappings in the tree and their corresponding
        keys & values, in key order.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Mapping* node, ref Key key, ref Value value ) dg )
    {
        int ret;

        foreach ( node, tree_item; this.tree )
        {
            NodeUnion item;
            item.integer = tree_item;

            ret = dg(node, item.data.key, item.data.value);

            if ( ret ) break;
        }

        return ret;
    }

    // TODO: lessEqual / greaterEqual iterators, if needed (see EBTree)
}



/*******************************************************************************

    EBTree ordered map class template with fast key lookup. Extends EBTreeMap
    and keeps an internal array map from keys to tree nodes, enabling fast
    lookup of keys without requiring a tree search.

    Template params:
        Key = type of keys stored in map (must be 32-bits)
        Value = type of values stored in map (must be 32-bits)

*******************************************************************************/

class EBTreeMapFastLookup ( Key, Value ) : EBTreeMap!(Key, Value, true)
{
    /***************************************************************************

        Mapping from keys to tree nodes, for fast node lookup

    ***************************************************************************/

    private alias ArrayMap!(Mapping*, Key) KeyToMapping;

    private KeyToMapping key_to_mapping;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        super();

        this.key_to_mapping = new KeyToMapping;
    }


    /***************************************************************************

        Adds a mapping.
    
        Note: this method is also aliased as put().
    
        Params:
            key = key
            value = value
    
        Returns:
            pointer to new mapping in tree
    
    ***************************************************************************/

    override public Mapping* add ( Key key, Value value )
    {
        auto mapping = super.add(key, value);

        this.key_to_mapping.put(key, mapping);

        return mapping;
    }


    /***************************************************************************

        Removes a mapping from the tree.

        Params:
            mapping = pointer to mapping to remove

    ***************************************************************************/

    override public void remove ( Mapping* mapping )
    {
        this.key_to_mapping.remove(super.mappingKey(mapping));

        super.tree.remove(mapping);
    }


    /***************************************************************************

        Removes all mappings.
    
    ***************************************************************************/
    
    override public void clear ( )
    {
        this.key_to_mapping.clear;

        super.clear;
    }


    /***************************************************************************

        Gets the mapping for the specified key.

        Params:
            key = key to look up

        Returns:
            mapping containing key, can be null if key not found

    ***************************************************************************/

    override public Mapping* lookupMapping ( Key key )
    {
        auto mapping = key in this.key_to_mapping;
        return (mapping is null) ? null : *mapping;
    }
}



/*******************************************************************************

    Unittest

*******************************************************************************/

debug ( OceanUnitTest )
{
    void testUniqueMap ( Map ) ( )
    {
        // Create map
        scope unique_map = new EBTreeMapFastLookup!(hash_t, uint);
        assert(unique_map.length == 0);
    
        // Add a mapping
        unique_map.put(1, 23);
        assert(unique_map.length == 1);
        assert(unique_map.first == 23);
        assert(unique_map.last == 23);
    
        // Replace the mapping (duplicate key)
        unique_map.put(1, 25);
        assert(unique_map.length == 1);
        assert(unique_map.first == 25);
        assert(unique_map.last == 25);
    
        // Add a mapping
        unique_map.put(2, 26);
        assert(unique_map.length == 2);
        assert(unique_map.first == 25);
        assert(unique_map.last == 26);
    
        // Add a mapping
        unique_map.put(3, 27);
        assert(unique_map.length == 3);
        assert(unique_map.first == 25);
        assert(unique_map.last == 27);
    
        // Update last mapping, value change
        unique_map.update(unique_map.lastMapping, 28);
        assert(unique_map.length == 3);
        assert(unique_map.first == 25);
        assert(unique_map.last == 28);
    
        // Update last mapping, key change, switched to front
        unique_map.update(unique_map.lastMapping, 0, 28);
        assert(unique_map.length == 3);
        assert(unique_map.first == 28);
        assert(unique_map.last == 26);
    
        // Remove first mapping
        unique_map.remove(unique_map.firstMapping);
        assert(unique_map.length == 2);
        assert(unique_map.first == 25);
        assert(unique_map.last == 26);
    
        // Remove last mapping
        unique_map.remove(unique_map.lastMapping);
        assert(unique_map.length == 1);
        assert(unique_map.first == 25);
        assert(unique_map.last == 25);
    
        // Clear map
        unique_map.clear;
        assert(unique_map.length == 0);
    }
    
    unittest
    {
        // Test normal map
        testUniqueMap!(EBTreeMap!(hash_t, uint, true));
    
        // Test fast-lookup map
        testUniqueMap!(EBTreeMapFastLookup!(hash_t, uint));
    }
}

