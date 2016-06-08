/*******************************************************************************

    Bindings for Elastic Binary Trees library's operations on Indirect
    Multi-Byte data nodes.

    This module contains the D binding of the library functions of ebimtree.h.
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

module ocean.util.container.ebtree.c.ebimtree;

import ocean.util.container.ebtree.c.ebtree;
import ocean.util.container.ebtree.c.ebpttree;

extern (C):

/* Find the first occurence of a key of a least <len> bytes matching <x> in the
 * tree <root>. The caller is responsible for ensuring that <len> will not exceed
 * the common parts between the tree's keys and <x>. In case of multiple matches,
 * the leftmost node is returned. This means that this function can be used to
 * lookup string keys by prefix if all keys in the tree are zero-terminated. If
 * no match is found, NULL is returned. Returns first node if <len> is zero.
 */
ebpt_node* ebim_lookup(ebpt_node* root, void *x, uint len);

/*
 * Insert ebpt_node <neww> into subtree starting at node root <root>, unless
 * <root> is tagged to allow adding unique keys only, i.e. root->b[EB_RGHT]==1,
 * and a node with neww.key already exists.
 * The len is specified in bytes.
 * Returns <neww> if added or the existing node if attempting to add a duplicate
 * and <root> is tagged to accept unique keys only.
 */

ebpt_node* ebim_insert(ebpt_node* root, ebpt_node* neww, uint len);
