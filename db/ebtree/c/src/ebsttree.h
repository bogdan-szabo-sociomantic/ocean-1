/*
 * Elastic Binary Trees - macros to manipulate String data nodes.
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

/* These functions and macros rely on Multi-Byte nodes */

#ifndef _EBSTTREE_H
#define _EBSTTREE_H

#include "ebtree.h"
#include "ebmbtree.h"

/* The following functions are not inlined by default. They are declared
 * in ebsttree.c, which simply relies on their inline version.
 */
extern struct ebmb_node *ebst_lookup(struct eb_root *root, const char *x);
extern struct ebmb_node *ebst_lookup_len(struct eb_root *root, const char *x, unsigned int len);
extern struct ebmb_node *ebst_insert(struct eb_root *root, struct ebmb_node *new);

#endif /* _EBSTTREE_H */

