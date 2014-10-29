/*
 * Elastic Binary Trees - macros and structures for Multi-Byte data nodes.
 * Version 6.0.5
 * (C) 2002-2011 - Willy Tarreau <w@1wt.eu>
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
    char key[0]; /* the key, its size depends on the application */
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
