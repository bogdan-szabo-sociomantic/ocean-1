/* Copyright (C) 1989-2009 Free Software Foundation, Inc.

   This file contains the GNU History Library (History), a set of
   routines for managing the text of previously typed lines.

   History is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   History is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with History.  If not, see <http://www.gnu.org/licenses/>.
*/

module ocean.io.console.readline.c.history;

public extern (C)
{
    /***************************************************************************

        Place STRING at the end of the history list.
        The associated data field (if any) is set to NULL.

    ***************************************************************************/

    void add_history(char*);

    /***************************************************************************

        Begin a session in which the history functions might be used. This just
        initializes the interactive variables.

    ***************************************************************************/

    void using_history ();
}
