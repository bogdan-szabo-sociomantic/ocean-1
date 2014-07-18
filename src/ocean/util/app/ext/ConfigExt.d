/*******************************************************************************

    Application extension to parse configuration files.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.ConfigExt;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.app.model.ExtensibleClassMixin;
private import ocean.util.app.model.IApplicationExtension;
private import ocean.util.app.Application;
private import ocean.util.app.ext.model.IConfigExtExtension;
private import ocean.util.app.ext.model.IArgumentsExtExtension;
private import ocean.util.app.ext.ArgumentsExt;

private import ocean.util.Config;
private import ocean.util.config.ConfigParser;
private import ocean.text.Arguments;

private import tango.text.Util : join, locate;
private import tango.core.Exception : IOException;



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

    ***************************************************************************/

    public override int order ( )
    {
        return -10_000;
    }


    /***************************************************************************

        Setup command line arguments (ArgumentsExt hook).

        Adds --config/-c option and --loose-config-parsing if appropriate.

    ***************************************************************************/

    public void setupArgs ( IApplication app, Arguments args )
    {
        args("config").aliased('c').params(1).smush()
            .help("use the configuration file CONFIG instead of the default "
                "(" ~ join(this.default_configs, ", ") ~ ")");
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
            .help("override a configuration value (example: "
                    "-O '[section-name]config-value = \"something\"', need "
                    "a space between -O and the option now because of a Tango "
                    "bug)");
    }


    /***************************************************************************

        Process command line arguments (ArgumentsExt hook).

        Overrides the loose_config_parsing variable if appropriate.

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

    ***************************************************************************/

    public void processOverrides ( Arguments args )
    {
        foreach (opt; args("override-config").assigned)
        {
            this.config.resetParser();

            auto section_end = locate(opt, ']');
            auto section = opt[0 .. section_end];
            this.config.parseLine(section);

            auto remaining = opt[section_end + 1 .. $];
            this.config.parseString(remaining);
        }
    }


    /***************************************************************************

        Do a simple validation over override-config arguments

    ***************************************************************************/

    public char[] validateArgs ( IApplication app, Arguments args )
    {
        char[][] errors;
        foreach (opt; args("override-config").assigned)
        {
            int pos = locate(opt, ']');
            if (pos >= opt.length)
            {
                errors ~= "bad override '" ~ opt ~ "', no section found";
                continue;
            }
            int pos2 = locate(opt, '=');
            if (pos2 >= opt.length)
            {
                errors ~= "bad override '" ~ opt ~ "', no key found";
                continue;
            }
            if (pos2 < pos)
            {
                errors ~= "bad override '" ~ opt ~ "', section expected "
                        "before key";
                continue;
            }
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
                this.config.resetParser();
                this.config.parse(config_file, false);
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

}

