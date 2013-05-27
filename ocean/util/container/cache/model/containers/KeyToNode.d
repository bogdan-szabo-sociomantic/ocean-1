/*******************************************************************************

    Copyright:      Copyright (C) 2013 sociomantic labs. All rights reserved

    Version:        2013-04-05: Initial release

    Author:        David Eckardt

    Mapping from key to the time-to-index mapping of an item in the cache.
    Limits the number of available mappings to a fixed value and preallocates
    all bucket elements in an array buffer.

*******************************************************************************/

module ocean.util.container.cache.model.containers.KeyToNode;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.container.map.HashMap;
private import ocean.util.container.cache.model.containers.ArrayPool;
private import ocean.util.container.cache.model.containers.TimeToIndex;

/******************************************************************************/

class KeyToNode: HashMap!(TimeToIndex.Node*)
{
    /***********************************************************************

        Array of bucket elements.

    ***********************************************************************/

    private const ArrayPool!(Bucket.Element) elements;

    /***********************************************************************

        Constructor.

        Params:
            n = maximum number of elements in mapping

    ***********************************************************************/

    public this ( size_t n )
    {
        super(n);
        this.elements = new typeof(this.elements)(n);
    }

    /***********************************************************************

        Disposer.

    ***********************************************************************/

    protected override void dispose ( )
    {
        super.dispose();
        delete this.elements;
    }

    /***************************************************************************

        Removes all elements from all buckets.

        Returns:
            this instance

     **************************************************************************/

    public override typeof(this) clear ( )
    {
        super.clear();
        this.elements.clear();
        return this;
    }

    /***************************************************************************

        Obtains a new bucket element.

        Returns:
            a new bucket element.

    ***************************************************************************/

    protected override Bucket.Element* newElement ( )
    {
        return this.elements.next;
    }
}
