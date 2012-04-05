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

#ifndef _INT128_H
#define _INT128_H
/*
 * This is the 128-bit integer type definition. It uses the GCC 4.6 extension of
 * 128-bit integer types for platforms with native support for 128-bit integers.
 * If supported, the __SIZEOF_INT128__ macro is defined and the intrinsic
 * signed/unsigned __int128 type exists.
 *
 * @see http://gcc.gnu.org/onlinedocs/gcc-4.6.2/gcc/_005f_005fint128.html
 * @see http://gcc.gnu.org/gcc-4.6/changes.html
 */

#ifdef __SIZEOF_INT128__

#define INT128_SUPPORTED /// Defined if the 128-bit integer types exist.

typedef unsigned __int128 uint128_t;
typedef   signed __int128  int128_t;

#endif // __SIZEOF_INT128__

#endif // _INT128_H
