/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        11/04/2012: Initial release

    authors:        David Eckardt, Gavin Norman

    Template for a class implementing a set of hashed keys. The set is built on
    top of an efficient bucket algorithm, allowing for fast look up of keys in
    the set.

    Usage example:

    ---

        private import ocean.util.container.map.HashSet;

        // A set of hash_t's
        auto set = new HashSet;

        hash_t hash = 232323;

        // Add a hash
        set.put(hash));

        // Check if a hash exists in the set (null if not found)
        auto exists = hash in set;

        // Remove a hash from the set
        set.remove(hash);

        // Clear the set
        set.clear();

    ---

*******************************************************************************/

module ocean.util.container.map.Set;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.container.map.model.BucketSet;

private import ocean.util.container.map.model.Bucket;

private import ocean.util.container.map.model.MapIterator;

private import ocean.util.container.map.model.StandardHash;

debug private import ocean.io.Stdout;

/*******************************************************************************

    Debug switch for verbose unittest output (uncomment if desired)

*******************************************************************************/

//debug = UnittestVerbose;

debug ( UnittestVerbose )
{
    private import tango.io.Stdout;
}

/*******************************************************************************

    StandardKeyHashingSet class template. Manages a set of K's with fast lookup
    using a standard way of hash calculation:
    
    - If K is a primitive type (integer, floating point, character), the hash
      value is calculated from the raw key data using the FNV1a hash function.
    - If K is a dynamic or static array of a  primitive type, the hash value is
      calculated from the raw data of the key array content using the FNV1a hash
      function.
    - If K is a class, struct or union, it is expected to implement toHash(),
      which will be used.
    - Other key types (arrays of non-primitive types, classes/structs/unions
      which do not implement toHash(), pointers, function references, delegates,
      associative arrays) are not supported by this class template.

*******************************************************************************/

public class StandardHashingSet ( K ) : Set!(K)
{
    /***************************************************************************

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
    
    ***************************************************************************/
    
    public this ( size_t n, float load_factor = 0.75 )
    {
        super(n, load_factor);
    }
    
    /***************************************************************************

        Mixin of the toHash() method which is declared abstract in BucketSet.
    
    ***************************************************************************/
    
    mixin StandardHash.toHash!(K);
}


/*******************************************************************************

    Set class. Manages a set of K's with fast lookup. The toHash() method must
    be implemented.

*******************************************************************************/

public abstract class Set ( K ) : BucketSet!(0, K)
{
    private alias .MapIterator!(void, K) SetIterator;
    
    /***************************************************************************

        Constructor, sets the number of buckets to n * load_factor

        Params:
            n = expected number of elements
            load_factor = load factor

    ***************************************************************************/

    public this ( size_t n, float load_factor = 0.75 )
    {
        super(n, load_factor);
    }


    /***************************************************************************

        Looks up key in the set.

        Params:
            key = key to look up

        Returns:
            true if found or false if not.

    ***************************************************************************/

    public bool opIn_r ( K key )
    {
        return this.get_(key) !is null;
    }


    /***************************************************************************

        Puts key into the set.

        Params:
            key = key to put into set

        Returns:
            true if the key was already on the set, false otherwise

    ***************************************************************************/

    public bool put ( K key )
    {
        bool added;

        this.put_(key, added);

        return !added;
    }


    /***************************************************************************

        Removes key from the set.

        Params:
            key = key to remove from set

        Returns:
            true if the key was in the set, false otherwise

    ***************************************************************************/

    public bool remove ( K key )
    {
        return this.remove_(key) !is null;
    }
    
    /***************************************************************************

        'foreach' iteration over the keys in the map.
        
        Notes:
        - During iteration it is forbidden to call clear() or redistribute() or
          remove map elements. If elements are added, the iteration may or may
          not include these elements.
        - If K is a static array, the iteration variable is a dynamic array of
          the same base type and slices the key of the element in the map.
          (The reason is that static array 'ref' parameters are forbidden in D.)
          In this case DO NOT modify the key in any way!
        - It is not recommended to do a 'ref' iteration over the keys. If you do
          it anyway, DO NOT modify the key in-place!

    ***************************************************************************/

    public int opApply ( SetIterator.Dg dg )
    {
        return super.opApply((ref Bucket.Element element)
                             {return SetIterator.iterate(dg, element);});
    }
}

