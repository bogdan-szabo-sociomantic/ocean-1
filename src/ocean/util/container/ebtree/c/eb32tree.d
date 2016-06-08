/******************************************************************************

    Bindings for Elastic Binary Trees library's operations on 32bit nodes.

    This module contains the D binding of the library functions of eb32tree.h.
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

 ******************************************************************************/

module ocean.util.container.ebtree.c.eb32tree;

import ocean.util.container.ebtree.c.ebtree: eb_root, eb_node;

/**
 * This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 */
struct eb32_node
{
    eb_node  node; // the tree node, must be at the beginning
    uint     key;

    /// Return next node in the tree, skipping duplicates, or NULL if none

    typeof (this) next ( )
    {
        return eb32_next(this);
    }

    /// Return previous node in the tree, or NULL if none

    typeof (this) prev ( )
    {
        return eb32_prev(this);
    }

    /// Return next node in the tree, skipping duplicates, or NULL if none

    typeof (this) next_unique ( )
    {
        return eb32_next_unique(this);
    }

    /// Return previous node in the tree, skipping duplicates, or NULL if none

    typeof (this) prev_unique ( )
    {
        return eb32_prev_unique(this);
    }
}

extern (C):

/// Return leftmost node in the tree, or NULL if none
eb32_node* eb32_first(eb_root* root);

/// Return rightmost node in the tree, or NULL if none
eb32_node* eb32_last(eb_root* root);

/// Return next node in the tree, or NULL if none
eb32_node* eb32_next(eb32_node* eb32);

/// Return previous node in the tree, or NULL if none
eb32_node* eb32_prev(eb32_node* eb32);

/// Return next node in the tree, skipping duplicates, or NULL if none
eb32_node* eb32_next_unique(eb32_node* eb32);

/// Return previous node in the tree, skipping duplicates, or NULL if none
eb32_node* eb32_prev_unique(eb32_node* eb32);

/**
 *  Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
void eb32_delete(eb32_node* eb32);

/**
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
eb32_node* eb32_lookup(eb_root* root, uint x);

/**
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */
eb32_node* eb32i_lookup(eb_root* root, int x);

/**
 * Find the last occurrence of the highest key in the tree <root>, which is
 * equal to or less than <x>. NULL is returned is no key matches.
 */
eb32_node* eb32_lookup_le(eb_root* root, uint x);

/**
 * Find the first occurrence of the lowest key in the tree <root>, which is
 * equal to or greater than <x>. NULL is returned is no key matches.
 */
eb32_node* eb32_lookup_ge(eb_root* root, uint x);

/**
 * Insert eb32_node <neww> into subtree starting at node root <root>, unless
 * <root> is tagged to allow adding unique keys only, i.e. root->b[EB_RGHT]==1,
 * and a node with neww.key already exists.
 * Returns <neww> if added or the existing node if attempting to add a duplicate
 * and <root> is tagged to accept unique keys only.
 */
eb32_node* eb32_insert(eb_root* root, eb32_node* neww);

/**
 * Insert eb32_node <neww> into subtree starting at node root <root>, unless
 * <root> is tagged to allow adding unique keys only, i.e. root->b[EB_RGHT]==1,
 * and a node with neww.key already exists.
 * Returns <neww> if added or the existing node if attempting to add a duplicate
 * and <root> is tagged to accept unique keys only.
 */
eb32_node* eb32i_insert(eb_root* root, eb32_node* neww);
