/*******************************************************************************

    Elastic binary tree class
    
    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved
    
    version:        April 2012: Initial release
    
    authors:        Gavin Norman, Mathias Baumann, David Eckardt
    
    Fast 64-bit value binary tree class based on the ebtree library from
    HAProxy.

    Link with:
        -Llibebtree.a

    (The library can be found pre-compiled in ocean.db.ebtree.c.lib, or can be
    built by running 'make' inside ocean.db.ebtree.c.src.)

    Usage example:
    
    ---
    
        import ocean.db.ebtree.EBTree64;
    
        // Create a tree
        auto tree = new EBTree64!();
    
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

    TODO: move this whole package out of ocean.db and into ocean.util.container.

*******************************************************************************/

module ocean.db.ebtree.EBTree64;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.db.ebtree.model.IEBTree,
               ocean.db.ebtree.model.Node,
               ocean.db.ebtree.model.KeylessMethods,
               ocean.db.ebtree.model.Iterators;

private import ocean.db.ebtree.nodepool.NodePool;

private import ocean.db.ebtree.c.ebtree: eb_node, eb_root;

/*******************************************************************************

    EBTree64 class template.
    
    Template params:
        signed = false: use 'ulong' as key type, true: use 'long'. 

*******************************************************************************/

class EBTree64 ( bool signed = false ) : IEBTree
{
    /**************************************************************************

        false if 'ulong' is the key type or true if it is 'long'. 
    
     **************************************************************************/
    
    public const signed_key = signed;
    
    /**************************************************************************

        Key type alias
    
     **************************************************************************/
    
    static if (signed)
    {
        public alias long Key;
    }
    else
    {
        public alias ulong Key;
    }
    
    /**************************************************************************

        Dual32Key struct, allows the usage of two 32-bit integer values as a
        combined 64-bit key.
    
     **************************************************************************/
    
    struct Dual32Key
    {
        /**********************************************************************

            false if 'uint' is the type of hi (below) or true if it is 'int'. 
        
         **********************************************************************/
        
        public const is_signed = signed;
        
        /**********************************************************************

            lo: Carries the lower 32 bits of the key.
        
         **********************************************************************/
        
        public uint lo;
        
        /**********************************************************************

            hi: Carries the higher 32 bits of the key.
        
         **********************************************************************/
        
        static if (signed)
        {
            public int hi;
        }
        else
        {
            public uint hi;
        }
        
        /**********************************************************************

            Compares this instance with other.
            
            Params:
                other = instance to compare with this
            
            Returns:
                a value less than 0 if this < other,
                a value greater than 0 if this > other
                or 0 if this == other.
    
         **********************************************************************/
        
        public int opCmp ( typeof (this) other )
        {
            return (this.hi > other.hi)? +1 : 
                   (this.hi < other.hi)? -1 : 
                   (this.lo >= other.lo)? (this.lo > other.lo) : -1; 
        }
        
        /**********************************************************************

            Obtains the key to store in the ebtree from this instance.
            
            Returns:
                key
    
         **********************************************************************/
        
        private EBTree64!(signed).Key opCast ( )
        {
            return ((cast (long) this.hi) << 0x20) | this.lo;
        }
    }
    
    /**************************************************************************

        Node struct, Node instances are stored in the ebtree.
    
     **************************************************************************/
    
    private static Key getKey ( eb64_node* node_ )
    {
        return node_.key_;
    }
    
    mixin Node!(eb64_node, Key, getKey,
                eb64_next, eb64_prev, eb64_prev_unique, eb64_next_unique,
                eb64_delete);
    
    mixin Iterators!(Node);
    
    /**************************************************************************

    Node pool interface type alias
    
     **************************************************************************/
    
    public alias .INodePool!(Node) INodePool;
    
    /**************************************************************************

        Node pool instance
    
     **************************************************************************/
    
    private const INodePool node_pool;
    
    /**************************************************************************

        Constructor
    
     **************************************************************************/
    
    public this ( )
    {
        this(new NodePool!(Node));
    }
    
    /**************************************************************************

        Constructor
        
        Params:
            node_pool = node pool instance to use
    
     **************************************************************************/
    
    public this ( INodePool node_pool )
    {
        this.node_pool = node_pool;
    }
    
    mixin KeylessMethods!(Node, eb64_first, eb64_last);
    
    /***************************************************************************
    
        Adds a new node to the tree, automatically inserting it in the correct
        location to keep the tree sorted.
    
        Params:
            key = key of node to add
    
        Returns:
            pointer to the newly added node
    
    ***************************************************************************/
    
    public Node* add ( Key key )
    out (node_out)
    {
        assert (node_out);
    }
    body
    {
        scope (success) ++this;
        
        return this.add_(this.node_pool.get(), key);
    }
    
    /***************************************************************************
    
        Adds a value to the tree, automatically inserting a new node in the
        correct location to keep the tree sorted.
    
        Params:
            key = value to add
    
        Returns:
            pointer to newly added node
    
    ***************************************************************************/
    
    public Node* add ( Dual32Key key )
    out (node_out)
    {
        assert (node_out);
    }
    body
    {
        return this.add(cast (Key) key);
    }
    
    /***************************************************************************
    
        Sets the key of node to key, keeping the tree sorted.
    
        Params:
            node = node to update key
            key  = new key for node 
    
        Returns:
            updated node
    
     ***************************************************************************/
    
    public Node* update ( ref Node node, Key key )
    out (node_out)
    {
        assert (node_out);
    }
    body
    {
        return (node.node_.key_ != cast (ulong) key)?
                this.add_(node.remove(), key) : &node;
    }
    
    /***************************************************************************
    
        Sets the key of node to key, keeping the tree sorted.
    
        Params:
            node = node to update key
            key  = new key for node 
    
        Returns:
            updated node
    
    ***************************************************************************/
    
    public Node* update ( ref Node node, Dual32Key key )
    out (node_out)
    {
        assert (node_out);
    }
    body
    {
        return this.update(node, cast (Key) key);
    }
    
    /***************************************************************************

        Searches the tree for the first node whose key is <= the specified key,
        and returns it.

        Params:
            key = key to search for

        Returns:
            first node <= than specified key, may be null if no node found

    ***************************************************************************/

    public Node* firstLessEqual ( Key key )
    {
        return this.ebCall!(eb64_lookup_le)(cast (ulong) key);
    }


    /***************************************************************************

        Searches the tree for the first node whose key is >= the specified key,
        and returns it.

        Params:
            key = key to search for

        Returns:
            first node >= than specified key, may be null if no node found

    ***************************************************************************/

    public Node* firstGreaterEqual ( Key key )
    {
        return this.ebCall!(eb64_lookup_ge)(cast (ulong) key);
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

    public Node* opIn_r ( Key key )
    {
        static if (signed)
        {
            return this.ebCall!(eb64i_lookup)(key);
        }
        else
        {
            return this.ebCall!(eb64_lookup)(key);
        }
    }
    
    /***************************************************************************
    
        Minimizes the memory usage of the node pool.
    
    ***************************************************************************/
    
    public void minimize ( )
    {
        this.node_pool.minimize();
    }
    
    /***************************************************************************
    
        Adds node to the tree, automatically inserting it in the correct
        location to keep the tree sorted.
    
        Params:
            node = node to add
            key  = key for node
    
        Returns:
            node
    
    ***************************************************************************/
    
    private Node* add_ ( Node* node, Key key )
    in
    {
        assert (node, "attempted to add null node (node pool returned null?)");
    }
    out (node_out)
    {
        assert (node_out);
    }
    body
    {
        node.node_.key_ = key;
        
        static if (signed)
        {
            return this.ebCall!(eb64i_insert)(&node.node_);
        }
        else
        {
            return this.ebCall!(eb64_insert)(&node.node_);
        }
    }
    
}

private:

/******************************************************************************

    This structure carries a node, a leaf, and a key.

 ******************************************************************************/

struct eb64_node
{
    private eb_node node; /* the tree node, must be at the beginning */
    private ulong key_;
}

extern (C):

/* Return leftmost node in the tree, or NULL if none */
eb64_node* eb64_first(eb_root* root);

/* Return rightmost node in the tree, or NULL if none */
eb64_node* eb64_last(eb_root* root);

/* Return next node in the tree, or NULL if none */
eb64_node* eb64_next(eb64_node* eb64);

/* Return previous node in the tree, or NULL if none */
eb64_node* eb64_prev(eb64_node* eb64);

/* Return next node in the tree, skipping duplicates, or NULL if none */
eb64_node* eb64_next_unique(eb64_node* eb64);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
eb64_node* eb64_prev_unique(eb64_node* eb64);

/* Delete node from the tree if it was linked in. Mark the node unused. */
void eb64_delete(eb64_node* eb64);

/*
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
eb64_node* eb64_lookup(eb_root* root, ulong x);

/*
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */
eb64_node* eb64i_lookup(eb_root* root, long x);

eb64_node* eb64_lookup_le(eb_root* root, ulong x);
eb64_node* eb64_lookup_ge(eb_root* root, ulong x);

/* Insert eb64_node <neww> into subtree starting at node root <root>.
 * Only neww->key needs be set with the key. The eb64_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */

eb64_node* eb64_insert(eb_root* root, eb64_node* neww);
/* Insert eb64_node <neww> into subtree starting at node root <root>, using
 * signed keys. Only neww->key needs be set with the key. The eb64_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb64_node* eb64i_insert(eb_root* root, eb64_node* neww);
