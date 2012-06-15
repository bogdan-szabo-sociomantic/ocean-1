/*
 * 128-bit integer type definition
 *
 * copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved
 *
 * version:        April 2012: Initial release
 *
 * authors:        Mathias Baumann, David Eckardt
 *
 * This is the 128-bit integer type definition. It uses the GCC 4.6 extension of
 * 128-bit integer types for platforms with native support for 128-bit integers.
 * If supported, the __SIZEOF_INT128__ macro is defined and the intrinsic
 * signed/unsigned __int128 type exists.
 *
 * @see http://gcc.gnu.org/onlinedocs/gcc-4.6.2/gcc/_005f_005fint128.html
 * @see http://gcc.gnu.org/gcc-4.6/changes.html
 */

#ifndef _INT128_H
#define _INT128_H

#ifdef __SIZEOF_INT128__

#define INT128_SUPPORTED /// Defined if the 128-bit integer types exist.

typedef unsigned __int128 uint128_t;
typedef   signed __int128  int128_t;

#endif // __SIZEOF_INT128__

#endif // _INT128_H
