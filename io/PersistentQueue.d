/*******************************************************************************

        Persistent Queue
        
        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Feb 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        The queue stores each item in a seperate file and contains the order of
        the added items in a seperate QueueFile. The content stored in the files
        is compressed and will be uncompressed on a pop.
        
        ---
        
        Compile Instructions:
        
        Please add buildflags=-L/usr/lib/libz.so to your dsss.conf
        
        ---
        
        Example 1: Add an Item to the queue
            
            char[512] id   = "http://www.example.com/w3c";
            void[] content = "<html><title>....";
            
            auto queue = new PersistentQueue("myQueue", "queue/storage/");
            
            queue.addItem(id, content);
            
            queue.close;
            
        ---        
        
        Example 2: Get an item from the queue

            auto queue = new PersistentQueue("myQueue", "queue/storage/");
            
            auto content = queue.nextItem();
            
            queue.close;
             
        ---
        
        TODO
                        
        1. Finish remove() method
            
        2. Implement binary file structure (header)
        
        3. New Possibility to add custom header for queue
           
           struct Header                          // 16 bytes
           {
                uint      size;                   // size of message body
                ushort    check;                  // header checksum
                ubyte     pad;                    // how much padding applied?
                char[512] identifier;             // e.g. url
                bool      compression;            // message body compressed
           }
            
           Compared to the current approach we wouldnt compress the
           header and had to chance to disable compression for better
           performance reasons.
           
        ---
        
            
            
********************************************************************************/

module  ocean.io.PersistentQueue;

private import  ocean.compress.Compress;

private import  ocean.util.TraceLog;

private import  ocean.io.device.QueueFile;

private import  tango.time.Clock;

private import  tango.io.FilePath, tango.io.device.File, 
                tango.io.stream.Buffered, tango.io.digest.Md5;

private import  Conv = tango.text.convert.Integer: toString;


/*******************************************************************************

    PersistentQueue

********************************************************************************/

class PersistentQueue
{
    
    /*******************************************************************************
    
         Class Variables

     *******************************************************************************/
    
    
    /**
     * Name of Queue 
     */
    private                     char[]                     queue_name;
    
    
    /**
     * Queue directory path 
     */
    private                     char[]                     queue_path;
    
    
    /**
     * Queue for url hashes
     */
    private                     QueueFile                  index_queue;    
    
    
    
    /*******************************************************************************
    
         Public Methods

     *******************************************************************************/


    /**
     * Return instance of PersistentQueue
     * 
     * ---
     *
     * Usage Example:
     * 
     * char[] queue_name = "myQueue";
     * char[] queue_path = "queue/storage/";
     * 
     * auto queue = new PersistentQueue(queue_name, queue_path);
     *
     * ---
     * 
     * Params
     *      name = name of queue
     *      path = relative path to queue
     */
    public this ( char[] name, char[] path ) 
    {
       this.queue_name = name;
       this.queue_path = path;
       
       this.createQueueStore;
       
       if ( TraceLog.getLogger is null ) 
           TraceLog.init("trace.log");
       
       this.index_queue = new QueueFile (TraceLog.getLogger, this.queue_path ~ 
               this.queue_name ~ ".queue", 1024 * 1024 * 1024);
    }

    
    
    /**
     * Puhes an item to the queue
     * 
     * ---
     *
     * Usage Example:
     * 
     * auto queue = new PersistentQueue("myQueue", "queue/storage/");
     * 
     * char[] id = "http://example.com/index.htm";
     * void[] content = "...";
     * 
     * queue.addItem(id, content);
     * 
     * queue.close;
     * 
     * --- 
     * 
     * Params:
     *     id = id of content added (e.g. url)
     *     content = content to add to queue
     *     
     * Returns:
     *     true if added and false if path filter denied adding to queue
     */
    public bool push ( char[512] id, void[] content ) 
    {
        if ( this.addItem(id, content) )
            return true;
        
        return false;
    }
    
    
    
    /**
     * Pops item from queue
     * 
     * Be aware that first 512bytes are reserved for the identifier and
     * the content starts at byte 513.
     * 
     * ---
     *
     * Usage Example:
     *
     * char[] id, hash;
     * void[] content;
     * 
     * auto queue = new PersistentQueue("myQueue", "queue/storage/");
     * 
     * while ( (hash = queue.pop(id, content)) !is null )
     * {
     *      Stdout.formatln("hash = {}", hash);
     *      Stdout.formatln("id = {}", id);
     *      Stdout.formatln("content.length = {}", content.length);
     * }
     * 
     * queue.close;
     *
     * ---
     * 
     * Returns:
     *      next hash and content by reference, or null if queue is empty
     */
    public char[] pop ( inout char[] id, inout void[] content )
    {
        void[] data;
        char[] hash;
        
        auto head = new char[512];
        
        if ( ( hash = this.nextItem(data) ) !is null )
        {
            head    = cast(char[]) data[0..512];
            content = data[512..$];
            
            foreach ( c; head)
                if ( c !is 255 )
                    url ~= c;
            
            return hash;
        }
        
        return null;
    }
    
    
    
    /**
     * Closes queue file on exit
     *
     */
    public void close () 
    {
        this.index_queue.close();
    }
    
    
    
    /**
     * Removes queue from disk
     *
     * Method removes all files and the directory related
     * with the queue on disk.
     * 
     */
    public void remove () {}
    
    
    
    /*******************************************************************************

         Private Methods

     *******************************************************************************/
    
    
    
    /**
     * Creates directory for queue store on disk
     * 
     * The queue store contains the single files for each item
     * added to the queue
     * 
     */
    private void createQueueStore ()
    {
        auto path = new FilePath (this.queue_path ~ this.queue_name);
            
        if ( !path.exists )
            path.createFolder;        
    }
    
    
    
    /**
     * Retrieves next item from queue
     * 
     * Returns:
     *      compressed content
     */
    private char[] nextItem ( inout void[] content)
    {
        char[] file_path;
        void[] key;
        
        key   = this.index_queue.pop();
        
        if ( key !is null )
        {
            file_path = this.queue_path ~ this.queue_name ~ "/" ~ cast(char[]) key;
            auto path = new FilePath(file_path);
            
            if ( path.exists )
            {
                auto file = new File (file_path, File.ReadExisting);
                
                auto comp = new Compress();
                content = comp.decode(file.input);
            }
            
            this.removeItem(file_path);
            
            return cast(char[]) key;
        }

        return null;
    }
    
    
    
    /**
     * Saves item in queue
     * 
     * Be aware that the first 512 bytes are reserved for the id of the content. From
     * byte 513 to EOF is the content itself.
     * 
     * |<---------------- 512byte [Id] ----------------------->|
     * |<---------------- 513..EOF [Content] ------------------|
     * |-------------------------------------------------------|
     * |------------------------------------------------------>|
     * 
     * Params:
     *     id = identifier of content (e.g. url)
     *     content = content to push to queue
     *     
     * Returns:
     *     true on success and false on error
     */
    private bool addItem ( char[] id, void[] content )
    {
        char[] ustamp, hash;
        bool   success;
        
        ustamp = this.currentTimeStamp;
        hash = this.createHash(id);
        
        success = this.saveItem(id, hash, ustamp, content);
            
        if ( !success )
        {
            //PersistentQueueException("StorageQueue Error: Queue write error!");
            
            return false;
        }

        this.index_queue.push(ustamp ~ "_" ~ hash);
        
        return true;
    }
    
    
    
    /**
     * Saves compressed item to the queue
     * 
     * Params:
     *     id      = identifier of content (e.g. url)
     *     hash    = hash of identifier
     *     ustamp  = current unix timestamp
     *     content = compressed content
     *     
     * Returns:
     *     true on success, false on error
     */
    private bool saveItem ( char[] id, char[] hash, char[] ustamp, void[] content )
    {
        char[512] url_pack;
        char[] fpath;
        long   size;
        
        fpath = this.queue_path ~ this.queue_name ~ "/" ~ ustamp ~ "_" ~ hash;

        auto file = new File (fpath, File.WriteCreate);
        
        auto output = new ZlibOutput(file.output, ZlibOutput.Level.Normal, 
            ZlibOutput.Encoding.Gzip, WINDOWBITS_DEFAULT);
        
        scope (exit) output.close;
        
        url_pack[0..url.length] = id;
        size = output.write (url_pack);

        size += output.write (content);
        
        if ( size > 0)
            return true;
        
        return false;
    }
    
    
    
    /**
     * Removes item from queue
     * 
     * Params:
     *      path = path to item in filesystem
     */
    private void removeItem( char[] path )
    {
        auto file = new FilePath (path);
        
        file.remove();
    }
    
    
    
    /**
     * Returns current unix timestamp
     * 
     * Returns:
     *      unix timestamp in seconds
     */
    private char[] currentTimeStamp ()
    {
        return Conv.toString(Clock.now.unix.seconds);
    }
    
    
    
    /**
     * Returns hash
     * 
     * Params:
     *      id = id to create hash from
     *      
     * Returns:
     *      hash or null on error
     */
    private char[] createHash ( char[] id )
    {
        char[] digest;
        
        Md5 hash = new Md5();
        
        hash.update(id);
        
        digest = hash.hexDigest();
        
        if ( digest.length)
            return digest;
        
        return null;
    }
    
}


/******************************************************************************

    PersistentQueueException

*******************************************************************************/

class PersistentQueueException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }
    
    protected:
        static void opCall(char[] msg) { throw new PersistentQueueException(msg); }
}
