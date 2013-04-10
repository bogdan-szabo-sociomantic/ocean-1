/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        11/04/2012: Initial release

    authors:        David Eckardt, Gavin Norman

    Template for a class implementing a mapping from a user-specified type to a
    user-specified type.

    The interface of the class has been kept deliberately simple, purely
    handling the management of the mapping. The handling of the mapping values
    is left entirely up to the user -- all methods simply return a pointer to
    the mapping value which the user can do what they like with. (This is an
    intentional design decision, in order to reduce the complexity of the
    template.)

    The HashMap is designed as a replacement for ocean.core.ArrayMap. It has
    several advantages:
        1. Memory safety. As the ArrayMap's buckets are implemented as dynamic
           arrays, each bucket will theoretically grow continually in size over
           extended periods of use. Even when clear()ed, the buffers allocated
           for the buckets will not reduce in size. The HashMap, on the other
           hand, uses a pool of elements, meaning that the memory allocated for
           each bucket is truly variable.
        2. Code simplicity via removing optional advanced features such as
           thread safety and value array copying.
        3. Extensibility. Functionality is split into several modules, including
           a base class for easier reuse of components.

    Usage example with various types stored in mapping:

    ---

        private import ocean.util.container.map.HashMap;

        // Mapping from hash_t -> int
        auto map = new HashMap!(int);

        hash_t hash = 232323;

        // Add a mapping
        *(map.put(hash)) = 12;

        // Check if a mapping exists (null if not found)
        auto exists = hash in map;

        // Remove a mapping
        map.remove(hash);

        // Clear the map
        map.clear();

        // Mapping from hash_t -> char[]
        auto map2 = new HashMap!(char[]);

        // Add a mapping
        map2.put(hash).copy("hello");

        // Mapping from hash_t -> struct
        struct MyStruct
        {
            int x;
            float y;
        }

        auto map3 = new HashMap!(MyStruct);

        // Add a mapping
        *(map3.put(hash)) = MyStruct(12, 23.23);

    ---

*******************************************************************************/

module ocean.util.container.map.Map;



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
    private import ocean.io.Stdout;
}

/*******************************************************************************

    StandardKeyHashingMap class template. Manages a mapping from K to V, using
    a standard way of hash calculation:

    - If K is a primitive type (integer, floating point, character), the hash
      value is calculated from the raw key data using the FNV1a hash function.
      That means, if the keys are dynamic arrays, including strings, the array
      content is used as the key, not the array instance (ptr/length).
    - If K is a dynamic or static array of a  primitive type, the hash value is
      calculated from the raw data of the key array content using the FNV1a hash
      function.
    - If K is a class, struct or union, it is expected to implement toHash(),
      which will be used.
    - Other key types (arrays of non-primitive types, classes/structs/unions
      which do not implement toHash(), pointers, function references, delegates,
      associative arrays) are not supported by this class template.

    Template params:
        V = type to store in values of map
        K = type to store in keys of map

*******************************************************************************/

public class StandardKeyHashingMap ( V, K ) : Map!(V, K)
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

    StandardKeyHashingMap class template. Manages a mapping from K to ubyte[V],
    using a standard way of hash calculation:

    - If K is a primitive type (integer, floating point, character), the hash
      value is calculated from the raw key data using the FNV1a hash function.
    - If K is a dynamic or static array of a primitive type, the hash value is
      calculated from the raw data of the key array content using the FNV1a hash
      function.
    - If K is a class, struct or union, it is expected to implement toHash(),
      which will be used.
    - Other key types (arrays of non-primitive types, classes/structs/unions
      which do not implement toHash(), pointers, function references, delegates,
      associative arrays) are not supported by this class template.

    Template params:
        V = byte length of the values to store in the map, must be at least 1
        K = type to store in keys of map

*******************************************************************************/

public class StandardKeyHashingMap ( size_t V, K ) : Map!(V, K)
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

    Map class template to store values of a certain type. Manages a mapping
    from K to V, leaving the hash function implementation to the subclass
    (abstract BucketSet.toHash()).

    Template params:
        V = type to store in values of map
        K = type to store in keys of map

*******************************************************************************/

public abstract class Map ( V, K ) : BucketSet!(V.sizeof, K)
{
    /***************************************************************************

        MapIterator template instance.

    ***************************************************************************/

    alias .MapIterator!(V, K) MapIterator;

    /***************************************************************************

        If V is a static array, opIndex() und opIndexAssign() need to return a
        dynamic array slicing the value.

        V.init redefinition to work around DMD bug 7752: If V is a static array,
        then V.init is of the array base type.

    ***************************************************************************/

    static if (is (V Base : Base[]) && !is (V == Base[]))
    {
        static if (is (typeof (V.init) == V))
        {
            pragma (msg, "DMD bug 7752 is fixed, please remove the workaround "
                         "in ", __FILE__, ":", __LINE__.stringof);
        }

        const V_is_static_array = true;

        alias Base[] VReturn;

        const Base[V.length] v_init = Base.init;
    }
    else
    {
        const V_is_static_array = false;

        alias V VReturn;

        const v_init = V.init;
    }

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

    protected this ( size_t n, float load_factor = 0.75 )
    {
        super(n, load_factor);
    }

    /***************************************************************************

        In operator. Looks up the value mapped by key.

        Note: If it is sure that a value for key is in the map, in other words,
        it would be a bug if it isn't, get() below is the preferred method to
        use because it guarantees never to return a null pointer.

        Params:
            key = key to look up the value for

        Returns:
            pointer to the value mapped by key, if it exists. null otherwise.

    ***************************************************************************/

    public V* opIn_r ( K key )
    {
        auto element = this.get_(key);

        return element? cast(V*)element.val[0 .. V.sizeof].ptr : null;
    }

    /***************************************************************************

        Obtains a reference to the value mapped by key. A value for key is
        expected to exist in the map.

        Note: Use this method if it is sure that a value for key is in the map,
        in other words, it would be a bug if it isn't. To look up a mapping that
        may or may not exist, use the 'in' operator (opIn_r() above).

        Params:
            key = key to obtain the value for

        Returns:
            pointer to the value mapped by key.

        Out:
            The returned pointer is never null, key must be in the map.

    ***************************************************************************/

    public V* get ( K key )
    out (val)
    {
        assert (val !is null);
    }
    body
    {
        return cast(V*)this.get_(key, true).val[0 .. V.sizeof].ptr;
    }

    /***************************************************************************

        Obtains a the value mapped by key. A value for key is expected to exist
        in the map.

        Note: Use this method if it is sure that a value for key is in the map,
        in other words, it would be a bug if it isn't. To look up a mapping that
        may or may not exist, use the 'in' operator (opIn_r() above).

        Params:
            key = key to obtain the value for

        Returns:
            the value mapped by key.

    ***************************************************************************/

    public VReturn opIndex ( K key )
    {
        return *this.get(key);
    }

    /***************************************************************************

        Looks up the mapping for key or adds one if not found.

        Note that, if a new mapping was added (added outputs true), the returned
        pointer may reference a previously removed value. If this is not
        desired, set the value referenced to by the pointer returned by remove()
        to the desired initial value (e.g. V.init).

        Params:
            key   = key to look up or add mapping for
            added = set to true if the mapping did not exist but was added

        Returns:
            the value mapped to by the specified key. If added outputs true, the
            value is unspecified and the caller should set the value as desired.

        Out:
            The returned pointer is never null.

    ***************************************************************************/

    public V* put ( K key, out bool added )
    out (val)
    {
        assert (val !is null);
    }
    body
    {
        return cast(V*)this.put_(key, added).val[0 .. V.sizeof].ptr;
    }

    /***************************************************************************

        Adds or updates a mapping from the specified key.

        Note that the returned slice may reference a previously removed value.
        If this is not desired, set the value referenced to by the pointer
        returned by remove() to the desired initial value (e.g. V.init).

        Params:
            key = key to add/update mapping for

        Returns:
            pointer to the value mapped to by the specified key. The caller
            should set the value as desired.

        Out:
            The returned pointer is never null.

    ***************************************************************************/

    public V* put ( K key )
    out (val)
    {
        assert (val !is null);
    }
    body
    {
        return cast(V*)this.put_(key).val[0 .. V.sizeof].ptr;
    }

    /***************************************************************************

        Adds or updates a mapping from the specified key.

        Params:
            key = key to add/update mapping for
            val = value to map to

        Returns:
            val

    ***************************************************************************/

    public VReturn opIndexAssign ( V val, K key )
    {
        static if (V_is_static_array)
        {
            return (*this.put(key))[] = val[];
        }
        else
        {
            return *this.put(key) = val;
        }
    }

    /***************************************************************************

        Removes the mapping for the specified key.

        Note that, if references to GC-allocated objects (objects or dynamic
        arrays), it is a good idea to set the value referenced to by the
        returned pointer to null to avoid these objects from being prevented
        from garbage collection. In general pointers should be set to null for
        the same reason and to avoid dangling pointers.

        Params:
            key = key to remove mapping for

        Returns:
            a pointer to the value of the remove element, if found, or null
            otherwise. It is guaranteed that the referenced value will
            remain unchanged until the next call to put(), which may reuse it,
            or to clear().

    ***************************************************************************/

    public V* remove ( K key )
    {
        return cast(V*)this.remove_(key).val[0 .. V.sizeof].ptr;
    }

    /***************************************************************************

        'foreach' iteration over key/value pairs currently in the map.

        Note: If V or K (or both) are a static array, the corresponding
        iteration variable is a dynamic array of the same base type and slices
        the key or value.
        (The reason is that static array 'ref' parameters are forbidden in D.)

    ***************************************************************************/

    public int opApply ( MapIterator.Dg dg )
    {
        return super.opApply((ref Bucket.Element element)
                             {return MapIterator.iterate(dg, element);});
    }

    /***************************************************************************

        Removes all elements from all buckets and sets the element values to
        val_init.

        Params:
            val_init = initialisation value

        Returns:
            this instance

    ***************************************************************************/

    public typeof(this) clearErase ( V val_init = v_init )
    {
        this.clear_((cast (void*) &val_init)[0 .. val_init.sizeof]);

        return this;
    }
}

/*******************************************************************************

    HashMap class template to store the raw data of values of a certain size.
    Manages a mapping from K to ubyte[V], leaving the hash function implementation
    to the subclass (abstract BucketSet.toHash()).
    Since static arrays cannot be returned, the access methods return a void[]
    slice to the value.

    Template params:
        V = byte length of the values to store in the map, must be at least 1
        K = type to store in keys of map

*******************************************************************************/

public abstract class Map ( size_t V, K ) : BucketSet!(V, K)
{
    /***************************************************************************

        V check.

    ***************************************************************************/

    static assert (V, "Please use Set for zero-length values.");

    /***************************************************************************

        MapIterator template instance.

    ***************************************************************************/

    alias .MapIterator!(Bucket.Element.Val, K) MapIterator;

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

    protected this ( size_t n, float load_factor = 0.75 )
    {
        super(n, load_factor);
    }

    /***************************************************************************

        In operator. Looks up the value mapped by key.

        Note: If it is sure that a value for key is in the map, in other words,
        it would be a bug if it isn't, get() below is the preferred method to
        use because it guarantees never to return a null pointer.

        Params:
            key = key to look up the value for

        Returns:
            an array slicing the value buffer mapped by key, if it exists, or
            null otherwise.

        Out:
            The returned array is either null or has the length V.

     ***************************************************************************/

    public void[] opIn_r ( K key )
    out (val)
    {
        if (val)
        {
            assert (val.length == V);
        }
    }
    body
    {
        return this.get_(key).val;
    }

    /***************************************************************************

        Obtains a reference to the value mapped by key. A value for key is
        expected to exist in the map.

        Note: Use this method if it is sure that a value for key is in the map,
        in other words, it would be a bug if it isn't. To look up a mapping that
        may or may not exist, use the 'in' operator (opIn_r() above).

        Params:
            key = key to obtain the value for

        Returns:
            pointer to the value mapped by key.

        Out:
            The returned array is never null and has the length V.

    ***************************************************************************/

    public void[] get ( K key )
    out (val)
    {
        assert (val.length == V);
    }
    body
    {
        return this.get_(key, true).val;
    }

    /***************************************************************************

        Obtains a the value mapped by key. A value for key is expected to exist
        in the map.

        Note: Use this method if it is sure that a value for key is in the map,
        in other words, it would be a bug if it isn't. To look up a mapping that
        may or may not exist, use the 'in' operator (opIn_r() above).

        Params:
            key = key to obtain the value for

        Returns:
            the value mapped by key.

    ***************************************************************************/

    alias get opIndex;

    /***************************************************************************

        Looks up the mapping for key or adds one if not found.

        Note that, if a new mapping was added (added outputs true), the returned
        slice may reference a previously removed value. If this is not desired,
        copy the desired initial value into the sliced buffer returned by
        remove().

        Params:
            key   = key to add/update mapping for
            added = set to true if the record did not exist but was added

        Returns:
            an array slicing the value buffer mapped to by the specified key. If
            added outputs true, the value is unspecified and the caller should
            set the value as desired.

        Out:
            The returned array is never null and has the length V.

     ***************************************************************************/

    public void[] put ( K key, out bool added )
    out (val)
    {
        assert (val.length == V);
    }
    body
    {
        return this.put_(key, added).val;
    }

    /***************************************************************************

        Adds or updates a mapping from the specified key. Note that, if a new
        mapping was added (added outputs true), the returned slice may reference
        a previously removed value. If this is not desired, copy the desired
        initial value into the sliced buffer returned by remove().

        Params:
            key   = key to add/update mapping for

        Returns:
            an array slicing the value buffer mapped to by the specified key.
            The caller should set the value as desired.

        Out:
            The returned array is never null and has the length V.

     **************************************************************************/

    public void[] put ( K key )
    out (val)
    {
        assert (val.length == V);
    }
    body
    {
        bool added;

        return this.put_(key, added).val;
    }

    /***************************************************************************

        Adds or updates a mapping from key to val, copying the content of val
        into the map.

        Params:
            key = key to add/update mapping for
            val = value to map to

        Returns:
            val

        In:
            val.length must be V.

    ***************************************************************************/

    public void[] opIndexAssign ( void[] val, K key )
    in
    {
        assert (val.length == V, "expected a value of length " ~ V.stringof);
    }
    body
    {
        bool added;

        this.put_(key, added).val[] = val[];

        return val;
    }

    /***************************************************************************

        Removes the mapping for the specified key.

        Params:
            key = key to remove mapping for

        Returns:
            an array slicing the value buffer of the removed element, if found,
            or null otherwise. It is guaranteed that the referenced value will
            remain unchanged until the next call to put(), which may reuse it,
            or to clear().

        Out:
            The returned array is either null or has the length V.

    ***************************************************************************/

    public void[] remove ( K key )
    out (val)
    {
        if (val)
        {
            assert (val.length == V);
        }
    }
    body
    {
        return this.remove_(key).val;
    }

    /***************************************************************************

        'foreach' iteration over keys or keys and the correspondign values
        currently in the map.

        Notes:
        - During iteration it is forbidden to call clear() or redistribute() or
          remove map elements. If elements are added, the iteration may or may
          not include these elements.
        - If V or K (or both) are a static array, the corresponding iteration
          variable is a dynamic array of the same base type and slices the key
          or value of the element in the map. (The reason is that static array
          'ref' parameters are forbidden in D.)
          In this case it is not recommended to do a 'ref' iteration over key or
          value. To modify a value during iteration, copy the new value contents
          into the array content. Example:
          ---
              // Using the StandardKeyHashingMap subclass because Map is an
              // abstract class (inherits abstract toHash()).

              alias int[7]  ValueType;
              alias char[4] KeyType;

              auto map = new StandardKeyHashingMap!(ValueType, KeyType);

              // Side note: Use the '[x, y, ...]' array literal only with
              // constants or in code locations that are not executed repeatedly
              // because for variables it invokes a buffer allocation, leading
              // to a memory leak condition when it is done very often.

              const int[7] new_value = [2, 3, 5, 7, 11, 13, 17];

              foreach (key, val; map)
              {
                  // - key is of type char[] and slices the key of the current
                  //   map element so key.length is guaranteed to be 4,
                  // - val is of type int[] and slices the value of the current
                  //   map element so val.length is guaranteed to be 7.

                  // Modify the value by copying into the static array
                  // referenced by val.

                  val[] = new_value[];

                  // It is also possible to modify single val array elements.

                  val[2] += val[5] * 4711;
              }
          ---
          DO NOT do that with the key or modify it in-place in any way!

        - It is not recommended to specify 'ref' for the key iteration variable.
          If you do it anyway, DO NOT modify the key in-place!

    ***************************************************************************/

    public int opApply ( MapIterator.Dg dg )
    {
        return super.opApply((ref Bucket.Element element)
                             {return MapIterator.iterate(dg, element);});
    }


    /***************************************************************************

        Removes all elements from all buckets and sets the element values to
        val_init.

        Params:
            val_init = initialisation value

        Returns:
            this instance

     **************************************************************************/

    public typeof(this) clear ( void[] val_init = null )
    in
    {
        assert (!val_init.length || val_init.length == V,
                "val_init.length expected to be 0 or " ~ V);
    }
    body
    {
        this.clear_(val_init);

        return this;
    }
}
