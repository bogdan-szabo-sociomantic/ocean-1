/*******************************************************************************

    Copyright:      Copyright (C) 2013 sociomantic labs. All rights reserved

    Version:        2013-04-05: Initial release

    Author:        David Eckardt

    Mapping from access time to the index of an item in the cache items array.
    Limits the number of available mappings to a fixed value and preallocates
    all nodes in an array buffer.

*******************************************************************************/

module ocean.util.container.cache.model.containers.TimeToIndex;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.ebtree.EBTree128;
import ocean.util.container.ebtree.nodepool.NodePool;
import ocean.util.container.cache.model.containers.ArrayPool;

/******************************************************************************/

class TimeToIndex: EBTree128!()
{
    /***************************************************************************

        Node wrapper struct, the node pool element type which must have a size
        that is an integer multiple of 16. This is because the libebtree
        requires that the pointers to the nodes passed to it are integer
        multiples of 16.

    ***************************************************************************/

    struct PaddedNode
    {
        /***********************************************************************

            Actual node.

        ***********************************************************************/

        Node node;

        /***********************************************************************

            Pad bytes.

        ***********************************************************************/

        private ubyte[Node.sizeof % 16] pad;

        /**********************************************************************/

        static assert(typeof(*this).sizeof % 16 == 0,
                      typeof(*this).stringof ~ ".sizeof must be an integer "
                      "multiple of 16, not " ~ typeof(*this).sizeof.stringof);
    }

    /**************************************************************************/

    static class ArrayNodePool: NodePool!(Node)
    {
        /***********************************************************************

            Array of bucket elements.

        ***********************************************************************/

        private const ArrayPool!(PaddedNode) elements;

        /***********************************************************************

            Constructor.

            Params:
                n = maximum number of elements in mapping

        ***********************************************************************/

        public this ( size_t n )
        {
            this.elements = new typeof(this.elements)(n);
        }

        /***********************************************************************

            Destructor.

        ***********************************************************************/

        protected override void dispose ( )
        {
            super.dispose();
            delete this.elements;
        }

        /***********************************************************************

            Obtains a new node from the array node pool.

            Returns:
                a new node.

            Out:
                The returned node pointer is an integer multiple of 16 as
                required by the libebtree (inherited postcondition).

        ***********************************************************************/

        protected override Node* newNode ( )
        {
            return &(this.elements.next.node);
        }
    }

    /***************************************************************************

        Array pool of nodes.

    ***************************************************************************/

    private const ArrayNodePool nodes;

    /***************************************************************************

        Constructor.

        Params:
            n = maximum number of elements in mapping

    ***************************************************************************/

    public this ( size_t n )
    {
        super(this.nodes = new typeof(this.nodes)(n));
    }

    /***************************************************************************

        Removes all values from the tree.

    ***************************************************************************/

    public override void clear ( )
    {
        super.clear();
        this.nodes.elements.clear();
    }

    /***********************************************************************

        Disposer.

    ***********************************************************************/

    protected override void dispose ( )
    {
        super.dispose();
        delete this.nodes;
    }
}
