/*******************************************************************************

    Application extension to parse configuration files.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.ConfigExt;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.app.model.ExtensibleClassMixin;
import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.Application;
import ocean.util.app.ext.model.IConfigExtExtension;
import ocean.util.app.ext.model.IArgumentsExtExtension;
import ocean.util.app.ext.ArgumentsExt;

import ocean.util.Config;
import ocean.util.config.ConfigParser;
import ocean.text.Arguments;
import ocean.io.Stdout : Stderr;

import tango.text.Util : join, locate, locatePrior, trim;
import tango.core.Exception : IOException;



/*******************************************************************************

    Application extension to parse configuration files.

    This extension is an extension itself, providing new hooks via
    IConfigExtExtension.

    It is also an extension for the ArgumentsExt extension, so if it is
    registered as such, it will add the --config command line option to specify
    the configuration file to read. If loose_config_parsing is false, it will
    also add a --loose-config-parsing option to enable that feature.

*******************************************************************************/

class ConfigExt : IApplicationExtension, IArgumentsExtExtension
{

    /***************************************************************************

        Adds a list of extensions (this.extensions) and methods to handle them.
        See ExtensibleClassMixin documentation for details.

    ***************************************************************************/

    mixin ExtensibleClassMixin!(IConfigExtExtension);


    /***************************************************************************

        Configuration parser to use.

    ***************************************************************************/

    public ConfigParser config;


    /***************************************************************************

        If true, configuration files will be parsed in a more relaxed way.

        This might be overridden by command line arguments.

    ***************************************************************************/

    public bool loose_config_parsing;


    /***************************************************************************

        Default configuration files to parse.

    ***************************************************************************/

    public char[][] default_configs;


    /***************************************************************************

        Constructor.

        Params:
            loose_config_parsing = if true, configuration files will be parsed
                                   in a more relaxed way
            default_configs = default configuration files to parse
            config = configuration parser to use, defaults to the global
                     instance provided by the ocean.util.Config module.

    ***************************************************************************/

    this ( bool loose_config_parsing = false,
            char[][] default_configs = [ "etc/config.ini" ],
            ConfigParser config = null )
    {
        this.loose_config_parsing = loose_config_parsing;
        this.default_configs = default_configs;
        if ( config is null )
        {
            config = Config;
        }
        this.config = config;
    }


    /***************************************************************************

        Extension order. This extension uses -10_000 because it should be
        called pretty early, but after the ArgumentsExt extension.

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return -10_000;
    }


    /***************************************************************************

        Setup command line arguments.

        Adds the following additional command line arguments:
            --config/-c
            --loose-config-parsing (if needed)
            --override-config/-O

        Params:
            app = the application instance
            args = parsed command line arguments

    ***************************************************************************/

    public void setupArgs ( IApplication app, Arguments args )
    {
        args("config").aliased('c').params(1).smush()
            .help("use the given configuration file");

        foreach (conf; this.default_configs)
        {
            args("config").defaults(conf);
        }

        if (!this.loose_config_parsing)
        {
            args("loose-config-parsing").params(0)
                .help("ignore unknown configuration parameters in config file");
        }

        args("override-config").aliased('O').params(1,int.max).smush()
            .help("override a configuration value "
                  "(example: -O 'category.key = value', need a space between "
                  "-O and the option now because of a Tango bug)");
    }


    /***************************************************************************

        Process command line arguments (ArgumentsExt hook).

        Overrides the loose_config_parsing variable if appropriate.

        Params:
            app = the application instance
            args = parsed command line arguments

    ***************************************************************************/

    public void processArgs ( IApplication app, Arguments args )
    {
        if (!this.loose_config_parsing)
        {
            this.loose_config_parsing = args("loose-config-parsing").set;
        }
    }


    /***************************************************************************

        Process overridden config options

        Params:
            args = parsed command line arguments

    ***************************************************************************/

    public void processOverrides ( Arguments args )
    {
        char[] category;
        char[] key;
        char[] value;

        foreach (opt; args("override-config").assigned)
        {
            auto error = this.parseOverride(opt, category, key, value);
            assert (error is null,
                    "Unexpected error while processing overrides, errors " ~
                    "should have been caught by the validateArgs() method");

            if ( value == "" )
            {
                this.config.remove(category, key);
            }
            else
            {
                this.config.set(category, key, value);
            }
        }
    }


    /***************************************************************************

        Do a simple validation over override-config arguments

        Params:
            app = the application instance
            args = parsed command line arguments

        Returns:
            error text if any

    ***************************************************************************/

    public char[] validateArgs ( IApplication app, Arguments args )
    {
        char[][] errors;
        foreach (opt; args("override-config").assigned)
        {
            char[] cat;
            char[] key;
            char[] val;

            auto error = this.parseOverride(opt, cat, key, val);

            if (error is null)
                continue;

            errors ~= error;
        }

        return join(errors, ", ");
    }


    /***************************************************************************

        Parse configuration files (Application hook).

        This function do all the extension processing invoking all the
        extensions hooks.

        If configuration file parsing fails, it exits with status code 3 and
        prints an appropriate error message.

        Note:
            This is not done in processArgs() method because it can be used
            without being registered as a ArgumentsExt extension.

        Params:
            app = the application instance
            cl_args = command line arguments

    ***************************************************************************/

    public void preRun ( IApplication app, char[][] cl_args )
    {
        foreach (ext; this.extensions)
        {
            ext.preParseConfig(app, this.config);
        }

        auto config_files = this.default_configs;
        auto args_ext = (cast(Application)app).getExtension!(ArgumentsExt);
        if (args_ext !is null)
        {
            config_files ~= args_ext.args("config").assigned;
        }

        foreach (e; this.extensions)
        {
            config_files = e.filterConfigFiles(app, this.config, config_files);
        }

        foreach (config_file; config_files)
        {
            try
            {
                this.config.parseFile(config_file, false);
            }
            catch (IOException e)
            {
                app.exit(3, "Error reading config file '" ~ config_file ~
                        "': " ~ e.toString());
            }
        }

        if (args_ext !is null)
        {
            this.processOverrides(args_ext.args);
        }

        foreach (ext; this.extensions)
        {
            ext.processConfig(app, this.config);
        }
    }


    /***************************************************************************

        Unused IApplicationExtension method.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    public void postRun ( IApplication app, char[][] args, int status )
    {
        // Unused
    }

    /// ditto
    public void atExit ( IApplication app, char[][] args, int status,
            ExitException exception )
    {
        // Unused
    }

    /// ditto
    public ExitException onExitException ( IApplication app,
            char[][] args, ExitException exception )
    {
        // Unused
        return exception;
    }


    /***************************************************************************

        Parses an overriden config.

        Category, key and value are filled with slices to the original opt
        string, so if you need to store them you probably want to dup() them.
        No allocations are performed for those variables, although some
        allocations are performed in case of errors (but only on errors).

        Since keys can't have a dot ("."), cate.gory.key=value will be
        interpreted as category="cate.gory", key="key" and value="value".

        Params:
            opt = the overriden config as specified on the command-line
            category = buffer to be filled with the parsed category
            key = buffer to be filled with the parsed key
            value = buffer to be filled with the parsed value

        Returns:
            null if parsing was successful, an error message if there was an
            error.

    ***************************************************************************/

    private char[] parseOverride ( char[] opt, out char[] category,
            out char[] key, out char[] value )
    {
        opt = trim(opt);

        if (opt.length == 0)
            return "Option can't be empty";

        auto key_end = locate(opt, '=');
        if (key_end == opt.length)
            return "No value separator ('=') found for config option " ~
                    "override: " ~ opt;

        value = trim(opt[key_end + 1 .. $]);

        auto cat_key = opt[0 .. key_end];
        auto category_end = locatePrior(cat_key, '.');
        if (category_end == cat_key.length)
            return "No category separator ('.') found before the value " ~
                    "separator ('=') for config option override: " ~ opt;

        category = trim(cat_key[0 .. category_end]);
        if (category.length == 0)
            return "Empty category for config option override: " ~ opt;

        key = trim(cat_key[category_end + 1 .. $]);
        if (key.length == 0)
            return "Empty key for config option override: " ~ opt;

        return null;
    }
}



/*******************************************************************************

    Unit tests

*******************************************************************************/

version (UnitTest)
{
    import ocean.core.Test : NamedTest;
    import ocean.core.Array : startsWith;
}

unittest
{
    auto ext = new ConfigExt;

    // Errors are compared only with startsWith(), not the whole error
    void testParser ( char[] opt, char[] exp_cat, char[] exp_key,
            char[] exp_val, char[] expected_error = null )
    {
        char[] cat;
        char[] key;
        char[] val;

        auto t = new NamedTest(opt);

        auto error = ext.parseOverride(opt, cat, key, val);

        if (expected_error is null)
        {
            t.test(error is null, "Error message mismatch, expected no " ~
                                  "error, got '" ~ error ~ "'");
        }
        else
        {
            t.test(error.startsWith(expected_error), "Error message " ~
                    "mismatch, expected an error starting with '" ~
                    expected_error ~ "', got '" ~ error ~ "'");
        }

        if (exp_cat is null && exp_key is null && exp_val is null)
            return;

        t.test!("==")(cat, exp_cat);
        t.test!("==")(key, exp_key);
        t.test!("==")(val, exp_val);
    }

    // Shortcut to test expected errors
    void testParserError ( char[] opt, char[] expected_error )
    {
        testParser(opt, null, null, null, expected_error);
    }

    // New format
    testParser("cat.key=value", "cat", "key", "value");
    testParser("cat.key = value", "cat", "key", "value");
    testParser("cat.key= value", "cat", "key", "value");
    testParser("cat.key =value", "cat", "key", "value");
    testParser("cat.key = value  ", "cat", "key", "value");
    testParser("  cat.key = value  ", "cat", "key", "value");
    testParser("  cat . key = value \t ", "cat", "key", "value");
    testParser("  empty . val = \t ", "empty", "val", "");

    // New format errors
    testParserError("cat.key value", "No value separator ");
    testParserError("key = value", "No category separator ");
    testParserError("cat key value", "No value separator ");
    testParserError(" . empty = cat\t ", "Empty category ");
    testParserError("  empty .  = key\t ", "Empty key ");
    testParserError("  empty . val = \t ", null);
    testParserError("  .   = \t ", "Empty ");
}
