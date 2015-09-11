/*******************************************************************************

    Copyright: Copyright (C) 2015 sociomantic labs. All rights reserved

    A bucket element allocator using the D runtime memory manager. Bucket
    elements are newed by get() and deleted by recycle().

*******************************************************************************/

module ocean.util.container.map.model.BucketElementGCAllocator;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.map.model.IBucketElementGCAllocator;


/*******************************************************************************

    A bucket element allocator using the D runtime memory manager. Even though
    this memory manager is called "GC-managed" this class
    in fact doesn't rely on garbage collection but explicitly deletes unused
    bucket elements.

*******************************************************************************/

public class BucketElementGCAllocator(Bucket) : IBucketElementGCAllocator
{
    public override void* get ( )
    {
        return new Bucket.Element;
    }
}
