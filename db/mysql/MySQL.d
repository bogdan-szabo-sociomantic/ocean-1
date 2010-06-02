/*******************************************************************************

    Singleton for MySQL Database Connection

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Feb 2009: Initial release

    authors:        Thomas Nicolai
                    Lars Kirchhoff

    Creates static instance of MySQL connection and loads configuration details
    from config file.

    --

    Usage example:

        auto con = MySQL.singleton("frontend");

        ...

        con.disconnect();
    --

*******************************************************************************/

module ocean.db.MySQL;

public  import ocean.core.Exception: MySQLException;

private import ocean.util.Config;

private import dbi.mysql.MysqlDatabase;

private import tango.util.log.Trace;
/*******************************************************************************

    MySQL

********************************************************************************/

class MySQL
{

    /**
     * private mysql instances
     */
    private static MysqlDatabase[char[]] connection;



    /**
     * Prevent from being used: Use singelton to retrieve instance of class
     *
     */
    protected this () {}



    /**
     * Returns instance of DB class
     *
     * Returns:
     *      static instance of DB class
     */
    public static MysqlDatabase singleton ( char[] dbname, bool reconnect = false )
    {
        if ( dbname in this.connection &&  this.connection[dbname] !is null && !reconnect )
           return this.connection[dbname];

        if ( !Config.isRead )
            Config.init();

        if ( Config.getChar("Database_" ~ dbname, "type") == "mysql" )
        {
            this.connection[dbname] = new MysqlDatabase();

            this.connection[dbname].connect(
                Config.getChar("Database_" ~ dbname, "db"),
                Config.getChar("Database_" ~ dbname, "user"),
                Config.getChar("Database_" ~ dbname, "passwd"),
                ["host": Config.getChar("Database_" ~ dbname, "host")]
                );
            Trace.formatln("new fresh mysql connection; done!");
            return this.connection[dbname];
        }

        MySQLException("Sorry, couldn't find database configuration!");
    }



    /**
     * Sets path to config file
     *
     * Params:
     *     path = path to config file
     *
     * Returns:
     *     true, if path to config file could be set
     */
    public void setConfig( char[] path )
    {
        return Config.init(path);
    }



    /**
     * Disconnect from database
     *
     * Params:
     *     dbname = name of database connection
     *
     * Returns:
     *     true, if connection was successfully closed
     */
    public static bool disconnect ( char[] dbname )
    {
        if ( this.connection[dbname] !is null )
        {
            this.connection[dbname].close();
            this.connection[dbname] = null;
            
            return true;
        }

        return false;
    }


}
