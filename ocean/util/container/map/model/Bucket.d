/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        11/04/2012: Initial release

    authors:        David Eckardt, Gavin Norman

    Template for a struct implementing a single bucket in a set (see
    ocean.util.container.map.model.BucketSet). A bucket contains a set of
    elements which can be added to, removed from and searched.

    Each element in a bucket has a unique key with which it can be identified.
    The elements' key type is templated, but defaults to hash_t. A bucket can
    only contain one element with a given key - if a duplicate is added it will
    replace the original. The elements in the bucket are stored as a linked
    list, for easy removal and insertion.

    Note that the bucket does not own its elements, these must be managed from
    the outside in a pool. The bucket itself simply keeps a pointer to the first
    element which it contains.

    Two element structs exist in this module, one for a basic bucket element,
    and one for a bucket element which contains a value in addition to a key.

    Usage:
        See ocean.util.container.map.model.BucketSet,
        ocean.util.container.map.HashMap & ocean.util.container.map.HashSet

*******************************************************************************/

module ocean.util.container.map.model.Bucket;



/*******************************************************************************

    Template to be mixed in to a bucket element. Contains the shared core
    members of a bucket element.

    This template mixin is used so that we can use structs for the bucket
    elements rather than classes, thus avoiding the memory overhead of class
    instances. In the case of bucket elements, which could exist in quantities
    of many thousands, this is significant.

    Using structs instead of classes means that we can't use an interface or
    base class, and the Bucket struct (below) has to simply assume that the
    Element struct has certain members. As it's purely internal, we can live
    with this.

    Template params:
        K = Key type

*******************************************************************************/

// TODO: do we need to handle non-hash keys?

private template BucketElementCore ( K = hash_t )
{
    /**********************************************************************

        Object pool index

     **********************************************************************/

    public uint object_pool_index;

    /**********************************************************************

        Key = bucket element key type

     **************************************************************************/

    public alias K Key;

    /**************************************************************************

        Element key

     **********************************************************************/

    public Key key;

    /**********************************************************************

        Next and previous element. For the first/last bucket element
        next/prev is null, respectively.

     **********************************************************************/

    private typeof (this) next = null,
                          prev = null;

    /**********************************************************************

        Bucket which this instance is an element in

     **********************************************************************/

    debug (HostingArrayMapBucket) private Bucket* bucket = null;

    /**********************************************************************

        Resets next/prev.

     **********************************************************************/

    private void reset ( )
    {
        this.next = this.prev = null;
    }
}



/*******************************************************************************

    Struct template for a bucket element.

    Template params:
        K = key type

*******************************************************************************/

package struct BucketElement ( K = hash_t )
{
    mixin BucketElementCore!(K);
}



/*******************************************************************************

    Struct template for a bucket element with a value. The element's value is
    stored as a simple array of ubytes, either dynamic or static, depending on
    the value of the template parameter V.

    Template params:
        V = value length in bytes, 0 specifies a variable value length
        K = key type

*******************************************************************************/

package struct ValueBucketElement ( size_t V, K = hash_t )
{
    mixin BucketElementCore!(K);

    /**************************************************************************

        Val = bucket element value type, if any

     **************************************************************************/

    private const val_length = V;

    /**********************************************************************

        Element value

     **********************************************************************/

    static if (val_length)
    {
        public alias ubyte[val_length] Val;
    }
    else
    {
        public alias ubyte[] Val;
    }

    public Val val;
}



/*******************************************************************************

    Template params:
        E = type of element stored in bucket (should be one of the bucket
            element structs defined above)

*******************************************************************************/

public struct Bucket ( E )
{
    /**************************************************************************

        Bucket element type

     **************************************************************************/

    public alias E Element;


    /**************************************************************************

        Number of elements in this bucket

     **************************************************************************/

    private size_t length_ = 0;


    /**************************************************************************

        First bucket element

     **************************************************************************/

    private Element* first = null;


    /**************************************************************************

        Invariant

     **************************************************************************/

    invariant ( )
    {
        if (this.length_)
        {
            assert (this.first, "have no first element but length is positive");
        }
        else
        {
            assert (!this.first, "have first element but length is 0");
        }
    }


    /**************************************************************************

        Length getter.

        Returns:
            number of elements in this bucket

     **************************************************************************/

    public size_t length ( )
    {
        return this.length_;
    }


    /**************************************************************************

        Looks up the element whose key equals key.

        Params:
            key = element key

        Returns:
            the element whose key equals key or null if not found.

     **************************************************************************/

    public Element* find ( Element.Key key )
    out (element)
    {
        debug (HostingArrayMapBucket) if (element)
        {
            assert (element.bucket, "bucket not set in found element");
            assert (element.bucket == this, "element found is not from this bucket");
        }
    }
    body
    {
        Element* result = null; 

        switch (this.length_)
        {
            case 1:
                if (this.first.key == key)
                {
                    result = this.first;
                }

            case 0:
                break;

            default:
                for (Element* element = this.first; element; element = element.next)
                {
                    if (element.key == key)
                    {
                        result = element;
                        break;
                    }
                }
        }

        return result;
    }


    /**************************************************************************

        'foreach' iteration over elements in this bucket.

        Asserts that the length of the bucket is not modified while iterating.

     **************************************************************************/

    public int opApply ( int delegate ( ref Element element ) dg )
    {
        int result = 0;

        size_t n = 0;

        for (Element* element = this.first;
                      element && !result;
                      element = element.next)
        {
            assert (n++ < this.length_);

            result = dg(*element);
        }

        assert (n == this.length_ || result);

        return result;
    }


    /**************************************************************************

        Adds a bucket element with key as key.

        The element is inserted as the first bucket element.

        Params:
            key = key for the new element
            new_element = expression returning a new element, evaluated exactly
                once, if the key to be added does not already exist in the
                bucket

        Returns:
            pointer to inserted element

     **************************************************************************/

    public Element* add ( Element.Key key, lazy Element* new_element )
    {
        Bucket.Element* element = this.find(key);

        if (!element)
        {
            (element = this.add(new_element)).key = key;
        }

        return element;
    }


    /**************************************************************************

        Adds a bucket element with key as key. An out parameter reports whether
        the added element was newly added to the bucket, or whether it replaced
        an existing element.

        The element is inserted as the first bucket element.

        Params:
            key = key for the new element
            new_element = expression returning a new element, evaluated exactly
                once, if the key to be added does not already exist in the
                bucket
            existed = flag set to true if an element already existed for the
                specified key

        Returns:
            pointer to inserted element

     **************************************************************************/

    public Element* add ( Element.Key key, lazy Element* new_element,
        out bool existed )
    {
        Bucket.Element* element = this.find(key);

        if (element)
        {
            existed = true;
        }
        else
        {
            (element = this.add(new_element)).key = key;
        }

        return element;
    }


    /**************************************************************************

        Removes element from this bucket. element must in fact be in this
        bucket, otherwise the map may get corrupted.

        The removed element must be recycled by the owner of the bucket.

        Element may be null; in this case nothing is done. This is to make
        remove/find call chains convenient:

        ---
            remove(find(key))
        ---

        Params:
            element = element to remove (or null to do nothing)

        Returns:
            element

     **************************************************************************/

    public Element* remove ( Element* element )
    in
    {
        if (element)
        {
            assert (this.length_, "attempted to remove from empty bucket");

            debug (HostingArrayMapBucket)
            {
                assert (element.bucket, "bucket not set in element to remove");
                assert (element.bucket == this, "element to remove is not from this bucket");
            }
        }
    }
    out (element)
    {
        debug (HostingArrayMapBucket) if (element) element.bucket = null;
    }
    body
    {
        if (element)
        {
            if (element.prev)
            {
                element.prev.next = element.next;
            }

            if (element.next)
            {
                element.next.prev = element.prev;
            }

            if (--this.length_)
            {
                if (!element.prev)
                {
                    assert (element is this.first);

                    this.first = element.next;
                }
            }
            else
            {
                assert (element is this.first);

                this.first = null;
            }
        }

        return element;
    }


    /**************************************************************************

        Removes all elements from the bucket. The bucket elements themselves
        must be recycled by the owner of the bucket.

        Note that it is also safe to clear a bucket by simply assigning
        Bucket.init to it.

     **************************************************************************/

    public void clear ( )
    {
        this.length_ = 0;
        this.first = null;
    }


    /**************************************************************************

        Adds an element to the bucket.

        The element is inserted as the first bucket element.

        Params:
            element = element to add

        Returns:
            pointer to inserted element

     **************************************************************************/

    private Element* add ( Element* element )
    in
    {
        debug (HostingArrayMapBucket) element.bucket = this;
    }
    body
    {
        Element* first_prev = this.first;

        with (*(this.first = element))
        {
            next = first_prev;
            prev = null;
        }

        if (this.length_++)
        {
            first_prev.prev = this.first;
        }

        return this.first;
    }
}

