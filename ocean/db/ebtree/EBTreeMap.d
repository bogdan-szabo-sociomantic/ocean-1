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

    Superseded by the dual keys feature of EBTree32, EBTree64 and EBTree128.

*******************************************************************************/

deprecated:

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

        Check that the key and value types are valid
    
    ***************************************************************************/

    static assert(Key.sizeof == Value.sizeof, This.stringof ~ ": key and value size must be the same (" ~ Key.sizeof.stringof ~ " != " ~ Value.sizeof.stringof);
    
    static assert(Key.sizeof == 8 || Key.sizeof == 4, This.stringof ~ ": only supports 32/64-bit types, not " ~ Value.stringof);

    /***************************************************************************

        Struct defining a single entry in the map -- a key and a value. The key
        is always placed as the most significant bytes, so the tree is sorted in
        key order.

    ***************************************************************************/

    private struct NodeStruct
    {
        /***********************************************************************

	        Struct key & value, order dependent on system endianness.

	    ***********************************************************************/

    	version ( BigEndian )
        {
            Key key;
            Value value;
        }
        else version ( LittleEndian )
        {
        	Value value;
        	Key key;
        }
        else
        {
            static assert(false, This.stringof ~ ": endianness version not found, cannot safely use this template");
        }


        /***********************************************************************

	        Struct comparator.

			Params:
				rhs = struct to compare against

	        Returns:
	            1 if this > rhs, -1 if rhs > this, 0 if this == rhs

	    ***********************************************************************/

        int opCmp ( NodeStruct rhs )
        {
            if ( key == rhs.key )
            {
                if ( value == rhs.value ) return 0;
                
                return cast(int) (value > rhs.value) * 2 - 1;
            }
            
            return cast(int) (key > rhs.key) * 2 - 1;
            /+
            if ( key > rhs.key ) return 1;
            if ( key < rhs.key ) return -1;
            if ( value > rhs.value ) return 1;
            if ( value < rhs.value ) return -1;
            
            return 0;
            +/
        }


        /***********************************************************************

	        Endianness independant method to create a NodeStruct instance from a
	        key and value.

			Params:
				k = key
				v = value

	        Returns:
	            new NodeStruct

	    ***********************************************************************/

	    static NodeStruct opCall ( Key k, Value v )
	    {
	        NodeStruct nodestruct;
	        nodestruct.key = k;
	        nodestruct.value = v;
	        return nodestruct;
	    }
    }
    
    /***************************************************************************

        EBTree and alias.

    ***************************************************************************/

    private alias EBTree!(NodeStruct) Tree;
    private Tree tree;
    
    /***************************************************************************

        Struct hosting an EBTree node and providing accessors to key and value.
        Key and value are merged to an ulong value which is the actual value
        stored in the tree.

    ***************************************************************************/

    public struct Mapping
    {        
        alias EBTreeMap.NodeStruct NodeStruct;
        
        /***********************************************************************

            EBTree node instance
    
        ***********************************************************************/

        Tree.Node* node = null;
        
        /***********************************************************************

            Make sure that methods are used only if we indeed have a node
            instance.
    
        ***********************************************************************/

        invariant ( )
        {
            assert (this.node !is null, "attempted to use a null mapping");
        }
        
        /***********************************************************************

            Sets the key of the item in the map.
            
            Params:
                k = new key
                
            Returns:
                key
    
        ***********************************************************************/

        Key key ( Key k )
        {
            return (cast(NodeStruct*) &this.node.key).key = k;
        }
        
        /***********************************************************************

            Returns:
                the current key of the item in the map.
    
        ***********************************************************************/

        Key key ( )
        {
            return (cast(NodeStruct*) &this.node.key).key;
        }
        
        /***********************************************************************

            Sets the value of the item in the map.
            
            Params:
                v = new value
                
            Returns:
                value
    
        ***********************************************************************/

        Value value ( Value v )
        {
            return (cast(NodeStruct*) &this.node.key).value = v;
        }
        
        /***********************************************************************

            Returns:
                the current value of the item in the map.
    
        ***********************************************************************/

        Value value ( )
        {
            return (cast(NodeStruct*) &this.node.key).value;
        }
    }


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

    public Mapping add ( Key key, Value value )
    {
        static if ( KeyUnique )
        {
            Mapping mapping;
            
            if ( this.lookupMapping(key, mapping) )
            {
                mapping.value = value;
                return mapping;
            }
            else
            {
                return Mapping(this.tree.add(Mapping.NodeStruct(key, value)));
            }
        }
        else
        {
            return Mapping(this.tree.add(Mapping.NodeStruct(key, value)));
        }
    }

    public alias add put;


    /***************************************************************************

        Updates a mapping's key and value, given a mapping. If the mapping has
        changed, it must be removed from and re-inserted into the tree to
        maintain the tree's sort order.

        Params:
            mapping = mapping to update
            key = new key
            value = new value

        Returns:
            pointer to updated mapping in tree

    ***************************************************************************/

    public Mapping update ( Mapping mapping, Key key, Value value )
    in
    {
        assert(mapping.node !is null, This.stringof ~ ".update: cannot update a null mapping");
    }
    body
    {
        if ( key != mapping.key || value != mapping.value ) // Map needs re-sorting
        {
            // Remove old mapping and add new one
            this.remove(mapping);

            return this.add(key, value);
        }
        else // Ebtree key hasn't changed, do nothing
        {
            return mapping;
        }
    }


    /***************************************************************************

        Removes a mapping from the tree.
    
        Params:
            mapping = pointer to mapping to remove
    
    ***************************************************************************/

    public void remove ( Mapping mapping )
    in
    {
        assert(mapping.node !is null, This.stringof ~ ".update: cannot remove a null mapping");
    }
    body
    {
        this.tree.remove(mapping.node);
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

        Gets the value mapped by the specified key. Note that it is possible
        for multiple mappings to have the same key, in this case only the first
        value is returned.

        Note: this lookup is not especially efficient, as it involves a tree
        search. If you need fast lookups use the extended class
        EBTreeMapFastLookup, below.

        Params:
            key   = key to look up
            value = value output

        Returns:
            true if found or false otherwise.

    ***************************************************************************/

    public bool lookup ( Key key, out Value value )
    {
        Mapping mapping;
        
        if (this.lookupMapping(key, mapping))
        {
            value = mapping.value;
            return true;
        }
        else
        {
            return false;
        }
    }


    /***************************************************************************

        Gets the mapping for the specified key. Note that it is possible for
        multiple mappings to have the same key, in this case only the first is
        returned. Further mappings can be fetched using mapping.node.next().
        
        Note: this lookup is not especially efficient, as it involves a tree
        search. If you need fast lookups use the extended class
        EBTreeMapFastLookup, below.

        Params:
            key     = key to look up
            mapping = mapping output, valid only if the return value is true.

        Returns:
            true if found or false otherwise.

    ***************************************************************************/

    public bool lookupMapping ( Key key, out Mapping mapping )
    out (found)
    {
        assert (!(found && mapping.node is null));
    }
    body
    {
        mapping = Mapping(this.tree.firstNodeGreaterEqual(Mapping.NodeStruct(key, 0)));
        
        return (mapping.node is null)? false : (mapping.key == key);
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

        return Mapping(this.tree.firstNode).value;
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

        return Mapping(this.tree.lastNode).value;
    }


    /***************************************************************************

        Gets the first mapping in the tree (which contains the lowest key).

        Returns:
            first mapping in tree, null if tree is empty

    ***************************************************************************/

    public Mapping firstMapping ( )
    {
        return Mapping(this.tree.firstNode);
    }


    /***************************************************************************

        Gets the last mapping in the tree (which contains the highest key).

        Returns:
            last mapping in tree, null if tree is empty

    ***************************************************************************/

    public Mapping lastMapping ( )
    {
        return Mapping(this.tree.lastNode);
    }


    /***************************************************************************

        foreach iterator over all keys in the map, in key order. The map is not
        updated if the key is iterated over as 'ref' and modified.
    
    ***************************************************************************/

    public int opApply ( int delegate ( ref Key key ) dg )
    {
        int ret;

        foreach ( ref node; this.tree )
        {
            Key key = Mapping(&node).key;
            
            ret = dg(key);

            if ( ret ) break;
        }

        return ret;
    }


    /***************************************************************************

        foreach iterator over all values in the map, in key order. The map is
        not updated if the value is iterated over as 'ref' and modified.
        TODO: This can be implemented if needed in the future.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Value value ) dg )
    {
        int ret;

        foreach ( ref node; this.tree )
        {
            Value value = Mapping(&node).value;
            
            ret = dg(value);

            if ( ret ) break;
        }

        return ret;
    }


    /***************************************************************************

        foreach iterator over all keys & values in the map, in key order. The
        map is not updated if the key or value are iterated over as 'ref' and
        modified.
        TODO: Modifying the value can be implemented if needed in the future.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Key key, ref Value value ) dg )
    {
        int ret;

        foreach ( ref node; this.tree )
        {
            auto mapping = Mapping(&node);
            
            Key   key   = mapping.key;
            Value value = mapping.value;
            
            ret = dg(key, value);

            if ( ret ) break;
        }

        return ret;
    }


    /***************************************************************************

        foreach iterator over all mappings in the tree and their corresponding
        keys & values, in key order. Be aware that you can change the key but
        the tree won't be resorted if you do.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Mapping mapping ) dg )
    {
        int ret;

        foreach ( ref node; this.tree )
        {
            auto mapping = Mapping(&node);

            ret = dg(mapping);

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

    private alias ArrayMap!(Mapping, Key) KeyToMapping;

    private KeyToMapping key_to_mapping;


    /***************************************************************************

        Constructor.

        Params:
            num_items = estimate of the maximum number of items that might be
                stored in the tree map (used for the construction of the
                internal ArrayMap)

    ***************************************************************************/

    public this ( size_t num_items )
    {
        super();

        this.key_to_mapping = new KeyToMapping(num_items);
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

    override public Mapping add ( Key key, Value value )
    {
        auto mapping = super.add(key, value);

        this.key_to_mapping.put(mapping.key, mapping);

        return mapping;
    }


    /***************************************************************************

        Removes a mapping from the tree.

        Params:
            mapping = pointer to mapping to remove

    ***************************************************************************/

    override public void remove ( Mapping mapping )
    {
        this.key_to_mapping.remove(mapping.key);

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

    override public bool lookupMapping ( Key key, out Mapping mapping )
    {
        auto mapping_ = key in this.key_to_mapping;
        
        if ( mapping_ is null )
        {
            return false;
        }
        else
        {
            mapping = *mapping_;
            return true;
        }
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

