/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        12/04/2012: Initial release

    authors:        Gavin Norman

    TODO: description of module

    The number of buckets in the set is always a power of 2. In this way the
    getBucket() method, which determines which bucket is responsible for a key,
    can use a simple bit mask instead of a modulo operation, leading to greater
    efficiency.

    TODO: the bucket pool could perhaps be simplified by replacing it with a
    free-list implementation in conjunction with a list of non-empty buckets.
    The non-empty list could be used for iteration over the elements, and for
    clearing only the buckets which contain elements. (The current clear()
    implementation simply clears all buckets.) Another advantage of using a
    free-list implementation would be the removal of the requirement for each
    bucket element to contain the object_pool_index member. In a bucket set
    with many elements, these additional 4 bytes per element becomes
    significant.

*******************************************************************************/

module ocean.util.container.map.model.BucketSet;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.container.map.model.Bucket;

private import ocean.core.ObjectPool;



/*******************************************************************************

    Bucket set class template.

    Template params:
        E = element type

*******************************************************************************/

public abstract class BucketSet ( E )
{
    /***************************************************************************

        Bucket type

    ***************************************************************************/

    protected alias .Bucket!(E) Bucket;


    /***************************************************************************

        List of buckets

    ***************************************************************************/

    protected Bucket[] buckets;


    /***************************************************************************

        Pool of bucket elements

    ***************************************************************************/

    protected alias Pool!(Bucket.Element) BucketElementPool;

    protected BucketElementPool bucket_elements;


    /***************************************************************************

        Bit mask used by the getBucket() method to determine which bucket is
        responsible for a key.

    ***************************************************************************/

    private hash_t bucketMask;


    /***************************************************************************

        Constructor, sets the number of buckets to n / load_factor, rounded up
        to the nearest power or 2.

        Params:
            n = expected number of elements in bucket set
            load_factor = ratio of n to the number of buckets. The desired
                (approximate) number of elements per bucket. For example, 0.5
                sets the number of buckets to double n; for 2 the number of
                buckets is the half of n. load_factor must be greater than 0.
                The load factor is basically a trade-off between memory usage
                (number of buckets) and search time (number of elements per
                bucket).

    ***************************************************************************/

    public this ( size_t n, float load_factor = 0.75 )
    in
    {
        assert (n);
        assert (load_factor > 0.0);
    }
    body
    {
        auto num_buckets = cast(size_t)(n / load_factor);

        size_t pow2 = 1;
        while ( pow2 < num_buckets )
        {
            pow2 *= 2;
        }

        this.bucketMask = pow2 - 1;

        this.buckets = new Bucket[pow2];

        this.bucket_elements = new BucketElementPool;
    }


    /***************************************************************************

        Returns:
            the number of items in all buckets

    ***************************************************************************/

    public size_t length ( )
    {
        return this.bucket_elements.num_busy;
    }


    /***************************************************************************

        Removes all elements from all buckets.

    ***************************************************************************/

    public typeof(this) clear ( )
    {
        // Clear bucket contents.
        foreach ( ref bucket; this.buckets )
        {
            bucket = Bucket.init;
        }

        // Recycle all bucket elements.
        scope it = this.bucket_elements.new BusyItemsIterator;
        foreach ( ref element; it )
        {
            this.bucket_elements.recycle(&element);
        }

        return this;
    }


    /***************************************************************************

        Returns:
            the average load of the bucket set

    ***************************************************************************/

    public float load ( )
    {
        return cast(float)this.bucket_elements.num_busy /
            cast(float)this.buckets.length;
    }


    /***************************************************************************

        Returns:
            the maximum load of the bucket set

    ***************************************************************************/

    public size_t max_load ( )
    {
        size_t max_load;

        foreach ( i, bucket; this.buckets )
        {
            if ( bucket.length > max_load )
            {
                max_load = bucket.length;
            }
        }

        return max_load;
    }


    /***************************************************************************

        Removes the specified element from the bucket in which it is stored. If
        the element does not exist in any bucket, then nothing happens.

        Params:
            key = key of element to remove

        Returns:
            the average load of the bucket set

    ***************************************************************************/

    protected Bucket.Element* removeElement ( hash_t key )
    {
        Bucket.Element* element = null;

        with (*this.getBucket(key))
        {
            element = remove(find(key));
        }

        return element;
    }


    /***************************************************************************

        Iterator scope class.

        The iteration is actually over a copy of the elements. Thus the bucket
        contents may be modified while iterating. However, the list of elements
        iterated over is not updated to any changes made.

    ***************************************************************************/

    protected scope class ElementsIterator
    {
        public int opApply ( int delegate ( ref Bucket.Element* ) dg )
        {
            int r;

            scope it = this.outer.bucket_elements.new BusyItemsIterator;
            foreach ( ref element; it )
            {
                auto ptr = &element;
                r = dg(ptr);
                if ( r ) break;
            }

            return r;
        }
    }


    /***************************************************************************

        Read only iterator scope class.

        The read-only iterator is more efficient as it does not require the
        copy of the items being iterated, which the safe iterator performs.

    ***************************************************************************/

    protected scope class ReadOnlyElementsIterator
    {
        public int opApply ( int delegate ( ref Bucket.Element* ) dg )
        {
            int r;

            scope it = this.outer.bucket_elements.new ReadOnlyBusyItemsIterator;
            foreach ( ref element; it )
            {
                auto ptr = &element;
                r = dg(ptr);
                if ( r ) break;
            }

            return r;
        }
    }


    /***************************************************************************

        Gets the bucket which is responsible for the given key.

        Params:
            key = key to get bucket for

        Returns:
            pointer to bucket responsible for the given key

    ***************************************************************************/

    protected Bucket* getBucket ( hash_t key )
    {
        return this.buckets.ptr + (key & this.bucketMask);
    }
}

