/*******************************************************************************

    Module to manage command-line arguments.

    ____________________________________________________________________________


    Simple usage:

    ---

        int main ( istring[] cl_args )
        {
            // Create an object to parse command-line arguments
            auto args = new Arguments;

            // Setup what arguments are valid
            // (these can be configured in various ways as will be demonstrated
            // later in the documentation)
            args("alpha");
            args("bravo");

            // Parse the actual command-line arguments given to the application
            // (the first element is the application name, so that should not be
            // passed to the 'parse()' function)
            auto args_ok = args.parse(cl_args[1 .. $]);

            if ( args_ok )
            {
                // Proceed with rest of the application
                ...
            }
            else
            {
                // Discover what caused the error and handle appropriately
            }
        }

    ---

    ____________________________________________________________________________


    For the sake of brevity, the rest of this documentation will not show the
    'main()' function or the creation of the 'args' object. Also, setting up of
    arguments will be shown only where necessary. Moreover, the 'args.parse()'
    function will be called with a custom string representing the command-line
    arguments. This is as shown in the following example:

    ---

        args.parse("--alpha --bravo");

        if ( args("alpha").set )
        {
            // This will be reached as '--alpha' was given
        }

        if ( args("bravo").set )
        {
            // This will be reached as '--bravo' was given
        }

        if ( args("charlie").set )
        {
            // This will *not* be reached as '--charlie' was not given
        }

    ---

    ____________________________________________________________________________


    When arguments are being set up, normally all arguments that an application
    supports are explicitly declared and suitably configured. But sometimes, it
    may be desirable to use on-the-fly arguments that are not set up but
    discovered during parsing. Such arguments are called 'sloppy arguments'.
    Support for sloppy arguments is disabled by default, but can be enabled when
    calling the 'parse()' function, as shown below:

    ---

        args("alpha");

        args.parse("--alpha --bravo");
            // This will result in an error because only 'alpha' was declared,
            // but not 'bravo'.

        args.parse("--alpha --bravo", true);
            // This, on the other hand would work. Space for 'bravo' (and
            // potentially any of its parameters) would be allocated when
            // 'bravo' gets discovered during parsing.

    ---

    ____________________________________________________________________________


    Arguments can be configured to have aliases. This is a convenient way to
    represent arguments with long names. Aliases are always exactly one
    character long. An argument can have multiple aliases. Aliases are always
    given on the command-line using the short prefix.

    ---

        args("alpha").aliased('a');
        args("help").aliased('?').aliased('h'); // multiple aliases allowed

        args.parse("-a -?");

    ---

    ____________________________________________________________________________


    Arguments can be configured to be mandatorily present, by calling the
    'required()' function as follows:

    ---

        args("alpha").required();

        args.parse("--bravo");
            // This will fail because the required argument 'alpha' was not
            // given.

    ---

    ____________________________________________________________________________


    An argument can be configured to depend upon another, by calling the
    'requires()' function as follows:

    ---

        args("alpha");
        args("bravo").requires("alpha");

        args.parse("--bravo");
            // This will fail because 'bravo' needs 'alpha', but 'alpha' was not
            // given.

        args.parse("--alpha --bravo");
            // This, on the other hand, will succeed.

    ---

    ____________________________________________________________________________


    An argument can be configured to conflict with another, by calling the
    'conflicts()' function as follows:

    ---

        args("alpha");
        args("bravo").conflicts("alpha");

        args.parse("--alpha --bravo");
            // This will fail because 'bravo' conflicts with 'alpha', so both of
            // them can't be present together.

    ---

    ____________________________________________________________________________


    By default arguments don't have any associated parameters. When setting up
    arguments, they can be configured to have zero or more associated
    parameters. Parameters assigned to an argument can be accessed using that
    argument's 'assigned[]' array at consecutive indices. The number of
    parameters assigned to an argument must exactly match the number of
    parameters it has been set up to have, or else parsing will fail. Dealing
    with parameters is shown in the following example:

    ---

        args("alpha");
        args("bravo").params(0);
            // Doing `params(0)` is redundant
        args("charlie").params(1);
            // 'charlie' must have exactly one associated parameter

        args.parse("--alpha --bravo --charlie=chaplin");
            // the parameter assigned to 'charlie' (i.e. 'chaplin') can be
            // accessed using `args("charlie").assigned[0]`

    ---

    ____________________________________________________________________________


    Parameter assignment can be either explicit or implicit. Explicit assignment
    is done using an assignment symbol (defaults to '=', can be changed),
    whereas implicit assignment happens when a parameter is found after a
    whitespace.
    Implicit assignment always happens to the last known argument target, such
    that multiple parameters accumulate (until the configured parameters count
    for that argument is reached). Any extra parameters encountered after that
    are assigned to a special 'null' argument. The 'null' argument is always
    defined and acts as an accumulator for parameters left uncaptured by other
    arguments.

    Notes:
        * if sloppy arguments are supported, and if a sloppy argument happens to
          be the last known argument target, then implicit assignment of any
          extra parameters will happen to that sloppy argument.
          [example 2 below]

        * explicit assignment to an argument always associates the parameter
          with that argument even if that argument's parameters count has been
          reached. In this case, 'parse()' will fail.
          [example 3 below]

    ---

        args("alpha").params(3);

        // Example 1
        args.parse("--alpha=one --alpha=two three four");
            // In this case, 'alpha' would have 3 parameters assigned to it (so
            // its 'assigned' array would be `["one", "two", "three"]`), and the
            // null argument would have 1 parameter (with its 'assigned' array
            // being `["four"]`).
            // Here's why:
            // Two of these parameters ('one' & 'two') were assigned explicitly.
            // The next parameter ('three') was assigned implicitly since
            // 'alpha' was the last known argument target. At this point,
            // alpha's parameters count is reached, so no more implicit
            // assignment will happen to 'alpha'.
            // So the last parameter ('four') is assigned to the special 'null'
            // argument.

        // Example 2
        // (sloppy arguments supported by passing 'true' as the second parameter
        // to 'parse()')
        args.parse("--alpha one two three four --xray five six", true);
            // In this case, 'alpha' would get its 3 parameters ('one', 'two' &
            // 'three') by way of implicit assignment.
            // Parameter 'four' would be assigned to the 'null' argument (since
            // implicit assignment to the last known argument target 'alpha' is
            // not possible as alpha's parameter count has been reached).
            // The sloppy argument 'xray' now becomes the new last known
            // argument target and hence gets the last two parameters ('five' &
            // 'six').

        // Example 3
        args.parse("--alpha one two three --alpha=four");
            // As before, 'alpha' would get its 3 parameters ('one', 'two' &
            // 'three') by way of implicit assignment.
            // Since 'four' is being explicitly assigned to 'alpha', parsing
            // will fail here as 'alpha' has been configured to have at most 3
            // parameters.

    ---

    ____________________________________________________________________________


    An argument can be configured to have one or more default parameters. This
    means that if the argument was not given on the command-line, it would still
    contain the configured parameter(s).
    It is, of course, possible to have no default parameters configured. But if
    one or more default parameters have been configured, then their number must
    exactly match the number of parameters configured.

    Notes:
        * Irrespective of whether default parameters have been configured or not,
          if an argument was not given on the command-line, its 'set()' function
          would return 'false'.
          [example 1 below]

        * Irrespective of whether default parameters have been configured or not,
          if an argument is given on the command-line, it must honour its
          configured number of parameters.
          [example 2 below]

    ---

        args("alpha").params(1).defaults("one");

        // Example 1
        args.parse("--bravo");
            // 'alpha' was not given, so `args("alpha").set` would return false
            // but still `args("alpha").assigned[0]` would contain 'one'

        // Example 2
        args.parse("--alpha");
            // this will fail because 'alpha' expects a parameter and that was
            // not given. In this case, the configured default parameter will
            // *not* be picked up.

    ---

    ____________________________________________________________________________


    Parameters of an argument can be restricted to a pre-defined set of
    acceptable values. In this case, argument parsing will fail on an attempt to
    assign a value from outside the set:

    ---

        args("greeting").restrict(["hello", "namaste", "ahoj", "hola"]);
        args("enabled").restrict(["true", "false", "t", "f", "y", "n"]);

        args.parse("--greeting=bye");
            // This will fail since 'bye' is not among the acceptable values

    ---

    ____________________________________________________________________________


    The parser makes a distinction between long prefix arguments and short
    prefix arguments. Long prefix arguments start with two hyphens (--argument),
    while short prefix arguments start with a single hyphen (-a) [the prefixes
    themselves are configurable, as shown in later documentation]. Within a
    short prefix argument, each character represents an individual argument.
    Long prefix arguments must always be distinct, while short prefix arguments
    may be combined together.

    ---

        args.parse("--alpha -b");
            // The argument 'alpha' will be set.
            // The argument represented by 'b' will be set (note that 'b' here
            // could be an alias to another argument, or could be the argument
            // name itself)

    ---

    ____________________________________________________________________________


    When assigning parameters to an argument using the argument's short prefix
    version, it is possible to "smush" the parameter with the argument. Smushing
    refers to omitting the explicit assignment symbol ('=' by default) or
    whitespace (when relying on implicit assignment) that separates an argument
    from its parameter. The ability to smush an argument with its parameter in
    this manner has to be explicitly enabled using the 'smush()' function.

    Notes:
        * smushing cannot be done with the long prefix version of an argument
          [example 2 below]

        * smushing is irrelevant if an argument has no parameters
          [example 3 below]

        * if an argument has more than one parameter, and smushing is desired,
          then the short prefix version of the argument needs to be repeated as
          many times as the number of parameters to be assigned (this is because
          one smush can only assign one parameter at a time)
          [example 4 below]

        * smushing cannot be used if the parameter contains the explicit
          assignment symbol ('=' by default). In this case, either explicit or
          implicit assignment should be used. This limitation is due to how
          argv/argc values are stripped of original quotes.
          [example 5 below]

    ---

        // Example 1
        args("alpha").aliased('a').params(1).smush;
        args.parse("-aparam");
            // OK - this is equivalent to `args.parse("-a param");`

        // Example 2
        args("bravo").params(1).smush;
        args.parse("--bravoparam");
            // ERROR - 'param' cannot be smushed with 'bravo'

        // Example 3
        args("charlie").smush;
            // irrelevant smush as argument has no parameters

        // Example 4
        args('d').params(2).smush;
        args.parse("-dfile1 -dfile2");
            // smushing multiple parameters requires the short prefix version of
            // the argument to be repeated. This could have been done without
            // smushing as `args.parse("-d file1 file2);`

        // Example 5
        args("e").params(1).smush;
        args.parse("-e'foo=bar'");
            // The parameter 'foo=bar' cannot be smushed with the argument as
            // the parameter contains '=' within. Be especially careful of this
            // as the 'parse()' function will not fail in this case, but may
            // result in unexpected behaviour.
            // The proper way to assign a parameter containing the explicit
            // assignment symbol is to use one of the following:
            //     args.parse("-e='foo=bar'"); // explicit assignment
            //     args.parse("-e 'foo=bar'"); // implicit assignment

    ---

    ____________________________________________________________________________


    The prefixes used for the long prefix and the short prefix version of the
    arguments default to '--' & '-' respectively, but they are configurable. To
    change these, the desired prefix strings need to be passed to the
    constructor as shown below:

    ---

        // Change short prefix to '/' & long prefix to '%'
        auto args = new Arguments("/", "%");

        args.parse("%alpha=param %bravo /abc");
            // arguments 'alpha' & 'bravo' set using the long prefix version
            // arguments represented by the characters 'a', 'b' & 'c' set using
            // the short prefix version

    ---

    Note that it is also possible to disable both prefixes by passing 'null' as
    the constructor parameters.

    ____________________________________________________________________________


    We noted in the documentation earlier that a parameter following a
    whitespace gets assigned to the last known target (implicit assignment). On
    the other hand, the symbol used for explicitly assigning a parameter to an
    argument defaults to '='. This symbol is also configurable, and can be
    changed by passing the desired symbol character to the constructor as shown
    below:

    ---

        // Change the parameter assignment symbol to ':'
        // (the short prefix and long prefix need to be passed as their default
        // values since we're not changing them)
        auto args = new Arguments("-", "--", ':');

        args.parse("--alpha:param");
            // argument 'alpha' will be assigned parameter 'param' using
            // explicit assignment

    ---

    ____________________________________________________________________________


    All text following a "--" token are treated as parameters (even if they
    start with the long prefix or the short prefix). This notion is applied by
    unix systems to terminate argument processing in a similar manner.

    If `version ( dashdash )` is enabled, then these parameters are always
    assigned to the special 'null' argument. Otherwise, they are assigned to the
    last known argument target.

    ---

        args("alpha").params(1);

        args.parse("--alpha one -- -two --three");
            // 'alpha' gets one parameter ('one')
            // the null argument gets two parameters ('-two' & '--three')
            // note how 'two' & 'three' are prefixed by the short and long
            // prefixes respectively, but the prefixes don't play any part as
            // these are just parameters now

    ---

    ____________________________________________________________________________


    When configuring the command-line arguments, qualifiers can be chained
    together as shown in the following example:

    ---

        args("alpha")
            .required
            .params(1)
            .aliased('a')
            .requires("bravo")
            .conflicts("charlie")
            .defaults("one");

    ---

    ____________________________________________________________________________


    The 'parse()' function will return true only where all conditions are met.
    If an error occurs, the parser will set an error code and return false.

    The error codes (which indicate the nature of the error) are as follows:

        None     : ok (no error)
        ParamLo  : too few parameters were assigned to this argument
        ParamHi  : too many parameters were assigned to this argument
        Required : this is a required argument, but was not given
        Requires : this argument depends on another argument which was not given
        Conflict : this argument conflicts with another given argument
        Extra    : unexpected argument (will not trigger an error if sloppy
                   arguments are enabled)
        Option   : parameter assigned is not one of the acceptable options


    A simple way to handle errors is to invoke an internal format routine, which
    constructs error messages on your behalf. The messages are constructed using
    a layout handler and the messages themselves may be customized (for i18n
    purposes). See the two 'errors()' methods for more information on this. The
    following example shows this way of handling errors:

    ---

        if ( ! args.parse (...) )
        {
            stderr(args.errors(&stderr.layout.sprint));
        }

    ---


    Another way of handling argument parsing errors, is to traverse the set of
    arguments, to find out exactly which argument has the error, and what is the
    error code. This is as shown in the following example:

    ---

        if ( ! args.parse (...) )
        {
            foreach ( arg; args )
            {
                if ( arg.error )
                {
                    // 'arg.error' contains one of the above error-codes

                    ...
                }
            }
        }

    ---

    ____________________________________________________________________________


    The following two types of callbacks are supported:
        - a callback called when an argument is parsed
        - a callback called whenever a parameter gets assigned to an argument
    (see the 'bind()' methods for the signatures of these delegates).

    ____________________________________________________________________________


    Copyright: Copyright (c) 2009 Kris. All rights reserved.


*******************************************************************************/

module tango.text.Arguments;

import tango.transition;

import tango.text.Util;
import tango.util.container.more.Stack;

version=dashdash;       // -- everything assigned to the null argument

/*******************************************************************************

    Command-line argument parser. Simple usage is:
    ---
    auto args = new Arguments;
    args.parse ("-a -b", true);
    auto a = args("a");
    auto b = args("b");
    if (a.set && b.set)
        ...
    ---

    Argument parameters are assigned to the last known target, such
    that multiple parameters accumulate:
    ---
    args.parse ("-a=1 -a=2 foo", true);
    assert (args('a').assigned.length is 3);
    ---

    That example results in argument 'a' assigned three parameters.
    Two parameters are explicitly assigned using '=', while a third
    is implicitly assigned. Implicit parameters are often useful for
    collecting filenames or other parameters without specifying the
    associated argument:
    ---
    args.parse ("thisfile.txt thatfile.doc -v", true);
    assert (args(null).assigned.length is 2);
    ---
    The 'null' argument is always defined and acts as an accumulator
    for parameters left uncaptured by other arguments. In the above
    instance it was assigned both parameters.

    Examples thus far have used 'sloppy' argument declaration, via
    the second argument of parse() being set true. This allows the
    parser to create argument declaration on-the-fly, which can be
    handy for trivial usage. However, most features require the a-
    priori declaration of arguments:
    ---
    args = new Arguments;
    args('x').required;
    if (! args.parse("-x"))
          // x not supplied!
    ---

    Sloppy arguments are disabled in that example, and a required
    argument 'x' is declared. The parse() method will fail if the
    pre-conditions are not fully met. Additional qualifiers include
    specifying how many parameters are allowed for each individual
    argument, default parameters, whether an argument requires the
    presence or exclusion of another, etc. Qualifiers are typically
    chained together and the following example shows argument "foo"
    being made required, with one parameter, aliased to 'f', and
    dependent upon the presence of another argument "bar":
    ---
    args("foo").required.params(1).aliased('f').requires("bar");
    args("help").aliased('?').aliased('h');
    ---

    Parameters can be constrained to a set of matching text values,
    and the parser will fail on mismatched input:
    ---
    args("greeting").restrict("hello", "yo", "gday");
    args("enabled").restrict("true", "false", "t", "f", "y", "n");
    ---

    A set of declared arguments may be configured in this manner
    and the parser will return true only where all conditions are
    met. Where a error condition occurs you may traverse the set
    of arguments to find out which argument has what error. This
    can be handled like so, where arg.error holds a defined code:
    ---
    if (! args.parse (...))
          foreach (arg; args)
                   if (arg.error)
                       ...
    ---

    Error codes are as follows:
    ---
    None:           ok (zero)
    ParamLo:        too few params for an argument
    ParamHi:        too many params for an argument
    Required:       missing argument is required
    Requires:       depends on a missing argument
    Conflict:       conflicting argument is present
    Extra:          unexpected argument (see sloppy)
    Option:         parameter does not match options
    ---

    A simpler way to handle errors is to invoke an internal format
    routine, which constructs error messages on your behalf:
    ---
    if (! args.parse (...))
          stderr (args.errors(&stderr.layout.sprint));
    ---

    Note that messages are constructed via a layout handler and
    the messages themselves may be customized (for i18n purposes).
    See the two errors() methods for more information on this.

    The parser make a distinction between a short and long prefix,
    in that a long prefix argument is always distinct while short
    prefix arguments may be combined as a shortcut:
    ---
    args.parse ("--foo --bar -abc", true);
    assert (args("foo").set);
    assert (args("bar").set);
    assert (args("a").set);
    assert (args("b").set);
    assert (args("c").set);
    ---

    In addition, short-prefix arguments may be "smushed" with an
    associated parameter when configured to do so:
    ---
    args('o').params(1).smush;
    if (args.parse ("-ofile"))
        assert (args('o').assigned[0] == "file");
    ---

    There are two callback varieties supports, where one is invoked
    when an associated argument is parsed and the other is invoked
    as parameters are assigned. See the bind() methods for delegate
    signature details.

    You may change the argument prefix to be something other than
    "-" and "--" via the constructor. You might, for example, need
    to specify a "/" indicator instead, and use ':' for explicitly
    assigning parameters:
    ---
    auto args = new Args ("/", "-", ':');
    args.parse ("-foo:param -bar /abc");
    assert (args("foo").set);
    assert (args("bar").set);
    assert (args("a").set);
    assert (args("b").set);
    assert (args("c").set);
    assert (args("foo").assigned.length is 1);
    ---

    Returning to an earlier example we can declare some specifics:
    ---
    args('v').params(0);
    assert (args.parse (`-v thisfile.txt thatfile.doc`));
    assert (args(null).assigned.length is 2);
    ---

    Note that the -v flag is now in front of the implicit parameters
    but ignores them because it is declared to consume none. That is,
    implicit parameters are assigned to arguments from right to left,
    according to how many parameters said arguments may consume. Each
    sloppy argument consumes parameters by default, so those implicit
    parameters would have been assigned to -v without the declaration
    shown. On the other hand, an explicit assignment (via '=') always
    associates the parameter with that argument even when an overflow
    would occur (though will cause an error to be raised).

    Certain parameters are used for capturing comments or other plain
    text from the user, including whitespace and other special chars.
    Such parameter values should be quoted on the commandline, and be
    assigned explicitly rather than implicitly:
    ---
    args.parse (`--comment="-- a comment --"`);
    ---

    Without the explicit assignment, the text content might otherwise
    be considered the start of another argument (due to how argv/argc
    values are stripped of original quotes).

    Lastly, all subsequent text is treated as paramter-values after a
    "--" token is encountered. This notion is applied by unix systems
    to terminate argument processing in a similar manner. Such values
    are considered to be implicit, and are assigned to preceding args
    in the usual right to left fashion (or to the null argument):
    ---
    args.parse (`-- -thisfile --thatfile`);
    assert (args(null).assigned.length is 2);
    ---

*******************************************************************************/

class Arguments
{
    public alias get                opCall;         // args("name")
    public alias get                opIndex;        // args["name"]

    private Stack!(Argument)        stack;          // args with params
    private Argument[istring]       args;           // the set of args
    private Argument[istring]       aliases;        // set of aliases
    private char                    eq;             // '=' or ':'
    private istring                 sp,             // short prefix
                                    lp;             // long prefix
    private istring[]               msgs;           // error messages
    private static istring[]        errmsg = [      // default errors
        "argument '{0}' expects {2} parameter(s) but has {1}\n",
        "argument '{0}' expects {3} parameter(s) but has {1}\n",
        "argument '{0}' is missing\n",
        "argument '{0}' requires '{4}'\n",
        "argument '{0}' conflicts with '{4}'\n",
        "unexpected argument '{0}'\n",
        "argument '{0}' expects one of {5}\n",
        "invalid parameter for argument '{0}': {4}\n",
    ];

    /***********************************************************************

      Construct with the specific short & long prefixes, and the
      given assignment character (typically ':' on Windows but we
      set the defaults to look like unix instead)

     ***********************************************************************/

    this (istring sp="-", istring lp="--", char eq='=')
    {
        this.msgs = this.errmsg;
        this.sp = sp;
        this.lp = lp;
        this.eq = eq;
        get(null).params;       // set null argument to consume params
    }

    /***********************************************************************

      Parse string[] into a set of Argument instances. The 'sloppy'
      option allows for unexpected arguments without error.

      Returns false where an error condition occurred, whereupon the
      arguments should be traversed to discover said condition(s):
      ---
      auto args = new Arguments;
      if (! args.parse (...))
      stderr (args.errors(&stderr.layout.sprint));
      ---

     ***********************************************************************/

    final bool parse (istring input, bool sloppy=false)
    {
        istring[] tmp;
        foreach (s; quotes(input, " "))
            tmp ~= s;
        return parse (tmp, sloppy);
    }

    /***********************************************************************

      Parse a string into a set of Argument instances. The 'sloppy'
      option allows for unexpected arguments without error.

      Returns false where an error condition occurred, whereupon the
      arguments should be traversed to discover said condition(s):
      ---
      auto args = new Arguments;
      if (! args.parse (...))
      Stderr (args.errors(&Stderr.layout.sprint));
      ---

     ***********************************************************************/

    final bool parse (istring[] input, bool sloppy=false)
    {
        bool    done;
        int     error;

        debug(Arguments) stdout.formatln ("\ncmdline: '{}'", input);
        stack.push (get(null));
        foreach (s; input)
        {
            debug(Arguments) stdout.formatln ("'{}'", s);
            if (done is false)
            {
                if (s == "--")
                {
                    done = true;
                    version(dashdash) stack.clear.push(get(null));
                    continue;
                }
                else
                    if (argument (s, lp, sloppy, false) ||
                            argument (s, sp, sloppy, true))
                        continue;
            }
            stack.top.append (s);
        }
        foreach (arg; args)
            error |= arg.valid;
        return error is 0;
    }

    /***********************************************************************

      Clear parameter assignments, flags and errors. Note this
      does not remove any Arguments

     ***********************************************************************/

    final Arguments clear ()
    {
        stack.clear;
        foreach (arg; args)
        {
            arg.set = false;
            arg.values = null;
            arg.error = arg.None;
        }
        return this;
    }

    /***********************************************************************

      Obtain an argument reference, creating an new instance where
      necessary. Use array indexing or opCall syntax if you prefer

     ***********************************************************************/

    final Argument get (char name)
    {
        return get (cast(istring) (&name)[0..1]);
    }

    /***********************************************************************

      Obtain an argument reference, creating an new instance where
      necessary. Use array indexing or opCall syntax if you prefer.

      Pass null to access the 'default' argument (where unassigned
      implicit parameters are gathered)

     ***********************************************************************/

    final Argument get (cstring name)
    {
        auto a = name in args;
        if (a is null)
        {
            auto _name = idup(name);
            return args[_name] = new Argument(_name);
        }
        return *a;
    }

    /***********************************************************************

      Traverse the set of arguments

     ***********************************************************************/

    final int opApply (int delegate(ref Argument) dg)
    {
        int result;
        foreach (arg; args)
            if ((result=dg(arg)) != 0)
                break;
        return result;
    }

    /***********************************************************************

      Construct a string of error messages, using the given
      delegate to format the output. You would typically pass
      the system formatter here, like so:
      ---
      auto msgs = args.errors (&stderr.layout.sprint);
      ---

      The messages are replacable with custom (i18n) versions
      instead, using the errors(char[][]) method

     ***********************************************************************/

    final istring errors (mstring delegate(mstring buf, cstring fmt, ...) dg)
    {
        char[256] tmp;
        istring result;
        foreach (arg; args)
            if (arg.error)
                result ~= dg (tmp, msgs[arg.error-1], arg.name,
                        arg.values.length, arg.min, arg.max,
                        arg.bogus, arg.options);
        return result;
    }

    /***********************************************************************

      Use this method to replace the default error messages. Note
      that arguments are passed to the formatter in the following
      order, and these should be indexed appropriately by each of
      the error messages (see examples in errmsg above):
      ---
      index 0: the argument name
      index 1: number of parameters
      index 2: configured minimum parameters
      index 3: configured maximum parameters
      index 4: conflicting/dependent argument (or invalid param)
      index 5: array of configured parameter options
      ---

     ***********************************************************************/

    final Arguments errors (istring[] errors)
    {
        if (errors.length is errmsg.length)
            msgs = errors;
        else
            assert (false);
        return this;
    }

    /***********************************************************************

      Expose the configured set of help text, via the given
      delegate

     ***********************************************************************/

    final Arguments help (void delegate(istring arg, istring help) dg)
    {
        foreach (arg; args)
            if (arg.text.ptr)
                dg (arg.name, arg.text);
        return this;
    }

    /***********************************************************************

      Test for the presence of a switch (long/short prefix)
      and enable the associated arg where found. Also look
      for and handle explicit parameter assignment

     ***********************************************************************/

    private bool argument (istring s, istring p, bool sloppy, bool flag)
    {
        if (s.length >= p.length && s[0..p.length] == p)
        {
            s = s [p.length..$];
            auto i = locate (s, eq);
            if (i < s.length)
                enable (s[0..i], sloppy, flag).append (s[i+1..$], true);
            else
                // trap empty arguments; attach as param to null-arg
                if (s.length)
                    enable (s, sloppy, flag);
                else
                    get(null).append (p, true);
            return true;
        }
        return false;
    }

    /***********************************************************************

      Indicate the existance of an argument, and handle sloppy
      options along with multiple-flags and smushed parameters.
      Note that sloppy arguments are configured with parameters
      enabled.

     ***********************************************************************/

    private Argument enable (istring elem, bool sloppy, bool flag=false)
    {
        if (flag && elem.length > 1)
        {
            // locate arg for first char
            auto arg = enable (elem[0..1], sloppy);
            elem = elem[1..$];

            // drop further processing of this flag where in error
            if (arg.error is arg.None)
            {
                // smush remaining text or treat as additional args
                if (arg.cat)
                    arg.append (elem, true);
                else
                    arg = enable (elem, sloppy, true);
            }
            return arg;
        }

        // if not in args, or in aliases, then create new arg
        auto a = elem in args;
        if (a is null)
            if ((a = elem in aliases) is null)
                return get(elem).params.enable(!sloppy);
        return a.enable;
    }

    /***********************************************************************

      A specific argument instance. You get one of these from
      Arguments.get() and visit them via Arguments.opApply()

     ***********************************************************************/

    class Argument
    {
        /***************************************************************

          Error identifiers:
          ---
None:           ok
ParamLo:        too few params for an argument
ParamHi:        too many params for an argument
Required:       missing argument is required
Requires:       depends on a missing argument
Conflict:       conflicting argument is present
Extra:          unexpected argument (see sloppy)
Option:         parameter does not match options
---

         ***************************************************************/

        enum {None, ParamLo, ParamHi, Required, Requires, Conflict, Extra, Option, Invalid};

        alias void   delegate() Invoker;
        alias istring delegate(istring value) Inspector;

        public int         min,            /// minimum params
                           max,            /// maximum params
                           error;          /// error condition
        public  bool       set;            /// arg is present
        public  istring    aliases;        /// Array of aliases
        private bool       req,            // arg is required
                           cat,            // arg is smushable
                           exp,            // implicit params
                           fail;           // fail the parse
        public  istring    name,           // arg name
                           text;           // help text
        private istring    bogus;          // name of conflict
        private istring[]  values;         // assigned values
        public istring[]   options,        // validation options
                           deefalts;       // configured defaults
        private Invoker    invoker;        // invocation callback
        private Inspector  inspector;      // inspection callback
        private Argument[] dependees,      // who we require
                           conflictees;    // who we conflict with

        /***************************************************************

          Create with the given name

         ***************************************************************/

        this (istring name)
        {
            this.name = name;
        }

        /***************************************************************

          Return the name of this argument

         ***************************************************************/

        override istring toString()
        {
            return name;
        }

        /***************************************************************

          return the assigned parameters, or the defaults if
          no parameters were assigned

         ***************************************************************/

        final istring[] assigned ()
        {
            return values.length ? values : deefalts;
        }

        /***************************************************************

          Alias this argument with the given name. If you need
          long-names to be aliased, create the long-name first
          and alias it to a short one

         ***************************************************************/

        final Argument aliased (char name)
        {
            if ( auto arg = (&name)[0..1] in this.outer.aliases )
            {
                assert(
                    false,
                    "Argument '" ~ this.name ~ "' cannot " ~
                        "be assigned alias '" ~ name ~ "' as it has " ~
                        "already been assigned to argument '"
                        ~ arg.name ~ "'."
                );
            }

            this.outer.aliases[idup((&name)[0..1])] = this;
            this.aliases ~= name;
            return this;
        }

        /***************************************************************

          Make this argument a requirement

         ***************************************************************/

        final Argument required ()
        {
            this.req = true;
            return this;
        }

        /***************************************************************

          Set this argument to depend upon another

         ***************************************************************/

        final Argument requires (Argument arg)
        {
            dependees ~= arg;
            return this;
        }

        /***************************************************************

          Set this argument to depend upon another

         ***************************************************************/

        final Argument requires (istring other)
        {
            return requires (this.outer.get(other));
        }

        /***************************************************************

          Set this argument to depend upon another

         ***************************************************************/

        final Argument requires (char other)
        {
            return requires (cast(istring) (&other)[0..1]);
        }

        /***************************************************************

          Set this argument to conflict with another

         ***************************************************************/

        final Argument conflicts (Argument arg)
        {
            conflictees ~= arg;
            return this;
        }

        /***************************************************************

          Set this argument to conflict with another

         ***************************************************************/

        final Argument conflicts (istring other)
        {
            return conflicts (this.outer.get(other));
        }

        /***************************************************************

          Set this argument to conflict with another

         ***************************************************************/

        final Argument conflicts (char other)
        {
            return conflicts (cast(istring) (&other)[0..1]);
        }

        /***************************************************************

          Enable parameter assignment: 0 to 42 by default

         ***************************************************************/

        final Argument params ()
        {
            return params (0, 42);
        }

        /***************************************************************

          Set an exact number of parameters required

         ***************************************************************/

        final Argument params (int count)
        {
            return params (count, count);
        }

        /***************************************************************

          Set both the minimum and maximum parameter counts

         ***************************************************************/

        final Argument params (int min, int max)
        {
            this.min = min;
            this.max = max;
            return this;
        }

        /***************************************************************

          Add another default parameter for this argument

         ***************************************************************/

        final Argument defaults (istring values)
        {
            this.deefalts ~= values;
            return this;
        }

        /***************************************************************

          Set an inspector for this argument, fired when a
          parameter is appended to an argument. Return null
          from the delegate when the value is ok, or a text
          string describing the issue to trigger an error

         ***************************************************************/

        final Argument bind (Inspector inspector)
        {
            this.inspector = inspector;
            return this;
        }

        /***************************************************************

          Set an invoker for this argument, fired when an
          argument declaration is seen

         ***************************************************************/

        final Argument bind (Invoker invoker)
        {
            this.invoker = invoker;
            return this;
        }

        /***************************************************************

          Enable smushing for this argument, where "-ofile"
          would result in "file" being assigned to argument
          'o'

         ***************************************************************/

        final Argument smush (bool yes=true)
        {
            cat = yes;
            return this;
        }

        /***************************************************************

          Disable implicit arguments

         ***************************************************************/

        final Argument explicit ()
        {
            exp = true;
            return this;
        }

        /***************************************************************

          Alter the title of this argument, which can be
          useful for naming the default argument

         ***************************************************************/

        final Argument title (istring name)
        {
            this.name = name;
            return this;
        }

        /***************************************************************

          Set the help text for this argument

         ***************************************************************/

        final Argument help (istring text)
        {
            this.text = text;
            return this;
        }

        /***************************************************************

          Fail the parse when this arg is encountered. You
          might use this for managing help text

         ***************************************************************/

        final Argument halt ()
        {
            this.fail = true;
            return this;
        }

        /***************************************************************

          Restrict values to one of the given set

         ***************************************************************/

        final Argument restrict (istring[] options ...)
        {
            this.options = options;
            return this;
        }

        /***************************************************************

          This arg is present, but set an error condition
          (Extra) when unexpected and sloppy is not enabled.
          Fires any configured invoker callback.

         ***************************************************************/

        private Argument enable (bool unexpected=false)
        {
            this.set = true;
            if (max > 0)
                this.outer.stack.push(this);

            if (invoker)
                invoker();
            if (unexpected)
                error = Extra;
            return this;
        }

        /***************************************************************

          Append a parameter value, invoking an inspector as
          necessary

         ***************************************************************/

        private void append (istring value, bool explicit=false)
        {
            // pop to an argument that can accept implicit parameters?
            if (explicit is false)
            {
                auto s = &(this.outer.stack);
                while (s.top.exp && s.size > 1)
                    s.pop;
            }

            this.set = true;        // needed for default assignments
            values ~= value;        // append new value

            if (error is None)
            {
                if (inspector)
                    if ((bogus = inspector(value)).length)
                        error = Invalid;

                if (options.length)
                {
                    error = Option;
                    foreach (option; options)
                        if (option == value)
                            error = None;
                }
            }
            // pop to an argument that can accept parameters

            auto s = &(this.outer.stack);
            while (s.top.values.length >= max && s.size>1)
                s.pop;
        }

        /***************************************************************

          Test and set the error flag appropriately

         ***************************************************************/

        private int valid ()
        {
            if (error is None)
            {
                if (req && !set)
                    error = Required;
                else
                    if (set)
                    {
                        // short circuit?
                        if (fail)
                            return -1;

                        if (values.length < min)
                            error = ParamLo;
                        else
                            if (values.length > max)
                                error = ParamHi;
                            else
                            {
                                foreach (arg; dependees)
                                    if (! arg.set)
                                        error = Requires, bogus=arg.name;

                                foreach (arg; conflictees)
                                    if (arg.set)
                                        error = Conflict, bogus=arg.name;
                            }
                    }
            }

            debug(Arguments)
                stdout.formatln ("{}: error={}, set={}, min={}, max={}, "
                    "req={}, values={}, defaults={}, requires={}",
                    name, error, set, min, max, req, values,
                    deefalts, dependees);
            return error;
        }
    }
}


/*******************************************************************************

 *******************************************************************************/

unittest
{
    auto args = new Arguments;

    // basic
    auto x = args['x'];
    assert (args.parse (""));
    x.required;
    assert (args.parse ("") is false);
    assert (args.clear.parse ("-x"));
    assert (x.set);

    // alias
    x.aliased('X');
    assert (args.clear.parse ("-X"));
    assert (x.set);

    // unexpected arg (with sloppy)
    assert (args.clear.parse ("-y") is false);
    assert (args.clear.parse ("-y") is false);
    assert (args.clear.parse ("-y", true) is false);
    assert (args['y'].set);
    assert (args.clear.parse ("-x -y", true));

    // parameters
    x.params(0);
    assert (args.clear.parse ("-x param"));
    assert (x.assigned.length is 0);
    assert (args(null).assigned.length is 1);
    x.params(1);
    assert (args.clear.parse ("-x=param"));
    assert (x.assigned.length is 1);
    assert (x.assigned[0] == "param");
    assert (args.clear.parse ("-x param"));
    assert (x.assigned.length is 1);
    assert (x.assigned[0] == "param");

    // too many args
    x.params(1);
    assert (args.clear.parse ("-x param1 param2"));
    assert (x.assigned.length is 1);
    assert (x.assigned[0] == "param1");
    assert (args(null).assigned.length is 1);
    assert (args(null).assigned[0] == "param2");

    // now with default params
    assert (args.clear.parse ("param1 param2 -x=blah"));
    assert (args[null].assigned.length is 2);
    assert (args(null).assigned.length is 2);
    assert (x.assigned.length is 1);
    x.params(0);
    assert (!args.clear.parse ("-x=blah"));

    // args as parameter
    assert (args.clear.parse ("- -x"));
    assert (args[null].assigned.length is 1);
    assert (args[null].assigned[0] == "-");

    // multiple flags, with alias and sloppy
    assert (args.clear.parse ("-xy"));
    assert (args.clear.parse ("-xyX"));
    assert (x.set);
    assert (args['y'].set);
    assert (args.clear.parse ("-xyz") is false);
    assert (args.clear.parse ("-xyz", true));
    auto z = args['z'];
    assert (z.set);

    // multiple flags with trailing arg
    assert (args.clear.parse ("-xyz=10"));
    assert (z.assigned.length is 1);

    // again, but without sloppy param declaration
    z.params(0);
    assert (!args.clear.parse ("-xyz=10"));
    assert (args.clear.parse ("-xzy=10"));
    assert (args('y').assigned.length is 1);
    assert (args('x').assigned.length is 0);
    assert (args('z').assigned.length is 0);

    // x requires y
    x.requires('y');
    assert (args.clear.parse ("-xy"));
    assert (args.clear.parse ("-xz") is false);

    // defaults
    z.defaults("foo");
    assert (args.clear.parse ("-xy"));
    assert (z.assigned.length is 1);

    // long names, with params
    assert (args.clear.parse ("-xy --foobar") is false);
    assert (args.clear.parse ("-xy --foobar", true));
    assert (args["y"].set && x.set);
    assert (args["foobar"].set);
    assert (args.clear.parse ("-xy --foobar=10"));
    assert (args["foobar"].assigned.length is 1);
    assert (args["foobar"].assigned[0] == "10");

    // smush argument z, but not others
    z.params;
    assert (args.clear.parse ("-xy -zsmush") is false);
    assert (x.set);
    z.smush;
    assert (args.clear.parse ("-xy -zsmush"));
    assert (z.assigned.length is 1);
    assert (z.assigned[0] == "smush");
    assert (x.assigned.length is 0);
    z.params(0);

    // conflict x with z
    x.conflicts(z);
    assert (args.clear.parse ("-xyz") is false);

    // word mode, with prefix elimination
    args = new Arguments (null, null);
    assert (args.clear.parse ("foo bar wumpus") is false);
    assert (args.clear.parse ("foo bar wumpus wombat", true));
    assert (args("foo").set);
    assert (args("bar").set);
    assert (args("wumpus").set);
    assert (args("wombat").set);

    // use '/' instead of '-'
    args = new Arguments ("/", "/");
    assert (args.clear.parse ("/foo /bar /wumpus") is false);
    assert (args.clear.parse ("/foo /bar /wumpus /wombat", true));
    assert (args("foo").set);
    assert (args("bar").set);
    assert (args("wumpus").set);
    assert (args("wombat").set);

    // use '/' for short and '-' for long
    args = new Arguments ("/", "-");
    assert (args.clear.parse ("-foo -bar -wumpus -wombat /abc", true));
    assert (args("foo").set);
    assert (args("bar").set);
    assert (args("wumpus").set);
    assert (args("wombat").set);
    assert (args("a").set);
    assert (args("b").set);
    assert (args("c").set);

    // "--" makes all subsequent be implicit parameters
    args = new Arguments;
    version (dashdash)
    {
        args('f').params(0);
        assert (args.parse ("-f -- -bar -wumpus -wombat --abc"));
        assert (args('f').assigned.length is 0);
        assert (args(null).assigned.length is 4);
    }
    else
    {
        args('f').params(2);
        assert (args.parse ("-f -- -bar -wumpus -wombat --abc"));
        assert (args('f').assigned.length is 2);
        assert (args(null).assigned.length is 2);
    }
}

/*******************************************************************************

 *******************************************************************************/

debug (Arguments)
{
    import tango.io.Stdout;

    void main()
    {
        char[] crap = "crap";
        auto args = new Arguments;

        args(null).title("root").params.help("root help");
        args('x').aliased('X').params(0).required.help("x help");
        args('y').defaults("hi").params(2).smush.explicit.help("y help");
        args('a').required.defaults("hi").requires('y').params(1).help("a help");
        args("foobar").params(2).help("foobar help");
        if (! args.parse ("'one =two' -xa=bar -y=ff -yss --foobar=blah1 --foobar barf blah2 -- a b c d e"))
            stdout (args.errors(&stdout.layout.sprint));
        else
            if (args.get('x'))
                args.help ((char[] a, char[] b){Stdout.formatln ("{}{}\n\t{}", args.lp, a, b);});
    }
}
