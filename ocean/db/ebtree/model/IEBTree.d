/*******************************************************************************

    Elastic binary tree base class

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        April 2012: Initial release

    authors:        Gavin Norman, Mathias Baumann, David Eckardt

    Base class for EBTree32/64/128. Hosts eb_root and the node counter.

*******************************************************************************/

module ocean.db.ebtree.model.IEBTree;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.db.ebtree.c.ebtree: eb_root;

/******************************************************************************/

abstract class IEBTree
{
    /***************************************************************************

        Tree root node.

    ***************************************************************************/

    protected eb_root root;


    /***************************************************************************

        Number of nodes in the tree.

    ***************************************************************************/

    private size_t count;


    /***************************************************************************

        Returns:
            the number of records currently in the tree.

    ***************************************************************************/

    public size_t length ( )
    {
        return this.count;
    }

    /***************************************************************************

        Removes all values from the tree.

    ***************************************************************************/

    public void clear ( )
    {
        this.count = 0;
        this.root  = this.root.init;
    }

    /***************************************************************************

        Deletes all free nodes in the node pool.

    ***************************************************************************/

    abstract public void minimize ( );

    /***************************************************************************

        Increases the record counter by n.

        Params:
            n = amount to add to the record counter value

        Returns:
            new record counter value

    ***************************************************************************/

    protected size_t opAddAssign ( size_t n )
    {
        return this.count += n;
    }

    /***************************************************************************

        Decreases the record counter by n.

        Params:
            n = amount to subtract from the record counter value

        Returns:
            new record counter value

        In:
            n must be at most the current record counter value.

    ***************************************************************************/

    protected size_t opSubAssign ( size_t n )
    in
    {
        assert (this.count >= n);
    }
    body
    {
        return this.count -= n;
    }

    /***************************************************************************

        Disposer

    ***************************************************************************/

    protected override void dispose ( )
    {
        this.clear();
        this.minimize();
    }
}
