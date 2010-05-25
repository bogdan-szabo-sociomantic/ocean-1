/*******************************************************************************

    Associative array implementation

    Copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    Version:        May 2010: Initial release
                    
    Authors:        Lars Kirchhoff, Thomas Nicolai & David Eckhardt
    
********************************************************************************/

module ocean.core.ArrayMap;

/*******************************************************************************

    Imports
    
********************************************************************************/

private     import      ocean.io.digest.Fnv1;

private     import      tango.core.sync.ReadWriteMutex;

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
    ArrayMap!(char[]) array;
    
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

struct ArrayMap ( V, K = hash_t, bool M = Mutex.Disable )
{
    
    /*******************************************************************************
        
        Array element (key/value)
        
     *******************************************************************************/
    
    private struct BucketElement
    {
            K key;
            V value;
    }
    
    /*******************************************************************************
        
        Array element (key/value)
        
     *******************************************************************************/
    
    private struct Bucket
    {
            size_t length = 0;
            BucketElement[] elements;
    }

    /*******************************************************************************
        
        Array hashmap
        
     *******************************************************************************/
    
    private             Bucket[]                        hashmap;
    
    /*******************************************************************************
        
        Number of hashmap buckets
        
     *******************************************************************************/
    
    private             size_t                          num_buckets = 10_000;
    
    /*******************************************************************************
        
        Number of hashmap buckets
        
     *******************************************************************************/
    
    private             size_t                          bucket_size = 5;
    
    /*******************************************************************************
        
        Number of elements in array
        
     *******************************************************************************/
    
    private             size_t                          num_elements = 0;
    
    /*******************************************************************************
        
        Mutex & condition (multi-thread support)
        
     *******************************************************************************/
    
    static if (M)
    {
        private             ReadWriteMutex                  mutex;
    }
    
    /*******************************************************************************
        
        Sets number of buckets used

        Example configuration for 1.000.000 array elements
        ---
        num_buckets = 100_000;
        bucket_size = 10;
        ---
        
        Params:
            num_buckets = default number of allocated buckets
            bucket_size = default number of allocated elements per bucket
            
        Returns:
            void
            
     *******************************************************************************/
    
    public void buckets ( size_t num_buckets = 10_000, size_t bucket_size = 5 )
    {
        assert(num_buckets  >= 10, "min bucket size > 10");
        assert(this.num_elements ==  0, "no resize supported; invoke free() first");
        
        this.num_buckets = num_buckets;
        this.bucket_size = bucket_size;
        
        this.hashmap.length = num_buckets;
        
        static if (M) 
        {
            this.mutex = new ReadWriteMutex(ReadWriteMutex.Policy.PREFER_READERS);
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
        return this.findSync(key) != null;
    }
    
    /*******************************************************************************
        
        Reset and free memory used by array map
        
        Returns:
            void
        
     *******************************************************************************/
    
    public void free ()
    {
        static if (M) 
        {
            synchronized (this.mutex.writer) this.reset();
        }
        else
        {
            this.reset();
        }
    }
    
    /*******************************************************************************
        
        Remove single key
        
        Returns:
            true on success, false on failure
        
     *******************************************************************************/
    
    public bool remove ( K key )
    {
        hash_t h = (toHash(key) % this.num_buckets);

        static if (M) 
        { 
            synchronized (this.mutex.writer) return this.remove(h, key);
        }
        else 
        {
            return this.remove(h, key);
        }
    }
    
    /*******************************************************************************
        
        Return number of elements stored in hashmap
        
        Returns:
            number of elements
        
     *******************************************************************************/
    
    public size_t length ()
    {
        return this.num_elements;
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
        static if (M)
        {
            synchronized (this.mutex.writer) this.set(key, value);
        }
        else
        {
            this.set(key, value);
        }
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
        BucketElement* p = this.findSync(key);
        
        if ( p !is null )
        {
            return (*p).value;
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
    
    public V* opIn_r ( K key)
    {
        BucketElement* p = this.findSync(key);
        
        if ( p !is null )
        {
            return &(*p).value;
        }
        
        return null;
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
         static if (M) 
         {
             synchronized (this.mutex.reader) return this.iterate(dg);
         }
         else
         {
             return this.iterate(dg);
         }
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
         static if (M) 
         {
             synchronized (this.mutex.reader) return this.iterate(dg);
         }
         else
         {
             return this.iterate(dg);
         }
     }
     
     /*******************************************************************************
         
         Resizes hash map for better performance
         
         In case the load factor because too large the hash map needs to be resized.
         Enlarging the number of buckets requires the existing keys to be shifted 
         to their new bucket.
         
         TODO support hashmap resizing
              http://en.wikipedia.org/wiki/Hash_table#Dynamic_resizing
         
         Returns:
             void
         
      *******************************************************************************/
     
     public void resize () 
     {
         assert(false, `array map resize not yet supported`);
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
        
        Returns pointer to array element associated with key
        
        Params:
            key = array key
            
        Returns:
            pointer to element value, or null if not found
        
     *******************************************************************************/
    
    private BucketElement* findSync ( K key )
    {
        return this.findSync(key, (toHash(key) % this.num_buckets));
    }
    
    /*******************************************************************************
        
        Returns pointer to array element associated with key from bucket h
        
        Params:
            key = array key
            h = bucket position
            
        Returns:
            pointer to element value, or null if not found
        
     *******************************************************************************/
    
    private BucketElement* findSync ( K key, hash_t h )
    {
        static if (M)  
        {
            synchronized (this.mutex.reader) return this.findNoSync(key, h);
        }
        else
        {
            return this.findNoSync(key, h);
        }
    }
    
    /*******************************************************************************
        
        Returns pointer to array element associated with key from bucket h
        
        Params:
            key = array key
            h = bucket position
            
        Returns:
            pointer to element value, or null if not found
        
     *******************************************************************************/
    
    private BucketElement* findNoSync ( K key, hash_t h )
    {
        if (this.hashmap[h].length)
            foreach ( ref element; this.hashmap[h].elements )
                if ( element.key == key )
                    return &element;
        
        return null;
    }
    
    /*******************************************************************************
        
        Set array element
        
        Params:
            key = array key
            value = array value
        
        Returns:
            void
        
     *******************************************************************************/
    
    private void set ( K key, V value )
    {
        hash_t h = (toHash(key) % this.num_buckets);
        BucketElement* p = this.findNoSync(key, h);
        
        if ( p is null )
        {
            if ( this.hashmap[h].length % this.bucket_size == 0 )
            {
                 this.hashmap[h].elements.length = 
                 this.hashmap[h].length + this.bucket_size;
            }
            
            this.hashmap[h].elements ~= BucketElement(key, value);
            this.hashmap[h].length++;
            
            this.num_elements++;
        }
        else
        {
            (*p).value = value;
        }
    }
    
    /*******************************************************************************
        
        Reset and free memory used by array map
        
        Returns:
            void
        
     *******************************************************************************/
    
    private void reset ()
    {
        this.num_elements   = 0;
        this.hashmap.length = 0;
        this.hashmap.length = this.num_buckets;
    }
    
    /*******************************************************************************
        
        Remove single key
        
        Returns:
            true on success, false on failure
        
     *******************************************************************************/
    
    private bool remove ( hash_t h, K key )
    {
        BucketElement* p = this.findNoSync(key, h);

        if ( p !is null )
        {
            if ( this.hashmap[h].length == 1 )
            {
                this.hashmap[h].length = 0;
            }
            else
            {
                *p = this.hashmap[h].elements[this.hashmap[h].length - 1];
                this.hashmap[h].length = this.hashmap[h].length - 1;
            }
            
            this.num_elements--;
            
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
    
    private int iterate (int delegate(ref K key, ref V value) dg)
    {
        int result = 0;
        
        foreach ( ref bucket; this.hashmap )
            foreach ( ref element; bucket.elements )
                if ( element.key )
                    if ((result = dg(element.key, element.value)) != 0)
                        break;
        
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
    
    public int iterate (int delegate(ref V value) dg)
    {
        int result = 0;
        
        foreach ( ref bucket; this.hashmap )
            foreach ( ref element; bucket.elements )
                if ( element.key )
                    if ((result = dg(element.value)) != 0)
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
    
    unittest
    {
        Trace.formatln("Running ocean.core.ArrayMap unittest");
        
        const uint iterations  = 5;
        const uint inserts     = 1_000_000;
        const uint num_threads = 2;
        
        StopWatch   w;
        ArrayMap!(uint, hash_t, Mutex.Disable) array;
        
        array.buckets(50_000, 5);
        
        array[1111] = 2;
        array[2222] = 4;
        
        assert(array[1111] == 2);
        assert(array[2222] == 4);
        assert(1111 in array);
        assert(2222 in array);
        assert(array.length == 2);
        
        foreach ( key, value; array)
        {
            Trace.formatln("k = {}, v = {}", key, value);
        }
        
        array[1111] = 3;
        
        assert(array[1111] == 3);
        assert(array.length == 2);

        array.remove(1111);
        assert((1111 in array) == null);
        assert(array.length == 1);
        
        Trace.formatln("running mem test...");
        
        for ( uint r = 1; r <= iterations; r++ )
        {
            array.free();
            w.start;
            
            for ( uint i = (r * inserts - inserts); i < (r * inserts); i++ )
            {
                array[i] = i;
            }
            
            Trace.format  ("loop {}: {} adds with {}/s and ", r, array.length, array.length/w.stop);
            Trace.formatln("{} bytes mem usage", GC.stats["poolSize"]);
        }
        Trace.formatln("array.length ======== {}", array.length);
        w.start;
        uint hits = 0;
        uint* p;
        
        for ( uint i = (iterations * inserts - inserts); i < (iterations * inserts); i++ )
        {
            p = i in array;
            
            if ( p !is null )
            {
                assert(i == *p);
                hits++;
            }
        }
        
        assert(inserts == hits);
        
        Trace.format  ("{}/{} gets/hits with {}/s and ", array.length, hits, array.length/w.stop);
        Trace.formatln("mem usage {} bytes", GC.stats["poolSize"]);

        Trace.formatln("running mutex thread test...");
        
        void readWrite ()
        {
            uint run;
            Trace.formatln("readWrite thread started");
            while ( run++ < iterations )
            {
                
                for ( uint i = 0; i < inserts; i++ ) array.remove(i);
                for ( uint i = 0; i < inserts; i++ ) array[i] = i;
            }
        }
        
        void writeRead ()
        {
            uint run;
            Trace.formatln("writeRead thread started");
            while ( run++ < iterations )
            {
                for ( uint i = 0; i < inserts; i++ ) array[i] = i;
                for ( uint i = 0; i < inserts; i++ ) array.remove(i);
            }
        }
        
        scope group = new ThreadGroup;
        
        w.start;
        
        for( int i = 0; i < num_threads; ++i )
            group.create( &readWrite );
        
        for( int i = 0; i < num_threads; ++i )
            group.create( &writeRead );
        
        Trace.formatln("waiting threads to be finished");
        group.joinAll();
        
        Trace.format  ("{} threads with {} iterations {}/s", num_threads, num_threads * iterations * inserts * 2, (num_threads * iterations * inserts * 2)/w.stop);
    
        Trace.formatln("done unittest");
        Trace.formatln("");
    }
}