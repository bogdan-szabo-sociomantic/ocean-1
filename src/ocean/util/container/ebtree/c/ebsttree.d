/*******************************************************************************

    Bindings for Elastic Binary Trees library's operations on String data nodes.

    This module contains the D binding of the library functions of ebsttree.h.
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

/* These functions and macros rely on Multi-Byte nodes */

module ocean.util.container.ebtree.c.ebsttree;

import ocean.util.container.ebtree.c.ebtree;
import ocean.util.container.ebtree.c.ebmbtree;

extern (C):

/* Find the first occurence of a zero-terminated string <x> in the tree <root>.
 * It's the caller's reponsibility to use this function only on trees which
 * only contain zero-terminated strings. If none can be found, return NULL.
 */
ebmb_node* ebst_lookup(eb_root* root, char* x);

/* Find the first occurence of a length <len> string <x> in the tree <root>.
 * It's the caller's reponsibility to use this function only on trees which
 * only contain zero-terminated strings, and that no null character is present
 * in string <x> in the first <len> chars. If none can be found, return NULL.
 */
ebmb_node* ebst_lookup_len(eb_root* root, char* x, uint len);

/* Insert ebmb_node <neww> into subtree starting at node root <root>, unless
 * <root> is tagged to allow adding unique keys only, i.e. root->b[EB_RGHT]==1,
 * and a node with neww.key already exists.
 * Only neww->key needs be set with the zero-terminated string key. The caller
 * is responsible for properly terminating the key with a zero.
 * Returns <neww> if added or the existing node if attempting to add a duplicate
 * and <root> is tagged to accept unique keys only.
 */
ebmb_node* ebst_insert(eb_root* root, ebmb_node* neww);
