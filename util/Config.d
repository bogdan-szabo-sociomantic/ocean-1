/*******************************************************************************

    Load Configuration from Config File

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Jan 2009: Initial release

    authors:        Lars Kirchhoff
                    Thomas Nicolai

    Config reads all properties of the application from an INI style
    file and stores them in ein internal variable, that can be accessed
    through get and set methods as follows:

    --

    Usage example:

        Config.init("etc/my_config.ini");

        char[] value = Config.getChar("category", "key");

        After first initialization by calling Config.init because the config
        object is a static implementation as well as its member variables.
        Therefore there is no need to call Config.init again.

    --

    A print function provides a facility to print all config properties at
    once for debugging reasons.

    	Config.print;

    Additionally the properties can be read again from the file with a read
    method and new configuration options can be written to the INI file using
    the write method as follows:

    	Config.read;

    If properties have changed within the program it can be written back to
    the INI file with a write function. This function clears the INI file and
    writes all current parameters stored in properties to INI file

    	Config.set("key", "new value");
        Config.write;

    --

    Config File Example Structure

    // --------------------------
    // Config Example
    // --------------------------

    [DATABASE]
    table1 = "name_of_table1"
    table2 = "name_of_table2"

    [LOGGING]
    level = 4
    file = "access.log"

    --

    TODO: Update Config.write and Config.print to new structure

    TODO: Intergrate opcall array that allows to access Configuration keys by
          Config["category"]["key"]

*******************************************************************************/

module         ocean.util.Config;

private        import         tango.io.device.File;

private        import         tango.io.stream.Lines;

//private        import         tango.io.FilePath;

private        import         Integer = tango.text.convert.Integer: toInt;

private        import         Float = tango.text.convert.Float: toFloat;

private        import         tango.text.Util: locate, trim;

private        import         tango.core.Exception;


/*******************************************************************************

    Config

*******************************************************************************/

class Config
{

    /*******************************************************************************

        Constants

    *******************************************************************************/

    const       char[]     CONF_FILE_NOT_FOUND         = "Could not find configuration file: ";
    const       char[]     PRINT_END_INI_CONFIGURATION = "----- END INI Configuration --------\n\n";
    const       char[]     PRINT_INI_CONFIGURATION     = "----- INI Configuration --------\nNumber of parameter(s):";


    /***************************************************************************

        Variables for the Storage of the Configuration

    ***************************************************************************/


	/**
	 * static variable that holds the property values
	 */
    private		static     char[][char[]][char[]]		properties;


    /**
     * static variable that holds the location of the configuration file
     */
    private		static      char[]     					configuration_file;


    
    /**
     * Constructor: prevented from being called directly
     *
     * instantiate the daemon object
     */
	private this() {}



	/**
	 * Initialization of config object
	 *
	 * Reads the content of the configuration file and copies to an static internal array.
	 *
	 * ---
     * Usage Example:
     *
     * Config.init("etc/config.ini");
     * ---
     *
	 * Params:
	 *   conf_file = string that contains the path to the configuration file
     *
     * Returns:
     *   bool = true, if configuration could be read
	 */
    public static bool init( char[] conf_file = "etc/config.ini" )
	{
		this.configuration_file = conf_file;

        return read();
    }



    /**
     * Returns wheter the configuration was already initialized or not
     *
     * Returns:
     *     true, if configuration is already initalized
     */
    public static bool isRead()
    {
        if ( this.properties.length == 0 )
            return false;

        return true;
    }



    /**
     * Returns the value of a configuration key
     *
     * ---
     *
     * Usage Example:
     *
     * Config.init("etc/config.ini");
     *
     * char[] value = Config.getChar("category", "key");
     *
     * ---
     *
     * Params:
     *   category = category to get key from
     *   key      = name of the property to get
     *
     * Returns:
     *   key value as char[]
     */
    public static char[] getChar(char[] category, char[] key)
    {
        return Config.get!(char[])(category, key);
    }



    /**
     * Returns the value of a configuration key
     *
     * ---
     *
     * Usage Example:
     *
     * Config.init("etc/config.ini");
     *
     * int value = Config.getInt("category", "key");
     *
     * ---
     *
     * Params:
     *   category = category to get key from
     *   key      = name of the property to get
     *
     * Returns:
     *   key value as int
     */
    public static int getInt(char[] category, char[] key)
    {
        return Config.get!(int)(category, key);
    }


    
    /**
     * Returns the value of a configuration key
     *
     * ---
     *
     * Usage Example:
     *
     * Config.init("etc/config.ini");
     *
     * bool value = Config.getBool("category", "key");
     *
     * ---
     *
     * Params:
     *   category = category to get key from
     *   key      = name of the property to get
     *
     * Returns:
     *   key value as bool
     */
    public static bool getBool(char[] category, char[] key)
    {
        char[] value;
        
        value = Config.get!(char[])(category, key);
        
        if ( value == "1" || value == "true" )
            return true;
        
        return false;
    }
    
    
    
    /**
     * Returns the value of a configuration key
     *
     * ---
     *
     * Usage Example:
     *
     * Config.init("etc/config.ini");
     *
     * bool value = Config.getFloat("category", "key");
     *
     * ---
     *
     * Params:
     *   category = category to get key from
     *   key      = name of the property to get
     *
     * Returns:
     *   key value as float
     */
    public static float getFloat(char[] category, char[] key)
    {
        return Config.get!(float)(category, key);
    }
    
    
    
    /**
     * Returns the value of a configuration key
     *
     * ---
     *
     * Usage Example:
     *
     * Config.init("etc/config.ini");
     *
     * long value = Config.getLong("category", "key");
     *
     * ---
     *
     * Params:
     *   category = category to get key from
     *   key      = name of the property to get
     *
     * Returns:
     *   key value as long
     */
    public static long getLong(char[] category, char[] key)
    {
        return Config.get!(long)(category, key);
    }



    /**
     * Sets a new key = value configuration pair.
     *
     * Params:
     *   key = name of the property to set
     *   value = value of the property
     */
    public static void set( char[] category, char[] key, char[] value )
    {
        this.properties[category][key] = value;
    }
    
    
    
    /**
     * Tells if a configuration key or category exists
     * 
     * Params:
     *   key      = key name to check
     *   category = name of the category of the key
     *   
     *  Returns:
     *   true if the configuration key exists in this category
     */
    public static bool exists(char[] category, char[] key)
    {
        return (category in this.properties) && (key in this.properties[category]);
    }
    

    
    /**
     * Returns the value of a configuration key
     *
     * Function needs to be called statically. Template can be instantiated with
     * integer, float or string (char[]) type.
     * If the requested key cannot be found, an exception is thrown.
     *
     * ---
     *
     * Usage Example:
     *
     * Config.init("etc/config.ini");
     *
     * Config.get!(char[])("my_config_key"); 				//retrieve the string value of a key
     * Config.get!(int)("number_of_threads");				//retrieve an int value of a key
     *
     * ---
     *
     * Params:
     *   category = category to get key from
     *   key      = name of the property to get
     *
     * Returns:
     *   The value of a configuration key
     */
    public static T get(T) (char[] category, char[] key)
    {
        try
        {
            assert(exists(category, key), "Critial Error: No configuration key '" ~ category ~ ":" ~ key ~ "' found");
            
            char[] property = this.properties[category][key];
            
            static if ( is(T : long) )
            {
                return Integer.toLong(property);
            }
            else static if ( is(T : real) )
            {
                return Float.toFloat(property);
            }
            else static if ( is(T : char[]) )
            {
                return cast (T) property;
            }
            else static assert(false, __FILE__ ~ " : get: type '" ~ T.stringof ~ "' is not supported");
        }
        catch (AssertException e)
        {
            ConfigException(e.msg);
        }
        catch (IllegalArgumentException)
        {
            ConfigException("Critial Error: Configuration key '" ~ category ~ ":" ~ key ~ "' appears not to be of type '" ~ T.stringof ~ "'");
        }
    }
    
    
    
    /**
     * Returns the value of a configuration key
     *
     * Function needs to be called statically. Template can be instantiated with
     * integer, float or string (char[]) type. If the configuration key cannot
     * be found, "value" remains unchanged.
     *
     * ---
     *
     * Usage Example:
     *
     * Config.init("etc/config.ini");
     *
     * Config.get!(char[])("my_config_key");                //retrieve the string value of a key
     * Config.get!(int)("number_of_threads");               //retrieve an int value of a key
     *
     * ---
     *
     * Params:
     *   value    = key value
     *   category = category to get key from
     *   key      = name of the property to get
     *
     * Returns:
     *   true on success or false if the key could not be found
     */
    public static bool get(T) (ref T value, char[] category, char[] key)
    {
        bool found = exists(category, key);
        
        if (found)
        {
            value = this.get!(T)(category, key);
        }
        
        return found;
    }
    
    
    
    /**
     * Reads all configuration parameter from INI file
     *
     * Each property in the ini file belongs to a category. A property has always
     * a key and a value associated to the key. The function parses currently three
     * different elements:
     *
     * i. Category (enclosed by [])
     * [Example Category]
     *
     * ii. Comments
     * // Comments always start with two slashes
     *
     * iii. Property
     * key = value
     *
     * Returns:
     * 	 bool = true, if configuration file could be read
     */
    public static bool read()
    {
        char[] text, category, key = "";
        
        int pos;

        this.properties = null;

        try
        {
            foreach (line; new Lines!(char) (new File(this.configuration_file)))
        	{
				text = trim (line);
			    
                if (text.length >= 2)
                {
    				if ( text.length && text != "//" && text[0] != ';' )        // ignore empty lines and comments
    				{
    					pos = locate(text, '[');								// category present in line?
    
    					if ( pos == 0 )
    					{
    						category = text[pos+1..locate (text, ']')];
                            
                            key = "";
    					}
    					else
    					{
    						pos = locate (text, '=');							// key value pair present in line?
    
    						if (pos < text.length)
                            {
                                key = trim (text[0 .. pos]);
                                
    							this.properties[category][key] = trim(text[pos+1 .. $]);
                            }
                            else
                            {
                                this.properties[category][key] ~= trim(text) ~ '\n';
                            }
    					}
    				}
                }
        	}
        }
        catch (Exception e)
        {
            ConfigException(e.msg);
        }
        
        return true;
    }



    /**
     * Writes the configuration parameter to configuration file
     *
     * FIXME: Needs to be adapated to new
     *       structure with categories!
     */
    public static void write()
    {
    	/*
        auto map = new MapOutput!(char)(new FileOutput(this.configuration_file));

        map.append(this.properties);

        map.flush();
        map.close();
        */
    }



    /**
     * Prints all configuration properties
     *
     * FIXME: Needs to be adapated to new
     *       structure with categories!
     */
    public static void print()
    {
    	/*
        Stdout.format("{} {}\n\n", PRINT_INI_CONFIGURATION, this.properties.length);

        foreach(key, value; this.properties)
            Stdout.formatln("{} = {}", key, value);

        Stdout.format(PRINT_END_INI_CONFIGURATION);
        */
    }

}

/******************************************************************************

    ConfigException

*******************************************************************************/

class ConfigException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }

    private:
        static void opCall(char[] msg) { throw new ConfigException(msg); }

}

