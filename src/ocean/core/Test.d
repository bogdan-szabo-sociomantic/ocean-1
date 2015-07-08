/******************************************************************************

  Defines base exception class thrown by test checks and set of helper
  functions to define actual test cases. These helpers are supposed to be
  used in unittest blocks instead of asserts.

  Copyright:      Copyright (c) 2014 sociomantic labs.

*******************************************************************************/

module ocean.core.Test;

public import tango.core.Test;

import tango.transition;
import tango.core.Memory;
import tango.core.Enforce;

/******************************************************************************

    Verifies that call to `expr` does not allocate GC memory

    This is achieved by checking GC usage stats before and after the call.

    Params:
        expr = any expression, wrapped in void-returning delegate if necessary

    Throws:
        TestException if unexpected allocation happens

******************************************************************************/

public void testNoAlloc ( lazy void expr, istring file = __FILE__,
    int line = __LINE__ )
{
    size_t used1, free1;
    GC.usage(used1, free1);

    expr();

    size_t used2, free2;
    GC.usage(used2, free2);

    enforceImpl!(TestException, bool)(
        used1 == used2 && free1 == free2,
        "Expression expected to not allocate but GC usage stats have changed",
        file,
        line
    );
}

///
unittest
{
    testNoAlloc({} ());

    testThrown!(TestException)(
        testNoAlloc({ auto x = new int; } ())
    );
}
