/*******************************************************************************

    Elastic binary tree node pool

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        April 2012: Initial release

    authors:        Gavin Norman, David Eckardt

    Simple struct pool for node struct instances

*******************************************************************************/

module ocean.util.container.ebtree.nodepool.NodePool;

/*******************************************************************************

    Node pool interface

*******************************************************************************/

interface INodePool ( Node )
{
    Node* get ( );

    void recycle ( Node* );
}

/*******************************************************************************

    Default node pool implementation

*******************************************************************************/

class NodePool ( Node ) : INodePool!(Node)
{
    static assert (is (Node == struct));

    /***************************************************************************

        List of free nodes. When a node is removed it is added to this list, so
        that it can be re-used when a new node is added.

    ***************************************************************************/

    private Node*[] free_nodes;

    /***************************************************************************

        Obtains a Node instance. If there are currently free nodes, one of these
        is used, otherwise a new Node instance is created.

        Returns:
            Node instance

    ***************************************************************************/

    public Node* get ( )
    {
        if ( this.free_nodes.length )
        {
            scope (success) this.free_nodes.length = this.free_nodes.length - 1;

            return this.free_nodes[$ - 1];
        }
        else
        {
            return this.newNode();
        }
    }

    /***************************************************************************

        Adds node to the list of free nodes.

        Params:
            node = free node instance

    ***************************************************************************/

    public void recycle ( Node* node )
    {
        this.free_nodes.length = this.free_nodes.length + 1;
        this.free_nodes[$ - 1] = node;
    }

    /***************************************************************************

        Creates a new node.
        May be overridden by a subclass to use a different allocation method.

        Returns:
            a newly created node.

        Out:
            The returned node pointer is an integer multiple of 16 as required
            by the libebtree.

    ***************************************************************************/

    protected Node* newNode ( )
    out (node)
    {
        assert(!((cast(size_t)node) % 0x10),
               "the node pointer must be an integer multiple of 16");
    }
    body
    {
        return new Node;
    }
}