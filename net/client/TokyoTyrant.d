/*******************************************************************************

    TokyoTyrant is a client library to access the TokyoTyrant server through the 
    native Tokyo Tyrant library, that provides network access to Tokyo Cabinet
    database files via TCP/IP.

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        July 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai

    --
    
    Description:

    
    --
    
    Usage:
    
    --
    
    Configuration parameter:
     
    --

	Requirements:
    
    Tokyo Tyrant library
    /usr/lib/libtokyotyrant.so
    
    --

    Additional information: 
    
    http://tokyocabinet.sourceforge.net/tyrantdoc/#api 

********************************************************************************/

module      net.client.TokyoTyrant;



/********************************************************************************

            imports

********************************************************************************/

public      import      ocean.core.Exception: TokyoTyrantException;

private     import      tango.stdc.stringz : toDString = fromStringz, toCString = toStringz;

private     import      ocean.net.client.c.tokyotyrant;



/*******************************************************************************

        @author     Thomas Nicolai <thomas.nicolai () sociomantic () com>
        @author     Lars Kirchhoff <lars.kirchhoff () sociomantic () com>
        @package    ocean
        @link       http://www.sociomantic.com

*******************************************************************************/

class TokyoTyrant
{
    /**
     * Host address 
     */
    private     char[]          host;    
    
    /**
     * Default port number 
     */
    private     uint            port        = 1978;
    
    /**
     * Tokyo tyrant database object
     */
    private     TCRDB*          rdb;
    
    /**
     * Is currently connected
     */
    private     bool            connected   = false;       
    
    /**
     * Enable fast add mode without waiting for a response from server
     */
    private     bool            addnr       = false; 
    
    
    
    /**
     * 
     * Params:
     *     host = host address
     *     port = port number
     */
    public this ( char[] host, uint port = 1978 )
    {
        this.host = host;
        this.port = port;
    }
    
    
    
    /**
     * Set if add should be executed with or without waiting for a
     * server response (tcrdbput2, tcrdbputnr2)
     * 
     * Params: 
     *     addnr = should addnr
     *      
     */
    public void setFastAdd ( bool addnr )
    {
        this.addnr = true;
    }
    
    
    
    /**
     * Store a string record into a remote object.
     *  
     * Params:
     *     key = key string
     *     
     * Returns:
     *     true, if sucess
     *     false, otherwise  
     */
    public char[] get ( char[] key )    
    {   
        char* value;
        
        if (this.connected)
        {
            value = tcrdbget2(this.rdb, toCString(key));
            
            if (value)
            {
                return toDString(value);
            }
            else 
            {                
                int ecode = tcrdbecode(this.rdb);
                TokyoTyrantException("TokyoTyrant Error: " ~ toDString(tcrdberrmsg(ecode)));
            }
        }
        
        return null;
    }
    
    
    
    /**
     * Store a string record into a remote object.
     *  
     * Params:
     *     key = key string
     *     value = value string
     *      
     * Returns:
     *     true, if sucess
     *     false, otherwise  
     *     
     * TODO: change if to delegate function      
     */
    public bool add ( char[] key, char value[] )    
    {   
        bool add_ok = false;
    
        if (this.connected)
        {
            if (this.addnr)
            {
                add_ok = tcrdbputnr2(this.rdb, toCString(key), toCString(value));                
            }
            else 
            {
                add_ok = tcrdbput2(this.rdb, toCString(key), toCString(value));
            }
            
            if (add_ok)
            {
                return true;
            }
            else
            {
                int ecode = tcrdbecode(this.rdb);
                TokyoTyrantException("TokyoTyrant Error: " ~ toDString(tcrdberrmsg(ecode)));
            }
        }
        
        return false;
    }
    
    
    
    /**
     * Concatenate a string value at the end of the existing record in a remote 
     * database object.
     * 
     * Params:
     *     key = key string
     *     value = value string
     *      
     * Returns:
     *     true, if sucess
     *     false, otherwise 
     */
    public bool append ( char[] key, char [] value )
    {
        if (this.connected)
        {
            if (tcrdbputcat2(this.rdb, toCString(key), toCString(value)))
            {
                return true;
            }
            else 
            {
                int ecode = tcrdbecode(this.rdb);
                TokyoTyrantException("TokyoTyrant Error: " ~ toDString(tcrdberrmsg(ecode)));
            }
        }
        
        return false;
    }
    
    
    
    /**
     * Remove a string record of a remote database object.
     * 
     * Params:
     *     key = key string
     *      
     * Returns:
     *     true, if sucess
     *     false, otherwise 
     */
    public bool append ( char[] key )
    {
        if (this.connected)
        {
            if (tcrdbout2(this.rdb, toCString(key)))
            {
                return true;
            }
            else 
            {
                int ecode = tcrdbecode(this.rdb);
                TokyoTyrantException("TokyoTyrant Error: " ~ toDString(tcrdberrmsg(ecode)));
            }
        }
        
        return false;
    }
    
    
    
    /**
     * Get the size of the value of a string record in a remote database object.
     * 
     * Params:
     *     key =
     *      
     * Returns:
     */
    public uint getSize ( char[] key )
    {
        uint size;
        
        if (this.connected)
        {
            size = tcrdbvsiz2(this.rdb, toCString(key));
            
            if (size)
            {
                return size;
            }
            else
            {
                int ecode = tcrdbecode(this.rdb);
                TokyoTyrantException("TokyoTyrant Error: " ~ toDString(tcrdberrmsg(ecode)));
            }
        }
        
        return 0;
    }
    
    
    
    
    
    
    /**
     * Create connection to tokyo tyrant server
     * 
     * Returns: 
     *     true, if sucess
     *     false, otherwise 
     */
    public bool connect ()
    {        
        /**
         * create new object
         */
        this.rdb = tcrdbnew();
        
        /**
         * open connection
         */
        if (!tcrdbopen(this.rdb, toCString(this.host), this.port))
        {
            int ecode = tcrdbecode(this.rdb);
            TokyoTyrantException("TokyoTyrant Error: " ~ toDString(tcrdberrmsg(ecode)));
            
            return false;
        }
        
        this.connected = true;
        
        return true;
    }
        
    
    
    /**
     * close connection to tokyo tyrant server
     * 
     * Returns: 
     *     true, if sucess
     *     false, otherwise 
     */
    public bool close ()
    {        
        /**
         * close the connection 
         */
        if (!tcrdbclose(this.rdb))
        {
            int ecode = tcrdbecode(this.rdb);
            TokyoTyrantException("TokyoTyrant Error: " ~ toDString(tcrdberrmsg(ecode)));
            
            return false;
        }

        /**
         * delete the object 
         */
        tcrdbdel(rdb);
        
        this.connected = false;        
        
        return true;
    }
    
} // TokyoTyrant
