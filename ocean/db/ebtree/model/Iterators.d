/*******************************************************************************

    Elastic binary tree node iterator classes template

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        April 2012: Initial release

    authors:        David Eckardt

    Used as mixin in the EBTree classes. The Iterator and PartIterator classes
    are nested classes of the EBTree class the template is mixed into.
    Both classes are suitable for memory-friendly 'scope' usage.

*******************************************************************************/

module ocean.db.ebtree.model.Iterators;

/*******************************************************************************

    Template with iterator classes.

    Template parameters:
        Node = tree node struct type; expected to be an instance of the Node
               struct template in ocean.db.ebtree.model.Node.

*******************************************************************************/

template Iterators ( Node )
{
    /***************************************************************************

        Provides 'foreach' and 'foreach_reverse' iteration over the nodes in the
        tree, starting with the first or last node, respectively.

    ***************************************************************************/

    class Iterator
    {
        /***********************************************************************

            Set to true to skip key duplicates. This flag may be changed during
            iteration.

        ***********************************************************************/

        public bool unique = false;

        /***********************************************************************

            Constructor

            Params:
                unique = true: skip key duplicates, false: iterate over all
                         nodes.

        ***********************************************************************/

        public this ( bool unique = false )
        {
            this.unique = unique;
        }

        /***********************************************************************

            foreach iterator over nodes in the tree. Any tree modification is
            permitted during iteration.

        ***********************************************************************/

        public int opApply ( int delegate ( ref Node node ) dg )
        {
            int ret = 0;

            for (Node* node = this.first; node && !ret;
                       node = this.unique? node.next_unique : node.next)
            {
                ret = dg(*node);
            }

            return ret;
        }

        /***************************************************************************

            foreach_reverse iterator over nodes in the tree. Any tree modification
            is permitted during iteration.

        ***************************************************************************/

        public int opApplyReverse ( int delegate ( ref Node node ) dg )
        {
            int ret = 0;

            for (Node* node = this.last; node && !ret;
                       node = this.unique? node.prev_unique : node.prev)
            {
                ret = dg(*node);
            }

            return ret;
        }

        /***********************************************************************

            Returns:
                the EBTree instance this instance iterates over.

        ***********************************************************************/

        public typeof (this.outer) host ( )
        {
            return this.outer;
        }

        /***********************************************************************

            Returns:
                the first node in the tree or null if there is none.

        ***********************************************************************/

        protected Node* first ( )
        {
            return this.outer.first;
        }

        /***********************************************************************

            Returns:
                the first last in the tree or null if there is none.

        ***********************************************************************/

        protected Node* last ( )
        {
            return this.outer.last;
        }
    }

    /***************************************************************************

        Provides 'foreach' and 'foreach_reverse' iteration over the nodes in the
        tree, starting with the first node whose key is greater or less than a
        reference key, respectively.

    ***************************************************************************/

    class PartIterator : Iterator
    {
        /***********************************************************************

            Reference key. May be changed at any time but becomes effective on
            the next iteration start.

        ***********************************************************************/

        public Key key;

        /***********************************************************************

            Constructor

            Params:
                key    = reference key
                unique = true: skip key duplicates, false: iterate over all
                         nodes.

        ***********************************************************************/

        public this ( Key key, bool unique = false )
        {
            super(unique);

            this.key = key;
        }

        /***********************************************************************

            Returns:
                the first node in the tree whose key is greater than or equal to
                the reference key or null if there is none.

        ***********************************************************************/

        protected Node* first ( )
        {
            return this.outer.firstGreaterEqual(this.key);
        }

        /***********************************************************************

            Returns:
                the first node in the tree whose key is less than or equal to
                the reference key or null if there is none.

        ***********************************************************************/

        protected Node* last ( )
        {
            return this.outer.firstLessEqual(this.key);
        }
    }
}
