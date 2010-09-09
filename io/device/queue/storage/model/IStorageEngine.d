module io.device.queue.storage.model.IStorageEngine;


/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.io.device.Conduit;

interface IStorageEngine
{
    /***************************************************************************
    
        Writes data to the Storage Engine
        
        Returns:
            amount of bytes written
            
        Params:
            data = data to write
            
    ***************************************************************************/
    
    public size_t write(void[] data);
    
    /***************************************************************************
        
        Reads data from the StorageEngine object
        
        Returns:
            the requested data
            
        Params:
            amount = the amount of bytes to read
            
    ***************************************************************************/
    
    public void[] read(size_t amount);
    
    /***************************************************************************
        
        Writes the content of the Storage Engine object to the provided conduit
        
        Params:
            conduit = the conduit to write to
            
    ***************************************************************************/
    
    public void writeToConduit(Conduit);
    
    /***************************************************************************
    
        Initializes the StorageEngine from the provided conduit.
        Size must be set accordingly.
        
        Params:
            conduit = the conduit to read from
            
    ***************************************************************************/
    
    public void readFromConduit(Conduit);
    
    /***************************************************************************
        
        Sets the read/write position in the object
        
        Returns:
            the new read/write position
            
        Params:
            offset = the requested read/write position
            
    ***************************************************************************/
    
    public size_t seek(size_t offset);
    
    /***************************************************************************
    
        current size of the memory object
        
        Returns:
            current size of the memory object            
            
    ***************************************************************************/
    
    public size_t size();
    
    /***************************************************************************
        
        (Re)sets the size of the object. 
        Warning! You lose all data.
        
        Params:
            size = new size of the memory object
            
    ***************************************************************************/
        
    public void init(size_t size);
};