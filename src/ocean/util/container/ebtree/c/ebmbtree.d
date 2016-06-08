/*******************************************************************************

    Bindings for Elastic Binary Trees library's operations on Multi-Byte data
    nodes.

    This module contains the D binding of the library functions of ebmbtree.h.
    Please consult the original header documentation for details.

    You need to have the library installed and link with -lebtree.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

        Bear in mind this module provides bindings to an external library that
        has its own license, which might be more restrictive. Please check the
        external library license to see which conditions apply for linking.

*******************************************************************************/

module ocean.util.container.ebtree.c.ebmbtree;

import ocean.util.container.ebtree.c.ebtree;

/* This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 * The 'node.bit' value here works differently from scalar types, as it contains
 * the number of identical bits between the two branches.
 */
struct ebmb_node
{
    eb_node node; /* the tree node, must be at the beginning */
    char[0] key; /* the key, its size depends on the application */
}

/*
 * Exported functions and macros.
 * Many of them are always inlined because they are extremely small, and
 * are generally called at most once or twice in a program.
 */

extern (C):

/* Return leftmost node in the tree, or NULL if none */
ebmb_node* ebmb_first(eb_root* root);

/* Return rightmost node in the tree, or NULL if none */
ebmb_node* ebmb_last(eb_root* root);

/* Return next node in the tree, or NULL if none */
ebmb_node* ebmb_next(ebmb_node* ebmb);

/* Return previous node in the tree, or NULL if none */
ebmb_node* ebmb_prev(ebmb_node* ebmb);

/* Return next node in the tree, skipping duplicates, or NULL if none */
ebmb_node* ebmb_next_unique(ebmb_node* ebmb);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
ebmb_node* ebmb_prev_unique(ebmb_node* ebmb);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
void ebmb_delete(ebmb_node* ebmb);

/* The following functions are not inlined by default. They are declared
 * in ebmbtree.c, which simply relies on their inline version.
 */
ebmb_node* ebmb_lookup(eb_root* root, void* x, uint len);
ebmb_node* ebmb_insert(eb_root* root, ebmb_node* neww, uint len);
ebmb_node* ebmb_lookup_longest(eb_root* root, void* x);
ebmb_node* ebmb_lookup_prefix(eb_root* root, void* x, uint pfx);
ebmb_node* ebmb_insert_prefix(eb_root* root, ebmb_node* neww, uint len);
