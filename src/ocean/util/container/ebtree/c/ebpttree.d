/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016, Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/


/*
 * Elastic Binary Trees - macros and structures for operations on pointer nodes.
 * Version 6.0
 * (C) 2002-2010 - Willy Tarreau <w@1wt.eu>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

module ocean.util.container.ebtree.c.ebpttree;

import ocean.util.container.ebtree.c.ebtree;
import ocean.util.container.ebtree.c.eb32tree;
import ocean.util.container.ebtree.c.eb64tree;

/* This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 * Internally, it is automatically cast as an eb32_node or eb64_node.
 */
struct ebpt_node
{
    eb_node node; /* the tree node, must be at the beginning */
    void* key;
}

extern (C):

/*
 * Exported functions and macros.
 * Many of them are always inlined because they are extremely small, and
 * are generally called at most once or twice in a program.
 */

/* Return leftmost node in the tree, or NULL if none */
ebpt_node* ebpt_first(eb_root *root);

/* Return rightmost node in the tree, or NULL if none */
ebpt_node* ebpt_last(eb_root* root);

/* Return next node in the tree, or NULL if none */
ebpt_node* ebpt_next(ebpt_node* ebpt);

/* Return previous node in the tree, or NULL if none */
ebpt_node* ebpt_prev(ebpt_node* ebpt);

/* Return next node in the tree, skipping duplicates, or NULL if none */
ebpt_node* ebpt_next_unique(ebpt_node* ebpt);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
ebpt_node* ebpt_prev_unique(ebpt_node* ebpt);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
void ebpt_delete(ebpt_node* ebpt);

/*
 * The following functions are inlined but derived from the integer versions.
 */
ebpt_node* ebpt_lookup(eb_root* root, void* x);

ebpt_node* ebpt_lookup_le(eb_root* root, void* x);

ebpt_node* ebpt_lookup_ge(eb_root* root, void* x);

ebpt_node* ebpt_insert(eb_root* root, ebpt_node* neww);

/*
 * The following functions are less likely to be used directly, because
 * their code is larger. The non-inlined version is preferred.
 */

/* Delete node from the tree if it was linked in. Mark the node unused. */
void ebpt_delete(ebpt_node* ebpt);

ebpt_node* ebpt_lookup(eb_root* root, void* x);

ebpt_node* ebpt_insert(eb_root* root, ebpt_node* neww);
