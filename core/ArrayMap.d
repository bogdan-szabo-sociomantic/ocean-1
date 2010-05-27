/*******************************************************************************

    Array HashMap

    Copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    Version:        May 2010: Initial release
                    
    Authors:        Thomas Nicolai
    
********************************************************************************/

module ocean.core.ArrayMap;

/*******************************************************************************

    Imports
    
********************************************************************************/

private     import      ocean.io.digest.Fnv1;

private     import      tango.stdc.posix.pthread;

/*******************************************************************************

    Mutex support for multithreading
    
    Enable  = enable multi thread support
    Disable = disable multi thread support (faster)

********************************************************************************/

struct Mutex
{
        const bool Enable  = true;
        const bool Disable = false;
}

/*******************************************************************************  

    Implements associative array with consistent hashing. 
    
    Consistent hashing provides a performant way to add or remove array 
    elements without significantly change the mapping of keys to buckets. By 
    using consistent hashing, only k/n keys need to be remapped on average: 
    k is the number of keys and n is the number of buckets. The performance 
    depends on the number of n stored entries and the resulting load factor. 
    The load factor is diretly influenced by n and s, its bucket size.
    
    Multithread support
    ---
    By providing the -version=Thread switch at compile time the array map
    can be used by multiple threads at the same time. Be aware that this 
    influcences the overall performance.
    ---
    
    Load factor
    ---
    The load factor specifies the ratio between the number of buckets and 
    the number of stored elements. A smaller load factor usually is better,
    nevertheless its also influenced by the memory allocation overhead.
    
    100.000 keys / 10.000 buckets = load factor 10
    ---
    
    Performance
    ---
    The current implementation offers a good overall performance. An 
    array hashmap with 1.000.000 uint elements and 20.000 buckets shows 
    the following performance metrics:
    
    2.8 mio inserts/sec
    5.2 mio lookups/sec
    ---
    
    Template Parameter
    ---
    V = type of value stored in array map
    K = type of key stored in array map (must be of simple type)
    M = enable/disable mutex
    ---
    
    Usage example for array without thread support
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
    
    Usage example for array without thread support
    ---
    ArrayMap!(char[], hash_t, Mutex.Enable) array;
    
    array.buckets(20_000, 5); // set number of buckets !!! important
    ---

*********************************************************************************/

class ArrayMap ( V, K = hash_t, bool M = Mutex.Disable )
{
    
    /*******************************************************************************
        
        Hashmap bucket key element
        
        key = key of array element
        pos = position of value in the value map
        
     *******************************************************************************/
    
    private struct KeyElement
    {
            K  key;
            uint pos;
    }

    /*******************************************************************************
        
        Hashmap bucket
        
        length   = number of key elemens in bucket
        elements = list of key elements
        
     *******************************************************************************/
    
    private struct Bucket
    {
            uint length = 0;
            KeyElement[] elements;
            
            static if (M) pthread_rwlock_t rwlock;
    }
    
    /*******************************************************************************
        
        Hashmap; storing the key indices
        
        Hashmap only stores the key indicies as well as the position of the value
        inside the value map.
        
     *******************************************************************************/
    
    private             Bucket[]                        k_map;
    
    /*******************************************************************************
        
        ValueMap
        
        Value map stores keys and values to be able to find the key element once
        a record gets deleted. otherwise removing a key would be very inefficient.
        
     *******************************************************************************/
    
    private             V[]                             v_map;
    
    /*******************************************************************************
        
        Number of buckets 
        
        Number of buckets is based on size of hashmap and the load factor. Usually
        a loadfactor around 0.75 is perfect.
        
     *******************************************************************************/
    
    private             uint                            buckets_length;
    
    /*******************************************************************************
        
        Number of hashmap bucket elements allocated at once
        
        Allocating more than one element at a time improves performance a lot.
        Nevertheless, allocating to much at once kills performance.
        
     *******************************************************************************/
    
    private             uint                            default_alloc_size = 1;

    /*******************************************************************************
        
        Default size of array map
        
     *******************************************************************************/
    
    private             uint                            default_size = 1_000;
    
    /*******************************************************************************
        
        Number of array elements stored
        
     *******************************************************************************/
    
    private             uint                            len;
    
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
    
    public this ( uint default_size = 10_000, float load_factor = 0.75 )
    {
        this.v_map.length   = default_size;
        this.default_size   = default_size;
        this.buckets_length = cast(int) (default_size / load_factor);
        this.k_map.length   = this.buckets_length;
        
        this.setAllocSize(load_factor);
        
        foreach ( ref bucket; this.k_map ) 
        {
            bucket.elements.length = this.default_alloc_size;
            
            static if (M) 
            {
                pthread_rwlock_init(&bucket.rwlock, null);
            }
        }
    }
    
    /*******************************************************************************
        
        Destructor; free memory used by hashmap
            
        Returns:
            void
            
     *******************************************************************************/
    
    public ~this () 
    {
        static if (M)
        {
            foreach ( ref bucket; this.k_map) 
                pthread_rwlock_destroy(&bucket.rwlock);
        }
        
        this.clear();
        this.free_();
    }
    
    /*******************************************************************************
        
        Clear array map
        
        Returns:
            void
        
     *******************************************************************************/
    
    public void clear ()
    {
        this.len = 0;
        
        foreach ( ref bucket; this.k_map ) 
        {
            this.writeLock ( &bucket, {bucket.length = 0;});
        }
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
        return this.findValueSync(key) != null;
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
        this.clear();
        this.free_();
    }
    
    /*******************************************************************************
        
        Remove single key
        
        Params:
            key = key of element to remove
            
        Returns:
            void
        
     *******************************************************************************/
    
    public void remove ( K key )
    {
        hash_t h = (toHash(key) % this.buckets_length);

        this.writeLock (&this.k_map[h], {this.remove_(h, key);});
    }
    
    /*******************************************************************************
        
        Return number of elements stored in hashmap
        
        Returns:
            number of elements
        
     *******************************************************************************/
    
    public uint length ()
    {
        return this.len;
    }
    
    /*******************************************************************************
        
        Set array element
        
        Params:
            key = array key
            value = array value
        
        Returns:
            void
        
     *******************************************************************************/
    
    public void opIndexAssign ( V value, K key )
    {
        this.set(key, value);
    }
    
    /*******************************************************************************
        
        Returns element value associated with key
        
        Params:
            key = array key
            
        Returns:
            value of array key
        
     *******************************************************************************/
    
    public V opIndex( K key )
    {
        V* v = this.findValueSync(key);
        
        if ( v !is null )
        {
            return *v;
        }
        
        assert(false, "key doesn't exist");
    }
    
    /***********************************************************************
    
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
    
    ************************************************************************/
    
    static if (M) public V* opIn_r ( K key )
    {
        V* v = this.findValueSync(key);
        
        if ( v !is null )
        {
            return v;
        }
        
        return null;
    }
    else public bool opIn_r ( K key )
    {
        V* v = this.findValueSync(key);
        
        if ( v !is null )
        {
            return true;
        }
        
        return false;
    }
    
    /***********************************************************************
        
        Returns iterator with key and value as reference
    
        Be aware that the returned list if unordered.
        
        Params:
            dg = iterator delegate
        
        Returns:
            array keys and values
    
    ************************************************************************/

     public int opApply (int delegate(ref K key, ref V value) dg)
     {
         return this.iterate(dg);
     }
     
     /***********************************************************************
         
         Returns iterator with value as reference
     
         Be aware that the returned list if unordered.
         
         Params:
             dg = iterator delegate
         
         Returns:
             array values
     
     ************************************************************************/

     public int opApply (int delegate(ref V value) dg)
     {
         return this.iterate(dg);
     }
     
     /*******************************************************************************
         
         Rehash key map
         
         Optimizes the key map map in case the load factor is larger than 0.75.
         
         Params:
             key = key to return hash
             
         Returns:
             hash
         
      *******************************************************************************/
     
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
     
     /*******************************************************************************
         
         Returns hash for given string
         
         Params:
             key = key to return hash
             
         Returns:
             hash
         
      *******************************************************************************/
     
     public hash_t toHash ( K key )
     {
         static if ( is(K : hash_t) )
         {
             return key;
         }
         else
         {
             return Fnv1a32.fnv1(key); // or Fnv1a64???
         }
     }
     
    /*******************************************************************************
        
        Returns pointer to array element value
        
        Params:
            key = array key
            
        Returns:
            pointer to element value, or null if not found
        
     *******************************************************************************/
    
    private V* findValueSync ( K key )
    {
        return this.findValueSync(key, (toHash(key) % this.buckets_length));
    }
    
    /*******************************************************************************
        
        Returns pointer to array element value
        
        Params:
            key = array key
            h = bucket position
            
        Returns:
            pointer to element value, or null if not found
        
     *******************************************************************************/
    
    private V* findValueSync ( K key, hash_t h )
    {
        static if (M)
        {
            pthread_rwlock_rdlock(&this.k_map[h].rwlock);
            scope (failure) pthread_rwlock_unlock(&this.k_map[h].rwlock); 
        }
        
        return this.findValue(key, h);
    }
    
    /*******************************************************************************
        
        Returns pointer to array element value
        
        Params:
            key = array key
            h = bucket position
            
        Returns:
            pointer to element value, or null if not found
        
     *******************************************************************************/
    
    private V* findValue ( K key, hash_t h )
    {
        for ( uint i = 0; i < this.k_map[h].length; i++ )
            if ( this.k_map[h].elements[i].key == key )
                return &(this.v_map[this.k_map[h].elements[i].pos]);
        
        return null;
    }
    
    /*******************************************************************************
        
        Returns pointer to value bucket
        
        Params:
            key = array key
            h = bucket position
            k = key element pointer to be set to position of element found
            v = value element pointer to be set to position of element found
            
        Returns:
            pointer to value bucket, or null if not found
        
     *******************************************************************************/
    
    private void findBucket ( in K key, in hash_t h, out KeyElement* k, out V* v )
    {
        for ( uint i = 0; i < this.k_map[h].length; i++ )
        {
            if ( this.k_map[h].elements[i].key == key )
            {
                v = &this.v_map[this.k_map[h].elements[i].pos];
                k = &this.k_map[h].elements[i];
                
                break;
            }
        }
    }
    
    /*******************************************************************************
        
        Set array element

        Params:
            key = array key
            value = array value
        
        Returns:
            void
        
     *******************************************************************************/
    
    private void set ( in K key, in V value )
    {
        hash_t h = (toHash(key) % this.buckets_length);
        
        this.writeLock ( &this.k_map[h],
        {
            V* p = this.findValue(key, h);
            
            if ( p is null )
            {
                    this.resizeBucket(h);
                    this.resizeMap();

                    this.v_map[this.len] = value;
                    this.k_map[h].elements[this.k_map[h].length] = KeyElement(key, this.len);
                
                    this.k_map[h].length++;
                    
                    static if (M) this.length_(true); else this.len++;
            }
            else
            {
                (*p) = value;
            }
        });
    }
    
    /*******************************************************************************
        
        Reset and free memory used by array map
        
        Returns:
            void
        
     *******************************************************************************/
    
    private void free_ ()
    {
        this.k_map.length = 0;
        this.v_map.length = 0;
    }
    
    /*******************************************************************************
        
        Resizes and allocates new memory in case the map runs out of memory
        
        Enlarges map by 10 percent. TODO Rehashing of key map still needs to be 
        implemented in order to keep speed up with the resizing of the value map.
        
        Returns:
            true on success, false on failure
        
     *******************************************************************************/
    
    private void resizeMap ()
    {
        if ( this.len && this.len % this.default_size == 0 )
        {
            synchronized
            {
                this.default_size = this.v_map.length + 
                                    cast(uint)(this.default_size/10);
                
                this.v_map.length = this.default_size;
            }
        }
    }
    
    /*******************************************************************************
        
        Resizes bucket
        
        Enlarges bucket length by certain amout of space by allocating a range of
        memory instead of just allocating the next element.
        
        Returns:
            void
        
     *******************************************************************************/
    
    private void resizeBucket ( hash_t h )
    {
        if ( this.k_map[h].length >= this.default_alloc_size && 
             this.k_map[h].length % this.default_alloc_size == 0 )
        {
                this.k_map[h].elements.length = this.k_map[h].length + 
                                                this.default_alloc_size;
        } 
    }
    
    /*******************************************************************************
        
        Remove single key
        
        Moves last key element to position of element to be removed if number 
        of elements in bucket is larger than 1, otherwise the bucket length is 
        set to 0. 
        
        Returns:
            true on success, false on failure
        
     *******************************************************************************/
    
    private bool remove_ ( hash_t h, K key )
    {
        KeyElement* k;
        V* v;
        
        this.findBucket(key, h, k, v);
        
        if ( k !is null && v !is null )
        {
            if ( this.k_map[h].length == 1 )
            {
                this.k_map[h].length = 0;
            }
            else
            {
                *k = this.k_map[h].elements[this.k_map[h].length - 1];
                this.k_map[h].length = this.k_map[h].length - 1;
            }
            
            if ( this.len == 1 )
            {
                this.v_map.length = 0;
            }
            else
            {
                *v = this.v_map[this.len-1];
            }
            
            static if (M) this.length_(false); else this.len--;

            return true;
        }
        
        return false;
    }
    
    /***********************************************************************
        
        Increases or decreases length
        
        The synchronization is necessary in case two threads changing
        different buckets and therefore changing the overall length.
        
        Params:
            bool = true to increment length, false to decrement length
        
        Returns:
            array keys and values
    
    ************************************************************************/
    
    synchronized private void length_ ( bool inc = true )
    {
        inc ? this.len++ : this.len--;
    }
    
    /***********************************************************************
        
        Returns iterator with key and value as reference
    
        Be aware that the returned list if unordered.
        
        Params:
            dg = iterator delegate
        
        Returns:
            array keys and values
    
    ************************************************************************/
    
    private int iterate (int delegate(ref K key, ref V value) dg)
    {
        int result = 0;
        
        foreach ( ref bucket; this.k_map )
        {
            static if (M)
            {
                pthread_rwlock_rdlock(&bucket.rwlock);
                scope (failure) pthread_rwlock_unlock(&bucket.rwlock); 
            }
            
            for ( uint i = 0; i < bucket.length; i++ )
                if ((result = dg(bucket.elements[i].key, 
                        this.v_map[bucket.elements[i].pos])) != 0)
                    break;
            
            static if (M) pthread_rwlock_unlock(&bucket.rwlock);
        }
        
        return result;
    }
    
    /***********************************************************************
        
        Returns iterator with value as reference
    
        Be aware that the returned list if unordered.
        
        Params:
            dg = iterator delegate
        
        Returns:
            array values
    
    ************************************************************************/
    
    private int iterate (int delegate(ref V value) dg)
    {
        int result = 0;
        
        foreach ( ref bucket; this.k_map )
        {
            static if (M)
            {
                pthread_rwlock_rdlock(&bucket.rwlock);
                scope (failure) pthread_rwlock_unlock(&bucket.rwlock); 
            }
            
            for ( uint i = 0; i < bucket.length; i++ )
                if ((result = dg(this.v_map[bucket.elements[i].pos])) != 0)
                    break;
            
            static if (M) pthread_rwlock_unlock(&bucket.rwlock);
        }
        
        return result;
    }
    
    /***********************************************************************
        
        Set allocation size
    
        Default alloc size is based on the load factor but 5 it is usally 
        best when the load factor gets larger than 2.
        
        Params:
            dg = iterator delegate
        
        Returns:
            array values
    
    ************************************************************************/

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
    
    /***********************************************************************
        
        Locks code for write operation
        
        Only one write operation can happen at the same time
        
        Params:
            dg = anonymus delegete (just some code section)
            
        Returns:
            void
        
     ***********************************************************************/
    
    private void writeLock ( Bucket* bucket, void delegate() dg )
    {
        static if (M) 
        {
            pthread_rwlock_wrlock(&bucket.rwlock);
            
            scope (exit) pthread_rwlock_unlock(&bucket.rwlock);
        }   
        
        dg();
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
    
    unittest
    {
        Trace.formatln("Running ocean.core.ArrayMap unittest");
        
        const uint iterations  = 1000;
        const uint inserts     = 1000000;
        const uint num_threads = 5;

        /***********************************************************************
            
            Assertion Test
            
         ***********************************************************************/
        
        StopWatch   w;
        
        scope array = new ArrayMap!(uint, hash_t, Mutex.Disable)(1_000_000);
        
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
            
            Thread hashmap test function
                
            Returns:
                void
            
         ***********************************************************************/
        
        scope arraym = new ArrayMap!(uint, hash_t, Mutex.Enable)(1_000_000);
        scope group  = new ThreadGroup;
        
        void threadFunc ()
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
    
        Trace.formatln("running mutex thread test...");

        w.start;
        
        for( int i = 0; i < num_threads; ++i )
            group.create( &threadFunc );
        
        group.joinAll();

        Trace.formatln  ("{} array elements found after thread iteration", arraym.length);
        Trace.formatln  ("{} threads with {} iterations {}/s", num_threads, 
                num_threads * iterations * inserts, (num_threads * iterations * inserts)/w.stop);
    
        Trace.formatln("done unittest");
        Trace.formatln("");

    }
}