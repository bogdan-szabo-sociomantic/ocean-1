/*******************************************************************************

    Bindings for Elastic Binary Trees library's generic operations and
    structures.

    This module contains the D binding of the library functions of ebtree.h.
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

module ocean.util.container.ebtree.c.ebtree;


import ocean.transition;


/* This is the same as an eb_node pointer, except that the lower bit embeds
 * a tag. See eb_dotag()/eb_untag()/eb_gettag(). This tag has two meanings :
 *  - 0=left, 1=right to designate the parent's branch for leaf_p/node_p
 *  - 0=link, 1=leaf  to designate the branch's type for branch[]
 */
alias void eb_troot_t;

/* The eb_root connects the node which contains it, to two nodes below it, one
 * of which may be the same node. At the top of the tree, we use an eb_root
 * too, which always has its right branch NULL (+/1 low-order bits).
 */
struct eb_root
{
    /* Number of bits per node, and number of leaves per node */
    const BITS          = 1;
    const BRANCHES      = (1 << BITS);

    /* Tags to set in root->b[RGHT] :
     * - NORMAL is a normal tree which stores duplicate keys.
     * - UNIQUE is a tree which stores unique keys.
     */
    const RGHT   = 1;
    const NORMAL = cast(eb_troot_t*)0;
    const UNIQUE = cast(eb_troot_t*)1;

    eb_troot_t*[BRANCHES] b; /* left and right branches */

    /* Return non-zero if the tree is empty, otherwise zero */
    bool is_empty ( )
    {
        return !!eb_is_empty(this);
    }

    /***************************************************************************

        Tells whether this tree is configured so that the `eb*_insert` functions
        allow adding unique nodes only or if they allow adding duplicates.

        Returns:
            true if only unique nodes are added for this tree or false if
            duplicates can be added.

    ***************************************************************************/

    bool unique ( )
    {
        return this.b[RGHT] is UNIQUE;
    }

    /***************************************************************************

        Configures this tree so that the `eb*_insert` functions either allow
        adding unique nodes only or allow adding duplicates.

        This configuration can be changed at any time and affects subsequent
        `eb*_insert` function calls.

        Params:
            enable = true: only allow unique nodes;
                     false: allow adding duplicates

        Returns:
            enable

    ***************************************************************************/

    bool unique ( bool enable )
    {
        this.b[RGHT] = enable? UNIQUE : NORMAL;
        return enable;
    }
}

/* The eb_node contains the two parts, one for the leaf, which always exists,
 * and one for the node, which remains unused in the very first node inserted
 * into the tree. This structure is 20 bytes per node on 32-bit machines. Do
 * not change the order, benchmarks have shown that it's optimal this way.
 */
struct eb_node
{
    eb_root     branches; /* branches, must be at the beginning */
    eb_troot_t* node_p,   /* link node's parent */
                leaf_p;   /* leaf node's parent */
    short       bit;      /* link's bit position. */
    short       pfx;      /* data prefix length, always related to leaf */

    /* Return the first leaf in the tree starting at <root>, or NULL if none */
    alias .eb_first first;

    /* Return the last leaf in the tree starting at <root>, or NULL if none */
    alias .eb_last last;

    /* Return previous leaf node before an existing leaf node, or NULL if none. */
    typeof (this) prev( )
    {
        return eb_prev(this);
    }

    /* Return next leaf node after an existing leaf node, or NULL if none. */
    typeof (this) next ( )
    {
        return eb_next(this);
    }

    /* Return previous leaf node before an existing leaf node, skipping duplicates,
     * or NULL if none. */
    typeof (this) prev_unique ( )
    {
        return eb_prev_unique(this);
    }

    /* Return next leaf node after an existing leaf node, skipping duplicates, or
     * NULL if none.
     */
    typeof (this) next_unique ( )
    {
        return eb_next_unique(this);
    }

    /* Removes a leaf node from the tree if it was still in it. Marks the node
     * as unlinked.
     */
    void remove ( )
    {
        eb_delete(this);
    }
};

/**************************************\
 * Public functions, for the end-user *
\**************************************/

extern (C):

/* Return non-zero if the tree is empty, otherwise zero */
int eb_is_empty(eb_root* root);

/* Return the first leaf in the tree starting at <root>, or NULL if none */
eb_node* eb_first(eb_root* root);

/* Return the last leaf in the tree starting at <root>, or NULL if none */
eb_node* eb_last(eb_root* root);

/* Return previous leaf node before an existing leaf node, or NULL if none. */
eb_node* eb_prev(eb_node* node);

/* Return next leaf node after an existing leaf node, or NULL if none. */
eb_node* eb_next(eb_node* node);

/* Return previous leaf node before an existing leaf node, skipping duplicates,
 * or NULL if none. */
eb_node* eb_prev_unique(eb_node* node);

/* Return next leaf node after an existing leaf node, skipping duplicates, or
 * NULL if none.
 */
eb_node* eb_next_unique(eb_node* node);

/* Removes a leaf node from the tree if it was still in it. Marks the node
 * as unlinked.
 */
void eb_delete(eb_node* node);

/* Compare blocks <a> and <b> byte-to-byte, from bit <ignore> to bit <len-1>.
 * Return the number of equal bits between strings, assuming that the first
 * <ignore> bits are already identical. It is possible to return slightly more
 * than <len> bits if <len> does not stop on a byte boundary and we find exact
 * bytes. Note that parts or all of <ignore> bits may be rechecked. It is only
 * passed here as a hint to speed up the check.
 */
int equal_bits(char* a, char* b, int ignore, int len);

/* check that the two blocks <a> and <b> are equal on <len> bits. If it is known
 * they already are on some bytes, this number of equal bytes to be skipped may
 * be passed in <skip>. It returns 0 if they match, otherwise non-zero.
 */
int check_bits(char* a, char* b, int skip, int len);

/* Compare strings <a> and <b> byte-to-byte, from bit <ignore> to the last 0.
 * Return the number of equal bits between strings, assuming that the first
 * <ignore> bits are already identical. Note that parts or all of <ignore> bits
 * may be rechecked. It is only passed here as a hint to speed up the check.
 * The caller is responsible for not passing an <ignore> value larger than any
 * of the two strings. However, referencing any bit from the trailing zero is
 * permitted. Equal strings are reported as a negative number of bits, which
 * indicates the end was reached.
 */
int string_equal_bits(char* a, char* b, int ignore);

int cmp_bits(char* a, char* b, uint pos);

int get_bit(char* a, uint pos);
