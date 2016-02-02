/* Copyright (C) 1987-2011 Free Software Foundation, Inc.

   This file is part of the GNU Readline Library (Readline), a library
   for reading lines of text with interactive input and history editing.

   Readline is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Readline is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with Readline.  If not, see <http://www.gnu.org/licenses/>.
*/

module ocean.io.console.readline.c.readline;


/*******************************************************************************

    Imports

*******************************************************************************/

import tango.transition;


public extern (C)
{
    /***************************************************************************

        Function signature for functions used with the rl_bind_key functions and
        various other functions.

    ***************************************************************************/

    alias int function (int count, int c) rl_command_func_t;

    /***************************************************************************

        Abort pushing back character param ''c'' to input stream

    ***************************************************************************/

    extern mixin(global("rl_command_func_t rl_abort;"));

    /***************************************************************************

        Insert character param  ``c'' back into input stream for param ``count''
        times

    ***************************************************************************/

    extern mixin(global("rl_command_func_t rl_insert;"));

    /***************************************************************************

        Utility functions to bind keys to readline commands.

    ***************************************************************************/

    int rl_bind_key(int key, rl_command_func_t* _function);

    /***************************************************************************

        Read a line of input. Prompt with PROMPT. A NULL PROMPT means none.

    ***************************************************************************/

    char* readline(char*);
}
