/*******************************************************************************

    Singleton for SQLite Database Connection

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Feb 2009: Initial release

    authors:        Thomas Nicolai
                    Lars Kirchhoff

    Creates static instance of SQLite connection and loads configuration details
    from config file.

    --

    Usage example:

        auto con = SQLite.singleton("frontend");

        ...

        con.disconnect();
    --

*******************************************************************************/

module ocean.db.SQLite;

private import ocean.util.Config;

private import tango.text.Unicode : toUpper;

private import dbi.sqlite.SqliteDatabase;

/******************************************************************************

    SqliteException

*******************************************************************************/

class SqliteException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static void opCall ( Args ... ) ( Args args )
    {
        throw new SqliteException(args);
    }
}

/*******************************************************************************

    SQLite

********************************************************************************/

class SQLite
{

    /**
     * private mysql instances
     */
    private static SqliteDatabase[char[]] connection;



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
    public static SqliteDatabase singleton ( char[] dbname )
    {
        if ( dbname in this.connection &&  this.connection[dbname] !is null )
            return this.connection[dbname];

        if ( !Config.isRead )
            Config.init();

        if ( Config.Char["DATABASE_" ~ toUpper(dbname), "type"] == "sqlite" )
        {
            this.connection[dbname] = new SqliteDatabase();

            this.connection[dbname].connect(
                Config.Char["DATABASE_" ~ toUpper(dbname), "db"],
                Config.Char["DATABASE_" ~ toUpper(dbname), "user"],
                Config.Char["DATABASE_" ~ toUpper(dbname), "passwd"]
                );

            return this.connection[dbname];
        }

        SqliteException("Sorry, couldn't find database configuration!");
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
    public bool setConfig( char[] path )
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
    public bool disconnect ( char[] dbname )
    {
        if ( this.connection[dbname] !is null )
        {
            this.connection[dbname].close();

            return true;
        }

        return false;
    }


}
