module io.device.queue.RingQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.device.model.IPersistQueue;

private import ocean.io.device.queue.storage.model.IStorageEngine;

private import ocean.io.device.queue.storage.Memory;

private import tango.io.device.Conduit;

debug private import tango.io.Stdout;


final class RingQueue : PersistQueue
{
    private IStorageEngine storageEngine;
    
    /***************************************************************************
    
        Location of the gap at the rear end of the buffer
        where the unused space starts

    ***************************************************************************/        
    
    private size_t gap;
  
    /***************************************************************************
     
        Flag enumeration for comfortable selection of the storage engine

    ***************************************************************************/    
    
    public enum EngineFlag
    {
        Memory,File
    };
        
    
    struct Header
    {
        static Header header(size_t length)
        {
            Header h; h.length = length; 
            return h;
        }
        size_t length;
    };  
    
    
    
    /***************************************************************************
    
        Constructor
    
        Params:
            name = name of queue (for logging)
            storage = storage engine to use 
    
        Note: the name parameter may be used be derived classes to denote a file
        name, ip address, etc.

    ***************************************************************************/
        
    public this(char[] name, IStorageEngine storage)
    {
        super(name,storage.size);
        this.storageEngine = storage;
        this.gap = storage.size;
    }
    
    
    /***************************************************************************
    
        Constructor
    
        Params:
            name = name of queue (for logging)
            max = max queue size (bytes)
            flag = flag to choose the storage engine
    
        Note: the name parameter may be used be derived classes to denote a file
        name, ip address, etc.

    ***************************************************************************/
        
    public this(char[] name, uint max,EngineFlag flag=EngineFlag.Memory)
    {
        super(name,max);    
        assert(flag == EngineFlag.Memory,"Only memory implemented so far");
        this.storageEngine = new Memory(max); 
        this.gap = max;    
        
    }
    

    /***************************************************************************
    
        Calculates the size (in bytes) an item would take if it
        were pushed to the queue. 
        
        Params:
            data = data of which the queue-size should be returned
            
        Returns:
            bytes that data will claim in the queue

    ***************************************************************************/

    public uint pushSize ( void[] data )
    {        
        return Header.sizeof+data.length;
    }
    
    /***************************************************************************

        Pushes a single item to the queue. 
        
        Params:
            item = item that will be pushed on the queue

    ***************************************************************************/

    protected void pushItem ( void[] item )
    {        
        debug Stdout.format("pushing {} now",cast(char[])item).newline;
        if(this.needsWrapping(item))
        {   // writing to the beginning of our storage
            // the calling function made sure it will fit.
            this.gap = super.write_to;
            super.write_to = 0;
            
            debug Stdout("wrapping!");
        }
        with(this.storageEngine)
        {
            seek(super.write_to);
            write((cast(void*)&Header.header(item.length))[0..Header.sizeof]);
            seek(super.write_to+Header.sizeof);
            write(item);
        }
        
        this.write_to+=this.pushSize(item);
        ++super.items;         
        
        debug Stdout.format("Items now {}",super.items).newline;
    }
    
    /***************************************************************************
    
        Gets the amount of data stored in the queue.
        
        Returns:
            bytes stored in queue
            
    ***************************************************************************/
        
    public uint usedSpace()
    {
        if(items == 0)
        {
            return 0;
        }
        if(super.write_to > super.read_from)
        {
            return super.usedSpace();
        }
        
        return this.gap-super.read_from + super.write_to;
        
    }
    
    /**********************************************************************
        
        Returns true if queue is full (write position >= end of queue)
    
        TODO: change to > 99% full? or < 1K free?
        
        Returns:
            true when there is no free space left
        
    **********************************************************************/

    public bool isFull()
    {
        return this.freeSpace() == 0;
    }
    
    /***************************************************************************
    
        Gets the amount of free space at the end of the queue.
        
        Returns:
            bytes free in queue
            
    ***************************************************************************/
        
    public uint freeSpace()
    {
        return super.dimension - this.usedSpace; 
    }
    
    /***************************************************************************

        Pops a single item from the queue. 
        
        Returns:
            the popped item
    
    ***************************************************************************/

    protected void[] popItem ( )
    {
        this.storageEngine.seek(super.read_from);
        Header* header=cast(Header*)this.storageEngine.read(Header.sizeof);
        
        this.storageEngine.seek(super.read_from+header.sizeof);
        void[] data = this.storageEngine.read(header.length);
        
        super.read_from += header.sizeof + header.length;
        
        // check whether there is an item at this offset
        if(super.read_from >= this.gap)
        {   // if no, set it to the beginning (wrapping around)
            super.read_from = 0;
            this.gap = this.dimension;
        }
        else if(super.read_from >= super.dimension)
        {
            super.read_from = 0;
        }
        --super.items;
        
        return data;
    }
    
    /***************************************************************************

        Finds out whether the provided data needs to be wrapped 
        
        Params:
            data = the data that should be checked
            
        Returns:
            true if the data needs wrapping, else false

    ***************************************************************************/

    private bool needsWrapping(void[] data)
    {
        return this.pushSize(data)+super.write_to > super.dimension;           
    }
    
    /***************************************************************************

        Finds out whether the provided data will fit in the queue. 
        Also considers the need of wrapping. 
        
        Params:
            data = data to check 
            
        Returns:
            true when the data fits, else false

    ***************************************************************************/
    
     
    public bool willFit ( void[] data)
    {
      //  debug Stdout("called willfit").newline;

        // check if the dimension is big enough when it's empty
        if(super.items == 0 && super.dimension >= this.pushSize(data))
        {
            debug Stdout("called willfit1").newline;
            return true;
        }
        if(this.needsWrapping(data))
        {
            debug Stdout.format("called willfit2, writeto: {}, pushsize {}",write_to,pushSize(data)).newline;
            // check if there is enough space at the beginning
            return super.read_from >= this.pushSize(data);
        }
        if(super.read_from < super.write_to)
        {
            debug Stdout("called willfit4").newline;
            return super.dimension-super.write_to >= this.pushSize(data);
        }
        // check if there is enough space between the new and old data
        if(super.read_from > super.write_to)
        {
            debug Stdout("called willfit3").newline;
            return super.read_from-super.write_to >= this.pushSize(data);
        }
        if(super.read_from == super.write_to && super.items != 0)
        {
            return false;
        }
        
                
        assert(false,"Not considered case happened");                
    }
    
    
    /***************************************************************************
    
        Opens the queue given an identifying name. Should
        create any data containers needed. This method is called by the
        PersistQueue constructor.
            
        Params:
            name = name of the queue to open

    ***************************************************************************/

    public void open ( char[] name )
    {
        super.setName=name;
        super.readFromFile();
    }
    
    /***************************************************************************
    
        this method is not needed.
    
    ***************************************************************************/
    
    public void cleanupQueue()
    {
        return;
    }
        
    /***************************************************************************
    
        This method is not needed.
    
    ***************************************************************************/

    public bool isDirty ( ) 
    { 
        return false; 
    }
    
    
    /***************************************************************************
    
        Copies the contents of the queue from the passed conduit.
    
        Params:
            conduit = conduit to read from

    ***************************************************************************/
    
    protected void readFromConduit ( Conduit conduit )
    {           
       
        this.storageEngine.init(this.dimension);
        this.storageEngine.readFromConduit(conduit);
    }
    /***************************************************************************
    
        Dumps the data in an linar way to the conduit
    
        Params:
            conduit = conduit to write to
    
    ***************************************************************************/

    protected void writeToConduit ( Conduit conduit )
    {
        assert(false,"Not yet implemented");
    }

    
    debug public void validateContents
      (bool show_summary, char[] message = "", bool show_contents_size = false )
    {
        
    }
                                   

    
    
}

debug( OceanUnitTest)
{
    unittest
    {
        scope queue = new RingQueue("test1",(9+RingQueue.Header.sizeof)*10);
        assert(!queue.isFull);
        assert(queue.isEmpty);
        
        assert(queue.push("Element 1"));                
        assert(queue.pop() == "Element 1");
        assert(queue.items == 0);
        assert(!queue.isFull);
        assert(queue.isEmpty);
        assert(queue.usedSpace() == 0);
        
        assert(queue.push("Element 1"));        
        assert(queue.push("Element 2"));
        assert(queue.push("Element 3"));
        assert(queue.push("Element 4"));
        assert(queue.push("Element 5"));
        assert(queue.push("Element 6"));
        assert(queue.push("Element 7"));
        assert(queue.push("Element 8"));
        assert(queue.push("Element 9"));
        assert(queue.push("Element10"));
        
        assert(queue.size() == 10);        
        assert(queue.isFull);
        assert(!queue.isEmpty);
        
        assert(!queue.push("more"));
        assert(queue.size() == 10);
        
        
        /*********************************
        Testing state
           
           [ ### ]
          
        *********************************/
        
        scope middle = new RingQueue("test2",5*5);        
        middle.push("1");        
        middle.push("2");
        middle.push("3");
        middle.push("4");
        assert(middle.pop == "1");        
        assert(middle.read_from == 5);
        assert(middle.write_to == 5*4);
        assert(middle.freeSpace() == 5*2);
        assert(middle.push("5"));
        assert(middle.push("6"));
        assert(middle.freeSpace() == 0);
    }
}