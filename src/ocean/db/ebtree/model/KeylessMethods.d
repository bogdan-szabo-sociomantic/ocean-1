/*******************************************************************************

    Elastic binary tree methods

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        April 2012: Initial release

    authors:        David Eckardt

    Used as mixin in the EBTree classes, contains the methods that do not use
    keys.

*******************************************************************************/

module ocean.db.ebtree.model.KeylessMethods;

/*******************************************************************************

    Template with keyless methods.

    Template parameters:
        Node = tree node struct type; expected to be an instance of the Node
               struct template in ocean.db.ebtree.model.Node.

        eb_first = eb_node* ( eb_root* root ); returns the first node
        eb_last  = eb_node* ( eb_root* root ); returns the last node

*******************************************************************************/

template KeylessMethods ( Node, alias eb_first, alias eb_last )
{
    /***************************************************************************

        Removes a node from the tree.

        Params:
            node = pointer to node to remove

    ***************************************************************************/

    public void remove ( ref Node node )
    {
        this.node_pool.recycle(node.remove());

        --this;
    }

    /***************************************************************************

        Returns:
            pointer to node with lowest value in the tree

    ***************************************************************************/

    public Node* first ( )
    out (node)
    {
        if (this.length)
        {
            assert (node, typeof (this).stringof ~
                    ".first: got a null node but the tree is not empty");
        }
        else
        {
            assert (!node, typeof (this).stringof ~
                           ".first: got a node but the tree is empty");
        }
    }
    body
    {
        return this.ebCall!(eb_first)();
    }


    /***************************************************************************

        Returns:
            pointer to node with highest value in the tree

    ***************************************************************************/

    public Node* last ( )
    out (node)
    {
        if (this.length)
        {
            assert (node, typeof (this).stringof ~
                    ".last: got a null node but the tree is not empty");
        }
        else
        {
            assert (!node, typeof (this).stringof ~
                           ".last: got a node but the tree is empty");
        }
    }
    body
    {
        return this.ebCall!(eb_last)();
    }


    /***************************************************************************

        foreach iterator over nodes in the tree. Any tree modification is
        permitted during iteration.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Node node ) dg )
    {
        int ret = 0;

        for (Node* node = this.first; node && !ret; node = node.next)
        {
            ret = dg(*node);
        }

        return ret;
    }

    /***************************************************************************

        foreach_reverse iterator over nodes in the tree. Any tree modification
        is permitted during iteration.

    ***************************************************************************/

    public int opApply_reverse ( int delegate ( ref Node node ) dg )
    {
        int ret = 0;

        for (Node* node = this.last; node && !ret; node = node.prev)
        {
            ret = dg(*node);
        }

        return ret;
    }

    /**********************************************************************

        Library function call wrapper. Invokes eb_func with this &this.root
        as first argument.

        Template params:
            eb_func = library function

        Params:
            args = additional eb_func arguments

        Returns:
            passes through the return value of eb_func, which may be null.

     **********************************************************************/

    private Node* ebCall ( alias eb_func, T ... ) ( T args )
    {
        static assert (is (typeof (eb_func(&this.root, args)) ==
                           typeof (&Node.init.node_)));

        return cast (Node*) eb_func(&this.root, args);
    }
}