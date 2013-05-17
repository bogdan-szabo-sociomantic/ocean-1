/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        12/04/2012: Initial release

    authors:        Gavin Norman, David Eckardt

    Template for a class implementing a set of buckets containing elements
    indexed by unique keys. The bucket set contains both a set of buckets and a
    pool of bucket elements. The bucket elements are structured as linked lists,
    thus each bucket simply contains a pointer to its first element.

    The number of buckets in the set is always a power of 2. In this way the
    getBucket() method, which determines which bucket is responsible for a key,
    can use a simple bit mask instead of a modulo operation, leading to greater
    efficiency.

    Usage:
        See ocean.util.container.map.HashMap & ocean.util.container.map.HashSet

    TODO: the element pool could perhaps be simplified by replacing it with a
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

private import ocean.util.container.map.model.Bucket,
               ocean.util.container.map.model.BucketInfo;

private import ocean.core.Array: clear, isClearable;

private import tango.core.BitManip: bsr;

private import ocean.util.container.map.model.BucketElementFreeList;

/******************************************************************************

    Generic BucketSet base class

 ******************************************************************************/

public abstract class IBucketSet
{
    /**************************************************************************

        Map and and bucket statistics like the map length or the number of
        buckets.

     **************************************************************************/

    public const BucketInfo bucket_info;

    /**************************************************************************

        Bucket elements free list.

     **************************************************************************/

    protected const FreeList free_bucket_elements;

    /**************************************************************************

        Bit mask used by the getBucket() method to determine which bucket is
        responsible for a key.

     **************************************************************************/

    private size_t bucket_mask;

    /**************************************************************************

        Constructor.

        Params:
            n = expected number of elements in mapping
            load_factor = ratio of n to the number of internal buckets. The
                desired (approximate) number of elements per bucket. For
                example, 0.5 sets the number of buckets to double n; for 2 the
                number of buckets is the half of n. load_factor must be greater
                than 0. The load factor is basically a trade-off between memory
                usage (number of buckets) and search time (number of elements
                per bucket).

     **************************************************************************/

    protected this ( size_t n, float load_factor = 0.75 )
    {
        size_t num_buckets = 1 << this.calcNumBucketsExp2(n, load_factor);

        this.bucket_mask = num_buckets - 1;

        this.bucket_info          = new BucketInfo(num_buckets);
        this.free_bucket_elements = new FreeList(n);
    }

    /***************************************************************************

        Disposer.

     **************************************************************************/

    protected override void dispose ( )
    {
        delete this.bucket_info;
        delete this.free_bucket_elements;
    }

    /***************************************************************************

        Removes all elements from all buckets.

        Returns:
            this instance

     **************************************************************************/

    public typeof(this) clear ( )
    {
        this.clear_();

        return this;
    }

    /***************************************************************************

        Changes the number of buckets to 2 ^ exp2.

        Params:
            exp2 = exponent of 2 of the new number of buckets

        Returns:
            this instance.

        In:
            2 ^ exp2 must fit into size_t.

    ***************************************************************************/

    abstract typeof (this) setNumBuckets ( uint exp2 );

    /***************************************************************************

        Changes the number of buckets to the lowest power of 2 that results in a
        load factor of at least load_factor with the current number of elements.

        Params:
            exp2 = exponent of 2 of the new number of buckets

        Returns:
            this instance.

        In:
            load_factor must be greater than 0.

    ***************************************************************************/

    public typeof (this) redistribute ( float load_factor = 0.75 )
    in
    {
        assert (load_factor > 0);
    }
    body
    {
        return this.setNumBuckets(this.calcNumBucketsExp2(this.bucket_info.length, load_factor));
    }

    /***************************************************************************

        Removes all elements from all buckets and sets the values to val_init if
        val_init is not empty.

        Params:
            val_init = initial element value

        Returns:
            this instance

     **************************************************************************/

    protected typeof(this) clear_ ( void[] val_init = null )
    {
        this.clearBuckets(val_init);

        this.bucket_info.clear();

        return this;
    }

    /***************************************************************************

        Removes all elements from all buckets.

        Returns:
            this instance

     **************************************************************************/

    abstract protected void clearBuckets ( void[] val_init );

    /***************************************************************************

        Calculates the lowest exponent of 2 so that a power of 2 with this
        exponent is at least n / load_factor.

        Params:
            n           = number of expected elements in the set
            load_factor = desired maximum load factor

        Returns:
            exponent of 2.

        In:
            load_factor must be greater than 0.

    ***************************************************************************/

    public static uint calcNumBucketsExp2 ( size_t n, float load_factor = 0.75 )
    in
    {
        assert (load_factor > 0);
    }
    body
    {
        return n? bsr(cast(size_t)(n / load_factor)) + 1 : 0;
    }
}

/******************************************************************************

    Bucket set class template.

    Template params:
        V = value size (.sizeof of the value type), may be 0 to store no value
        K = key type

 ******************************************************************************/

public abstract class BucketSet ( size_t V, K = hash_t ) : IBucketSet
{
    /**************************************************************************

        Bucket type

    **************************************************************************/

    protected alias .Bucket!(V, K) Bucket;


    /***************************************************************************

        List of buckets

    ***************************************************************************/

    private Bucket[] buckets;

    /***************************************************************************

        Constructor, sets the number of buckets to n / load_factor, rounded up
        to the nearest power or 2.

        Params:
            n = expected number of elements in bucket set
            load_factor = ratio of n to the number of buckets. The desired
                (approximate) number of elements per bucket. For example, 0.5
                sets the number of buckets to double n; for 2 the number of
                buckets is the half of n. load_factor must be greater than 0
                (this is asserted in IBucketSet.calcNumBucketsExp2()). The load
                factor is basically a trade-off between memory usage (number of
                buckets) and search time (number of elements per bucket).

    ***************************************************************************/

    protected this ( size_t n, float load_factor = 0.75 )
    {
        super(n, load_factor);

        this.buckets = new Bucket[this.bucket_info.num_buckets];
    }

    /***************************************************************************

        Disposer.

    ***************************************************************************/

    protected override void dispose ( )
    {
        super.dispose();

        delete this.buckets;
    }


    /***************************************************************************

        Removes all elements from all buckets and sets the values to val_init if
        val_init is not empty.

        Params:
            val_init = initial element value, the length must be V or 0

        In:
            val_init.length must be V.

    ***************************************************************************/

    protected void clearBuckets ( void[] val_init = null )
    in
    {
        assert (!val_init.length || val_init.length == V);
    }
    body
    {
        // Recycle all bucket elements.

        foreach (ref element; this)
        {
            static if (V) if (val_init.length)
            {
                element.val[] = cast (ubyte[]) val_init[];
            }

            this.free_bucket_elements.recycle(&element);
        }

        // Clear bucket contents.

        .clear(this.buckets);
    }

    /**************************************************************************

        Ensures that Bucket.init consists only of zero bytes so that the
        memset() method in clear() will work.

     **************************************************************************/

    unittest
    {
        assert(isClearable!(Bucket),
               Bucket.stringof ~ ".init contains non-zero byte: " ~
               typeof (this).stringof ~ ".clear_() will not work");
    }


    /***************************************************************************

        Looks up a mapping from the specified key.

        Params:
            key        = key to look up mapping for
            must_exist = true: assert that the mapping exists, false: the
                         mapping may or may not exist

        Returns:
            a pointer to the element mapped to by the specified key or null if
            not found and must_exist is false.
            The caller should make sure that the key is not changed.

        Out:
            - The returned array can only be null if must_exist is false.
            - The length of the returned array is V unless the array is null.

     ***************************************************************************/

    final protected Bucket.Element* get_ ( K key, bool must_exist = false )
    out (element)
    {
        // FIXME: Disabled due to DMD bug 6417, the method parameter argument
        // values are junk inside this contract.

        version (none) if (element)
        {
            assert (element.key == key, "key mismatch");
        }
        else
        {
            assert (!must_exist, "element not found");
        }
    }
    body
    {
        auto element = this.buckets[this.toHash(key) & this.bucket_mask].find(key);

        if (element)
        {
            assert (element.key == key, "key mismatch");
        }
        else
        {
            assert (!must_exist, "element not found");
        }

        return element;
    }

    /***************************************************************************

        Adds or updates a mapping from the specified key.

        Params:
            key   = key to add/update mapping for
            added = set to true if the record did not exist but was added

        Returns:
            a pointer to the element mapped to by the specified key. The caller
            should set the value as desired and make sure that the key is not
            changed.

     ***************************************************************************/

    final protected Bucket.Element* put_ ( K key, out bool added )
    out (element)
    {
        // FIXME: Disabled due to DMD bug 6417, the method parameter argument
        // values are junk inside this contract.

        version (none)
        {
            assert (element !is null);

            assert (element.key == key, "key mismatch");
        }
    }
    body
    {
        size_t bucket_index = this.toHash(key) & this.bucket_mask;

        with (this.buckets[bucket_index])
        {
            auto element = add(key,
            {
                added = true;

                if (has_element)
                {
                    this.bucket_info.put(bucket_index);
                }
                else
                {
                    this.bucket_info.create(bucket_index);
                }

                return cast (Bucket.Element*) this.free_bucket_elements.get(this.newElement());
            }());

            assert (element !is null);

            assert (element.key == key, "key mismatch");

            return element;
        }
    }

    /***************************************************************************

        Creates a new bucket element. May be overridden by a subclass to
        implement a different allocation method.

        Returns:
            a new bucket element.

    ***************************************************************************/

    protected Bucket.Element* newElement ( )
    {
        return new Bucket.Element;
    }

    /***************************************************************************

        Adds or updates a mapping from the specified key.

        Params:
            key = key to add/update mapping for

        Returns:
            the element mapped to by the specified key. The caller should set
            the value as desired and make sure that the key is not changed.

    ***************************************************************************/

    final protected Bucket.Element* put_ ( K key )
    {
        bool added;

        return this.put_(key, added);
    }

    /***************************************************************************

        Removes the mapping for the specified key.

        Params:
            key = key to remove mapping for

        Returns:
            the removed element. It is guaranteed to remain unchanged until the
            next call to put_(), which may reuse it, or to clear().

    ***************************************************************************/

    final protected Bucket.Element* remove_ ( K key )
    out (element)
    {
        // FIXME: Disabled due to DMD bug 6417, the method parameter argument
        // values are junk inside this contract.

        version (none) if (element)
        {
            assert (element.key == key, "key mismatch");
        }
    }
    body
    {
        size_t bucket_index = this.toHash(key) & this.bucket_mask;

        Bucket.Element* element = this.buckets[bucket_index].remove(key);

        if ( element )
        {
            this.bucket_info.remove(bucket_index);

            this.free_bucket_elements.recycle(element);

            assert (element.key == key, "key mismatch");
        }

        return element;
    }

    /***************************************************************************

        Calculates the hash value from key.

        Params:
            key = key to hash

        Returns:
            the hash value that corresponds to key.

    ***************************************************************************/

    abstract public hash_t toHash ( K key );

    /***************************************************************************

        Changes the number of buckets to 2 ^ exp2.

        Params:
            exp2 = exponent of 2 of the new number of buckets

        Returns:
            this instance.

        In:
            2 ^ exp2 must fit into size_t.

    ***************************************************************************/

    public typeof (this) setNumBuckets ( uint exp2 )
    in
    {
        assert (exp2 < size_t.sizeof * 8);
    }
    body
    {
        size_t n_prev = this.buckets.length,
        n_new  = 1 << exp2;

        if (n_prev != n_new)
        {
            // Park the bucket elements that are currently in the set.

            scope parked_elements = this.free_bucket_elements.new ParkingStack(this.bucket_info.length);

            foreach (ref element; this)
            {
                parked_elements.push(&element);
            }

            // Resize the array of buckets and the bucket_info and calculate
            // the new bucket_mask.

            this.buckets.length = n_new;

            .clear(this.buckets[0 .. (n_prev < $)? n_prev : $]);

            this.bucket_info.clearResize(n_new);

            this.bucket_mask = n_new - 1;

            // Put the parked elements back into the buckets.

            foreach (element_; parked_elements)
            {
                auto element = cast (Bucket.Element*) element_,
                bucket_index = this.toHash(element.key) & this.bucket_mask;

                assert (!this.bucket_info[bucket_index] ^ this.buckets[bucket_index].has_element,
                        "bucket with zero length has an element or "
                        "bucket with non-zero length has no element");

                this.bucket_info.put(bucket_index);

                this.buckets[bucket_index].add(element);
            }
        }

        // This call must be outside the scope of parked_elements.

        this.free_bucket_elements.minimize(n_new);

        return this;
    }

    /***************************************************************************

        'foreach' iteration over elements in the set.
        DO NOT change the element keys during iteration because this will
        corrupt the map (unless it is guaranteed that the element will go to the
        same bucket).

    ***************************************************************************/

    protected int opApply ( int delegate ( ref Bucket.Element element ) dg )
    {
        int result = 0;

        foreach (i, info; this.bucket_info.filled_buckets)
        {
            with (this.buckets[info.index])
            {
                assert (has_element);

                result = opApply(dg);
            }

            if (result) break;
        }

        return result;
    }
}
