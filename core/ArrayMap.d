/*******************************************************************************

    Hashtable with Multi-Thread Support

    Copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    Version:        May 2010: Initial release
                    
    Authors:        Thomas Nicolai, David Eckardt, Mathias Baumann
    
 ******************************************************************************/

module ocean.core.ArrayMap;

/*******************************************************************************

    Imports
    
*******************************************************************************/

private     import      ocean.core.Exception: ArrayMapException, assertEx;

private     import      ocean.io.digest.Fnv1;

private     import      tango.io.model.IConduit:  InputStream,   OutputStream;

private     import      tango.core.Exception: IOException;

private     import      tango.stdc.posix.pthread: pthread_rwlock_t,
                                                  pthread_rwlockattr_t,
                                                  pthread_rwlock_init,
                                                  pthread_rwlock_destroy,
                                                  pthread_rwlock_rdlock,
                                                  pthread_rwlock_wrlock,
                                                  pthread_rwlock_unlock;

/*******************************************************************************

    Mutex support for multithreading
    
    Enable  = enable multi thread support
    Disable = disable multi thread support (faster)

 ******************************************************************************/

struct Mutex
{
        const bool Enable  = true;
        const bool Disable = false;
}

/*******************************************************************************

    Key/value bag for ArrayMapKV implementation

 ******************************************************************************/

private struct KeyValueElement ( K, V )
{
        K key;
        V value;
}

/*******************************************************************************  

    Hashmap with consistent hashing and without key iteration.
    
    Consistent hashing provides a performant way to add or remove array 
    elements without significantly change the mapping of keys to buckets. By 
    using consistent hashing, only k/n keys need to be remapped on average: 
    k is the number of keys and n is the number of buckets. The performance 
    depends on the number of n stored entries and the resulting load factor. 
    The load factor is diretly influenced by n and s, its bucket size.
    
    Multithread support
    
    By using the MutexedArrayMap class template (or setting the respective
    ArrayMap template parameter) the array map can be used by multiple threads
    at the same time. Be aware that this influcences the overall performance.
    
    Load factor

    The load factor specifies the ratio between the number of buckets and 
    the number of stored elements. The smaller the load factor the better the 
    performance but it should never be below zero. The optimal load factor is
    said to be about 0.75.
    
    Performance

    The hashmap implementation offers a good overall performance. An array 
    hashmap with 1.000.000 uint[uint] elements and 20.000 buckets shows the 
    following performance metrics:
    
    ~ 20 mio inserts/sec
    ~ 40 mio lookups/sec
    
    Limitations

    The hashmap does not support key, value iteration. Only value iteration
    is supported.
    
    Data dumping and restoring

    The internal data of an ArrayMap instance can be dumped to serialized data
    which can be stored and later re-read to resume the array map instance.
    
    Template Params:
        V = type of value stored in array map
        K = type of key stored in array map (must be of simple type)
        M = enable/disable mutex
    
    Usage example without thread support
    ---
    scope array = new ArrayMap!(char[])(10_000);
    ---
    
    Add & get an element
    ---
    array[0] = "value";
    
    char[] value = array[0];
    ---
    
    Free the memory allocated
    ---
    array.free();
    ---
    
    Usage example with thread support enabled
    ---
    scope array = new ArrayMap!(char[], hash_t, Mutex.Enable) ;
    ---
    
    FIXME: Return values of the pthread_rwlock_* POSIX API functions are
    currently ignored although they might indicate errors. However, according to
    the specification of these functions,
    
        http://www.opengroup.org/onlinepubs/000095399/basedefs/pthread.h.html
    
    , they would indicate errors only in situations where the calling program
    behaves erroneously (attempting to destroy a currently locked lock or wrong
    locking/unlocking order, for example).
    
 ******************************************************************************/

class ArrayMap ( V, K = hash_t, bool M = Mutex.Disable )
{
    /***************************************************************************
    
        Aliases for key & value types, so they can be accessed externally.
        
     **************************************************************************/

    public alias V ValueType;
    public alias K KeyType;

    /***************************************************************************
    
        VisArray flag to indicate whether the value type V is an array
        
     **************************************************************************/

    static if (is (V W == W[]))
    {
        const VisArray = true;
    }
    else
    {
        const VisArray = false;
    }
    
    /***************************************************************************
        
        Hashmap bucket key element
        
        key = key of array element
        pos = position of value in the value map
        
     **************************************************************************/
    
    private struct KeyElement
    {
            K  key;
            size_t pos;
    }

    /***************************************************************************
        
        Hashmap bucket
        
        length   = number of key elemens in bucket
        elements = list of key elements
        
     **************************************************************************/
    
    private struct Bucket
    {
            size_t length = 0;
            KeyElement[] elements;
    }
    
    
    static if (M)
    {
        /***********************************************************************
        
            Read/write locks: Each element corresponds to the element of k_map
            (bucket) with the same index.
            
         **********************************************************************/

        private         pthread_rwlock_t[]              rwlocks;
        
        /***********************************************************************
        
            Consistency check between k_map length (number of buckets) and
            number of read/write locks 
            
         **********************************************************************/

        invariant ( )
        {
            assert (this.k_map.length == this.rwlocks.length, "rwlocks/k_map length mismatch");
        }
    }

    /***************************************************************************
        
        Hashtable based key map
        
        Hashmap only stores the key indicies as well as the position of the value
        inside the value map.
        
     **************************************************************************/
    
    final               Bucket[]                        k_map;
   
    /***************************************************************************
    
        Holds a value and a key
    
    ***************************************************************************/
    
    struct KeyVal
    {
        V value;
        K key;
        
        static KeyVal opCall (V v,K b) 
        {
            KeyVal bv = { v, b};
            
            return bv;
        }
    }
    
    /***************************************************************************
    
        KeyValue map
    
    ***************************************************************************/
    
    final               KeyVal[]                             v_map;
    
    /***************************************************************************
        
        Number of buckets 
        
        Number of buckets is based on size of hashmap and the load factor. Usually
        a loadfactor around 0.75 is perfect.
        
     **************************************************************************/
    
    final               size_t                            buckets_length;
    
    /***************************************************************************
        
        Number of hashmap bucket elements allocated at once
        
        Allocating more than one element at a time improves performance a lot.
        Nevertheless, allocating to much at once kills performance.
        
     **************************************************************************/
    
    final               size_t                          default_alloc_size = 1;

    /***************************************************************************
        
        Startup size of array map
        
     **************************************************************************/
    
    final               size_t                          default_size;
    
    /***************************************************************************
        
        Load factor
        
     **************************************************************************/
    
    final               float                           load_factor;

    /***************************************************************************
        
        Number of array elements stored
        
     **************************************************************************/
    
    final               size_t                            len;
    
    /***************************************************************************
        
        Sets number of buckets used

        Usage example
        ---
        scope array = new ArrayMap (1_000_000, 0.75);
        ---
        
        TODO find way to avoid pre-allocation as this leads to a pretty bad
             performance while dealing with a lot of small array maps
        
        Params:
            default_size = estimated number of elements to be stored
            load_factor  = Determines the ratio of default_size to the number of
                           internal buckets. For example, 0.5 sets the number of
                           buckets to the double of default_size; for 2 the
                           number of buckets is the half of default_size.
                           load_factor must be greater than 0.
                           
     **************************************************************************/
    
    public this ( size_t default_size = 10_000, float load_factor = 0.75 )
    {
        assertEx!(ArrayMapException)(default_size, "zero default size");
        assertEx!(ArrayMapException)(0 <= load_factor, "load factor <= 0");
        
        this.default_size = default_size;
        this.load_factor  = load_factor;
        
        this.buckets_length = cast (typeof (this.buckets_length)) (default_size / load_factor);
                
        static if (M)
        {
            this.rwlocks = new pthread_rwlock_t[this.buckets_length];
        }
        
        this.k_map = new Bucket[this.buckets_length];
        
        this.v_map = new KeyVal[this.default_size];
        
        foreach (i, ref bucket; this.k_map) 
        {
            bucket.elements = new KeyElement[this.default_alloc_size];
            
            static if (M)
            {
                pthread_rwlock_init(this.rwlocks.ptr + i, null);
            }
        }
    }
      
    /***************************************************************************
    
        Constructor
    
        Loads the content previously produced by dump() from input as serial
        data.
        
        Loading the key map will only succeed if the value type is a value data
        type. (Note: Structs are value data types.)
        
        If the value type is an array, the content of all value arrays is
        restored.
        Loading the value map will only succeed if the value type is a value
        data type or an array (not an associative array). (Note: Structs are
        value data types.)
        
        It is highly recommended to use a buffered input stream; a buffer size
        of about 64 kB improves I/O performance a lot as trials have shown.
        However, if using the BufferedInput class from
        tango.io.stream.Buffered, make sure its load() method is patched to
        return exactly as much data as requested. Ticket 1933 on the Tango web
        site, currently available at
        
            http://dsource.org/projects/tango/ticket/1933
         
        , shows a patch code example.
    
        The imported data should have been produced by the same program in the
        same environment, using the same class template instance. Data
        interchangeability cannot be relied upon because data alignment, byte
        order, native data word width (which determines the size of size_t) and
        binary floating point number format must be the same when loading as it
        was when dump()ing. 
        
        Params:
            input = input stream to read data from
         
        Throws:
            IOException on error
         
     **************************************************************************/
     
    public this ( InputStream input )
    {
        this.loadParams(input);
        
        this.loadKmap(input);
        
        assertEx!(ArrayMapException)(this.k_map.length == this.buckets_length, "invalid key map length");
        
        this.loadVmap(input);
        
        assertEx!(ArrayMapException)(this.v_map.length == this.default_size, "invalid value map length");
        
        static if (M)
        {
            this.rwlocks = new pthread_rwlock_t[this.buckets_length];
            
            for (size_t i = 0; i < this.rwlocks.length; i++)
            {
                pthread_rwlock_init(this.rwlocks.ptr + i, null);
            }
        }
    }
    
    /***************************************************************************
    
        Destructor; free memory to gc
            
     **************************************************************************/
    
    ~this () 
    {
        this.len = 0;
        
        foreach (i, ref bucket; this.k_map)
        {
            static if (M)
            {
                pthread_rwlock_destroy(this.rwlocks.ptr + i);
            }
            
            bucket.length = 0;
            
            delete bucket.elements;
        }
        
        static if (this.VisArray)
        {
            foreach (ref value; this.v_map)
            {
                delete value.value;
            }
        }
        
        delete this.v_map;
        
        delete this.k_map;
        
        static if (M)
        {
            delete this.rwlocks;
        }
    }

    /***************************************************************************
        
        Put element to array map
        
        If the key does not yet exists the element is added otherwise the value of
        the existing element matching the key is replaced by the new value.
        
        Params:
            key = array key
            value = array value
        
     **************************************************************************/
    
    public void put ( K key, V value )
    {
        size_t p = this.getPutIndex(key);
        
        static if (this.VisArray)
        {
            this.v_map[p].value.length = value.length;
        }
        
        this.v_map[p] = KeyVal(value,key);
    }

    /***************************************************************************
    
        Append element value to value of existing element in array map
        
        If the key does not yet exists the element is added otherwise the new
        value is appended to the value of the existing element matching the key.
        
        Params:
            key = array key
            value = array value
        
     **************************************************************************/
    
    static if (this.VisArray) public void putcat ( in K key, in V value )
    {
        size_t p = this.getPutIndex(key);
        
        this.v_map[p].value ~= value;
    }

    /***************************************************************************
        
        Returns value associated with key
        
        Params:
            key = array key
            
        Returns:
            value of array element
        
     **************************************************************************/
    
    public V get ( K key )
    {
        size_t v = this.findValueSync(key);
        
        if ( v !is size_t.max )
        {            
            return this.v_map[v].value;
        }
        
        throw new ArrayMapException(`key doesn't exist`);
    }

    /***************************************************************************
        
        Returns value associated with key
        
        Params:
            key = array key
            hash = hash value of key
            
        Returns:
            value of array element
        
     **************************************************************************/

    public V get ( K key, hash_t hash )
    {
        size_t v = this.findValueSync(key, hash % this.buckets_length);
        
        if ( v !is size_t.max )
        {            
            return this.v_map[v].value;
        }
        
        throw new ArrayMapException(`hash doesn't exist`);
    }

    /***************************************************************************
        
        Remove element from array map
        
        FIXME: Not reentrance/thread-safe with put() -- may cause wrong values.
        
        Params:
            key = key of element to remove
        
     **************************************************************************/
    
    public void remove ( K key )
    {
        hash_t h = (toHash(key) % this.buckets_length);

        this.writeLock(h, delegate void () {this.remove_(h, key);});
    }
    
    /***************************************************************************
        
        Clear array map
        
     **************************************************************************/
    
    public void clear ()
    {
        if ( this.len )
        {
            this.len = 0;
            
            foreach ( h, ref bucket; this.k_map ) 
                this.writeLock(h, {bucket.length = 0;});
        }
    }
    
    /***************************************************************************
        
        Copies content of this instance to dst
        
        Params:
            dst = destination ArrayMap instance
        
     **************************************************************************/
    
    public void copy ( ref typeof (this) dst )
    {
        if (this.len)
        {
            dst.len                = this.len;
            dst.buckets_length     = this.buckets_length;
            dst.default_size       = this.default_size; 
            dst.default_alloc_size = this.default_alloc_size;
            dst.load_factor        = this.load_factor;
            
            dst.k_map = this.k_map.dup;
            
            foreach (i, bucket; this.k_map)
            {
                dst.k_map[i].elements = bucket.elements.dup;
            }
            
            dst.v_map = this.v_map.dup;
            
            static if (this.VisArray)
            {
                foreach (i, keyval; this.v_map)
                {
                    dst.v_map[i].key   = keyval.key;
                    dst.v_map[i].value = keyval.value.dup;
                }
            }
            
            static if (M)
            {
                for (size_t i = dst.k_map.length; i < dst.rwlocks.length; i++)
                {
                    pthread_rwlock_destroy(dst.rwlocks.ptr + i);
                }
                
                dst.rwlocks.length = dst.k_map.length;
                
                for (size_t i = dst.rwlocks.length; i < dst.k_map.length; i++)
                {
                    pthread_rwlock_init(dst.rwlocks.ptr + i, null);
                }
            }
        }
    }

    /***************************************************************************
    
        Copies content of this instance to dst
        
        If mutexes are enabled, dst.k_map.length must equal this.k_map.length.
        
        Params:
            dst = destination ArrayMap instance
        
     **************************************************************************/
    
    public typeof (this) dup ( )
    {
        auto array = new typeof (this)(1, 1);
        
        this.copy(array);
        
        return array;
    }
    
    /***************************************************************************
        
        Returns whether key exists or not
        
        Params:
            key = array key
            
        Returns:
            true if key exists, false otherwise
        
     **************************************************************************/
    
    bool exists ( K key )
    {   
        return this.findValueSync(key) != size_t.max;
    }

    /***************************************************************************
        
        Returns whether key exists or not
        
        Params:
            key = array key
            hash = hash of key
            
        Returns:
            true if key exists, false otherwise
        
     **************************************************************************/

    bool exists ( K key, hash_t hash )
    {
        return this.findValueSync(key, hash % this.buckets_length) != size_t.max;
    }
    
    /***************************************************************************
        
        Free memory allocated by array map
        
        Using free on an array map leads to freeing of any memory allocated. The
        array map can't be reused anymore afterwards.
        
        Returns:
            void
        
     **************************************************************************/
    
    public void free ()
    {
        this.len = 0;
        
        foreach (h, ref bucket; this.k_map)
        {
            this.writeLock(h,
            {
                bucket.length = 0;
                bucket.elements.length = 0;
            });
        }
        
        static if (this.VisArray)
        {
            foreach (ref value; this.v_map)
            {
                value.value.length = 0;
            }
        }
    }
    
    /***************************************************************************
        
        Return number of elements stored in array map
        
        Returns:
            number of elements
        
     **************************************************************************/
    
    public size_t length ()
    {
        return this.len;
    }
    
    /***************************************************************************
        
        Returns element value associated with key
        
        Params:
            key = array key
            
        Returns:
            value of array key
        
     **************************************************************************/
    
    alias get opIndex;
    
    /***************************************************************************
        
        Put element to array map
        
        If the key does not yet exists the element is added otherwise the value of
        the existing element matching the key is replaced by the new value.
        
        Params:
            key = array key
            value = array value
        
     **************************************************************************/
    
    public void opIndexAssign ( V value, K key )
    {
        this.put(key, value);
    }
    
    /***************************************************************************
    
        Return the element associated with key.
        Does not return a pointer if Mutex.Enable is set, 
        to prevent race conditions.
    
        Usage example on efficient key search
        ---
        ArrayMap(char[]) array;
        
        array.bucket = 100;
        ---
        
        Search for key
        ---
        char[]* v = key in array;
            
        if ( v !is null )
        {
            // do something with *v;
            char[] value = *v
        }
        ---
        
        Params:
            key = array key
        
        Returns:
            a pointer to the located value, or null if not found
    
     **************************************************************************/
    
    static if (M)
    {
        alias exists opIn_r;
    }
    else public V* opIn_r ( K key )
    {
        size_t v = this.findValueSync(key);
        
        return (v == v.max)? null : &(this.v_map.ptr + v).value; 
    }
     
    /***************************************************************************
         
         Returns iterator with value as reference
     
         Be aware that the returned list is unordered and that the array map
         does not support iteration over the key of the element as this 
         would be very inefficent.
         
         Params:
             dg = iterator delegate
         
         Returns:
             array values
     
      *************************************************************************/

     public int opApply ( int delegate ( ref V value ) dg )
     {
         int result = 0;
         
         foreach ( ref value; this.v_map[0 .. this.len] )
         {
             result = dg(value.value);
             if (result) break;
         }
         
         return result;
     }
     
     public int opApply ( int delegate ( ref K key, ref V value ) dg )
     {
         int result = 0;
         
         foreach ( ref value; this.v_map[0 .. this.len] )
         {             
             result = dg(value.key,value.value);
             
             if (result) break;
         }
         
         
         return result;
     }
     
     /**************************************************************************
         
         Rehash key map
         
         Optimizes the key map map in case the load factor is larger than 0.75.
         
         Params:
             key = key to return hash
             
         Returns:
             hash
         
      *************************************************************************/
     
     public void rehash ()
     {
         if ( this.len / this.buckets_length > 0.75 )
         {
             /*
                 we need to have a new bucket_length set 
                 and while resizing each lookup has to happen against the old
                 and new position until the restructuration is done
                 
                 steps in between:
                 
                 * rearange keys by building new hash
                 * build new hashes for each item
             */
         }
     }
     
    /***************************************************************************
     
         Dumps the current content to output as serial data. The data can later
         be used by load() to restore the content.
         
         Note that no key type introspection is done so the key type must be a
         value data type. (Note: Structs are value data types.)
         
         If the value type is an array, the content of all value arrays is
         dumped, too, so that restoring the content will restore the content of
         all value arrays.
         Note that no further value type introspection is done; the value type V
         must be either a value data type or an array (not an associative array). 
         (Note: Structs are value data types.) If, for example, the value type is
         a struct containing an array, content of that array will be lost. The
         same applies for arrays of arrays and associative arrays; their content
         will also be lost.
         
         It is highly recommended to use a buffered output stream; a buffer size
         of about 64 kB improves I/O performance a lot as trials have shown.
         If using the BufferedOutput class from tango.io.stream.Buffered, do not
         forget to flush() the buffer before closing the output device!
                  
         The produced data is intended to be reimported by the same program in
         the same environment, using the same class template instance. Data
         interchangeability cannot be relied upon because data alignment, byte
         order, native data word width (which determines the size of size_t) and
         binary floating point number format must be the same when load()ing as
         it was when dump()ing. 
         
         Params:
             output = output stream to write data to
              
         Returns:
             number of bytes written to output
          
         Throws:
             IOException on error
          
     **************************************************************************/
      
    public size_t dump ( OutputStream output )
    {
        size_t total = 0;
      
        total += this.dumpParams(output);
        total += this.dumpKmap(output);
        total += this.dumpVmap(output);
      
        return total;
    }
      
    /**************************************************************************
         
         Returns hash for given key. If the key type can implicitly be casted to
         hash_t, the original value of key is used.
         
         The following types are implicitly castable to hash_t:
         
         hash_t, size_t, bool, 
         byte,   ubyte,  char,
         short,  ushort, wchar,
         int,    uint,   dchar,
         long,   ulong         
         
         Params:
             key = key to return hash
             
         Returns:
             hash
         
      *************************************************************************/

    public static hash_t toHash ( K key )
     {
         static if (is (K : hash_t))
         {
             return key;
         }
         else
         {
             return Fnv1a.fnv1(key);
         }
     }
     
    /***************************************************************************
        
        Returns array element value index
        
        Params:
            key = array key
            
        Returns:
            element value index in this.v_map, or size_t.max if not found
        
     **************************************************************************/
    
    private size_t findValueSync ( K key )
    {
        return this.findValueSync(key, (toHash(key) % this.buckets_length));
    }
    
    /***************************************************************************
        
        Returns array element value index
        
        Params:
            key = array key
            h = bucket position
            
        Returns:
            element value index in this.v_map, or size_t.max if not found
        
     **************************************************************************/
    
    private size_t findValueSync ( K key, hash_t h )
    {
        static if (M)
        {
            pthread_rwlock_t* lock = this.rwlocks.ptr + h;
            
            pthread_rwlock_rdlock(lock);
            scope (exit) pthread_rwlock_unlock(lock);
            
            return this.findValue(key, h);
        }
        else
        {
            return this.findValue(key, h);
        }
    }
    
    /***************************************************************************
    
        Returns array element value index
        
        Params:
            key = array key
            h = bucket position
            
        Returns:
            element value index in this.v_map, or size_t.max if not found
        
     **************************************************************************/

    private size_t findValue ( K key, hash_t h )
    {
        return this.findValue(key, this.k_map.ptr + h);
    }
    
    /***************************************************************************
        
        Returns pointer to array element value
        
        Params:
            key    = array key
            bucket = bucket
            
        Returns:
            element value index in this.v_map, or size_t.max if not found
        
     **************************************************************************/
    
    private size_t findValue ( K key, Bucket* bucket )
    {
        size_t length = bucket.length;
        
        for ( size_t i = 0; i < length; i++ )
        {
            KeyElement* element = bucket.elements.ptr + i;
            
            if ( element.key == key )
                return element.pos;
        }
        
        return size_t.max;
    }
    
    /***************************************************************************
        
        Looks up the bucket element which includes key.
        
        Params:
            key = array key
            h = bucket position
            k = key element pointer to be set to position of element found
            v = value element pointer to be set to position of element found
        
     **************************************************************************/
    
    private void findBucket ( in K key, in hash_t h, out KeyElement* k, out V* v )
    {
        Bucket* bucket = this.k_map.ptr + h;
        
        foreach ( ref element; bucket.elements[0 .. bucket.length] )
        {
            if ( element.key == key )
            {
                v = &(this.v_map.ptr + element.pos).value;
                k = &element;
                
                break;
            }
        }
    }
    
    /***************************************************************************
        
        Returns the value index of the element in this.v_map that corresponds to
        key. Adds an element to array map if key does not yet exist.
        
        Params:
            key = array key
        
        Returns:
            value index of the element in this.v_map

     **************************************************************************/
    
    private size_t getPutIndex ( in K key)
    {
        hash_t h = (toHash(key) % this.buckets_length);
        
        static if (M) 
        {
            pthread_rwlock_t* lock = this.rwlocks.ptr + h;
            
            pthread_rwlock_wrlock(lock);
            
            scope (exit) pthread_rwlock_unlock(lock);
        }   
        
        Bucket* bucket = this.k_map.ptr + h;
        
        size_t p = this.findValue(key, bucket);
        
        if ( p == size_t.max )
        {
            /*
             * To avoid a race condition, use the return value of
             * incrementVMap() rather than repeatedly querying this.len.
             * incrementVMap() is synchronized, increments this.len and returns 
             * the value of this.len before incrementation.
             */
            
            p = this.incrementMap();
            
            this.resizeBucket(bucket);
            
            bucket.elements[bucket.length] = KeyElement(key, p);
        
            bucket.length++;
        }

        return p;
    }
    
    /***************************************************************************
        
        Reset and free memory used by array map
        
     **************************************************************************/
    
    private void free_ ()
    {
        static if (this.VisArray)
        {
            foreach (ref value; this.v_map)
            {
                value.value.length = 0;
            }
        }
        
        foreach (ref bucket; this.k_map)
        {
            bucket.elements.length = 0;
        }
        
        this.k_map.length = 0;
        this.v_map.length = 0;
        
    }
    
    /***************************************************************************
    
        Increments the value map by one; resizes and allocates new memory in
        case the map runs out of memory.
        
        Returns:
            length of array map before incrementation
        
     **************************************************************************/
    
    static if (M)
    {
        synchronized private size_t incrementMap ()
        {
            return this.incrementMap_();
        }
    }
    else
    {
        private alias incrementMap_ incrementMap;
    }
    
    /***************************************************************************
    
        Increments the value map by one; resizes and allocates new memory in
        case the map runs out of memory.
        
        Enlarges map by 10 percent.
        
        TODO Rehashing of key map still needs to be implemented in order to keep
        speed up with the resizing of the value map.
        
        FIXME: Resizing this.v_map may cause the memory manager to move its
        memory location. If a concurrent thread accidently has a pointer to an
        element of this.v_map at the same time, as it is returned by
        this.findValue(), this pointer will become invalid, resulting in
        corrupt value data or a Segmentation Fault.
        
        Returns:
            length of array map before incrementation
        
     **************************************************************************/
    
    private size_t incrementMap_ ()
    {
        if ( this.len && this.len % this.default_size == 0 )
        {
            this.default_size = this.v_map.length + this.default_size / 10;
            
            this.v_map.length = this.default_size;
        }
        
        return this.len++;
    }

    
    /***************************************************************************
        
        Resizes bucket
        
        Enlarges bucket length by certain amout of space by allocating a range of
        memory instead of just allocating the next element.
        
        Params:
            bucket = bucket to resize
        
     **************************************************************************/
    
    private void resizeBucket ( Bucket* bucket )
    {
        size_t length = bucket.length;
        
        if ( length >= this.default_alloc_size && length % this.default_alloc_size == 0 )
        {
             bucket.elements.length = length + this.default_alloc_size;
        } 
    }
    
    /***************************************************************************
        
        Remove single key
        
        Moves last key element to position of element to be removed if number 
        of elements in bucket is larger than 1, otherwise the bucket length is 
        set to 0. 
        
        FIXME: Not reentrant/thread-safe with put() -- may cause wrong values
        in v_map.
        
        Returns:
            true on success, false on failure
        
     **************************************************************************/
    
    private bool remove_ ( hash_t h, K key )
    {
        KeyElement* k,nk;
        V* v,nv;
        
        this.findBucket(key, h, k, v);
        
        if ( k !is null && v !is null )
        {
            Bucket* bucket = this.k_map.ptr + h;
            auto oldpos = k.pos;

            if ( bucket.length == 1 )
            {
                bucket.length = 0;
            }
            else
            {
                *k = bucket.elements[bucket.length - 1];
                bucket.length = bucket.length - 1;
            }
            
            if (oldpos != this.len - 1)
            {
                this.findBucket(this.v_map[this.len - 1].key,
                  toHash(this.v_map[this.len - 1].key) % this.buckets_length,
                  nk,nv);

                assert(nk !is null && nv !is null);
                
                nk.pos = oldpos;
                
                    
            }

            if ( this.len > 1 ) this.v_map[oldpos] = this.v_map[this.len - 1];
            
            assert(oldpos == this.len -1 || v_map[oldpos].key == nk.key);
            
            static if (M) synchronized
            {
                this.len--;
            }
            else
            {
                this.len--;
            }

            return true;
        }
        
        return false;
    }
    
    
    /***************************************************************************
        
        Set allocation size
    
        Default alloc size is based on the load factor but 5 it is usally 
        best when the load factor gets larger than 2.
        
        Params:
            dg = iterator delegate
    
    ***************************************************************************/

    private void setAllocSize ( float load_factor )
    {
        if ( load_factor > 2 )
        {
            this.default_alloc_size = 5;
        }
        else 
        {
            this.default_alloc_size = 1;
        }
    }
    
    
    /***************************************************************************
        
        Locks code for write operation
        
        Only one write operation can happen at the same time
        
        Params:
            dg = anonymus delegete (just some code section)
            
        Returns:
            void
        
     **************************************************************************/
    
    private void writeLock ( hash_t h, void delegate() dg )
    {
        static if (M) 
        {
            pthread_rwlock_wrlock(this.rwlocks.ptr + h);
            
            scope (exit) pthread_rwlock_unlock(this.rwlocks.ptr + h);
        }   
        
        dg();
    }
    
    /***************************************************************************
    
        Dumps the parameters.
        
        Params:
            output = output stream to write data to
            
        Returns:
            number of bytes written to output
        
        Throws:
            IOException on error
        
     **************************************************************************/
    
    private size_t dumpParams ( OutputStream output )
    {
        return this.dumpItems(output,
                              this.len,
                              this.buckets_length,
                              this.default_size, 
                              this.default_alloc_size,
                              this.load_factor);
    }

    /***************************************************************************
    
        Dumps the value map.
        If the value type is an array, the content of all value arrays is
        dumped, too, so that restoring the content will restore the content of
        all value arrays.
        Note that no further value type introspection is done; the value type V
        must be either a value data type or an array (not an associative array). 
        (Note: Structs are value data types.) If, for example, the value type is
        a struct containing an array, content of that array will be lost. The
        same applies for arrays of arrays and associative arrays; their content
        will also be lost.
        
        Params:
            output = output stream to write data to
            
        Returns:
            number of bytes written to output
        
        Throws:
            IOException on error
        
     **************************************************************************/
    
    private size_t dumpVmap ( OutputStream output )
    {
        size_t total = this.dumpItems(output, this.v_map);
        
        static if (this.VisArray)
        {
            foreach (value; this.v_map)
            {
                total += this.dumpItems(output, value);
            }
        }
        
        return total;
    }
    
    /**************************************************************************
    
        Dumps the key map.
        Note that no key type introspection is done so the key type must be a
        value data type. (Note: Structs are value data types.)
        
        Params:
            output = output stream to write data to
            
        Returns:
            number of bytes written to output
        
        Throws:
            IOException on error
        
     **************************************************************************/
    
    private size_t dumpKmap ( OutputStream output )
    {
        size_t total = this.dumpItems(output, this.k_map);
        
        foreach (bucket; this.k_map)
        {
            total += this.dumpItems(output, bucket, bucket.elements);
        }
        
        return total;
    }
    
    /**************************************************************************
    
        Loads the parameters.
        
        Params:
            input = input stream to read data from
            
        Returns:
            number of bytes read from input
        
        Throws:
            IOException on error
        
     **************************************************************************/
    
    private size_t loadParams ( InputStream input )
    {
        return this.loadItems(input,
                              this.len,
                              this.buckets_length,
                              this.default_size, 
                              this.default_alloc_size,
                              this.load_factor);
    }
    
    /**************************************************************************
    
        Loads the value map.
        If the value type is an array, the content of all value arrays is
        restored.
        Loading the value map will only succeed if the value type is a value
        data type or an array (not an associative array). (Note: Structs are
        value data types.)
        
        Params:
            input = input stream to read data from
            
        Returns:
            number of bytes read from input
        
        Throws:
            IOException on error
        
     **************************************************************************/
    
    private size_t loadVmap ( InputStream input )
    {
        size_t total = this.loadItems(input, this.v_map);
        
        static if (this.VisArray)
        {
            foreach (ref value; this.v_map)
            {
                total += this.loadItems(input, value);
            }
        }
        
        return total;
    }
    
    /**************************************************************************
    
        Loads the value map.
        Loading the key map will only succeed if the value type is a value data
        type. (Note: Structs are value data types.)
        
        Params:
            input = input stream to read data from
            
        Returns:
            number of bytes read from input
        
        Throws:
            IOException on error
        
     **************************************************************************/
    
    private size_t loadKmap ( InputStream input )
    {
        size_t total = this.loadItems(input, this.k_map);
        
        foreach (ref bucket; this.k_map)
        {
            total += this.loadItems(input, bucket);
            total += this.loadItems(input, bucket.elements);
        }
        
        return total;
    }
    
    static:
    
    /***************************************************************************
    
        Decomposes items to their raw data and writes that data to output.
        If the type of an item is an array (not an associative array), its raw
        data correspond to the raw data of the array content buffer, preceeded
        by the array length given as size_t.
        If the type of an item is a pointer, the object pointed at will be
        dumped.
        
        Params:
            output = output stream to write data to
            items  = items to dump
            
        Returns:
            number of bytes written to output
        
        Throws:
            IOException on error
        
     **************************************************************************/
        
    private size_t dumpItems ( T ... ) ( OutputStream output, T items )
    {
        size_t total = 0;
        
        foreach (i, Type; T)
        {
            //debug pragma (msg, "dump " ~ i.stringof ~ ": " ~ Type.stringof);
            
            total += write(output, items[i]);
        }
        
        return total;
    }
    
    
    /***************************************************************************
    
        Decomposes item to its raw data and writes that data to output.
        If the type of the item is an array (not an associative array), its raw
        data correspond to the raw data of the array content buffer, preceeded
        by the array length given as size_t.
        If the type of the item is a pointer, the object pointed at will be
        dumped.
        
        Params:
            output = output stream to write data to
            item   = item to dump
            
        Returns:
            number of bytes written to output
        
        Throws:
            IOException on error
        
     **************************************************************************/
    
    private size_t write ( T ) ( OutputStream output, T item )
    {
        static if (is (T U == U[]))
        {
            size_t written  = write(output, item.length);
            
            if (item.length)
            {
                written += output.write((cast (void*) item.ptr)[0 .. U.sizeof * item.length]);
            }
        }
        else static if (is (T U == U*))
        {
            size_t written = output.write((cast (void*) item)[0 .. U.sizeof]);
        }
        else
        {
            size_t written = output.write((cast (void*) &item)[0 .. T.sizeof]);
        }
        
        assertEx!(IOException)(written != output.Eof,
                               typeof (this).stringof ~ ": end of flow whilst writing");
        
        return written;
    }
    
    /***************************************************************************
    
        Composes items from their raw data which are read from input.
        If the type of an item is an array (not an associative array), its raw
        data correspond to the raw data of the array content buffer, preceeded
        by the array length given as size_t.
        
        Params:
            input = input stream to read data from
            items = items to load
            
        Returns:
            number of bytes read from input
        
        Throws:
            IOException on error
        
     **************************************************************************/
    
    private size_t loadItems ( T ... ) ( InputStream input, out T items )
    {
        size_t total = 0;
        
        foreach (i, Type; T)
        {
            //debug pragma (msg, "load: " ~ Type.stringof);
            
            total += readItem(input, items[i]);
        }
        
        return total;
    }
    
    /***************************************************************************
    
        Composes item from its raw data which are read from input.
        If the type of the item is an array (not an associative array), its raw
        data correspond to the raw data of the array content buffer, preceeded
        by the array length given as size_t.
        
        Params:
            input = input stream to read data from
            item  = item to load
            
        Returns:
            number of bytes read from input
        
        Throws:
            IOException on error
        
     **************************************************************************/
    
    private size_t readItem ( T ) ( InputStream input, out T item )
    {
        size_t total = 0;
        void[] data;
        
        static if (is (T U == U[]))
        {
            total += read(input, size_t.sizeof, data);
            
            item.length = *(cast (size_t*) data.ptr);
            
            total += read(input, U.sizeof * item.length, data);
            
            item = (cast (U*) data.ptr)[0 .. item.length].dup; 
        }
        else static if (is (T U == U*))
        {
            static assert (false, typeof (this).stringof ~ ": reading not supported for pointers");
        }
        else
        {
            total += read(input, T.sizeof, data);
            
            item = *(cast (T*) data.ptr);
        }
        
        return total;
    }
    
    /***************************************************************************
    
        Reads len bytes of _data from input and puts them to data.
        
        Params:
            input = input stream to read data from
            len   = number of bytes to read
            data  = data output
            
        Returns:
            number of bytes read from input
        
        Throws:
            IOException on error, or, if the number of bytes returned by input
            differs from the requested number

        FIXME: InputStream.load creates a new buffer each time it's called
               out void[] data should be ref

     **************************************************************************/
    
    private size_t read ( InputStream input, size_t len, out void[] data )
    {
        data = input.load(len);
        
        assertEx!(IOException)(!(data.length < len),
                               typeof (this).stringof ~ ": end of flow whilst reading");
        
        assertEx!(IOException)(data.length == len,
                               typeof (this).stringof ~ ": got too much data");
        
        return len;
    }
}

/*******************************************************************************

    Unittest

 ******************************************************************************/

debug = OceanUnitTest;

debug (OceanUnitTest)
{
    import tango.util.log.Trace;
    import tango.core.Memory;
    import tango.time.StopWatch;
    import tango.core.Thread;
    import tango.util.container.HashMap;
    import tango.io.Buffer;
    import tango.util.container.HashMap;
    private import  tango.math.random.Random;

    
    struct slowdown { 
        int a,b,c; 
        static slowdown opCall(int a, int b, int c){ slowdown f; return f; }
    }
    
    
    void test ( T ) ( T array,uint iterations , uint inserts, bool free = true)
    {
        StopWatch   w;
        Trace.format("{}:\t", T.stringof);
        w.start;
        for (uint r = 1; r <= iterations; r++)
        {
            array.clear();
            for (uint i = ((inserts * r) - inserts); i < (inserts * r); i++)
            {
                array[i] = slowdown(i, i + 1, i + 2);
            }
        }
        Trace.format("put = {}/s\t", (inserts * iterations) / w.stop);
        w.start;
        uint hits = 0;
        uint* p;
        for (auto a = 0; a < iterations; ++a)
        {
            hits=0;
            for (uint i = ((inserts * iterations) - inserts); i < (inserts * iterations); i++)
            {
                if (i in array) hits++;
            }
        }
        assert (inserts == hits);
        Trace.format("{}/{} gets/hits\tget = {}/s and ", array.length, hits,
                     iterations*array.length / w.stop);
        Trace.formatln("mem usage {} mbytes", GC.stats["poolSize"]/1024/1024);
        
        w.start;
        for (auto a = 0; a < iterations; ++a)
        {
            size_t ii;
            foreach (el; array)
            {
                assert (el == slowdown(ii, ii + 1, ii + 2));                
                ++ii;
            }            
        }
        Trace.format("\tforeach = {}/s", (iterations * inserts) / w.stop);
        
        w.start;
        for (uint r = 1; r <= iterations; r++)
        {
            for (uint i = ((inserts * r) - inserts); i < (inserts * r); i++)
            {
                array.remove(i);
            }
        }
        Trace.formatln("\tdelete = {}/s", (iterations * inserts) / w.stop);
        
        if(free)
        {
            array.free;
            
            delete array;
        }
    }
    
    
    import tango.util.Convert;
    
    
    unittest
    {
        Trace.formatln("Running ocean.core.ArrayMap unittest");
        
        const uint iterations  = 50;
        const uint inserts     = 1_000_000;
        const uint num_threads = 1;

        
        StopWatch   w;
      
        {
            ArrayMap!(slowdown, hash_t, Mutex.Disable) maps[char[]];
            
            
            Trace.formatln("Testing {} arrays with each {}",10,inserts*0.1);
            char[][10] strs;
            
            for(uint i=0;i<10;++i)
            {
                maps[to!(char[])(i)] = new ArrayMap!(slowdown, hash_t, Mutex.Disable)(cast(uint)(inserts*0.1));
                strs[i] = to!(char[])(i);
            }
            
            
            w.start;  
            for (uint r = 1; r <= iterations; r++)
            {
                foreach(map ; maps) map.clear();
                for (uint i = ((cast (uint) (inserts * 0.1) * r) - cast (uint) (inserts * 0.1)); i < (cast (uint) (inserts * 0.1) * r); i++)
                {
             
                    foreach (str; strs)
                    {
                        maps[str][i] = slowdown(i, i + 1, i + 2);
                    }
                }
            }
            Trace.format("put = {}/s\t", (inserts * iterations) / w.stop).flush;
            
            
            w.start; 
            uint hits = 0;
            uint* p;
            for (uint r = 1; r <= iterations; r++)            
            {
                //Trace.format("iteration {}",r);
                hits=0;
                uint i=(((cast (uint) (inserts * 0.1) * iterations)) - (cast (uint) (inserts * 0.1) ));
                uint b=i;
                //Trace.format(" {} -> ",i);
                for (i = (((cast (uint) (inserts * 0.1) * iterations)) - (cast (uint) (inserts * 0.1) )); i < ((cast (uint) (inserts * 0.1) * iterations) ); i++)
                {
                    foreach (str; strs)
                        if (i in maps[str]) hits++;
                }
                //Trace.formatln("{} ({}).. done",i,i-b);
            }
            
            
            Trace.format("{}/{} gets/hits\tget = {}/s and ", inserts, hits,
                         iterations*inserts / w.stop);
            Trace.formatln("mem usage {} mbytes", GC.stats["poolSize"]/1024/1024);
            assert (inserts == hits);
            Trace.formatln("done.");
        }
        
        
        /***********************************************************************
            
            ArrayMap Assertion Test
            
        ***********************************************************************/        
       
        {
            scope
                  array = new ArrayMap!(slowdown, hash_t, Mutex.Disable)(
                                                                         inserts);
            Trace.formatln("running performance test...");
            test(array, iterations, inserts);
            array = new ArrayMap!(slowdown, hash_t, Mutex.Disable)(inserts);
            Trace.formatln("running remove test...");
            scope random = new Random();
            // fill the map, remove i, fill it again, ++i, repeat till i==size
            w.start;
            for (uint r = 1, remove = 1; r <= (iterations > inserts)? iterations : inserts; r += inserts * 0.1 , remove += inserts * 0.1)
            {
                array.clear();
                if (remove > inserts) break;
                //Trace.formatln("Filling");
                // fill
                for (uint i = ((inserts * r) - inserts); i < (inserts * r); i++)
                {
                    array[i] = slowdown(i, i + 1, i + 2);
                }
                
                //Trace.formatln("Validating filled!");
                foreach(i, kv ; array.v_map)
                {
                    assert(i >= array.len || array[kv.key] == kv.value);
                }
                // remove
                uint rand;
                random(rand);
                auto rem = rand % (inserts - remove);
                //Trace.formatln("removing {} starting at {}", remove, rem);
                for (uint i = rem; i < remove + rem; ++i)
                {
                    array.remove((inserts * r) - inserts + i);
                /+    Trace.formatln("removing {}",(inserts * r - inserts + i));
                    foreach(kv ; array.v_map)
                    {
                        assert(array[kv.key] == kv.value);
                    }+/
                }
                assert (array.length == inserts - remove);
                //Trace.formatln("Validating");
                // validate
                uint count = 0;
                for (uint i = ((inserts * r) - inserts); i < (inserts * r); i++)
                {
                    if (auto x = i in array)
                    {
                        assert (*x == slowdown(i, i + 1, i + 2), "failed to validate");
                        ++count;
                    }
                }
                
                //Trace.formatln("Validating!");
                foreach(i, kv ; array.v_map)
                {
                    assert(i >= array.len || array[kv.key] == kv.value);
                }
                
                assert (count == array.length, "length doesn't fit");
                //Trace.formatln("Filling again starting at {}", rem);
                // fill again
                for (uint i = ((inserts * r) - (inserts - rem)); i < (inserts * r) - (inserts - rem) + remove; i++)
                {
                    //      Trace.formatln("adding {}", i);
                    assert (!(i in array));
                    array[i] = slowdown(i, i + 1, i + 2);
                }
                
                //Trace.formatln("length is {}, insetrs are {}", array.length,
                //      inserts);
                assert (array.length == inserts);
                //Trace.formatln("Validating again");
                // validate again
                for (uint i = ((inserts * r) - inserts); i < (inserts * r); i++)
                {
                    assert (array[i] == slowdown(i, i + 1, i + 2), "failed to validate 2");
                }
                
                //Trace.formatln("Validating again!");
                foreach(i, kv ; array.v_map)
                {
                    assert(i >= array.len || array[kv.key] == kv.value);
                }
            }
            w.stop;
            array.clear();
            array.free();
        }
        
        
        Trace.formatln("running general functionality test...");
        auto array = new ArrayMap!(uint, hash_t, Mutex.Disable)(2);

       
        array[1111] = 2;
        array[2222] = 4;

        assert(array[1111] == 2);

        assert(array[2222] == 4);
        assert(1111 in array);
        assert(2222 in array);
        assert(array.get(2222,array.toHash(2222)) == 4);
        assert(array.exists(2222,array.toHash(2222)));
        assert(array.length == 2);
        
        array[1111] = 3;
        
        assert(array[1111] == 3);
        assert(array.length == 2);

        array.remove(1111);
        assert((1111 in array) == null);
        assert(array.length == 1);
        
        
        bool catchme=false;
        try array.get(3333);
        catch (ArrayMapException e) catchme=true;
        assert(catchme); catchme = false;
        
        {
            scope array2 = new ArrayMap!(uint, hash_t, Mutex.Disable)(1);
            array.copy(array2);
            assert (array[2222] == array2[2222]);            
        }
        
        assert(array.dup[2222] == array[2222]);
        
        array[3333] = 234;
        
        {
            size_t count = 0;
            auto vals = [ 4,234]; 
            foreach (v; array)
            {
                ++count;        
                assert(v == 234 || v == 4);
            }
            assert(count == array.length);
        }
        
        {
            size_t count = 0;
            auto vals = [ 4,234]; 
            foreach (k,v; array)
            {
                ++count;       
                
                assert((v == 234 && k == 3333) || 
                       (v == 4   && k == 2222));
                
            }
            assert(count == array.length);
        }
        
      //scope buf = new Buffer;
       // assert(array.dump(buf) == 8);
       //  assert(array[2222] == array2[2222]);
       // assert(array == array2);
        
        

        Thread.sleep(2);
    
        /***********************************************************************
            
            Muli-Threading Test
            
         **********************************************************************/
        
        scope arraym = new ArrayMap!(uint, hash_t, Mutex.Enable)(1_000_000);
        scope group  = new ThreadGroup;
        
        void write ()
        {
            StopWatch   s;

            for ( uint r = 1; r <= iterations; r++ )
            {
                s.start;
                
                for ( uint i = 1; i <= inserts; i++ ) arraym[i] = i;
                
                Trace.formatln  ("loop {}: {} adds with {}/s and {} bytes mem usage", 
                        r, arraym.length, arraym.length/s.stop, GC.stats["poolSize"]);
            }
        }
        
        void read ()
        {
            StopWatch   s;

            for ( uint r = 1; r <= iterations; r++ )
            {
                s.start;
                
                for ( uint i = 1; i <= inserts; i++ ) i in arraym;
                
                Trace.formatln  ("loop {}: {} lookups with {}/s and {} bytes mem usage", 
                        r, inserts, inserts/s.stop, GC.stats["poolSize"]);
            }
        }
        
        Trace.formatln("running mutex read/write thread test...");

        w.start;
        
        for( int i = 0; i < num_threads; ++i )
            group.create( &write );
        
        for( int i = 0; i < num_threads; ++i )
            group.create( &read );
        
        group.joinAll();

        Trace.formatln  ("{} array elements found after thread iteration", arraym.length);
        Trace.formatln  ("{} threads with {} adds/lookups {}/s", num_threads, 
                num_threads * iterations * inserts, (num_threads * iterations * inserts)/w.stop);

        Trace.formatln("done unittest");
        Trace.formatln("");

    }
}