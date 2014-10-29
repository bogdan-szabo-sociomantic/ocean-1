/******************************************************************************

    Kept with "_slowtest" suffix because sleep is used to ensure cache
    invalidation timeout works.

    Copyright: Copyright (c) 2014 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.container.cache.CachingStructLoader_slowtest;

/******************************************************************************

    Imports

******************************************************************************/

import ocean.util.container.cache.CachingStructLoader,
       ocean.util.container.cache.ExpiringCache;
import ocean.util.serialize.contiguous.package_;

import ocean.io.select.EpollSelectDispatcher,
       ocean.io.select.client.TimerEvent;

import ocean.core.Test;

import tango.stdc.posix.time;

/******************************************************************************

    Trivial struct type to imitate stored value

******************************************************************************/

struct Trivial
{
    int field;
}

/******************************************************************************

    Shared event loop

******************************************************************************/

EpollSelectDispatcher epoll;

/******************************************************************************

    Used instead of "sleep" to keep event loop running

    Params:
        seconds = amount of seconds to wait

******************************************************************************/

void wait(long seconds)
{
    auto timer = new TimerEvent(
        () {
            epoll.shutdown();
            return false;
        }
    );

    timer.set( timespec(seconds) );
    epoll.register(timer);
    epoll.eventLoop();
}

/******************************************************************************

    CachingStructLoader mock implementation

******************************************************************************/

class TestCache(S) : CachingStructLoader!(S)
{
    // data source for missing records
    void[][hash_t] source;

    bool add_empty;

    void addToSource(hash_t key, S value)
    {
        Serializer.serialize(value, this.source[key]);
    }

    this (Cache cache)
    {
        super(cache);
        this.add_empty = true; 
    }

    void addEmptyValues(bool newval)
    {
        this.add_empty = newval;
    }

    override protected void getData ( hash_t key, void delegate ( Contiguous!(S) data ) got )
    {
        auto data = key in this.source;
        if (data)
        {
            auto instance = Deserializer.deserialize!(S)(*data);
            got(instance);
        }
        else
        {
            if (this.add_empty)
            {
                got(Contiguous!(S)(null));
            }
        }
    }
}

/******************************************************************************

    Various test related objects/types reused by all test cases

******************************************************************************/

alias TestCache!(Trivial) Cache;

private const Cache.Cache cache_storage;

private const Cache cache;

static this()
{
    epoll = new EpollSelectDispatcher();
    cache_storage = new Cache.Cache(5, 1); // max 5 items, 1 second
    cache = new Cache(cache_storage);
}

/******************************************************************************

    Cleans all global state. Called in the beginning of each new test case.

******************************************************************************/

private void reset()
{
    cache_storage.clear();
    cache.source = null;
}

/******************************************************************************

    Tests

******************************************************************************/

// Empty cache
unittest
{
    reset();

    auto result = 42 in cache;
    test!("is")(result, null);
}

// Missing item cached
unittest
{
    reset();

    auto result = 42 in cache;
    cache.addToSource(42, Trivial(42));
    result = 42 in cache;
    test!("is")(result, null);
}

// Missing item cached not cached if (add_empty_values == false)
unittest
{
    reset();
    cache.addEmptyValues(false);
    scope(exit) cache.addEmptyValues(true);

    auto result = 42 in cache;
    test!("is")(result, null);
    cache.addToSource(42, Trivial(42));
    result = 42 in cache;
    test!("!is")(result, null);
}

// Missing item updated after timeout
unittest
{
    reset();

    auto result = 42 in cache;
    cache.addToSource(42, Trivial(42));
    result = 42 in cache;

    wait(2);
    result = 42 in cache;
    test!("!is")(result, null);
    test!("==")(result.field, 42);
}

// Exists on first access
unittest
{
    reset();

    cache.addToSource(43, Trivial(43));
    auto result = 43 in cache;
    test!("!is")(result, null);
    test!("==")(result.field, 43);

    // also verify persistent identity
    auto result2 = 43 in cache;
    test!("is")(result, result2);
}
