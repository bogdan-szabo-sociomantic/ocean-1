/*******************************************************************************

    Elastic binary tree node pool

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        April 2012: Initial release

    authors:        Gavin Norman, David Eckardt

    Simple struct pool for node struct instances

*******************************************************************************/

module ocean.db.ebtree.nodepool.NodePool;

/*******************************************************************************

    Node pool interface

*******************************************************************************/

interface INodePool ( Node )
{
    Node* get ( );

    void recycle ( Node* );

    void minimize ( );
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
            return new Node;
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

        Deletes all free nodes.

    ***************************************************************************/

    void minimize ( )
    {
        if (this.free_nodes)
        {
            foreach (ref node; this.free_nodes)
            {
                delete node;
            }

            delete this.free_nodes;
        }
    }

    /***************************************************************************

        Disposer

    ***************************************************************************/

    protected override void dispose ( )
    {
        this.minimize();
    }
}
