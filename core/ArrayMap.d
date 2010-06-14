/******************************************************************************

    Hashtable with Multi-Thread Support

    Copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    Version:        May 2010: Initial release
                    
    Authors:        Thomas Nicolai, David Eckardt
    
 ******************************************************************************/

module ocean.core.ArrayMap;

/******************************************************************************

    Imports
    
 ******************************************************************************/

private     import      ocean.core.Exception: ArrayMapException;

private     import      ocean.io.digest.Fnv1;

private     import      tango.stdc.posix.pthread;

/******************************************************************************

    Mutex support for multithreading
    
    Enable  = enable multi thread support
    Disable = disable multi thread support (faster)

 ******************************************************************************/

struct Mutex
{
    const bool Enable  = true;
    const bool Disable = false;
}

/******************************************************************************

    Hashmap with consistent hashing and without key iteration.
    
    Consistent hashing provides a performant way to add or remove array 
    elements without significantly change the mapping of keys to buckets. By 
    using consistent hashing, only k/n keys need to be remapped on average: 
    k is the number of keys and n is the number of buckets. The performance 
    depends on the number of n stored entries and the resulting load factor. 
    The load factor is diretly influenced by n and s, its bucket size.
    
    Multithread support

    By providing the -version=Thread switch at compile time the array map
    can be used by multiple threads at the same time. Be aware that this 
    influcences the overall performance.
    
    Load factor

    The load factor specifies the ratio between the number of buckets and 
    the number of stored elements. A smaller load factor the better the 
    performance but it should never be below zero. The optimal load factor
    is said to 0.75.
    
    Performance

    The hashmap implementation offers a good overall performance. An array 
    hashmap with 1.000.000 uint[uint] elements and 20.000 buckets shows the 
    following performance metrics:
    
    ~ 20 mio inserts/sec
    ~ 40 mio lookups/sec
    
    Limitations

    The hashmap does not support key, value iteration. Only value iteration
    is supported.
    
    Template Params:
        V = type of value stored in array map
        K = type of key stored in array map (must be of simple type)
        M = enable/disable mutex
    
    Usage example without thread support
    ---
    scope array = new ArrayMap!(char[])(10_000);
    
    array.buckets(20_000, 5); // set number of buckets!!! important
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
    
    array.buckets(20_000, 5); // set number of buckets !!! important
    ---

 *******************************************************************************/

class ArrayMap ( V, K = hash_t, bool M = Mutex.Disable )
{
    static if (is (V W == W[]))
    {
        const VisArray = true;
    }
    else
    {
        const VisArray = false;
    }
    
    
    /**************************************************************************
        
        Hashmap bucket key element
        
        key = key of array element
        pos = position of value in the value map
        
     **************************************************************************/
    
    private struct KeyElement
    {
        K  key;
        size_t pos;
    }

    /**************************************************************************
        
        Hashmap bucket
        
        length   = number of key elemens in bucket
        elements = list of key elements
        
     **************************************************************************/
    
    private struct Bucket
    {
        size_t length = 0;
        KeyElement[] elements;
        
        static if (M)
        {
            pthread_rwlock_t rwlock;
        }
    }

    /**************************************************************************
        
        Hashtable based key map
        
        Hashmap only stores the key indicies as well as the position of the
        value inside the value map.
        
     **************************************************************************/
    
    final               Bucket[]                        k_map;
    
    /**************************************************************************
        
        Value map
        
     **************************************************************************/
    
    final               V[]                             v_map;
    
    /**************************************************************************
        
        Number of buckets 
        
        Number of buckets is based on size of hashmap and the load factor.
        Usually
        a load factor around 0.75 is perfect.
        
     **************************************************************************/
    
    final               size_t                            buckets_length;
    
    /**************************************************************************
        
        Number of hashmap bucket elements allocated at once
        
        Allocating more than one element at a time improves performance a lot.
        Nevertheless, allocating to much at once kills performance.
        
     **************************************************************************/
    
    final               size_t                            default_alloc_size = 1;

    /**************************************************************************
        
        Startup size of array map
        
     **************************************************************************/
    
    final               size_t                            default_size;
    
    /**************************************************************************
        
        Load factor
        
     **************************************************************************/
    
    final               float                           load_factor;

    /*******************************************************************************
        
        Number of array elements stored
        
     **************************************************************************/
    
    final               size_t                            len;
    
    /**************************************************************************
        
        Sets number of buckets used

        Usage example
        ---
        scope array = new ArrayMap (1_000_000, 0.75);
        ---
        
        Params:
            default_size = estimated number of elements to be stored
            load_factor = determines the number of buckets used
            
        Returns:
            void
            
     **************************************************************************/
    
    public this ( in size_t default_size = 10_000, in float load_factor = 0.75 )
    {
        this.default_size = default_size;
        this.load_factor  = load_factor;
        
        this.buckets_length = cast(int) (default_size / load_factor);
        
        this.k_map = new Bucket[this.buckets_length];
        this.v_map = new V[default_size];
        
        foreach ( ref bucket; this.k_map ) 
        {
            bucket.elements = new KeyElement[this.default_alloc_size];
            
            static if (M)
            {
                pthread_rwlock_init(&bucket.rwlock, null);
            }
        }
    }
      
    /**************************************************************************
        
        Put element to array map
        
        If the key does not yet exists the element is added otherwise the value of
        the existing element matching the key is replaced by the new value.
        
        Params:
            key = array key
            value = array value
        
     **************************************************************************/
    
    public void put (in  K key, in V value )
    {
        this.put_(key, value);
    }

    
    /**************************************************************************
    
        Append element value to value of existing element in array map
        
        If the key does not yet exists the element is added otherwise the new
        value is appended to the value of the existing element matching the key.
        
        Params:
            key = array key
            value = array value
        
     **************************************************************************/

    static if (this.VisArray) public void putCat ( in K key, in V value )
    {
        this.put_!(true)(key, value);
    }
    
    /**************************************************************************
        
        Returns value associated with key
        
        Params:
            key = array key
            
        Returns:
            value of array key
        
     **************************************************************************/
    
    public V get ( in K key )
    {
        V* v = this.findValueSync(key);
        
        if ( v !is null )
        {
            return *v;
        }
        
        throw new ArrayMapException(`key doesn't exist`);
    }
    
    /**************************************************************************
        
        Remove element from array map
        
        Params:
            key = key of element to remove
            
        Returns:
            void
        
     **************************************************************************/
    
    public void remove ( in K key )
    {
        this.remove_(key);
    }
    
    /**************************************************************************
        
        Clear array map
        
        Returns:
            void
        
     **************************************************************************/
 
    public void clear ()
    {
        if ( this.len )
        {
            this.len = 0;
            
            foreach ( ref bucket; this.k_map ) 
                this.writeLock ( &bucket, (Bucket* b) {b.length = 0;});
        }
    }
    
    /**************************************************************************
        
        Copies content of array map
        
        Params:
            key = array key
            
        Returns:
            true if key exists, false otherwise
        
     **************************************************************************/
    
    public void copy ( ref ArrayMap dst )
    {
        if (this.len)
        {
            dst.v_map  = this.v_map.dup;
            dst.k_map  = this.k_map.dup;
            dst.length = this.length;
        }
    }

    /**************************************************************************
        
        Returns whether key exists or not
        
        Params:
            key = array key
            
        Returns:
            true if key exists, false otherwise
        
     **************************************************************************/
    
    bool exists ( in K key )
    {   
        return this.findValueSync(key) != null;
    }
    
    /**************************************************************************
        
        Free memory allocated by array map
        
        Using free on an array map leads to freeing of any memory allocated. The
        array map can't be reused anymore afterwards.
        
     **************************************************************************/
    
    public void free ()
    {
        this.clear();
        this.free_();
    }
    
    /**************************************************************************
        
        Return number of elements stored in array map
        
        Returns:
            number of elements
        
     **************************************************************************/
    
    public size_t length ()
    {
        return this.len;
    }
    
    /**************************************************************************
        
        Set number of elements stored in array map
        
        Params:
            number of elements
        
        Returns:
            void
        
     **************************************************************************/
    
    public void length ( in size_t length )
    {
        this.len = length;
    }

    /**************************************************************************
        
        Returns element value associated with key
        
        Params:
            key = array key
            
        Returns:
            value of array key
        
     **************************************************************************/
    
    public V opIndex ( in K key )
    {
        V* v = this.findValueSync(key);
        
        if ( v !is null )
        {
            return *v;
        }
        
        throw new ArrayMapException(`key doesn't exist`);
    }
    
    /**************************************************************************
        
        Put element to array map
        
        If the key does not yet exists the element is added otherwise the value of
        the existing element matching the key is replaced by the new value.
        
        Params:
            key = array key
            value = array value
        
        Returns:
            void
        
     **************************************************************************/
    
    public void opIndexAssign ( in V value, in K key )
    {
        this.put_(key, value);
    }
    
    /**************************************************************************
    
        Return the element associated with key
    
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
    
    ***************************************************************************/
    
    static if (M)
    {
        alias exists opIn_r;
    }
    else
    {
        public V* opIn_r ( K key )
        {
            return this.findValueSync(key);
        }
    }
     
     /*************************************************************************
         
         Note: Please iterate over v_map instead.
         
         'foreach' iteration over array values
     
         Be aware that the values are unordered.
     
     **************************************************************************/

     deprecated public int opApply ( int delegate ( ref V value ) dg )
     {
         int result = 0;
         
         foreach (ref value; this.v_map)
         {
             result = dg(value);
             
             if (result) break;
         }
         
         return result;
     }
     
     /*************************************************************************
         
         'foreach' iteration over array key/value pairs
     
         Be aware that the key/value pairs are unordered and that the key/value 
         iteration is very inefficent. In order to have the best performance 
         please consider using ArrayMapKV.
     
     **************************************************************************/
     
     public int opApply ( int delegate( ref K key, ref V value ) dg )
     {
         int result = 0;
         
         foreach (bucket; this.k_map)
         {
             foreach (ref element; bucket.elements[0 .. bucket.length])
             {
                 result = dg(element.key, this.v_map[element.pos]);
                 
                 if (result) break;
             }
         }
         
         return result;
     }
 
     /*************************************************************************
         
         Rehash key map
         
         Optimizes the key map map in case the load factor is larger than 0.75.
         
      *************************************************************************/
     
     public void rehash ()
     {
         if ( cast (float) this.len / cast (float) this.buckets_length > 0.75f )
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
     
     /*************************************************************************
     
         Generates the hash from to key. If key is compatible to hash_t, its
         value is copied.
         
         Params:
             key = key of bucket to pick
             
         Returns:
             hash
         
      *************************************************************************/
     
     public static hash_t toHash ( in K key )
     {
         static if (is (K : hash_t))
         {
             return key;
         }
         else
         {
             return Fnv1aGeneric.fnv1(key);
         }
     }
     
     /*************************************************************************
     
         Returns an array of values where each element corresponds to the number
         of elements in a bucket.
          
         Returns:
             array of usage values
         
      *************************************************************************/
     
     public size_t[] getBucketUsage ( )
     {
         auto usage = new size_t[this.k_map.length];
         
         this.getBucketUsage(usage);
         
         return usage;
     }
     
     /*************************************************************************
     
         Fills usage so that each element corresponds to the number of elements
         in a bucket.
          
         Params:
             usage = output array of usage values
         
      *************************************************************************/
     
     public void getBucketUsage ( out size_t[] usage )
     {
         usage.length = this.k_map.length;
         
         foreach (i, bucket; this.k_map)
         {
             usage[i] = bucket.length;
         }
     }
     
     /*************************************************************************
         
         Picks the bucket which corresponds to key.
         
         Params:
             key = key of bucket to pick
             
         Returns:
             (pointer to) bucket
         
      *************************************************************************/
     
     private Bucket* getBucket ( in K key )
     {
         return this.k_map.ptr + (this.toHash(key) % this.buckets_length);
     }
     
     /+
     /*************************************************************************
         
         Returns hash for given string
         
         Params:
             key = key to return hash
             
         Returns:
             hash
         
      *************************************************************************/
     
     private uint toHash ( K key )
     {
         /*
         is (K : hash_t)  || 
         is (K : int)     || 
         is (K : uint)    || 
         is (K : long)    || 
         is (K : ulong)   || 
         is (K : short)   || 
         is (K : ushort)  ||
         is (K : byte)    || 
         is (K : ubyte)   ||
         is (K : char)    || 
         is (K : wchar)   || 
         is (K : dchar))
      */
         
        static if (is (K : long))
        {
            pragma (msg, K.stringof ~ " : long");
            
            return cast (hash_t) (key);
        }
        else
        {
            pragma (msg, K.stringof ~ " !: long");
            
            return (Fnv1a32.fnv1(key) & 0x7FFFFFFF);
        }
     }
     +/
     
    /*************************************************************************
        
        Returns pointer to array element value
        
        Params:
            key = array key
            
        Returns:
            pointer to element value, or null if not found
        
     **************************************************************************/
    
     private V* findValueSync ( in K key )
     {
         static if (M)
         {
             Bucket* bucket = this.getBucket(key);
             
                          pthread_rwlock_rdlock(&bucket.rwlock);
             scope (exit) pthread_rwlock_unlock(&bucket.rwlock);
             
             return this.findValue(bucket, key);
         }
         else
         {
             return this.findValue(this.getBucket(key), key);
         }
     }
     
    /**************************************************************************
        
        Returns pointer to array element value.
        
        Note: The bucket corresponding to key can be retrieved by getBucket(). 
        
        Params:
            bucket = bucket corresponding to key 
            key    = array key
            
        Returns:
            pointer to element value, or null if not found
        
     **************************************************************************/
    
     private V* findValue ( in Bucket* bucket, in K key )
     {
         foreach (element; bucket.elements[0 .. bucket.length])
         {
             if (element.key == key)
             {
                 return this.v_map.ptr + element.pos;
             }
         }
         
         return null;
     }

    /**************************************************************************
        
        Put array element

        Adds element to array map in not yet existing otherwise the existing value
        is replaced by the new value.

        Params:
            key = array key
            value = array value

     **************************************************************************/
    
    private void put_ ( bool append = false ) ( in K key, in V value )
    {
        static assert (!append || this.VisArray,
                       "appending only supported for array value type, not '" ~ V.stringof ~ '\'');
        
        Bucket* bucket = this.getBucket(key);
        
        this.writeLock ( bucket, (Bucket* b)
        {
            V* p = this.findValue(b, key);
            
            if (p)
            {
                static if (append)
                {
                    *p ~= value;
                }
                else
                {
                    *p = value;
                }
            }
            else
            {
                version (None) this.resizeBucket(b);                            // not really implemented yet
                
                this.resizeMap();

                this.v_map[this.len] = value;
                
                b.elements[b.length] = KeyElement(key, this.len);
            
                b.length++;

                static if (M)
                {
                    this.length_(true);
                }
                else
                {
                    this.len++;
                }
            }
        });
    }
    
    version (None)  // not really implemented yet:
    {
        /**********************************************************************
            
            Resizes bucket
            
            Enlarges bucket length by certain amout of space by allocating a range of
            memory instead of just allocating the next element.
            
            Returns:
                void
            
         **********************************************************************/
        
        private void resizeBucket ( Bucket* bucket )
        {
            size_t len = bucket.length;
            
            if ( len >= this.default_alloc_size && len % this.default_alloc_size == 0 )
            {
                    bucket.elements.length = len + this.default_alloc_size;
            } 
        }
    }
    
    /**************************************************************************
        
        Remove single key
        
        Moves last key element to position of element to be removed if number 
        of elements in bucket is larger than 1, otherwise the bucket length is 
        set to 0. 
        
        Params:
            key = key to remove
        
        Returns:
            true on success, false on failure
        
     **************************************************************************/
    
    private bool remove_ ( K key )
    {
        KeyElement* k;
        V*          v;
        
        Bucket* bucket = this.findBucketElement(key, k, v);
        
        bool found = k && v;
        
        if ( found ) this.writeLock ( bucket, (Bucket* b)
        {
            if ( b.length > 1 )
            {
                *k = b.elements[b.length - 1];
            }
            
            b.length--;
            
            if ( this.len > 1 )
            {
                *v = this.v_map[this.len - 1];
            }
            
            static if (M)
            {
                this.length_(false);
            }
            else
            {
                this.len--;
            }
        });
        
        return found;
    }
    
    /**************************************************************************
    
        Picks the bucket corresponding to key and sets k and v point to the
        location of key and value of the array map element corresponding to key.
        If the key is not found, k and v remain null.
        
        Params:
            key = array key
            k = key element pointer to be set to position of element found
            v = value element pointer to be set to position of element found
            
        Returns:
            (pointer to) bucket
        
     **************************************************************************/
    
    private Bucket* findBucketElement ( in K key, out KeyElement* k, out V* v )
    {
        Bucket* bucket = this.getBucket(key);
        
        foreach (i, element; bucket.elements[0 .. bucket.length])
        {
            if (element.key == key)
            {
                v = this.v_map.ptr + element.pos;
                k = bucket.elements.ptr + i;
                
                break;
            }
        }
        
        return bucket;
    }

    /**************************************************************************
        
        Locks code to reentrant/thread-safely perform operation on bucket.
        
        Params:
            dg = delegate to be reentrant/thread-safely invoked (e.g. just some
                 code section for anonymous delegate); bucket is passed to it 
                 as argument
                 
     ***********************************************************************/
    
    private void writeLock ( Bucket* bucket, void delegate ( Bucket* ) dg )
    {
        static if (M)
        {
                         pthread_rwlock_wrlock(&bucket.rwlock);
            scope (exit) pthread_rwlock_unlock(&bucket.rwlock);
            
            dg(bucket);
        }
        else
        {
            dg(bucket);
        }
    }
    
    /**************************************************************************
    
        Increases or decreases length
        
        The synchronization is necessary in case two threads changing
        different buckets and therefore changing the overall length.
        
        Params:
            bool = true to increment length, false to decrement length
    
    ************************************************************************/
    
    synchronized private void length_ ( bool inc = true )
    {
        inc ? this.len++ : this.len--;
    }
    
    /**************************************************************************
        
        Set allocation size
    
        Default alloc size is based on the load factor but 5 it is usally 
        best when the load factor gets larger than 2.
        
        Params:
            load_factor = load factor
    
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

    /**************************************************************************
        
        Resizes and allocates new memory in case the map runs out of memory
        
        Enlarges map by 10 percent. TODO Rehashing of key map still needs to be 
        implemented in order to keep speed up with the resizing of the value
        map.
        
     **************************************************************************/
    
    private void resizeMap ()
    {
        if ( this.len && this.len % this.default_size == 0 )
        {
            synchronized
            {
                this.default_size = this.v_map.length +  (this.default_size / 10);
                
                this.v_map.length = this.default_size;
            }
        }
    }

    /**************************************************************************
    
        Reset and free memory used by array map
        
     **************************************************************************/
    
    private void free_ ()
    {
        delete this.k_map;
        delete this.v_map;
    }

    /**************************************************************************
    
        Destructor; free memory to gc
            
     **************************************************************************/
    
    private ~this () 
    {
        this.len = 0;
        
        foreach ( ref bucket; this.k_map )
        {
            static if (M)
            {
                pthread_rwlock_destroy(&bucket.rwlock);
            }
            
            bucket.length = 0;
            
            delete bucket.elements;
        }
    
        this.free_();
    }

}

/****************************************************************************** 

    Hashmap with consistent hashing and with key iteration.
    
    The ArraySet supports key/value iteration whereas the ArrayMap only 
    supports value iteration. The price for having key/value iteration is 
    having the key stored inside the key map as well as in the value map.
    
    Template Params:
        V = type of value stored in array map
        K = type of key stored in array map (must be of simple type)
        M = enable/disable mutex
    
 ******************************************************************************/

class ArrayMapKV ( V, K = hash_t, bool M = Mutex.Disable )
{
    /******************************************************************************

        Key/value bag for ArrayMapKV implementation
    
     ******************************************************************************/
    
    private struct KeyValueElement ( K, V )
    {
            K key;
            V value;
    }

    
    /*******************************************************************************
        
        KeyValue element alias
        
     *******************************************************************************/
    
    private alias       KeyValueElement!(K, V)                  Element;
    
    /*******************************************************************************
        
        Map
        
     *******************************************************************************/
    
    final               ArrayMap!(KeyValueElement!(K, V), K, M)    map;

    /*******************************************************************************
        
        Sets number of buckets used
    
        Usage example
        ---
        scope array = new ArrayMap (1_000_000, 0.75);
        ---
        
        Params:
            default_size = estimated number of elements to be stored
            load_factor = determines the number of buckets used
            
        Returns:
            void
            
     *******************************************************************************/
    
    public this ( size_t default_size = 10_000, float load_factor = 0.75 )
    {
        map = new ArrayMap!(KeyValueElement!(K, V), K, M)(default_size, load_factor);
    }
    
    /*******************************************************************************
        
        Destructor; free memory to gc
            
        Returns:
            void
            
     *******************************************************************************/
    
    public ~this () 
    {
        delete map;
    }

    /*******************************************************************************
        
        Put element to array map
        
        If the key does not yet exists the element is added otherwise the value of
        the existing element matching the key is replaced by the new value.
        
        Params:
            key = array key
            value = array value
        
        Returns:
            void
        
     *******************************************************************************/
    
    public void put ( K key, V value )
    {
        map.put(key, Element(key, value));
    }
    
    /*******************************************************************************
        
        Returns value associated with key
        
        Params:
            key = array key
            
        Returns:
            value of array key
        
     *******************************************************************************/
    
    public V get ( K key )
    {
        return (map.get(key)).value;
    }

    /*******************************************************************************
        
        Remove element from array map
        
        Params:
            key = key of element to remove
            
        Returns:
            void
        
     *******************************************************************************/
    
    public void remove ( K key )
    {
        map.remove(key);
    }
    
    /*******************************************************************************
        
        Clear array map
        
        Returns:
            void
        
     *******************************************************************************/
    
    public void clear ()
    {
        map.clear();
    }
    
    /*******************************************************************************
        
        Returns whether key exists or not
        
        Params:
            key = array key
            
        Returns:
            true if key exists, false otherwise
        
     *******************************************************************************/
    
    public ArrayMapKV dup ()
    {
        auto clone = new ArrayMapKV!(V, K, M)(map.default_size, map.load_factor);
        
        map.copy(clone.map);
        
        return clone;
    }
    
    /*******************************************************************************
        
        Returns whether key exists or not
        
        Params:
            key = array key
            
        Returns:
            true if key exists, false otherwise
        
     *******************************************************************************/
    
    bool exists ( K key )
    {   
        return map.exists(key);
    }
    
    /*******************************************************************************
        
        Free memory allocated by array map
        
        Using free on an array map leads to freeing of any memory allocated. The
        array map can't be reused anymore afterwards.
        
        Returns:
            void
        
     *******************************************************************************/
    
    public void free ()
    {
        map.free;
    }
    
    /*******************************************************************************
        
        Return number of elements stored in hashmap
        
        Returns:
            number of elements
        
     *******************************************************************************/
    
    public size_t length ()
    {
        return map.length;
    }

    /*******************************************************************************
        
        Returns element value associated with key
        
        Params:
            key = array key
            
        Returns:
            value of array key
        
     *******************************************************************************/
    
    public V opIndex ( K key )
    {
        return (map.get (key)).value;
    }

    /*******************************************************************************
        
        Put element to array map
        
        If the key does not yet exists the element is added otherwise the value of
        the existing element matching the key is replaced by the new value.
        
        Params:
            key = array key
            value = array value
        
        Returns:
            void
        
     *******************************************************************************/
    
    public void opIndexAssign ( V value, K key )
    {
        map.put(key, Element(key, value));
    }
    
    /***********************************************************************
        
        Return value associated with key
        
        Params:
            key = array key
        
        Returns:
            a pointer to the located value, or null if not found
    
    ************************************************************************/
    
    static if (M) public bool opIn_r ( K key )
    {
        return key in map;
    }
    else public V* opIn_r ( K key )
    {
        Element* e = key in map;
        
        if ( e !is null )
        {
            return &(*e).value;
        }
        
        return null;
    }
    
    /***********************************************************************
        
        Returns iterator with value as reference
    
        Be aware that the returned list is unordered and that the array map
        does not support iteration over the key of the element is this 
        would be very inefficent.
        
        Params:
            dg = delegate to pass values to
        
        Returns:
            delegate result
    
    ************************************************************************/
    
    public int opApply (int delegate(ref V value) dg)
    {
        int result = 0;
        
        foreach ( element; map.v_map )
            if ((result = dg(element.value)) != 0)
                break;
        
        return result;
    }
    
    /***********************************************************************
        
        Returns iterator with key and value as reference
    
        Be aware that the returned list is unordered and that the array map
        does not support iteration over the key of the element is this 
        would be very inefficent.
        
        Params:
            dg = delegate to pass key & values to
        
        Returns:
            delegate result
    
    ************************************************************************/
    
    public int opApply (int delegate ( ref K key, ref V value ) dg)
    {
        int result = 0;
        
        foreach ( element; map.v_map )
            if ((result = dg(element.key, element.value)) != 0) 
                break;
        
        return result;
    }

}

/*******************************************************************************

    Unittest

********************************************************************************/


debug (OceanUnitTest)
{
    import tango.util.log.Trace;
    import tango.core.Memory;
    import tango.time.StopWatch;
    import tango.core.Thread;
    import tango.util.container.HashMap;
    
    unittest
    {
        Trace.formatln("Running ocean.core.ArrayMap unittest");
        
        const uint iterations  = 5;
        const uint inserts     = 1_000_000;
        const uint num_threads = 1;
        
        /***********************************************************************
            
            ArrayMapKV Assertion Test
            
         ***********************************************************************/
        
        StopWatch   w;
        
        scope map = new ArrayMapKV!(uint, hash_t, Mutex.Disable)(100);
        
        map.put(1,11111);
        map.put(2,22222);
    
        assert(map[1] == 11111);
        assert(map[2] == 22222);
        
        assert(1 in map);
        assert(2 in map);
        
        assert(map.length == 2);
        
        map[3] = 33333;
        
        assert(map.length == 3);
        assert(map.get(3) == 33333);
        
        map.remove(3);
        assert((3 in map) == null);
        assert(map.length == 2);
        
        /***********************************************************************
            
            ArrayMap Assertion Test
            
         ***********************************************************************/
        
        scope array = new ArrayMap!(uint, hash_t, Mutex.Disable)(inserts);
        
        array[1111] = 2;
        array[2222] = 4;

        assert(array[1111] == 2);

        assert(array[2222] == 4);
        assert(1111 in array);
        assert(2222 in array);
        assert(array.length == 2);
        
        array[1111] = 3;
        
        assert(array[1111] == 3);
        assert(array.length == 2);

        array.remove(1111);
        assert((1111 in array) == null);
        assert(array.length == 1);
        
        /***********************************************************************
            
            Memory Test
            
         ***********************************************************************/
        
        Trace.formatln("running mem test...");
        
        for ( uint r = 1; r <= iterations; r++ )
        {
            array.clear();
            
            w.start;

            for ( uint i = ((inserts * r) - inserts); i < (inserts * r); i++ )
            {
                array[i] = i;
            }
            
            Trace.formatln  ("[{}:{}-{}]\t{} adds with {}/s and {} bytes mem usage", 
                    r, ((inserts * r) - inserts), (inserts * r), array.length, 
                    array.length/w.stop, GC.stats["poolSize"]);
        }
        
        w.start;
        uint hits = 0;
        uint* p;
        
        for ( uint i = ((inserts * iterations) - inserts); i < (inserts * iterations); i++ )
        {
            if ( i in array ) hits++;
        }
        Trace.formatln("inserts = {}, hits = {}", inserts, hits);
        assert(inserts == hits);
        
        Trace.format  ("{}/{} gets/hits with {}/s and ", array.length, hits, array.length/w.stop);
        Trace.formatln("mem usage {} bytes", GC.stats["poolSize"]);
        
        Trace.formatln("freeing memory allocated");
        Trace.formatln("");
        
        array.free;

        Thread.sleep(2);
    
        /***********************************************************************
            
            Multi-Threading Test
            
         ***********************************************************************/
        
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
