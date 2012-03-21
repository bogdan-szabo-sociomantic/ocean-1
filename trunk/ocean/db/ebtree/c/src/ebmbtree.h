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

#ifndef _EBMBTREE_H
#define _EBMBTREE_H

#include <string.h>
#include "ebtree.h"

#define EBMB_ROOT	EB_ROOT
#define EBMB_TREE_HEAD	EB_TREE_HEAD

/* This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 * The 'node.bit' value here works differently from scalar types, as it contains
 * the number of identical bits between the two branches.
 */
struct ebmb_node {
	struct eb_node node; /* the tree node, must be at the beginning */
	unsigned char key[0]; /* the key, its size depends on the application */
};

/*
 * Exported functions and macros.
 * Many of them are always inlined because they are extremely small, and
 * are generally called at most once or twice in a program.
 */

/* Return leftmost node in the tree, or NULL if none */
extern struct ebmb_node *ebmb_first(struct eb_root *root);

/* Return rightmost node in the tree, or NULL if none */
extern struct ebmb_node *ebmb_last(struct eb_root *root);

/* Return next node in the tree, or NULL if none */
extern struct ebmb_node *ebmb_next(struct ebmb_node *ebmb);

/* Return previous node in the tree, or NULL if none */
extern struct ebmb_node *ebmb_prev(struct ebmb_node *ebmb);

/* Return next node in the tree, skipping duplicates, or NULL if none */
extern struct ebmb_node *ebmb_next_unique(struct ebmb_node *ebmb);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
extern struct ebmb_node *ebmb_prev_unique(struct ebmb_node *ebmb);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
extern void ebmb_delete(struct ebmb_node *ebmb);

/* The following functions are not inlined by default. They are declared
 * in ebmbtree.c, which simply relies on their inline version.
 */
extern struct ebmb_node *ebmb_lookup(struct eb_root *root, const void *x, unsigned int len);
extern struct ebmb_node *ebmb_insert(struct eb_root *root, struct ebmb_node *new, unsigned int len);
extern struct ebmb_node *ebmb_lookup_longest(struct eb_root *root, const void *x);
extern struct ebmb_node *ebmb_lookup_prefix(struct eb_root *root, const void *x, unsigned int pfx);
extern struct ebmb_node *ebmb_insert_prefix(struct eb_root *root, struct ebmb_node *new, unsigned int len);

#endif /* _EBMBTREE_H */

