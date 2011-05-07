/*******************************************************************************

    Elastic binary tree class
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    authors:        Gavin Norman
    
    Fast 32- or 64-bit value binary tree class based on the ebtree library from
    HAProxy.

    Link with:
        -Llibebtree.a

    (The library can be found pre-compiled in ocean.db.ebtree.c.lib, or can be
    built by running 'make' inside ocean.db.ebtree.c.src.)

    Usage example:
    
    ---
    
        import ocean.db.ebtree.EBTree;
    
        // Create a tree
        auto tree = new EBTree!(uint);
    
        // Add some values to the tree
        for ( uint i; i < 100; i++ )
        {
            tree.add(i);
        }
    
        // Get the lowest value in the tree
        auto lowest = tree.first;
    
        // Get the highest value in the tree
        auto lowest = tree.last;
    
        // Iterate over all nodes in the key whose values are <= 50
        foreach ( node; tree.lessEqual(50) )
        {
            // node value is node.key
        }
    
        // Empty the tree
        tree.clear;
    
    ---

*******************************************************************************/

module ocean.db.ebtree.EBTree;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Pool;

private import ocean.db.ebtree.c.ebtree;
private import ocean.db.ebtree.c.eb32tree;
private import ocean.db.ebtree.c.eb64tree;

private import tango.core.Traits;



/*******************************************************************************

    EBTree class template.
    
    Template params:
        T = internal type (must be a 32- or 64-bit integer type)

*******************************************************************************/

public class EBTree ( T )
{
    /***************************************************************************

        Check template type is an integer.

    ***************************************************************************/

    static if ( !isIntegerType!(T) )
    {
        static assert(false, typeof(this).stringof ~ ": internal type must be an integer type, not " ~ T.stringof);
    }


    /***************************************************************************

        Check template type is 32- or 64-bits, and define aliases for the tree's
        node type and the functions to get the first and last values in the
        tree.

    ***************************************************************************/

    static if ( T.sizeof == 4 )
    {
        public alias eb32_node Node;
        private alias eb32_first getFirst;
        private alias eb32_last getLast;
    }
    else static if ( T.sizeof == 8 )
    {
        public alias eb64_node Node;
        private alias eb64_first getFirst;
        private alias eb64_last getLast;
    }
    else
    {
        public alias bool Node;
        static assert(false, typeof(this).stringof ~ ": internal type must be either a 32- or 64-bit type, not " ~ T.stringof);
    }


    /***************************************************************************

        Signed / unsigned flag.

    ***************************************************************************/

    private const bool Signed = isSignedIntegerType!(T);


    /***************************************************************************

        Key type.

    ***************************************************************************/

    public alias T KeyType;


    /***************************************************************************
    
        Tree root node.
    
    ***************************************************************************/
    
    private eb_root root;
    
    
    /***************************************************************************
    
        Pool of tree nodes & alias.
    
    ***************************************************************************/
    
    private alias Pool!(Node) NodePool;
    
    private NodePool node_pool;
    
    
    /***************************************************************************
    
        Constructor.
    
    ***************************************************************************/
    
    public this ( )
    {
        this.node_pool = new NodePool;
    }
    
    
    /***************************************************************************
    
        Adds a value to the tree, automatically inserting a new node in the
        correct location to keep the tree sorted.
    
        Params:
            i = value to add
    
        Returns:
            pointer to newly added node
    
    ***************************************************************************/
    
    public Node* add ( KeyType i )
    {
        auto node = this.node_pool.get();
        node.key = i;
    
        static if ( Signed )
        {
            return node.insert_signed(&this.root);
        }
        else
        {
            return node.insert(&this.root);
        }
    }
    
    
    /***************************************************************************
    
        Removes a node from the tree.
    
        Params:
            node = pointer to node to remove
    
    ***************************************************************************/
    
    public void remove ( Node* node )
    {
        node.remove();
    }
    
    
    /***************************************************************************
    
        Returns:
            lowest value in the tree
    
    ***************************************************************************/
    
    public KeyType first ( )
    {
        auto node = getFirst(&this.root);
        return node.key;
    }
    
    
    /***************************************************************************
    
        Returns:
            highest value in the tree
    
    ***************************************************************************/
    
    public KeyType last ( )
    {
        auto node = getLast(&this.root);
        return node.key;
    }
    
    
    /***************************************************************************
    
        Removes all values from the tree.
    
    ***************************************************************************/
    
    public void clear ( )
    {
        this.node_pool.clear();
        this.root = root.init;
    }
    
    
    /***************************************************************************
    
        Gets a 'less than or equal' iterator over the tree's nodes.
    
        Params:
            key = key to compare
    
        Returns:
            iterator providing opApply over all nodes in the tree whose keys are
            <= the specified key
    
    ***************************************************************************/
    
    public LEIterator lessEqual ( KeyType key )
    {
        LEIterator it;
        it.node = getFirst(&this.root);
        it.key = key;
    
        return it;
    }
    
    
    /***************************************************************************
    
        Gets a 'greater than or equal' iterator over the tree's nodes.
    
        Params:
            key = key to compare
    
        Returns:
            iterator providing opApply over all nodes in the tree whose keys are
            >= the specified key
    
    ***************************************************************************/
    
    public GEIterator greaterEqual ( KeyType key )
    {
        GEIterator it;
        it.node = getLast(&this.root);
        it.key = key;
    
        return it;
    }
    
    
    /***************************************************************************
    
        Tree node 'less than or equal' iterator.
    
    ***************************************************************************/
    
    public struct LEIterator
    {
        private Node* node;
        private KeyType key;
    
        public int opApply ( int delegate ( ref KeyType ) dg )
        {
            int ret;
    
            while ( node !is null && cast(KeyType)node.key <= this.key )
            {
                ret = dg(node.key);
                if ( ret ) break;
    
                node = node.next;
            }
    
            return ret;
        }
    
        public int opApply ( int delegate ( ref Node*, ref KeyType ) dg )
        {
            int ret;
    
            while ( node !is null && cast(KeyType)node.key <= this.key )
            {
                ret = dg(node, node.key);
                if ( ret ) break;
    
                node = node.next;
            }
    
            return ret;
        }
    }
    
    
    /***************************************************************************
    
        Tree node 'greater than or equal' iterator.
    
    ***************************************************************************/
    
    public struct GEIterator
    {
        private Node* node;
        private KeyType key;
    
        public int opApply ( int delegate ( ref KeyType ) dg )
        {
            int ret;
    
            while ( node !is null && cast(KeyType)node.key >= this.key )
            {
                ret = dg(node.key);
                if ( ret ) break;
    
                node = node.prev;
            }
    
            return ret;
        }
    
        public int opApply ( int delegate ( ref Node*, ref KeyType ) dg )
        {
            int ret;
    
            while ( node !is null && cast(KeyType)node.key >= this.key )
            {
                ret = dg(node, node.key);
                if ( ret ) break;
    
                node = node.prev;
            }
    
            return ret;
        }
    }
}

