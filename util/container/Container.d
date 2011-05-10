module ocean.util.container.Container;


private import ocean.core.Pool;


struct PoolHeap ( T )
{
    private alias Pool!(T) PoolType;

    private PoolType pool;

    private PoolType poolInstance ( )
    {
        if ( pool is null )
        {
            pool = new PoolType;
        }
        return pool;
    }

    /***************************************************************

        allocate a T sized memory chunk
            
    ***************************************************************/

    T* allocate ()
    {
        return poolInstance.get;
    }

    /***************************************************************

        Invoked when a specific T* is discarded

    ***************************************************************/

    void collect (T* p)
    {
        if ( p )
        {
            poolInstance.recycle(p);
        }
    }

    /***************************************************************

        Invoked when clear/reset is called on the host. 
        This is a shortcut to clear everything allocated.

        Should return true if supported, or false otherwise. 
        False return will cause a series of discrete collect
        calls

    ***************************************************************/

    bool collect (bool all = true)
    {
        poolInstance.clear;
        return true;
    }
}
