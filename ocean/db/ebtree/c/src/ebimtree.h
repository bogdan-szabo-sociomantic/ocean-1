/*
 * Elastic Binary Trees - macros for Indirect Multi-Byte data nodes.
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

#include "ebtree.h"
#include "ebpttree.h"

/* These functions and macros rely on Pointer nodes and use the <key> entry as
 * a pointer to an indirect key. Most operations are performed using ebpt_*.
 */

/* The following functions are not inlined by default. They are declared
 * in ebimtree.c, which simply relies on their inline version.
 */
extern struct ebpt_node *ebim_lookup(struct eb_root *root, const void *x, unsigned int len);
extern struct ebpt_node *ebim_insert(struct eb_root *root, struct ebpt_node *new, unsigned int len);
