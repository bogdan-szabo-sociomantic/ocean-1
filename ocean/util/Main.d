/*******************************************************************************

    Helper functions for main().

    copyright:  Copyright (c) 2011 sociomantic labs. All rights reserved

    version:    November 2011: Initial release

    authors:    Gavin Norman, Leandro Lucarella

    main() helper functions which provide the following features:
        * --help / -h argument
        * Automatic display of arguments errors & help
        * --version / -v argument which displays the exe version
        * Automatically writes the exe version to the console and a file
          ("log/version.log") on startup (optional)

    If using processArgsConfig() it also handles configuration file parsing,
    adding an option to specify the location of the configuration file:
        * --config / -c argument.
        * The logging system is configured from the config file reading the
          [LOG*] sections using ocean.util.log.Util.configureLoggers(). See its
          documentation for details.
        * An extra config option is added to the [LOG] section:
          'default_version_log', which is a boolean defaulting to true, which
          indicates if the default version log appender should be added (it
          appends to a file located at log/version.log).

    Most common usage example:

    ---

        import some.local.ConfigStruct;
        import ocean.text.Arguments;
        import ocean.util.Main;
        import src.main.Version;

        int main ( char[][] cl_args )
        {
            // Set up app dependant arguments parser
            auto arguments = new Arguments;
            arguments("something").aliased('s').help("do something");

            const app_description = "this is a program which does something";

            // Main.processArgs parses arguments and returns true to run app
            auto r = Main.processArgsConfig!(ConfigStruct)(cl_args, arguments,
                    Version, app_description);
            if ( r.exit )
            {
                return r.exit_code;
            }

            // run application

            return 0;
        }

    ---

    This module is complemented by a script at script/mkversion.sh, which you
    can call in your Makefile to generate a D module with the version
    information (src.main.Version in this example), each time you compile the
    program.

    For example you can add something like this to your Makefile:

    ---

    DEPENDENCIES := ocean swarm sonar
    .PHONY: revision
    revision:
        @../ocean/script/mkversion.sh $(DEPENDENCIES)

    myprog: revision

    ---

    This assumes your libraries lives in the ../ directory, you want your
    Version module be generated at src/main/Version.d, you want to use the
    default template to generate the info, the date to be taken from the date
    command and  the author of the build to be guessed from the logged in user.
    All that can be overriden if necessary using mkversion.sh options (run
    mkversion.sh -h for help).

    For more details con the ConfigStruct see the processArgsConfig()
    documentation.

    Here is another, less useful, example showing how to fill the version
    information yourself, and without reading a config file:

    ---

        import ocean.text.Arguments;
        import ocean.util.Main;

        int main ( char[][] cl_args )
        {
            // Set up version information
            VersionInfo version;
            version.revision = "r1034";
            version.build_date = "today";
            version.build_author = "some guy";
            version.libraries["ocean"] = "r123";
            version.libraries["swarm"] = "r321";

            // Set up app dependant arguments parser
            auto arguments = new Arguments;
            arguments("something").aliased('s').help("do something");

            const app_description = "this is a program which does something";

            // Main.processArgs parses arguments and returns true to run app
            auto r = Main.processArgs(cl_args, arguments, Version,
                    app_description);
            if ( r.exit )
            {
                return r.exit_code;
            }

            // Only if you want to also log the version of the program
            Main.logVersion(cl_args[0], Version);

            // run application

            return 0;
        }

    ---

    TODO: Do a proper library that integrates config files and command line
          arguments (and posibly other common program features, like signal
          handling, standard logging configuration, etc.).

*******************************************************************************/

module ocean.util.Main;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.text.Arguments;
private import ocean.util.Config;
private import Class = ocean.util.config.ClassFiller;
private import ocean.util.Unittest;

// Can't use just Log because of the (in)famous DMD bug:
// http://d.puremagic.com/issues/show_bug.cgi?id=314
// Using Log instead of LogUtil will make it conflict with tango.util.log.Log.
private import LogUtil = ocean.util.log.Util;

private import tango.util.log.Log;
private import tango.util.log.AppendFile;
private import tango.util.log.LayoutDate;
private import tango.io.Stdout;



/*******************************************************************************

    Helper struct to store version information.

    This struct is meant to be filled automatically by the mkversion.sh script.

    See the module documentation for details.

*******************************************************************************/

public struct VersionInfo
{
    public char[]         revision     = "<unknown>";
    public char[]         gc           = "<unknown>";
    public char[]         build_date   = "<unknown>";
    public char[]         build_author = "<unknown>";
    public char[][char[]] libraries;
}


/*******************************************************************************

    Information on the results of processing the arguments.

    If exit is true, the program should exit and it should exit using the
    provided exit_code. Otherwise the program should run normally and exit_code
    should be ignored.

*******************************************************************************/

struct ProcessArgsResult
{
    public bool exit;
    public int  exit_code;
}


/*******************************************************************************

    Main class, all members static

*******************************************************************************/

public class Main
{

    /***************************************************************************

        Logger used to log the version.

    ***************************************************************************/

    private static Logger ver_log;

    static this ( )
    {
        ver_log = Log.lookup("ocean.util.Main.version");
    }


    /***************************************************************************

        Private constructor prevents instantiation.

    ***************************************************************************/

    private this ( ) {}


    /***************************************************************************

        Parses command line arguments, displays errors, help and application
        version as appropriate.

        Params:
            cl_args = command line arguments, as received by main()
            version_info = description of the application's version / revision
            description = application description

        Returns:
            if the program should exit and using what return code, see
            ProcessArgsResult for details

    ***************************************************************************/

    static public ProcessArgsResult processArgs ( char[][] cl_args,
            VersionInfo version_info, char[] description)
    {
        scope args = new Arguments;
        return processArgs(cl_args, args, version_info, description);
    }


    /***************************************************************************

        Parses command line arguments, displays errors, help and application
        version as appropriate.

        Params:
            cl_args = command line arguments, as received by main()
            args = arguments parser with application dependant arguments already
                initialised (this method adds -v and -h arguments)
            version_info = description of the application's version / revision
            description = application description

        Returns:
            if the program should exit and using what return code, see
            ProcessArgsResult for details

    ***************************************************************************/

    static public ProcessArgsResult processArgs ( char[][] cl_args,
            Arguments args, VersionInfo version_info, char[] description)
    {
        Unittest.check();
        
        auto app_name = cl_args[0];

        auto args_ok = parseArgs(cl_args, args);

        if ( args.exists("help") )
        {
            Stdout.formatln(getVersionString(app_name, version_info));
            Stdout.formatln("{}", description);

            args.displayHelp(app_name, Stdout);

            return ProcessArgsResult(true, 0);
        }

        if ( args.exists("version") )
        {
            Stdout.formatln(getFullVersionString(app_name, version_info));
            return ProcessArgsResult(true, 0);
        }

        if ( !args_ok )
        {
            args.displayErrors();

            Stderr.formatln("\nType {} -h for help", app_name);

            return ProcessArgsResult(true, 1);
        }

        return ProcessArgsResult(false);
    }


    /***************************************************************************

        Parses command line arguments and configuration file, displays errors,
        help and application version as appropriate.

        The StaticConfig template argument as to have an init() static method
        with this signature:

            public static void init(char[] exe_path, char[] config_file);

        Where exe_path is the path to the running executable and config_file is
        the path to a config file to read (it has to handle a null/empty
        config_file, in which case the StaticConfig should decide where to read
        the config file.

        Params:
            cl_args = command line arguments, as received by main()
            version_info = description of the application's version / revision
            description = application description

        Returns:
            if the program should exit and using what return code, see
            ProcessArgsResult for details

        TODO: Do a proper library that integrates config files and command line
              arguments (and possibly other common program features, like signal
              handling, standard logging configuration, etc.).

    ***************************************************************************/

    static public ProcessArgsResult processArgsConfig(StaticConfig) (
            char[][] cl_args, Arguments args, VersionInfo version_info,
            char[] description)
    {
        args("config").aliased('c').params(1).defaults("etc/config.ini")
            .help("use the configuration file CONFIG instead of the default "
                "(<bin-dir>/etc/config.ini)");

        auto r = Main.processArgs(cl_args, args, version_info, description);

        if ( r.exit )
        {
            return r;
        }

        StaticConfig.init(cl_args[0], args("config").assigned[0]);

        // LOG configuration parsing
        LogUtil.configureLoggers(Class.iterate!(LogUtil.Config)("LOG"),
                                 Class.fill!(LogUtil.MetaConfig)("LOG"));

        if (Config.get("LOG", "default_version_log", true))
        {
            ver_log.add(new AppendFile("log/version.log", new LayoutDate));
        }

        logVersion(cl_args[0], version_info);

        return r;
    }


    /***************************************************************************

        Log the program's version and dependencies.

        Params:
            app_name = name of the program
            version_info = description of the application's version / revision

    ***************************************************************************/

    static public void logVersion(char[] app_name, VersionInfo version_info)
    {
        ver_log.info(getFullVersionString(app_name, version_info));
    }


    /***************************************************************************

        Get a single version string with all the libraries versions.

        Params:
            libs = associative array with the name as the key and the revision
                   as the value

    ***************************************************************************/

    static public char[] getLibsVersionsString(char[][char[]] libs)
    {
        char[] s;
        foreach (name, rev; libs)
        {
            s ~= " " ~ name ~ ":" ~ rev;
        }
        return s;
    }


    /***************************************************************************

        Get the program's name and version information as a string.

        Params:
            app_name = program's name
            version_info = description of the application's version / revision

        Return:
            String with the version information

    ***************************************************************************/

    static public char[] getVersionString(char[] app_name,
            VersionInfo version_info)
    {
        return app_name ~ " version " ~ version_info.revision;
    }


    /***************************************************************************

        Get the program's name and full version information as a string.

        Params:
            app_name = program's name
            version_info = description of the application's version / revision

        Return:
            String with the version information

    ***************************************************************************/

    static public char[] getFullVersionString(char[] app_name,
            VersionInfo version_info)
    {
        return app_name ~ " version " ~ version_info.revision ~
                " (compiled by '" ~ version_info.build_author ~ "' on " ~
                version_info.build_date ~ " using GC:" ~ version_info.gc ~
                getLibsVersionsString(version_info.libraries) ~ ")";
    }


    /***************************************************************************

        Adds -v (--version) and -h (--help) arguments to the provided arguments
        parser, and parses the provided command line arguments.

        Params:
            cl_args = command line arguments, as received by main()
            args = arguments parser with application dependant arguments already
                initialised (this method adds -v and -h arguments)

        Returns:
            true if the command line arguments were parsed successfully

    ***************************************************************************/

    static private bool parseArgs ( char[][] cl_args, Arguments args )
    {
        args("help").aliased('h').help("display help");
        args("version").aliased('v').help("display version information");

        return args.parse(cl_args[1..$]);
    }

}

