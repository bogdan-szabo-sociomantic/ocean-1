/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        06/07/2012: Initial release

    authors:        David Eckardt, Gavin Norman

    Bucket set helper class for bookkeeping of the number of elements in each
    bucket.

*******************************************************************************/

module ocean.util.container.map.model.BucketInfo;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Array: clear;

debug (BucketInfo) import tango.io.Stdout;

/*******************************************************************************/

class BucketInfo
{
    /**************************************************************************

        Information about a non-empty bucket.

     **************************************************************************/

    struct Bucket
    {
        /**********************************************************************

            Bucket index, the index of the bucket in the array of buckets.

         **********************************************************************/

        size_t index;

        /**********************************************************************

            Bucket length, the number of elements in the bucket. 0 means that
            the bucket is empty.

         **********************************************************************/

        size_t length;

        /**********************************************************************

            Sorting criterium: Makes .sort of an array of this struct sort the
            elements by .length in descending order.

         **********************************************************************/

        int opCmp ( typeof (this) other )
        {
            return (this.length >= other.length)? this.length > other.length : -1;
        }

        /**********************************************************************/

        debug (BucketInfo) private void print ( )
        {
            Stderr.format(" {,2}/{,2}", this.index, this.length);
        }
    }

    /**************************************************************************

        Number of non-empty buckets.

     **************************************************************************/

    private size_t n_filled = 0;

    /**************************************************************************

        List of Bucket info instances, with the non-empty buckets first, so that
        buckets[0 .. n_filled] refers to the non-empty buckets.

     **************************************************************************/

    private Bucket[] buckets;

    /**************************************************************************

        Index in the list of Bucket info instances by bucket index, so that for
        a bucket index b the bucket info for this bucket can be obtained by
        buckets[bucket_list_indices[b]].

     **************************************************************************/

    private size_t[] bucket_list_indices;

    /**************************************************************************

        Number of elements that are currently in the map.

     **************************************************************************/

    private size_t n_elements;

    /**************************************************************************

        Consistency check.

     **************************************************************************/

    invariant ( )
    {
        assert (this.buckets.length == this.bucket_list_indices.length);
        assert (this.n_filled <= this.buckets.length);
        assert (this.n_filled <= this.n_elements);

        if (this.n_elements)
        {
            assert (this.n_filled);
        }
    }

    /**************************************************************************

        Constructor.

        Params:
            num_buckets = number of buckets

     **************************************************************************/

    public this ( size_t num_buckets )
    {
        this.buckets             = new Bucket[num_buckets];
        this.bucket_list_indices = new size_t[num_buckets];
    }

    /**************************************************************************

        Disposer.

        Params:
            num_buckets = number of buckets

     **************************************************************************/

    protected override void dispose ( )
    {
        delete this.buckets;
        delete this.bucket_list_indices;
    }

    /**************************************************************************

        Returns:
            the number of non-empty buckets.

     **************************************************************************/

    public size_t num_buckets ( )
    {
        return this.buckets.length;
    }

    /**************************************************************************

        Returns:
            the number of elements currently in the map.

     **************************************************************************/

    public size_t length ( )
    {
        return this.n_elements;
    }

    /**************************************************************************

        Returns:
            the number of non-empty buckets.

     **************************************************************************/

    public size_t num_filled_buckets ( )
    {
        return this.n_filled;
    }

    /***************************************************************************

        Returns:
            the average load of the bucket set

    ***************************************************************************/

    public float load ( )
    {
        return (cast(float)this.n_elements) / this.buckets.length;
    }

    /***************************************************************************

        Returns:
            the maximum load of the bucket set (i.e. the number of elements in
            the most-filled bucket)

    ***************************************************************************/

    public size_t max_load ( )
    {
        size_t max_load;

        foreach ( bucket; this.buckets )
        {
            if ( bucket.length > max_load )
            {
                max_load = bucket.length;
            }
        }

        return max_load;
    }

    /***************************************************************************

        Increases the length of the bucket info for the bucket specified by
        bucket_index by 1. If the bucket is currently empty, a bucket info is
        created and the number of non-empty buckets increased by 1.

        Params:
            bucket_index = index of the bucket into which one element has
                           been put

    ***************************************************************************/

    package void put ( size_t bucket_index )
    {
        if (this.buckets[this.bucket_list_indices[bucket_index]].length)
        {
            this.update(bucket_index);
        }
        else
        {
            this.create(bucket_index);
        }
    }

    /***************************************************************************

        Creates a bucket info for the currently empty bucket specified by
        bucket_index, sets the length to 1; increases the number of non-empty
        buckets by 1.

        Params:
            bucket_index = index of the bucket into which the first element has
                           been put

        In:
            The bucket is expected to be currently empty.

    ***************************************************************************/

    package void create ( size_t bucket_index )
    in
    {
        assert (this);

        assert (this.n_filled < this.buckets.length,
                "create: one element or more in each bucket");

        debug (BucketInfo) this.print("cre ", bucket_index);
    }
    out
    {
        assert (this);
        assert (this.n_filled, "all buckets are empty after create");

        debug (BucketInfo) this.print("    ", bucket_index);
    }
    body
    {
        with (this.buckets[this.n_filled])
        {
            index  = bucket_index;
            length = 1;
        }

        this.bucket_list_indices[bucket_index] = this.n_filled++;

        this.n_elements++;
    }

    /***************************************************************************

        Increases the length of the bucket info for the non-empty bucket
        specified by bucket_index by 1.

        Params:
            bucket_index = index of the bucket into which another element has
                           been put

        In:
            The bucket is expected to be non-empty.

    ***************************************************************************/

    package void update ( size_t bucket_index )
    in
    {
        assert (this);

        assert (this.buckets[this.bucket_list_indices[bucket_index]].length,
                "attempted to update an empty bucket info: use create()/put() "
                "instead");

        assert (this.n_elements, "update: no element in map");

        debug (BucketInfo) this.print("upd ", bucket_index);
    }
    out
    {
        assert (this);
        assert (this.n_filled, "all buckets are empty after update");

        debug (BucketInfo) this.print("    ", bucket_index);
    }
    body
    {
        this.buckets[this.bucket_list_indices[bucket_index]].length++;

        this.n_elements++;
    }

    /***************************************************************************

        Decreases the length of the bucket info for the non-empty bucket
        specified by bucket_index by 1. Decreases the number of non-empty
        buckets by 1 if the bucket becomes empty.

        Params:
            bucket_index = index of the bucket into which another element has
                           been put

        In:
            The bucket is expected to be non-empty.

    ***************************************************************************/

    package void remove ( size_t bucket_index )
    in
    {
        assert (this);

        assert (this.buckets[this.bucket_list_indices[bucket_index]].length,
                "remove: attempted to remove an element from an empty bucket");

        assert (this.n_elements, "remove: no element in map");

        debug (BucketInfo) this.print("rem ", bucket_index);
    }
    out
    {
        assert (this);

        debug (BucketInfo) this.print("    ", bucket_index);
    }
    body
    {
        size_t* bucket_info_index = &this.bucket_list_indices[bucket_index];

        Bucket* info_to_remove = &this.buckets[*bucket_info_index];

        /*
         *  Decrease the number of elements in the bucket. If it becomes empty,
         *  move the bucket to the back of the bucket info list.
         *
         *  The 'in' contract makes sure that info_to_remove.length != 0.
         */

        if (!--info_to_remove.length)
        {
            /*
             * Get the last bucket info and decrease the number of non-empty
             * buckets. The 'in' contract together with the class invariant make
             * sure that this.n_filled != 0.
             */

            Bucket* last_info = &this.buckets[--this.n_filled];

            if (info_to_remove !is last_info)
            {
                /*
                 * If this is not the last bucket, overwrite the info to remove
                 * with the last info. To make assertions fail easier in the
                 * case of a bug, clear the last info and set the index for the
                 * empty bucket to buckets.length.
                 */

                assert (last_info.length, "last bucket info is empty");

                *info_to_remove = *last_info;

                this.bucket_list_indices[info_to_remove.index] = *bucket_info_index;
            }

            with (*last_info)
            {
                index = this.buckets.length;
                length = 0;
            }

            *bucket_info_index = this.buckets.length;
        }

        this.n_elements--;
    }

    /***************************************************************************

        Obtains the list of bucket infos for the non-empty buckets. Each element
        contains the bucket index and the number of elements in the bucket.

        DO NOT MODIFY list elements in-place!

        Returns:
            the list of bucket infos for the non-empty buckets. Each element
            contains the bucket index and the number of bucket elements.

    ***************************************************************************/

    package Bucket[] filled_buckets ( )
    {
        return this.buckets[0 .. this.n_filled];
    }

    /***************************************************************************

        Obtains the number of elements in the bucket specified by bucket_index.

        Params:
            bucker_index = bucket index

        Returns:
            the number of elements in the bucket specified by bucket_index.

        In:
            bucket_index must be less than the number of buckets.

    ***************************************************************************/

    public size_t opIndex ( size_t bucket_index )
    in
    {
        assert (bucket_index < this.bucket_list_indices.length);
    }
    body
    {
        size_t index = this.bucket_list_indices[bucket_index];

        return (index < this.n_filled)? this.buckets[index].length : 0;
    }

    /**************************************************************************

        Clears all bucket infos and sets the number of non-empty buckets to 0.

     **************************************************************************/

    package void clear ( )
    out
    {
        assert (this);

        assert (!this.n_elements, "clear: remaining elements");
    }
    body
    {
        .clear(this.filled_buckets);

        this.n_filled = this.n_elements = 0;
    }

    /**************************************************************************

        Clears all bucket infos, sets the number of non-empty buckets to 0 and
        sets the total number of buckets to n.

        Params:
            n = new total number of buckets

     **************************************************************************/

    package void clearResize ( size_t n )
    {
        if (this.buckets.length != n)
        {
            this.buckets.length             = n;
            this.bucket_list_indices.length = n;

            if (this.n_filled > n)
            {
                this.n_filled = n;
            }
        }

        this.clear();
    }

    /**************************************************************************

        Prints the bucket infos.

     **************************************************************************/

    debug (BucketInfo) private void print ( char[] prefix, size_t bucket_index )
    {
        Stderr(prefix);
        Stderr.format("{,2} >>>>> ", bucket_index);

        foreach (bucket; this.buckets[0 .. this.n_filled])
        {
            bucket.print();
        }

        Stderr('|');

        foreach (bucket; this.buckets[this.n_filled .. $])
        {
            bucket.print();
        }

        Stderr('\n').flush();
    }
}
