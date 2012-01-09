/*******************************************************************************

        NGram Writer

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Jan 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        D library for saving ngrams and id/num pairs into hash-named binary
        files. Each file is named by the hash of an ngram and contains id/count
        pairs whereas the count stands for the number of occurrences of the
        ngram within a document with the given id.

        ngram = ngram found in the document
        id    = document id
        score = number of occurrences of a the ngram within the document

        --

        Usage example for adding a new triple to the index

            auto ngram = new NGramWriter;

            dchar[] 4gram = "lore";

            uint id    = 1;
            uint score = 10;

            ngram.add(4gram.dup, id, score);

            ngram.close;

        ---

        Usage Example for cleaning the existing ngram index

            auto ngram = new NGramWriter;

            NGramWriter.removeAll();

        ---

********************************************************************************/

module  ocean.text.ling.ngram.NGramWriter;

private import  Path = tango.io.Path;

private import  tango.util.digest.Md5;

private import  tango.io.device.File;

private import  tango.io.stream.Buffered;

//private import  tango.io.device.Array;

private import  tango.util.log.Trace;



/*******************************************************************************

     NGramWriter

********************************************************************************/

class NGramWriter
{

    /***************************************************************************

          NGram Definition

     ***************************************************************************/


    /**
     * ngram index directory
     */
    private             char[]                    directory;


    /**
     * ngram map
     */
    //private             Array[char[]]             map_buffer;


    /**
     * ngram map flush limit
     */
    private             long                      map_flush_limit   = 10_000;


    /**
     * current size of the ngram map
     */
    private             long                      map_size = 0;


    /**
     * pair hash
     */
    private             char[]                    hash;



    /***************************************************************************

         Public Methods

     ***************************************************************************/


    /**
     * Constructur
     *
     * Params:
     *      path = ngram index location
     */
    public this ( char[] path = null )
    {
        if ( path.length )
            this.directory = path;

        if ( !this.createIndexDirectory )
            this.removeAll();
    }



    /**
     * Adds an ngram to the n-gram index
     *
     * Params:
     *     ngram = ngram to index
     *     id    = document id
     *     score = number of occurrences of the ngram
     */
    public void add ( dchar[] ngram, uint id, uint score )
    {
        this.createDigest (ngram);
        this.writePair (id, score);
    }



    /**
     * Removes all files of the ngram index directory
     *
     */
    public void removeAll ()
    {
        char[] index   = "0123456789abcdef";

        Trace.format ("Removing old ngram index files...").flush;

        foreach ( d; index )
            Path.FS.list ( (this.directory ~ d ~ "/").dup, &remove );

        Trace.formatln ("done!");
    }



    /**
     * Closes all file descriptors
     *
     */
    public void close ()
    {
        //if ( this.map_size > 0 )
        //    this.flushToDisk;
    }



    /***************************************************************************

         Private Methods

     ***************************************************************************/


    /***
     * Write pair to ngram hash-file
     *
     * Params:
     *     id    = document id pointer
     *     score = ngram score (number of occurrences)
     *
     * Returns:
     *      returns true if written to file, false on error
     */
    private void writePair ( uint id, uint score )
    {
        uint[] vector = [id,score];
        this.write(this.hash, vector);

        /*
        uint[] pair = [id, score];

        if ( this.map_size >= this.map_flush_limit )
        {
            Trace.formatln("---------------------------");
            Trace.formatln("Flushing after 1000 pairs");
            Trace.formatln("---------------------------");

            this.flushToDisk;

            this.map_size = 0;
        }

        if ( !(this.hash in this.map_buffer) )
            this.map_buffer[this.hash] = new Array(1024);

        this.map_buffer[this.hash].append(pair);

        this.map_size++;
        */
    }




    /**
     * Flushes ngram map to disk
     *
     */
    private void flushToDisk ()
    {
        /*
        foreach (key; this.map_buffer.keys)
        {
            this.map_buffer[key].clear;
            this.map_buffer[key].detach;
            this.map_buffer.remove(key);
        }
        */
        /*
        foreach ( h, vector; this.map )
            this.write(h, vector);

        foreach (key; this.map.keys)
        {
            this.map[key].length = 0;
            this.map.remove(key);
        }

        this.map = this.map.init;
        */
    }



    /**
     * Write vector to disk
     *
     * Params:
     *     hash = vector hash
     *     data = vector
     */
    private void write ( ref char[] hash, ref uint[] data )
    {
        char[] filepath = null;

        filepath = this.directory ~ hash[0] ~ "/" ~ hash;

        auto hashfile = new BufferedOutput(new File(filepath.dup, File.WriteAppending), 64);

        hashfile.write (data);

        hashfile.flush.close;

        delete hashfile;
    }



    /**
     * Create ngram-hash
     *
     * Returns:
     *      hash or null on error
     */
    private void createDigest ( dchar[] ngram )
    {
        auto md5 = new Md5;

        md5.update(cast(ubyte[])ngram);

        this.hash = md5.hexDigest();

        md5.reset;

        delete md5;
    }



    /**
     * Creates ngram-index base directory if not yet existing
     *
     * Returns
     *      true if index directory was created
     */
    private bool createIndexDirectory ()
    {
        bool   created = false;

        char[] index   = "0123456789abcdef";

        if ( !Path.exists(this.directory) )
        {
            Path.createFolder(this.directory.dup);
            created = true;
        }

        foreach ( d; index )
        {
            if (!Path.exists(this.directory ~ d))
            {
                Path.createFolder((this.directory ~ d).dup);
                created = true;
            }
        }

        return created;
    }



    /**
     * Removes file from ngram index
     *
     * Params:
     *     info = file info struct
     *
     * Returns:
     *     0 if everything is OK
     */
    public int remove( inout Path.FS.FileInfo file )
    {
        if ( !file.folder )
            Path.remove((this.directory ~ file.name[0] ~ "/" ~ file.name).dup);

        return 0;
    }

}

