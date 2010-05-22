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

/*******************************************************************************  

    Implements associative array with consistent hashing. 
    
    Constisten hashing provides a performant way to add or remove array 
    elements without significantly change the mapping of keys to buckets. 
    By using consistent hashing, only k/n keys need to be remapped on 
    average. k is the number of keys and n is the number of buckets.
    
    Performance is dependent on the number of n stored entries and the 
    resulting load factor. The load factor is diretly influenced by n
    and s, its bucket size
    
    Buckets size
    
    Load factor
    
    The load factor specifies the ratio between the number of buckets and 
    the number of stored elements. A smaller load factor usually is better,
    nevertheless its also influenced by the memory allocation overhead.
    
    100.000 keys / 10.000 buckets = load factor 10
    
    Overall performance
    
    The current implementation offers a good overall performance, an
    array hashmap with 1.000.000 entries and 10_000 buckets shows the
    following performance:
    
    1.2  mio inserts/sec
    3.1  mio lookups/sec
    
    
    Assoc array usage example
    ---
    ArrayMap!(char[]) array;
    
    array.buckets(10_000, 5); // set number of buckets !!! important
    ---
    
    Add aa element
    ---
    t_hash key;
    char[] value;
    
    array[key] = value;
    ---
    
    Get aa element
    ---
    value = array[key];
    ---
    
    Reset and free the memory allocated
    ---
    array.free();
    ---
    
    Equal implementations can be found on the dsource website
    
    http://www.dsource.org/projects/dcollections/browser/trunk/dcollections
    http://www.dsource.org/projects/dcollections/browser/trunk/dcollections/Link.d
    http://www.dsource.org/projects/dcollections/browser/trunk/dcollections/HashMap.d
    http://www.dsource.org/projects/dcollections/browser/trunk/dcollections/Hash.d
    http://www.digitalmars.com/d/1.0/hash-map.html
    http://en.wikipedia.org/wiki/Consistent_hashing

*********************************************************************************/

struct ArrayMap ( V, K = hash_t )
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
        
        this.num_buckets    = num_buckets;
        this.bucket_size    = bucket_size;
        this.hashmap.length = num_buckets;
    }
    
    /*******************************************************************************
        
        Returns number of elements stored in hashmap
        
        Returns:
            number of elements
        
     *******************************************************************************/
    
    public size_t length ()
    {
        return this.num_elements;
    }
    
    /*******************************************************************************
        
        Resets and clears hashmap
        
        Returns:
            void
        
     *******************************************************************************/
    
    public void free ()
    {
        this.num_elements   = 0;
        this.hashmap.length = 0;
        this.hashmap.length = this.num_buckets;
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
        
        Returns whether key exists or not
        
        Params:
            key = array key
            
        Returns:
            true if key exists, false otherwise
        
     *******************************************************************************/
    
    bool exists ( K key )
    {
        return this.find(key) != null;
    }
    
    
    /*******************************************************************************
        
        Set array element
        
        Be aware not to use 0 as key!!!
        
        Params:
            key = array key
            value = array value
        
        Returns:
            void
        
     *******************************************************************************/
    
    public void opIndexAssign ( V value, K key )
    {
        hash_t h = (toHash(key) % this.num_buckets);
        V* p = this.find(key, h);
        
        if ( p is null )
        {
            if ( this.hashmap[h].length % this.bucket_size == 0 )
                this.hashmap[h].elements.length = this.hashmap[h].length + 
                                                  this.bucket_size;
            
            this.hashmap[h].elements ~= BucketElement(key, value);
            this.hashmap[h].length++;
            
            this.num_elements++;
        }
        else
        {
            *p = value;
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
        V* p = this.find(key);
        
        if ( p !is null )
        {
            return *p;
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
        V* p = this.find(key);
        
        if ( p !is null )
        {
            return p;
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

     final int opApply (int delegate(ref K key, ref V value) dg)
     {
         int result = 0;
         
         foreach ( ref bucket; this.hashmap )
             foreach ( ref element; bucket.elements )
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

     final int opApply (int delegate(ref V value) dg)
     {
         int result = 0;
         
         foreach ( ref bucket; this.hashmap )
             foreach ( ref element; bucket.elements )
                 if ((result = dg(element.value)) != 0)
                     break;
         
         return result;
     }
     
    /*******************************************************************************
        
        Returns pointer to array element associated with key
        
        Params:
            key = array key
            
        Returns:
            pointer to element value, or null if not found
        
     *******************************************************************************/
    
    private V* find ( K key )
    {
        return this.find(key, (toHash(key) % this.num_buckets));
    }
    
    /*******************************************************************************
        
        Returns pointer to array element associated with key from bucket h
        
        Params:
            key = array key
            h = bucket position
            
        Returns:
            pointer to element value, or null if not found
        
     *******************************************************************************/
    
    private V* find ( K key, hash_t h )
    {
        if (this.hashmap[h].length)
        {
            foreach ( ref element; this.hashmap[h].elements )
                if ( element.key == key )
                    return &element.value;
        }
        
        return null;
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
    
    private void resize () {}
    
}


/*******************************************************************************

    Unittest

********************************************************************************/

debug (OceanUnitTest)
{
    import tango.util.log.Trace;
    import tango.core.Memory;
    import tango.time.StopWatch;
    
    unittest
    {
        Trace.formatln("ArrayMap unittest");
        
        StopWatch   w;
        ArrayMap!(uint) array;
        
        array.buckets(10_000);
        
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

        for ( uint n = 0; n < 5; n++ )
        {
            array.free();
            w.start;
            
            for ( uint i = 0; i < 1_000_000; i++ )
            {
                array[i] = i;
            }
            
            Trace.formatln ("{} adds: {}/s", array.length, array.length/w.stop);
            Trace.formatln ("memory usage = {} bytes", GC.stats["poolSize"]);
        }
        
        w.start;
        uint hits = 0;
        uint* p;
        
        for ( uint i=0; i <= 5_000_000; i++ )
        {
            p = i in array;
            
            if ( p !is null )
            {
                assert(i == *p);
                hits++;
            }
        }
        
        Trace.formatln ("mem usage {} bytes", GC.stats["poolSize"]);
        Trace.formatln ("array.length = {} gets = {}/s with {} hits", array.length, array.length/w.stop, hits);

    }
}