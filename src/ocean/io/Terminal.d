/*******************************************************************************

    Provides the current size of the terminal. Updates the values when
    the size changes.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        Initial release: November 2011

    author:         Mathias Baumann

*******************************************************************************/

module ocean.io.Terminal;

/*******************************************************************************

    C functions and structures to get terminal information

******************************************************************************/

private import tango.stdc.posix.signal;


private
{
    const TIOCGWINSZ = 0x5413;
    const SIGWINCH = 28;

    /***************************************************************************

        Function to get information about the terminal, taken from the C header

    ***************************************************************************/

    extern (C) int ioctl ( int d, int request, ... );

    struct winsize
    {
        ushort ws_row;
        ushort ws_col;
        ushort ws_xpixel;
        ushort ws_ypixel;
    };
}

/*******************************************************************************

    Struct containing information and helpers to handle terminals

    Most of the control sequences can be prefixed with a ASCII digit string
    (referred to by 'n' from now on) representing usually how often the
    command should be executed.

    Cases where this is not the case are documented.

    Example:
    -----
    // Move the cursor four lines up
    Trace.formatln("{}4{}", Terminal.CSI, Terminal.CURSOR_UP);
    -----

******************************************************************************/

struct Terminal
{
    /***************************************************************************

        Amount of columns available in the terminal

    ***************************************************************************/

    public static ushort columns;

    /***************************************************************************

        Amount of rows (lines) available in the terminal

    ***************************************************************************/

    public static ushort rows;

    /***************************************************************************

        Start Sequence

    ***************************************************************************/

    public const CSI         = "\x1B[";

    /***************************************************************************

        Colours

    ***************************************************************************/

    public struct Foreground
    {
        public const BLACK               = "30m";
        public const RED                 = "31m";
        public const GREEN               = "32m";
        public const YELLOW              = "33m";
        public const BLUE                = "34m";
        public const MAGENTA             = "35m";
        public const CYAN                = "36m";
        public const WHITE               = "37m";
        public const DEFAULT_UNDERSCORE  = "38m";
        public const DEFAULT             = "39m";
    }

    public struct Background
    {
        public const BLACK      = "40m";
        public const RED        = "41m";
        public const GREEN      = "42m";
        public const YELLOW     = "43m";
        public const BLUE       = "44m";
        public const MAGENTA    = "45m";
        public const CYAN       = "46m";
        public const WHITE      = "47m";
        public const DEFAULT    = "49m";
    }


    /***************************************************************************

        Colour arrays, one for foreground and one for background colours
        Each uses the Colour enum values as index

        The enum can be useful for passing to functions in order to specify
        one of the colours defined in this module with validation
        (as opposed to accepting a generic char[]).

    ***************************************************************************/

    public enum Colour
    {
        Black,
        Red,
        Green,
        Yellow,
        Blue,
        Magenta,
        Cyan,
        White,
        Default
    }

    public static const char[][] fg_colour_codes = [
        Colour.Black: Foreground.BLACK,
        Colour.Red: Foreground.RED,
        Colour.Green: Foreground.GREEN,
        Colour.Yellow: Foreground.YELLOW,
        Colour.Blue: Foreground.BLUE,
        Colour.Magenta: Foreground.MAGENTA,
        Colour.Cyan: Foreground.CYAN,
        Colour.White: Foreground.WHITE,
        Colour.Default: Foreground.DEFAULT
    ];

    public static const char[][] bg_colour_codes = [
        Colour.Black: Background.BLACK,
        Colour.Red: Background.RED,
        Colour.Green: Background.GREEN,
        Colour.Yellow: Background.YELLOW,
        Colour.Blue: Background.BLUE,
        Colour.Magenta: Background.MAGENTA,
        Colour.Cyan: Background.CYAN,
        Colour.White: Background.WHITE,
        Colour.Default: Background.DEFAULT
    ];


    /***************************************************************************

        Bold / non-bold text.

    ***************************************************************************/

    public const BOLD   = "1m";

    public const NON_BOLD   = "22m";

    /***************************************************************************

        Command for cursor up

    ***************************************************************************/

    public const CURSOR_UP   = "A";

    /***************************************************************************

        Moves the cursor n lines up and places it at the beginning of the line

    ***************************************************************************/

    public const LINE_UP   = "F";

    /***************************************************************************

        Command for scrolling up

    ***************************************************************************/

    public const SCROLL_UP    = "S";

    /***************************************************************************

        Command for inserting a line

    ***************************************************************************/

    public const INSERT_LINE = "L";

    /***************************************************************************

        Command for erasing the rest of the line

        Erases part of the line.
        If n is zero (or missing), clear from cursor to the end of the line.
        If n is one, clear from cursor to beginning of the line.
        If n is two, clear entire line. Cursor position does not change.

    ***************************************************************************/

    public const ERASE_REST_OF_LINE = "K";

    /***************************************************************************

        Command for erasing everything below and right of the cursor

        Clears part of the screen.
        If n is zero (or missing), clear from cursor to end of screen.
        If n is one, clear from cursor to beginning of the screen.
        If n is two, clear entire screen (and moves cursor to upper
        left on MS-DOS ANSI.SYS).

    ***************************************************************************/

    public const ERASE_REST_OF_SCREEN = "J";

    /***************************************************************************

        Command for hiding the cursor

    ***************************************************************************/

    public const HIDE_CURSOR = "?25l";

    /***************************************************************************

        Command for showing the cursor

    ***************************************************************************/

    public const SHOW_CURSOR = "?25h";

    /***************************************************************************

        Moves the cursor to column n.

    ***************************************************************************/

    public const HORIZONTAL_MOVE_CURSOR = "G";
}

/*******************************************************************************

    Static Constructor.

    Registers the signal handler for window size changes and gets the size
    the first time.

******************************************************************************/

static this ( )
{
    sigaction_t act;
    with (act)
    {
        sa_flags = SA_SIGINFO;
        sa_sigaction = &window_size_changed;
    }

    sigaction(SIGWINCH, &act, null);
    window_size_changed(0, null, null);

    debug(Term) Trace.formatln("Termsize: {} {}", Terminal.rows, Terminal.columns);
}

/*******************************************************************************

    Signal handler.

    Updates TermInfo with the current terminal size

    Params:
        signal = the signal that caused the call (should always be SIGWINCH)(unused)
        info   = information about the signal (unused)
        data   = context information (unused)

*******************************************************************************/

extern (C) private void window_size_changed ( int signal, siginfo_t* info,
                                              void* data )
{
    winsize max;
    ioctl(0, TIOCGWINSZ, &max);

    Terminal.columns = max.ws_col;
    Terminal.rows    = max.ws_row;
}
