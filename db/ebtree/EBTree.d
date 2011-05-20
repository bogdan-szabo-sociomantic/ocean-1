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

private import ocean.db.ebtree.c.ebtree;
private import ocean.db.ebtree.c.eb32tree;
private import ocean.db.ebtree.c.eb64tree;

private import tango.core.Traits;

debug private import tango.util.log.Trace;



/*******************************************************************************

    EBTree class template.
    
    Template params:
        T = internal type (must be a 32- or 64-bit integer type)

*******************************************************************************/

public class EBTree ( T )
{
    /***************************************************************************

        This alias

    ***************************************************************************/

    private alias typeof(this) This;


    /***************************************************************************

        Check template type is an integer.

    ***************************************************************************/

    static if ( !isIntegerType!(T) )
    {
        static assert(false, This.stringof ~ ": internal type must be an integer type, not " ~ T.stringof);
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
        private alias eb32_lookup_le lookupLE;
        private alias eb32_lookup_ge lookupGE;
    }
    else static if ( T.sizeof == 8 )
    {
        public alias eb64_node Node;
        private alias eb64_first getFirst;
        private alias eb64_last getLast;
        private alias eb64_lookup_le lookupLE;
        private alias eb64_lookup_ge lookupGE;
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
    
        Number of nodes in the tree.

    ***************************************************************************/

    private size_t count;


    /***************************************************************************

        List of free nodes. When a node is removed it is added to this list, so
        that it can be re-used when a new node is added.

    ***************************************************************************/

    private Node*[] free_nodes;


    /***************************************************************************
    
        Constructor.
    
    ***************************************************************************/
    
    public this ( )
    {
    }


    /***************************************************************************
    
        Adds a value to the tree, automatically inserting a new node in the
        correct location to keep the tree sorted.
    
        Params:
            key = value to add
    
        Returns:
            pointer to newly added node
    
    ***************************************************************************/

    public Node* add ( KeyType key )
    {
        Node* node;
        if ( this.free_nodes.length )
        {
            node = this.free_nodes[$-1];
            this.free_nodes.length = this.free_nodes.length - 1;
        }
        else
        {
            node = new Node;
        }
        this.count++;

        node.key = key;
    
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
        if ( node !is null )
        {
            node.remove();
            this.free_nodes.length = this.free_nodes.length + 1;
            this.free_nodes[$-1] = node;
            this.count--;
        }
    }
    
    
    /***************************************************************************
    
        Returns:
            lowest value in the tree

        Throws:
            exception if tree is empty
    
    ***************************************************************************/
    
    public KeyType first ( )
    {
        auto node = getFirst(&this.root);
        if ( node is null )
        {
            throw new Exception(typeof(this).stringof ~ ".first: tree is empty, no first entry");
        }
        else
        {
            return node.key;
        }
    }
    
    
    /***************************************************************************
    
        Returns:
            highest value in the tree
    
        Throws:
            exception if tree is empty
    
    ***************************************************************************/
    
    public KeyType last ( )
    {
        auto node = getLast(&this.root);
        if ( node is null )
        {
            throw new Exception(typeof(this).stringof ~ ".last: tree is empty, no last entry");
        }
        else
        {
            return node.key;
        }
    }


    /***************************************************************************

        Searches the tree for the first node whose key is <= the specified key,
        and returns the node's key.

        Params:
            key = key to search for

        Returns:
            key of first node <= than specified key

        Throws:
            exception if no node found
    
    ***************************************************************************/
    
    public KeyType firstLessEqual ( KeyType key )
    {
        auto node = lookupLE(&this.root, key);
        if ( node is null )
        {
            throw new Exception(typeof(this).stringof ~ ".firstLessEqual: no entry <= specified key");
        }
        else
        {
            return node.key;
        }
    }


    /***************************************************************************

        Searches the tree for the first node whose key is >= the specified key,
        and returns the node's key.

        Params:
            key = key to search for

        Returns:
            key of first node >= than specified key

        Throws:
            exception if no node found

    ***************************************************************************/

    public KeyType firstGreaterEqual ( KeyType key )
    {
        auto node = lookupGE(&this.root, key);
        if ( node is null )
        {
            throw new Exception(typeof(this).stringof ~ ".firstGreaterEqual: no entry >= specified key");
        }
        else
        {
            return node.key;
        }
    }


    /***************************************************************************

        Returns:
            pointer to node with lowest value in the tree

    ***************************************************************************/

    public Node* firstNode ( )
    {
        return getFirst(&this.root);
    }


    /***************************************************************************

        Returns:
            pointer to node with highest value in the tree

    ***************************************************************************/

    public Node* lastNode ( )
    {
        return getLast(&this.root);
    }


    /***************************************************************************

        Searches the tree for the first node whose key is <= the specified key,
        and returns it.

        Params:
            key = key to search for

        Returns:
            first node <= than specified key, may be null if no node found

    ***************************************************************************/

    public Node* firstNodeLessEqual ( KeyType key )
    {
        return lookupLE(&this.root, key);
    }


    /***************************************************************************

        Searches the tree for the first node whose key is >= the specified key,
        and returns it.

        Params:
            key = key to search for

        Returns:
            first node >= than specified key, may be null if no node found

    ***************************************************************************/

    public Node* firstNodeGreaterEqual ( KeyType key )
    {
        return lookupGE(&this.root, key);
    }


    /***************************************************************************

        Searches the tree for the specified key, and returns the first node with
        that key.

        Params:
            key = key to search for

        Returns:
            pointer to first node in tree with specified key, may be null if no
            nodes found

    ***************************************************************************/

    public Node* lookup ( KeyType key )
    {
        return Node.lookup(&this.root, key);
    }


    /***************************************************************************

        Returns:
            number of items in tree

    ***************************************************************************/

    size_t length ( )
    {
        return this.count;
    }


    /***************************************************************************
    
        Removes all values from the tree.
    
    ***************************************************************************/
    
    public void clear ( )
    {
        foreach ( node, key; this )
        {
            this.free_nodes.length = this.free_nodes.length + 1;
            this.free_nodes[$-1] = node;
        }

        this.count = 0;

        this.root = root.init;
    }


    /***************************************************************************

        foreach iterator over keys.

    ***************************************************************************/

    public int opApply ( int delegate ( ref KeyType key ) dg )
    {
        int ret;

        foreach ( node, key; this )
        {
            ret = dg(key);
            
            if ( ret ) break;
        }

        return ret;
    }


    /***************************************************************************

        foreach iterator over nodes & keys.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Node* node, ref KeyType key ) dg )
    {
        Node* node = this.firstNode;

        int ret;

        while ( node !is null )
        {
            ret = dg(node, node.key);
            if ( ret ) break;

            node = node.next;
        }

        return ret;
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
        it.node = this.firstNode;
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
        it.node = this.lastNode;
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

            foreach ( node, key; *this )
            {
                ret = dg(key);
                
                if ( ret ) break;
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

            foreach ( node, key; *this )
            {
                ret = dg(key);
                
                if ( ret ) break;
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

