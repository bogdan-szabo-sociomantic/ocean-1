/*
 * Elastic Binary Trees - macros and structures for operations on 128bit nodes.
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

module ocean.db.ebtree.c.eb128tree;

private import ocean.db.ebtree.c.ebtree;

/* This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 */
struct eb128_node ( T )
{
    static assert (T.sizeof == 16);
    
    eb_node node; /* the tree node, must be at the beginning */
    T key;

    /* Return leftmost node in the tree, or NULL if none */
    alias .eb128_first first;

    /* Return rightmost node in the tree, or NULL if none */
    alias .eb128_last last;

    /* Return next node in the tree, or NULL if none */
    typeof (this) next ( )
    {
        return eb128_next(this);
    }

    /* Return previous node in the tree, or NULL if none */
    typeof (this) prev ( )
    {
        return eb128_prev(this);
    }

    /* Return next node in the tree, skipping duplicates, or NULL if none */
    typeof (this) next_unique ( )
    {
        return eb128_next_unique(this);
    }

    /* Return previous node in the tree, skipping duplicates, or NULL if none */
    typeof (this) prev_unique ( )
    {
        return eb128_prev_unique(this);
    }

    /* Delete node from the tree if it was linked in. Mark the node unused. Note
     * that this function relies on a non-inlined generic function: eb_delete.
     */
    void remove ( )
    {
        eb128_delete(this);
    }

    /*
     * Find the first occurence of a key in the tree <root>. If none can be
     * found, return NULL.
     */
    alias .eb128_lookup lookup;

    /*
     * Find the first occurence of a signed key in the tree <root>. If none can
     * be found, return NULL.
     */
    alias .eb128i_lookup lookup;

    /*
     * Find the last occurrence of the highest key in the tree <root>, which is
     * equal to or less than <x>. NULL is returned is no key matches.
     */
    alias .eb128_lookup_le lookup_le;

    /*
     * Find the first occurrence of the lowest key in the tree <root>, which is
     * equal to or greater than <x>. NULL is returned is no key matches.
     */
    alias .eb128_lookup_ge lookup_ge;

    /* Insert eb32_node <new> into subtree starting at node root <root>.
     * Only new->key needs be set with the key. The eb32_node is returned.
     * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
     */
    typeof (this) insert ( eb_root* root )
    {
        return eb128_insert(root, this);
    }

    /* Insert eb32_node <new> into subtree starting at node root <root>, using
     * signed keys. Only new->key needs be set with the key. The eb32_node
     * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
     */
    typeof (this) insert_signed ( eb_root* root )
    {
        return eb128i_insert(root, this);
    }
};

/*
 * Exported functions and macros.
 * Many of them are always inlined because they are extremely small, and
 * are generally called at most once or twice in a program.
 */

extern (C):

/* Return leftmost node in the tree, or NULL if none */
eb128_node* eb128_first(eb_root* root);

/* Return rightmost node in the tree, or NULL if none */
eb128_node* eb128_last(eb_root* root);

/* Return next node in the tree, or NULL if none */
eb128_node* eb128_next(eb128_node* eb128);

/* Return previous node in the tree, or NULL if none */
eb128_node* eb128_prev(eb128_node* eb128);

/* Return next node in the tree, skipping duplicates, or NULL if none */
eb128_node* eb128_next_unique(eb128_node* eb128);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
eb128_node* eb128_prev_unique(eb128_node* eb128);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
void eb128_delete(eb128_node* eb128);

/*
 * The following functions are not inlined by default. They are declared
 * in eb128tree.c, which simply relies on their inline version.
 */
eb128_node* eb128_lookup(eb_root* root, ulong x);
eb128_node* eb128i_lookup(eb_root* root, long x);
eb128_node* eb128_lookup_le(eb_root* root, ulong x);
eb128_node* eb128_lookup_ge(eb_root* root, ulong x);
eb128_node* eb128_insert(eb_root* root, eb128_node* neww);
eb128_node* eb128i_insert(eb_root* root, eb128_node* neww);

/*
 * The following functions are less likely to be used directly, because their
 * code is larger. The non-inlined version is preferred.
 */

/* Delete node from the tree if it was linked in. Mark the node unused. */
void __eb128_delete(eb128_node* eb128);

/*
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
eb128_node* __eb128_lookup(eb_root* root, ulong x);

/*
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */
eb128_node* __eb128i_lookup(eb_root* root, long x);

/* Insert eb128_node <neww> into subtree starting at node root <root>.
 * Only neww->key needs be set with the key. The eb128_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb128_node* __eb128_insert(eb_root* root, eb128_node* neww);

/* Insert eb128_node <neww> into subtree starting at node root <root>, using
 * signed keys. Only neww->key needs be set with the key. The eb128_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb128_node* __eb128i_insert(eb_root* root, eb128_node* neww);

