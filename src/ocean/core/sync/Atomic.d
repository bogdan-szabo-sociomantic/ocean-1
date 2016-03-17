/**
 * The Atomic module is intended to provide some basic support for the so called lock-free
 * concurrent programming.
 * The current design replaces the previous Atomic module by Sean and is inspired
 * partly by the llvm atomic operations, and Sean's version
 *
 * If no atomic ops are available an (inefficent) fallback solution is provided
 * For classes atomic access means atomic access to their *address* not their content
 *
 * If you want unique counters or flags to communicate in multithreading settings
 * look at ocean.core.sync.Counter that provides them in a better way and handles
 * better the absence of atomic ops.
 *
 * Copyright: Copyright (C) 2008-2010 the blip developer group
 * License:   BSD style: $(LICENSE)
 * Author:    Fawzi Mohamed
 */

module ocean.core.sync.Atomic;

public import core.atomic;
