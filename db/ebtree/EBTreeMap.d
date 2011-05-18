/*******************************************************************************

    Sorted map class, based on an elastic binary tree

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    authors:        Gavin Norman
    
    Fast, ordered, 32-bit key, 32-bit value map. The map is ordered by the key
    type.
    
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
    
        // Iterate over all keys and values in the map
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

private import tango.stdc.time : time_t;

private import ocean.db.ebtree.EBTree;



/*******************************************************************************

    EBTree ordered map class template. The map is ordered by the key type.

    Internally a 64-bit tree is used, with keys consisting of the bitwise
    concatenated mapping key and value (32-bits each). The key forms the highest
    32 bits of the tree node's key, where the value forms its lowest 32 bits.
    This ensures that the key nodes are sorted by the mapping keys.

    Template params:
        Key = type of keys stored in map (must be 32-bits)
        Value = type of values stored in map (must be 32-bits)

*******************************************************************************/

class EBTreeMap ( Key, Value )
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

        Struct defining a single entry in the map -- a key and a value.

    ***************************************************************************/

    private struct NodeData
    {
        Key key;
        Value value;
    }


    /***************************************************************************

        Union for converting between the actual values which are stored in the
        EBTree (ulongs -- 64-bit integers) and the NodeData struct declared
        above.

    ***************************************************************************/

    private union NodeUnion
    {
        NodeData data;
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

    public alias Tree.Node Node;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.tree = new Tree;
    }


    /***************************************************************************

        Adds a mapping.

        Params:
            key = key
            value = value

        Returns:
            pointer to new node in tree

    ***************************************************************************/

    public Node* add ( Key key, Value value )
    {
        NodeUnion item;
        item.data.key = key;
        item.data.value = value;

        return this.tree.add(item.integer);
    }


    /***************************************************************************

        Removes a node from the tree.
    
        Params:
            node = pointer to node to remove
    
    ***************************************************************************/

    public void remove ( Node* node )
    {
        this.tree.remove(node);
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

        Gets the mapped value corresponding to a node in the tree.

        Params:
            node = pointer to node
    
        Returns:
            value of tree node

    ***************************************************************************/

    public Value getValue ( Node* node )
    in
    {
        assert(node !is null, This.stringof ~ ".getValue: cannot get a value from a null node");
    }
    body
    {
        NodeUnion item;
        item.integer = node.key;

        return item.data.value;
    }


    /***************************************************************************

        Gets the mapped key corresponding to a node in the tree.

        Params:
            node = pointer to node

        Returns:
            key of tree node

    ***************************************************************************/

    public Value getKey ( Node* node )
    in
    {
        assert(node !is null, This.stringof ~ ".getKey: cannot get a key from a null node");
    }
    body
    {
        NodeUnion item;
        item.integer = node.key;
    
        return item.data.value;
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

        Gets the first node in the tree (which contains the lowest key).

        Returns:
            first node in tree, null if tree is empty

    ***************************************************************************/

    public Node* firstNode ( )
    {
        return this.tree.firstNode;
    }


    /***************************************************************************

        Gets the last node in the tree (which contains the highest key).

        Returns:
            last node in tree, null if tree is empty

    ***************************************************************************/

    public Node* lastNode ( )
    {
        return this.tree.lastNode;
    }


    /***************************************************************************

        foreach iterator over all keys in the map.
    
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

        foreach iterator over all values in the map.

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

        foreach iterator over all keys & values in the map.

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

        foreach iterator over all nodes in the tree and their corresponding
        keys & values.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Node* node, ref Key key, ref Value value ) dg )
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

