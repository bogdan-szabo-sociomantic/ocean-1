/*******************************************************************************

    Load Configuration from Config File

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Jan 2009: Initial release

    authors:        Lars Kirchhoff
                    Thomas Nicolai
                    David Eckhardt
                    
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

********************************************************************************/

module         ocean.util.Config;


/*******************************************************************************

    Imports

********************************************************************************/

private        import         tango.io.device.File;

private        import         tango.io.stream.Lines;

private        import         Integer = tango.text.convert.Integer: toInt;

private        import         Float = tango.text.convert.Float: toFloat;

private        import         tango.text.Util: locate, trim, delimit;

private        import         tango.text.convert.Utf;

private        import         tango.core.Exception;


/*******************************************************************************

    Config

********************************************************************************/

class Config
{
    
    /*******************************************************************************
        
        Config Keys and Properties
    
     *******************************************************************************/
    
    private		        static char[][char[]][char[]]       properties;


    /*******************************************************************************
        
        Config File Location
    
     *******************************************************************************/
    
    private             static char[]                       configFile;


    
    /*******************************************************************************
        
        Constructor 
        
        Don't called directly as its protected to be called. Use function directly
        instead as they are static.
    
     *******************************************************************************/
    
	private this() {}


    /*******************************************************************************
        
        Read Config File
        
        Reads the content of the configuration file and copies to a static 
        array buffer.
        
        ---
     
        Usage Example:
     
            Config.init("etc/config.ini");
     
        ---
     
        Params:
            filePath = string that contains the path to the configuration file
       
        Returns:
            true, if configuration could be read
            
     *******************************************************************************/

    public static bool init( char[] filePath = "etc/config.ini" )
	{
		this.configFile = filePath;

        return read();
    }


    /*******************************************************************************
        
        Returns Config Status
       
        Returns:
            true, if configuration is already initalized
            
     *******************************************************************************/
    
    public static bool isRead()
    {
        if ( this.properties.length == 0 )
            return false;

        return true;
    }


    /*******************************************************************************
        
        Returns Value of a Config-Key
        
        Function needs to be called statically. Template can be instantiated with
        integer, float or string (char[]) type. If the requested key cannot be 
        found, an exception is thrown.
        
        ---
     
        Usage Example:
     
            const char[] my_config_cat = "options";
            
            char[] my_config_par;
            int    num_threads;
            
            Config.init("etc/config.ini");
            
            my_config_par = Config.get!(char[])(my_config_cat, "my_config_key");
            num_threads   = Config.get!(int)(my_config_cat, "number_of_threads");
            
        ---
     
        Params:
            category = category to get key from
            key      = name of the property to get
       
        Returns:
            value of a configuration key, or null if none
            
     *******************************************************************************/
    
    public static T get (T) (char[] category, char[] key)
    {
        try
        {
            assert(exists(category, key), "Critial Error: No configuration key "
                                          "'" ~ category ~ ":" ~ key ~
                                          "' found");
            
            char[] property = this.properties[category][key];
            
            static if ( is(T : bool) )
            {
                return getBool(category, key);
            }
            else static if ( is(T : long) )
            {
                return Integer.toLong(property);
            }
            else static if ( is(T : real) )
            {
                return Float.toFloat(property);
            }
            else static if ( is(char[] T : T[]) || is(wchar[] T : T[]) || is(dchar[] T : T[]) )
            {
                return fromString8!(T)(property, null);
            }
            else static assert(false, __FILE__ ~ " : get(): type '" ~
                                     T.stringof ~ "' is not supported");
        }
        catch (AssertException e)
        {
            ConfigException(e.msg);
        }
        catch (IllegalArgumentException)
        {
            ConfigException("Critial Error: Configuration key '" ~ category ~
            ":" ~ key ~ "' appears not to be of type '" ~ T.stringof ~ "'");
        }
    }
    
    
    /*******************************************************************************
        
        Returns Value of a Config-Key
        
        Function needs to be called statically. Instantitate template with T = int, 
        long, float, bool or string (char[]) type or a type compatible to these. If 
        the configuration key cannot be found, "value" remains unchanged.
        
        ---
     
        Usage Example:
     
            const char[] my_config_cat = "options";
            
            char[] my_config_par = "my_default_value";
            int    num_threads   = 4711;
            
            Config.init("etc/config.ini");
            
            Config.get!(char[])(my_config_cat, my_config_par, "my_config_key");
            Config.get!(int   )(my_config_cat, num_threads, "number_of_threads");
            
        ---
     
        Params:
            value    = key value
            category = category to get key from
            key      = name of the property to get
            
        Returns:
            true on success or false if the key could not be found
            
     *******************************************************************************/
    
    public static bool get (T) (ref T value, char[] category, char[] key)
    {
        bool found = exists(category, key);
        
        if (found)
        {
            value = get!(T)(category, key);
        }
        
        return found;
    }
    
    
    /*******************************************************************************
        
        Returns Value of a Config-Key
        
        Function needs to be called statically. Instantitate template with a value 
        parameter which is of int, long, float, bool or string (char[]) type or a 
        type compatible to these. If the configuration key cannot be found, "value" 
        remains unchanged.
        
        ---
     
        Usage Example:
     
            const char[] my_config_cat = "options";
            
            char[] my_config_par = "my_default_value";
            int    num_threads   = 4711;
            
            Config.init("etc/config.ini");
            
            my_config_par     = Config.get!(my_config_par)(my_config_cat, "my_config_key");
            number_of_threads = Config.get!(number_of_threads)(my_config_cat);
            
        ---
     
        Params:
            value    = key value
            category = category to get key from
            key      = name of the property to get; omit or set to null to use the
                       name of the variable behind "value"
        Returns:
            true on success or false if the key could not be found
            
     *******************************************************************************/
    
    public static bool get (alias value) (char[] category, char[] key = null)
    {
        return get!(typeof (value))(value, category, key? key : value.stringof);
    }
    
    
    /*******************************************************************************
        
        Returns Value of a Config-Key
        
        ---
     
        Usage Example:
     
            Config.init("etc/config.ini");
            
            char[] value = Config.getChar("category", "key");
            
        ---
     
        Params:
            category = category to get key from
            key      = name of the property to get
            
        Returns:
            value of config key
            
     *******************************************************************************/

    public static T[] getChar ( T = char ) (char[] category, char[] key)
    {
        return get!(T[])(category, key);
    }


    /*******************************************************************************
        
        Returns Value of a Config-Key
        
        ---
     
        Usage Example:
     
            Config.init("etc/config.ini");
            
            int value = Config.getInt("category", "key");
            
        ---
     
        Params:
            category = category to get key from
            key      = name of the property to get
            
        Returns:
            value of config key
            
     *******************************************************************************/
    
    public static int getInt(char[] category, char[] key)
    {
        return Config.get!(int)(category, key);
    }
    
    
    /*******************************************************************************
        
        Returns Value of a Config-Key
        
        ---
     
        Usage Example:
     
            Config.init("etc/config.ini");
            
            bool value = Config.getBool("category", "key");
            
        ---
     
        Params:
            category = category to get key from
            key      = name of the property to get
            
        Returns:
            value of config key
            
     *******************************************************************************/
    
    public static bool getBool(char[] category, char[] key)
    {
        char[] value;
        
        value = get!(char[])(category, key);
        
        if ( value == "1" || value == "true" )
            return true;
        
        return false;
    }
    
    
    /*******************************************************************************
        
        Returns Value of a Config-Key
        
        ---
     
        Usage Example:
     
            Config.init("etc/config.ini");
            
            float value = Config.getFloat("category", "key");
            
        ---
     
        Params:
            category = category to get key from
            key      = name of the property to get
            
        Returns:
            value of config key
            
     *******************************************************************************/
    
    public static float getFloat(char[] category, char[] key)
    {
        return get!(float)(category, key);
    }
    
    
    /*******************************************************************************
        
        Returns Value of a Config-Key
        
        ---
     
        Usage Example:
     
            Config.init("etc/config.ini");
            
            long value = Config.getLong("category", "key");
            
        ---
     
        Params:
            category = category to get key from
            key      = name of the property to get
            
        Returns:
            value of config key
            
     *******************************************************************************/
    
    public static long getLong(char[] category, char[] key)
    {
        return Config.get!(long)(category, key);
    }


    /*******************************************************************************
        
        Set Config-Key Property
        
        ---
     
        Usage Example:
     
            Config.init(`etc/config.ini`);
            
            Config.set(`category`, `key`, `value`);
            
        ---
     
        Params:
            category = category to get key from
            key      = name of the property to get
            value = value of the property
            
     *******************************************************************************/
    
    public static void set( char[] category, char[] key, char[] value )
    {
        this.properties[category][key] = value;
    }
    
    
    /*******************************************************************************
        
        Checks if Key exists in Category
        
     
        Params:
            category = category to get key from
            key      = name of the property to get
        
        Returns:
            true if the configuration key exists in this category
            
     *******************************************************************************/
    
    public static bool exists(char[] category, char[] key)
    {
        return (category in this.properties) && (key in this.properties[category]);
    }
    

    /*******************************************************************************
        
        Returns the Multi-Line Value
        
        Retrieves the value list of a configuration key with a multi-line value. 
        If the value is a single line, the list has one element.
        
        Params:
            value    = output list of values, changed only if the key was found
            category = key category name
            key      = key name
        
        Returns:
            true on success or false if the key could not be found
            
     *******************************************************************************/
    
    public static bool getList ( T = char ) ( ref T[][] value, char[] category, 
                                              char[] key )
    {
        bool found = exists(category, key);
        
        if (found)
        {
            value = getList!(T)(category, key);
        }
        
        return found;
    }
    
    
    /*******************************************************************************
        
        Returns the Multi-Line Value
        
        Retrieves the value list of a configuration key with a multi-line value. 
        If the value is a single line, the list has one element.
        
        Params:
            category = key category name
            key      = key name
        
        Returns:
            list of values
            
     *******************************************************************************/
    
    public static T[][] getList ( T = char ) ( char[] category, char[] key )
    {
        return delimit!(T)(fromString8!(T)(get!(char[])(category, key), null), "\n");
    }
    
    
    /*******************************************************************************
        
        Reads Configuration File
        
        Each property in the ini file belongs to a category. A property has always
        a key and a value associated to the key. The function parses currently 
        three different elements:
        
        ---
        
        i. Categories
        [Example Category]
        
        ii. Comments
        // comments always start with two slashes
        
        iii. Property
        key = value
        
        ---
        
        Returns:
            true, if configuration file could be read
            
     *******************************************************************************/
    
    public static bool read()
    {
        char[] text, category, key = "";
        
        int pos;
        
        bool multiline_first = true;
        
        this.properties = null;

        try
        {
            foreach (line; new Lines!(char) (new File(this.configFile)))
        	{
				text = trim (line);
			    
                if (text.length >= 2)
                {
    				if ( text[0 .. 2] != "//" && text[0] != ';' ) // ignore empty lines and comments
    				{
    					pos = locate(text, '['); // category present in line?
    
    					if ( pos == 0 )
    					{
    						category = text[pos+1..locate (text, ']')];
                            
                            key = "";
    					}
    					else
    					{
    						pos = locate (text, '='); // check for key value pair
    
    						if (pos < text.length)
                            {
                                key = trim (text[0 .. pos]);
                                
                                text = trim(text[pos+1 .. $]);
                                
    							this.properties[category][key] = text;
                                
                                multiline_first = !text.length;
                            }
                            else
                            {
                                text = trim(text);
                                
                                if (text.length)
                                {
                                    if (!multiline_first)
                                    {
                                        this.properties[category][key] ~= '\n';
                                    }
                                    
                                    this.properties[category][key] ~= text;
                                    
                                    multiline_first = false;
                                }
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


    /*******************************************************************************
        
        Writes Configuration
        
        FIXME: Needs to be adapated to new structure with categories
            
     *******************************************************************************/
    
    public static void write()
    {
    	/*
        auto map = new MapOutput!(char)(new FileOutput(this.configFile));

        map.append(this.properties);

        map.flush();
        map.close();
        */
    }


    /*******************************************************************************
        
        Prints Configuration to Screen
        
        FIXME: Needs to be adapated to new structure with categories
            
     *******************************************************************************/
    
    public static void print()
    {
    	/*
        Stdout.format("----- INI Configuration --------").newline;
        Stdout.format("{}",    this.properties.length).newline;

        foreach(key, value; this.properties)
            Stdout.formatln("{} = {}", key, value);

        Stdout.format("--------------------------------").newline;
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

