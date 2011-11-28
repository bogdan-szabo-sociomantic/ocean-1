/*
 * Elastic Binary Trees - macros and structures for operations on 32bit nodes.
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

module ocean.db.ebtree.c.eb32tree;

private import  ocean.db.ebtree.c.ebtree;


/* This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 */
struct eb32_node
{
    eb_node node; /* the tree node, must be at the beginning */
    uint key;
    
    /* Return leftmost node in the tree, or NULL if none */
    alias .eb32_first first;

    /* Return rightmost node in the tree, or NULL if none */
    alias .eb32_last last;

    /* Return next node in the tree, or NULL if none */
    typeof (this) next ( )
    {
        return eb32_next(this);
    }

    /* Return previous node in the tree, or NULL if none */
    typeof (this) prev ( )
    {
        return eb32_prev(this);
    }

    /* Return next node in the tree, skipping duplicates, or NULL if none */
    typeof (this) next_unique ( )
    {
        return eb32_next_unique(this);
    }

    /* Return previous node in the tree, skipping duplicates, or NULL if none */
    typeof (this) prev_unique ( )
    {
        return eb32_prev_unique(this);
    }

    /* Delete node from the tree if it was linked in. Mark the node unused. Note
     * that this function relies on a non-inlined generic function: eb_delete.
     */
    void remove ( )
    {
        eb32_delete(this);
    }

    /*
     * Find the first occurence of a key in the tree <root>. If none can be
     * found, return NULL.
     */
    alias .eb32_lookup lookup;

    /*
     * Find the first occurence of a signed key in the tree <root>. If none can
     * be found, return NULL.
     */
    alias .eb32i_lookup lookup;

    /*
     * Find the last occurrence of the highest key in the tree <root>, which is
     * equal to or less than <x>. NULL is returned is no key matches.
     */
    alias .eb32_lookup_le lookup_le;

    /*
     * Find the first occurrence of the lowest key in the tree <root>, which is
     * equal to or greater than <x>. NULL is returned is no key matches.
     */
    alias .eb32_lookup_ge lookup_ge;

    /* Insert eb32_node <new> into subtree starting at node root <root>.
     * Only new->key needs be set with the key. The eb32_node is returned.
     * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
     */
    typeof (this) insert ( eb_root* root )
    {
        return eb32_insert(root, this);
    }

    /* Insert eb32_node <new> into subtree starting at node root <root>, using
     * signed keys. Only new->key needs be set with the key. The eb32_node
     * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
     */
    typeof (this) insert_signed ( eb_root* root )
    {
        return eb32i_insert(root, this);
    }
}

/*
 * Exported functions and macros.
 * Many of them are always inlined because they are extremely small, and
 * are generally called at most once or twice in a program.
 */

extern (C):

/* Return leftmost node in the tree, or NULL if none */
eb32_node* eb32_first(eb_root* root);

/* Return rightmost node in the tree, or NULL if none */
eb32_node* eb32_last(eb_root* root);

/* Return next node in the tree, or NULL if none */
eb32_node* eb32_next(eb32_node* eb32);

/* Return previous node in the tree, or NULL if none */
eb32_node* eb32_prev(eb32_node* eb32);

/* Return next node in the tree, skipping duplicates, or NULL if none */
eb32_node* eb32_next_unique(eb32_node* eb32);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
eb32_node* eb32_prev_unique(eb32_node* eb32);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
void eb32_delete(eb32_node* eb32);

/*
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
eb32_node* eb32_lookup(eb_root* root, uint x);

/*
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */
eb32_node* eb32i_lookup(eb_root* root, int x);

/*
 * Find the last occurrence of the highest key in the tree <root>, which is
 * equal to or less than <x>. NULL is returned is no key matches.
 */
eb32_node* eb32_lookup_le(eb_root* root, uint x);

/*
 * Find the first occurrence of the lowest key in the tree <root>, which is
 * equal to or greater than <x>. NULL is returned is no key matches.
 */
eb32_node* eb32_lookup_ge(eb_root* root, uint x);

/* Insert eb32_node <new> into subtree starting at node root <root>.
 * Only new->key needs be set with the key. The eb32_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb32_node* eb32_insert(eb_root* root, eb32_node* neww);

/* Insert eb32_node <new> into subtree starting at node root <root>, using
 * signed keys. Only new->key needs be set with the key. The eb32_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb32_node* eb32i_insert(eb_root* root, eb32_node* neww);
