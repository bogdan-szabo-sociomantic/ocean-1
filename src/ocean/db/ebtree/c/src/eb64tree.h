/*
 * Elastic Binary Trees - macros and structures for operations on 64bit nodes.
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

#ifndef _EB64TREE_H
#define _EB64TREE_H

#include "ebtree.h"
#include <stdint.h>

#define EB64_ROOT	EB_ROOT
#define EB64_TREE_HEAD	EB_TREE_HEAD

/* This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 */
struct eb64_node {
	struct eb_node node; /* the tree node, must be at the beginning */
	uint64_t key;
};

/*
 * Exported functions and macros.
 * Many of them are always inlined because they are extremely small, and
 * are generally called at most once or twice in a program.
 */

/* Return leftmost node in the tree, or NULL if none */
extern struct eb64_node *eb64_first(struct eb_root *root);

/* Return rightmost node in the tree, or NULL if none */
extern struct eb64_node *eb64_last(struct eb_root *root);

/* Return next node in the tree, or NULL if none */
extern struct eb64_node *eb64_next(struct eb64_node *eb64);

/* Return previous node in the tree, or NULL if none */
extern struct eb64_node *eb64_prev(struct eb64_node *eb64);

/* Return next node in the tree, skipping duplicates, or NULL if none */
extern struct eb64_node *eb64_next_unique(struct eb64_node *eb64);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
extern struct eb64_node *eb64_prev_unique(struct eb64_node *eb64);

/* Delete node from the tree if it was linked in. Mark the node unused. */
extern void eb64_delete(struct eb64_node *eb64);

/*
 * Find the first occurence of a key in the tree <root>. If none can be found,
 * return NULL.
 */

extern struct eb64_node *eb64_lookup(struct eb_root *root, uint64_t x);

/*
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */

extern struct eb64_node *eb64i_lookup(struct eb_root *root, int64_t x);

/*
 * Find the last occurrence of the highest key in the tree <root>, which is
 * equal to or less than <x>. NULL is returned is no key matches.
 */

extern struct eb64_node *eb64_lookup_le(struct eb_root *root, uint64_t x);

/*
 * Find the first occurrence of the lowest key in the tree <root>, which is
 * equal to or greater than <x>. NULL is returned is no key matches.
 */

extern struct eb64_node *eb64_lookup_ge(struct eb_root *root, uint64_t x);

/* Insert eb64_node <new> into subtree starting at node root <root>.
 * Only new->key needs be set with the key. The eb64_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */

extern struct eb64_node *eb64_insert(struct eb_root *root, struct eb64_node *new);

/* Insert eb64_node <new> into subtree starting at node root <root>, using
 * signed keys. Only new->key needs be set with the key. The eb64_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */

extern struct eb64_node *eb64i_insert(struct eb_root *root, struct eb64_node *new);

#endif /* int64_tEB64_TREE_H */
