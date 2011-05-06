/*******************************************************************************

    32-bit elastic binary tree class

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman

    Fast 32-bit value binary tree class based on the ebtree library from
    HAProxy.

    Link with:
        -Llibebtree.a

    (The library can be found pre-compiled in ocean.db.ebtree.c.lib, or can be
    built by running 'make' inside ocean.db.ebtree.c.src.)

    Usage example:

    ---

        import ocean.db.ebtree.Eb32Tree;

        // Create a tree
        const bool signed_keys = false;

        auto tree = new Eb32Tree!(signed_keys);

        // Add some values to the tree
        for ( int i; i < 100; i++ )
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

module ocean.db.ebtree.Eb32Tree;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Pool;

private import ocean.db.ebtree.c.ebtree;
private import ocean.db.ebtree.c.eb32tree;

private import tango.core.Traits;



/*******************************************************************************

    Eb32Tree class template.

    Template params:
        Signed = if true, the values in the tree will be interpreted as signed

*******************************************************************************/

public class Eb32Tree ( bool Signed )
{
    /***************************************************************************

        Value type alias, dependant on signed / unsigned template parameter.

    ***************************************************************************/

    static if ( Signed )
    {
        public alias int KeyType;
    }
    else
    {
        public alias uint KeyType;
    }


    /***************************************************************************

        Tree node alias.

    ***************************************************************************/

    public alias eb32_node Node;


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
        auto node = eb32_first(&this.root);
        return node.key;
    }


    /***************************************************************************

        Returns:
            highest value in the tree

    ***************************************************************************/

    public KeyType last ( )
    {
        auto node = eb32_last(&this.root);
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
        it.node = eb32_first(&this.root);
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
        it.node = eb32_last(&this.root);
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

