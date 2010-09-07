module io.device.queue.storage.Memory;


private import ocean.io.device.queue.storage.model.IStorageEngine;
private import tango.core.Exception;
private import tango.io.device.Conduit;


class Memory : IStorageEngine
{
    private void[] data;
    private size_t position;
    /***************************************************************************
        
        Constructs a Memory object
        
        Params:
            size = Size of the memory object
            
    ***************************************************************************/

    this(size_t size)
    {
        this.init(size);
    }
        
    /***************************************************************************
    
        Resets the size of the memory object. 
        Warning! You loose all data.
        
        Params:
            size = new size of the memory object
            
    ***************************************************************************/
        
    final void init(size_t size)
    {
        this.data.length = size;
    }
    
    /***************************************************************************
    
        Reads the data from the provided conduit.
        Size must be set accordingly.
        
        Params:
            conduit = the conduit to read from
            
    ***************************************************************************/
    
    void readFromConduit ( Conduit conduit )
    {        
        if(auto len = conduit.read(this.data) != Conduit.Eof)
        {
           assert(false,"buffer size to small");
        }
            
    }
    
    /***************************************************************************
        
        Writes the content of this memory object to the provided conduit
        
        Params:
            conduit = the conduit to write to
            
    ***************************************************************************/
    
    void writeToConduit(Conduit conduit)
    {
        
    }
    
    /***************************************************************************
    
        Writes data to the memory object
        
        Returns:
            amount of bytes written
            
        Params:
            data = data to write
            
    ***************************************************************************/
    
    final public size_t write(void[] data)
    {
        if(data.length <= this.data.length-this.position)
        {
            this.data[this.position..this.position+data.length] = data;
            return data.length;
        }
                
        this.data[this.position..$] = data[0..this.data.length-this.position];
        return this.data.length-this.position;        
        
    }
    /***************************************************************************
        
        Reads data from the memory object
        
        Returns:
            the requested data
            
        Params:
            amount = the amount of bytes to read
            
    ***************************************************************************/
    
    final public void[] read(size_t amount)
    {
        if(amount > this.data.length-this.position)
        {
            return this.data[this.position..$];
        }
        return this.data[this.position..this.position+amount];    
    }

    /***************************************************************************
        
        Sets the read/write position in the object
        
        Returns:
            the new read/write position
            
        Params:
            offset = the requested read/write position
            
    ***************************************************************************/
    
    final public size_t seek(size_t offset)
    {
        if(offset > this.data.length)
        {
            this.position = this.data.length;
        }
        else
        {
            this.position = offset;
        }
        
        return this.position; 
    }
    
    /***************************************************************************
    
        current size of the memory object
        
        Returns:
            current size of the memory object            
            
    ***************************************************************************/
    
    final public size_t size()
    {
        return data.length;    
    }

    unittest
    {
        scope storage = new Memory(5);
        assert(storage.size == 5);
        storage.write("12345");
        assert(storage.read(5) == "12345");
    
    }
}

