/******************************************************************************

    Copyright (c) 2009-2015 sociomantic labs.  All rights reserved

*******************************************************************************/

module ocean.util.container.queue.LinkedListQueue;

import tango.transition;

import tango.util.log.Log;
import tango.core.Memory;
import tango.util.container.Container;
import ocean.core.Test;
import ocean.util.container.queue.model.ITypedQueue;
import ocean.core.Array;
public import ocean.util.container.queue.model.ITypedQueue: push, pop;


/******************************************************************************

    A typed-queue based on a linked list. (Internally, the queue is composed of
    instances of a struct which contains a value (of type T) and a pointer to
    next item.)

    The linked list implementation allows the following extensions to ITypedQueue:

        * The ability to find a specified value in the queue: contains().
        * The ability to remove one or all instances of a specified value from
          the queue: remove().

    The items in the linked list are allocated and deallocated by Malloc allocation
    manager, to avoid the GC from not so efficiently going over the linked list
    (see explanation at LinkedListQueue.heap below).

    Template params:

        T = Type of values stored in the linked list queue

*******************************************************************************/

public class LinkedListQueue ( T ) : ITypedQueue!( T )
{
    /**************************************************************************

        Should the values in queue be added to GC as roots, thus
        preventing the GC from collecting these values.

        Since the items in the queue are allocated by the Malloc allocation
        manager, they are not scanned by the GC. This means that whatever the items
        reference - the values, are not considered as being referenced by anything
        (unless the values are referenced by some other "GC scanned" object).
        This will result in GC collecting these values, which will have very bad
        ramifications as we're still referencing them in the queue.

        So we add the values to GC as roots, thus preventing the GC from collecting
        them, depending on the value of 'root_values'

    ***************************************************************************/

    protected static bool root_values;


    /**************************************************************************

        Static constructor.

        Checks whether the values in the queue (of Type T) are in GC memory,
        and sets 'root_values' accordingly.

    ***************************************************************************/

    public static this ( )
    {
        // Checking for TypeInfo.flags()
        root_values = ( typeid(T).flags() & 1 )  == 1;
    }


    /**************************************************************************

        Type of items in queue - a struct of value and pointer to next item

    ***************************************************************************/

    protected struct QueueItem
    {
        /**********************************************************************

            Pointer to next item in queue

        ***********************************************************************/

        public QueueItem* next;


        /**********************************************************************

            The value stored in this item

        ***********************************************************************/

        public T value;


        /**********************************************************************

            Finds a QueueItem which contains the given value

            Params:
                element = value to find

            Returns:
                pointer to the first QueueItem which contains the value, null if
                not found

        ***********************************************************************/

        public QueueItem* find ( T find_value )
        {
            for ( auto p = this; p; p = p.next )
                 if ( find_value == p.value )
                     return p;
            return null;
        }
    }


    /**************************************************************************

        Number of items in the queue

    ***************************************************************************/

    protected size_t count;


    /**************************************************************************

        Pointer to first (and oldest) item in queue

    ***************************************************************************/

    protected QueueItem* head;


    /**************************************************************************

        Pointer to last item in queue

    ***************************************************************************/

    protected QueueItem* tail;


    /**************************************************************************

        Malloc allocation manager, to allocate and deallocate items in queue.
        We use the malloc allocation manager as to keep the linked list away
        from the reach of the GC, for efficiency reasons.
        The reason for this is:
        The GC collector scans the memory in order to identify the root objects,
        and then collect them. The scanning process, roughly speaking, is done in
        such a way that each time the GC detects a new address it runs another scan.
        On the entire memory. After each scan the amount of detected addresses is
        increased until there are mo more undetected addresses, and the scanning
        stops.
        The problem with linked list is that the GC will detect a single item in
        each scan. So GC will run as many scans as the number of items in the
        linked list. And again, each scan goes over the entire memory.

    ***************************************************************************/

    protected Container.Malloc!(QueueItem) heap;


    /**************************************************************************

        Validate the following:

        1. If length is > 0 then head must not be null
        2. If length is 1, head and tail must point to the same item
        3. If length is > 1, head and tail must not point to the same item
        4. If it's empty then head is null

    ***************************************************************************/

    invariant ( )
    {
        if ( this.count )
        {
            assert ( this.head, "LinkedListQueue length isn't 0, it's head should not be null!" );

            if ( this.count == 1 )
                assert ( this.head is this.tail, "LinkedListQueue length is 1, it's head and tail should point to the same item!" );

            if ( this.count > 1 )
                assert ( this.head !is this.tail, "LinkedListQueue length is > 1, it's head and tail should not point to the same item!" );
        }
        else
        {
            assert ( !this.head, "LinkedListQueue length is 0, it's head should be null!" );
        }
    }


    /**************************************************************************

        Returns:
            true if queue is empty, false otherwise

    ***************************************************************************/

    public override bool empty ( )
    {
        return this.count == 0;
    }


    /**************************************************************************

        Returns:
            number of items in the queue

    ***************************************************************************/

    public override size_t length ( )
    {
        return this.count;
    }


    /**************************************************************************

        Removes all items from the queue in O(n)

    ***************************************************************************/

    public override void clear ( )
    {
        while ( this.count )
        {
            this.discardTop();
        }
    }


    /**************************************************************************

        Pushes an item to the queue. The caller should set the returned item as
        desired

        Returns:
            Pointer to the newly pushed item

    ***************************************************************************/

    public override T* push ( )
    {
        auto new_element = this.newItem();

        // Just created first item in queue, both head and tail
        // should point to it
        if ( this.count == 0 )
        {
            this.head = new_element;
            this.tail = this.head;
        }
        else // Update tail to point to new item
        {
            this.tail.next = new_element;
            this.tail = this.tail.next;
        }

        this.count++;

        return &new_element.value;
    }


    /**************************************************************************

        Discards the item at the top of the queue.

    ***************************************************************************/

    public override void discardTop ( )
    {
        if ( this.count == 0 )
            return;

        QueueItem* head_to_be_removed = this.head;
        this.head = this.head.next;

        this.deleteItem(head_to_be_removed);
        this.count--;
    }


    /**************************************************************************

        Returns:
            A pointer to the item at the top of the queue, null if the queue is
            empty

    ***************************************************************************/

    public override T* top ( )
    {
        if ( this.count == 0 )
            return null;

        return &this.head.value;
    }


    /**************************************************************************

        Checks whether a value exists in queue in O(n).

        Params:
            value = value to find

        Returns:
            true if value exists, false otherwise

    ***************************************************************************/

    public bool contains ( T value )
    {
        if ( this.count == 0 )
            return false;

        return this.head.find(value) !is null;
    }


    /**************************************************************************

        Removes a value from queue, in O(n)

        Params:
            value = value to remove
            all   = if true then remove all values equal to value, othetrwise only
                    first matching value will be removed

        Returns:
            number of removed values

    ***************************************************************************/

    public size_t remove ( T value, bool all = false )
    {
        // iterate over items in queue
        QueueItem* iterator = this.head;

        // keep pointer to previous item
        QueueItem* previous = iterator;

        // keep count of how many we removed
        auto old_count = this.count;

        while( iterator )
        {
            auto next = iterator.next;

            if ( iterator.value == value )
            {
                bool is_tail;
                bool is_head;

                // head item is to be removed
                // update head to point to next item
                if ( iterator is this.head )
                {
                    this.head = next;
                    previous = next;
                    is_head = true;
                }

                // tail item is to be removed
                // update tail to point to previous item
                if ( iterator is this.tail )
                {
                    this.tail = previous;
                    is_tail = true;

                    if ( !is_head )
                        this.tail.next = null;
                }

                // "in the middle" item is to be removed
                // connect the items before and after the removed one
                if ( !is_tail && !is_head )
                {
                    previous.next = next;
                }

                // remove
                this.deleteItem(iterator);
                this.count--;

                // should we look for more matched values? have we reached the end?
                if ( !all || this.count == 0 )
                    break;
            }
            else
            {
                previous = iterator;
            }

            iterator = next;
        }

        return old_count - this.count;
    }


    /**************************************************************************

        Deallocate an item. Called upon item removal from queue.

        Params:
            to_delete = pointer to item in queue to delete

    ***************************************************************************/

    protected void deleteItem ( QueueItem* to_delete )
    {
         if ( root_values )
            GC.removeRange(&to_delete.value);

        this.heap.collect(to_delete);
    }


    /**************************************************************************

        Allocate an item. Called upon item addition to queue.

        Params:
            to_add = value to add to queue

        Returns:
            pointer to newly allocated item

    ***************************************************************************/

    protected QueueItem* newItem ( )
    {
        auto new_element = this.heap.allocate();
        new_element.next = null;

        // By adding the value to GC as root we're preventing GC from
        // collecting it
        if ( root_values )
            GC.addRange(&new_element.value, T.sizeof);

        return new_element;
    }
}


/******************************************************************************

    Test root_values is determined correctly

*******************************************************************************/

unittest
{
    struct emptyStruct { }
    struct someStruct { int[] array; }
    class someClass { }

    // int
    test((new LinkedListQueue!(int)).root_values == false, "'int' should not be added as GC root");

    // empty struct
    test((new LinkedListQueue!(emptyStruct)).root_values == false, "An empty struct should not be added as GC root");

    // struct that points to GC memory
    test((new LinkedListQueue!(someStruct)).root_values, "A struct containing an array should be added as GC root!");

    // pointer to struct
    test((new LinkedListQueue!(emptyStruct*)).root_values, "A pointer to a struct should be added as GC root!");

    // class
    test((new LinkedListQueue!(someClass)).root_values, "A class should be added as GC root!");
}


/******************************************************************************

    Test ITypedQueue methods

*******************************************************************************/

unittest
{
    class JustSomeClass
    {
        protected int just_some_int;

        public this ( int set_just_some_int ) { this.just_some_int = set_just_some_int; }

        override public bool opEquals ( Object _another )
        {
            auto another = cast(JustSomeClass) _another;
            if (another is null)
                return false;
            return this.just_some_int == another.just_some_int;
        }
    }

    // T = int
    LinkedListQueue!(int) integersList = new LinkedListQueue!(int)();

    // T = JustSomeClass
    LinkedListQueue!(JustSomeClass) classesList = new LinkedListQueue!(JustSomeClass)();

    const int size = 100;
    int[] int_array;
    JustSomeClass[] class_array;

    for(int i = 0; i < size; i++)
    {
        int_array ~= i;
        class_array ~= new JustSomeClass(i);
    }

    testInterfaceMethods(integersList, int_array);
    testInterfaceMethods(classesList, class_array);
}


/******************************************************************************

    Test LinkedListQueue methods

*******************************************************************************/

unittest
{
    /**************************************************************************

        A class to test LinkedListQueue.

        The 'invariant' section validates the exact content of the
        LinkedListQueue. And in case of validation failure the name of the
        particular test is printed.

    ***************************************************************************/

    class TestQueue
    {
        /**********************************************************************

            The tested LinkedListQueue

        ***********************************************************************/

        protected LinkedListQueue!(int) int_queue;


        /**********************************************************************

            The values expected to be in intQueue, and their expected order

        ***********************************************************************/

        protected int[] expected_values;


        /**********************************************************************

            The name of the particular test, to be printed in case of test
            failure

        ***********************************************************************/

        protected istring name;


        /**********************************************************************

            Constructor

            Params:
                in_name = The name of the particular test

        ***********************************************************************/

        public this (istring in_name)
        {
            this.int_queue = new LinkedListQueue!(int)();
            this.name = in_name;
        }


        /**********************************************************************

            Invarinat to validate the contents in int_queue and expected_values
            are the same.

        ***********************************************************************/

        invariant ( )
        {
            test!("==")(this.int_queue.length(), this.expected_values.length, name ~ ": length should be the same");

            if ( this.expected_values.length == 0 )
            {
                test(this.int_queue.empty(), name ~ ": queue should be mepty");
                test!("==")(this.int_queue.top(), null, name ~ ": queue is empty. Top should have returned null");
            }

            LinkedListQueue!(int).QueueItem* iterator = this.int_queue.head;

            // compare all values
            foreach( value; this.expected_values)
            {
                test!("==")(iterator.value, value, name ~ ": value incorrect");
                iterator = iterator.next;
            }
        }


        /**********************************************************************

            Push values into LinkedListQueue.

            Params:
                values = values to push

        ***********************************************************************/

        public void push ( int[] values )
        {
            foreach( value; values )
            {
                .push(this.int_queue, value);
                this.expected_values ~= value;
            }
        }


        /**********************************************************************

            Removes a value from LinkedListQueue.

            Params:
                value              = value to remove
                expected_to_remove = number of items expected to be removed
                all                = should all instances of value be removed

        ***********************************************************************/

        public void remove ( int value, int expected_to_remove = 1, bool all = true )
        {
            bool continue_remove = true;

            if ( expected_to_remove )
                test(this.int_queue.contains(value),
                    name ~ ": value should have been found in LinkedListQueue");

            test(this.int_queue.remove(value, all) == expected_to_remove,
                name ~ ": Removed wrong number of items from LinkedListQueue");
            test(!this.int_queue.contains(value),
                name ~ ": value should NOT have been found in LinkedListQueue");

            if ( all )
            {
                int[] result, match;
                match ~= value;
                this.expected_values = .remove(this.expected_values, match, result);
            }
            else
            {
                foreach ( i, item; this.expected_values )
                {
                    if ( item == value )
                    {
                        removeShift(this.expected_values, i);
                        break;
                    }
                }
            }
        }
    }


    {
        // [1]
        TestQueue testQueue = new TestQueue("Test 'remove' from LinkedListQueue with a single item");
        testQueue.push([1]);
        testQueue.remove(1);
    }
    {
        // [3] 4
        TestQueue testQueue = new TestQueue("Test 'remove' first item from LinkedListQueue");
        testQueue.push([3, 4]);
        testQueue.remove(3);
    }
    {
        // 5 [6]
        TestQueue testQueue = new TestQueue("Test 'remove' last item from LinkedListQueue");
        testQueue.push([5, 6]);
        testQueue.remove(6);
    }
    {
        // [7] [8]
        TestQueue testQueue = new TestQueue("Test 'remove' all items from LinkedListQueue");
        testQueue.push([7, 8]);
        testQueue.remove(7);
        testQueue.remove(8);
    }
    {
        // 9 [10] 11
        TestQueue testQueue = new TestQueue("Test 'remove' middle item from LinkedListQueue");
        testQueue.push([9, 10, 11]);
        testQueue.remove(10);
    }
    {
        // 12 [13] [14] 15
        TestQueue testQueue = new TestQueue("Test 'remove' several middle items from LinkedListQueue");
        testQueue.push([12, 13, 14, 15]);
        testQueue.remove(13);
        testQueue.remove(14);
    }
    {
        // [16] 17 18 [19]
        TestQueue testQueue = new TestQueue("Test 'remove' first and last items from LinkedListQueue");
        testQueue.push([16, 17, 18, 19]);
        testQueue.remove(16);
        testQueue.remove(19);
    }
    {
        // [20] 21 21 [20]
        TestQueue testQueue = new TestQueue("Test 'remove' repeating values from LinkedListQueue");
        testQueue.push([20, 21, 21, 20]);
        testQueue.remove(20, 2);
        testQueue.remove(20, 0);
    }
    {
        // remove from an empty queue
        TestQueue testQueue = new TestQueue("Test 'remove' on an empty LinkedListQueue");
        testQueue.remove(1, 0);
    }
}
