/******************************************************************************

    Elastic Binary Trees - macros and structures for operations on 64bit nodes.
    Version 6.0
    (C) 2002-2010 - Willy Tarreau <w@1wt.eu>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

    D language binding:

    You need to have the library installed and link with -lebtree. A Debian
    package is provided in Sociomantic repos.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.util.container.ebtree.c.eb64tree;

import ocean.util.container.ebtree.c.ebtree: eb_root, eb_node;

/**
 * This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 */
struct eb64_node
{
    eb_node node; // the tree node, must be at the beginning
    ulong   key;

    /// Return next node in the tree, skipping duplicates, or NULL if none

    typeof (this) next ( )
    {
        return eb64_next(this);
    }

    /// Return previous node in the tree, or NULL if none

    typeof (this) prev ( )
    {
        return eb64_prev(this);
    }

    /// Return next node in the tree, skipping duplicates, or NULL if none

    typeof (this) next_unique ( )
    {
        return eb64_next_unique(this);
    }

    /// Return previous node in the tree, skipping duplicates, or NULL if none

    typeof (this) prev_unique ( )
    {
        return eb64_prev_unique(this);
    }
}

extern (C):

///// Return leftmost node in the tree, or NULL if none
eb64_node* eb64_first(eb_root* root);

/// Return rightmost node in the tree, or NULL if none
eb64_node* eb64_last(eb_root* root);

/// Return next node in the tree, or NULL if none
eb64_node* eb64_next(eb64_node* eb64);

/// Return previous node in the tree, or NULL if none
eb64_node* eb64_prev(eb64_node* eb64);

/// Return next node in the tree, skipping duplicates, or NULL if none
eb64_node* eb64_next_unique(eb64_node* eb64);

/// Return previous node in the tree, skipping duplicates, or NULL if none
eb64_node* eb64_prev_unique(eb64_node* eb64);

/**
*  Delete node from the tree if it was linked in. Mark the node unused. Note
* that this function relies on a non-inlined generic function: eb_delete.
*/
void eb64_delete(eb64_node* eb64);

/**
* Find the first occurence of a key in the tree <root>. If none can be
* found, return NULL.
*/
eb64_node* eb64_lookup(eb_root* root, ulong x);

/**
* Find the first occurence of a signed key in the tree <root>. If none can
* be found, return NULL.
*/
eb64_node* eb64i_lookup(eb_root* root, long x);

/**
* Find the last occurrence of the highest key in the tree <root>, which is
* equal to or less than <x>. NULL is returned is no key matches.
*/
eb64_node* eb64_lookup_le(eb_root* root, ulong x);

/**
* Find the first occurrence of the lowest key in the tree <root>, which is
* equal to or greater than <x>. NULL is returned is no key matches.
*/
eb64_node* eb64_lookup_ge(eb_root* root, ulong x);

/**
 * Insert eb64_node <neww> into subtree starting at node root <root>, unless
 * <root> is tagged to allow adding unique keys only, i.e. root->b[EB_RGHT]==1,
 * and a node with neww.key already exists.
 * Returns <neww> if added or the existing node if attempting to add a duplicate
 * and <root> is tagged to accept unique keys only.
 */
eb64_node* eb64_insert(eb_root* root, eb64_node* neww);

/**
 * Insert eb64_node <neww> into subtree starting at node root <root>, unless
 * <root> is tagged to allow adding unique keys only, i.e. root->b[EB_RGHT]==1,
 * and a node with neww.key already exists.
 * Returns <neww> if added or the existing node if attempting to add a duplicate
 * and <root> is tagged to accept unique keys only.
 */
eb64_node* eb64i_insert(eb_root* root, eb64_node* neww);
