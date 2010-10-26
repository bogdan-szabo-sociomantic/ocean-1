/******************************************************************************

    Interface for StorageEngines

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        Sep 2010: Initial release

    authors:        Mathias Baumann

*******************************************************************************/

module io.device.queue.storage.model.IStorageEngine;


/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.io.model.IConduit: InputStream, OutputStream;


/*******************************************************************************

    Interface for StorageEngines. 
    Provides methods for reading, writing, seeking, 
    querying of information and reading/writing from/to conduits
    of the underlying storage.

*******************************************************************************/

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
            output = the output stream to write to
            
        Returns:
            number of bytes written
            
    ***************************************************************************/
    
    public size_t writeToConduit(OutputStream output);
    
    /***************************************************************************
    
        Initializes the StorageEngine from the provided conduit.
        Size must be set accordingly.
        
        Params:
            input = the input stream to read from
            
        Returns:
            number of bytes read
            
    ***************************************************************************/
    
    public size_t readFromConduit(InputStream input);
    
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