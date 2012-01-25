/******************************************************************************

    Manages an array buffer for better incremental appending performance
    
    Copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    Version:        May 2011: Initial release
    
    Authors:        David Eckardt
    
    Manages an array buffer for better performance when elements are
    incrementally appended to an array.
    
    Note that, as with each dynamic array, changing the length invalidates
    existing slices to the array, potentially turning them into dangling
    references.
    
 ******************************************************************************/

module ocean.util.container.AppendBuffer;

debug private import ocean.util.log.Trace;

/******************************************************************************
    
    AppendBuffer Base interface.

 ******************************************************************************/

interface IAppendBufferBase
{
    /**************************************************************************
    
        Returns:
            number of elements in content
    
     **************************************************************************/
    
    size_t length ( );
}
    
/******************************************************************************
    
    Read-only AppendBuffer interface.
    
    Note that there is no strict write protection to an IAppendBufferReader
    instance because it is still possible to modify the content an obtained
    slice refers to. However, this is no the intention of this interface and
    may not result in the desired or even result in undesired side effects.

 ******************************************************************************/

interface IAppendBufferReader ( T ) : IAppendBufferBase
{
    /**************************************************************************
    
        Returns the i-th element in content.
        
        Params:
            i = element index
    
        Returns:
            i-th element in content
    
     **************************************************************************/

    T opIndex ( size_t i );
    
    /**************************************************************************
    
        Returns:
            the current content
    
     **************************************************************************/

    T[] opSlice ( );
    
    /**************************************************************************
    
        Returns content[start .. end].
        start must be at most end and end must be at most the current content
        length.
        
        Params:
            start = start index
            end   = end index (exclusive)
        
        Returns:
            content[start .. end]
    
     **************************************************************************/

    T[] opSlice ( size_t start, size_t end );
    
    /**************************************************************************
    
        Returns content[start .. length].
        
        Params:
            start = start index
        
        Returns:
            content[start .. length]
    
     **************************************************************************/

    T[] tail ( size_t start );
}

/******************************************************************************
 
    Template params:
        T = array element type
 
 ******************************************************************************/

public class AppendBuffer ( T ) : AppendBufferImpl, IAppendBufferReader!(T)
{
    /**********************************************************************
    
        Constructor
        
     **********************************************************************/
    
    this ( )
    {
        this(0);
    }
    
    /**************************************************************************
    
        Constructor
        
        Params:
            n = content length for preallocation (optional)
    
     **************************************************************************/
    
    this ( size_t n, bool limited = false )
    {
        super(T.sizeof, n);
        
        super.limited = limited;
    }
    
    /**************************************************************************
    
        Returns the i-th element in content.
        
        Params:
            i = element index
    
        Returns:
            i-th element in content
    
     **************************************************************************/

    T opIndex ( size_t i )
    {
        return *cast (T*) super.index_(i);
    }
    
    /**************************************************************************
    
        Sets the i-th element in content.
        
        Params:
            i = element index
    
        Returns:
            element
    
     **************************************************************************/

    T opIndexAssign ( T val, size_t i )
    {
        return *cast (T*) super.index_(i) = val;
    }
    
    /**************************************************************************
    
        Returns:
            the current content
    
     **************************************************************************/

    T[] opSlice ( )
    {
        return cast (T[]) super.slice_();
    }
    
    /**************************************************************************
    
        Returns content[start .. end].
        start must be at most end and end must be at most the current content
        length.
        
        Params:
            start = start index
            end   = end index (exclusive)
        
        Returns:
            content[start .. end]
    
     **************************************************************************/

    T[] opSlice ( size_t start, size_t end )
    {
        return cast (T[]) super.slice_(start, end);
    }
    
    /**************************************************************************
    
        Returns content[start .. length].
        
        Params:
            start = start index
        
        Returns:
            content[start .. length]
    
     **************************************************************************/

    T[] tail ( size_t start )
    {
        return this[start .. super.length];
    }
    
    /**************************************************************************
    
        Copies chunk to the content, setting the content length to chunk.length.
        
        Params:
            chunk = chunk to copy to the content
        
        Returns:
            slice to chunk in the content
    
     **************************************************************************/

    T[] opSliceAssign ( T[] chunk )
    {
        return cast (T[]) super.copy_(chunk);
    }
    
    /**************************************************************************
    
        Copies chunk to content[start .. end].
        chunk.length must be end - start and end must be at most the current
        content length.
        
        Params:
            chunk = chunk to copy to the content
        
        Returns:
            slice to chunk in the content
    
     **************************************************************************/

    T[] opSliceAssign ( T[] chunk, size_t start, size_t end )
    {
        return cast (T[]) super.copy_(chunk, start, end);
    }
    
    /**************************************************************************
    
        Sets all elements in the current content to element.
        
        Params:
            element = element to set all elements to
        
        Returns:
            current content
    
     **************************************************************************/
    
    T[] opSliceAssign ( T element )
    {
        return this.opSlice()[] = element;
    }
    
    /**************************************************************************
    
        Copies chunk to the content, setting the content length to chunk.length.
        
        Params:
            chunk = chunk to copy to the content
        
        Returns:
            slice to chunk in the content
    
     **************************************************************************/
    
    T[] opSliceAssign ( T element, size_t start, size_t end )
    {
        return this.opSlice(start, end)[] = element;
    }
    
    /**************************************************************************
    
        Appends chunk to the content, extending content where required.
        
        Params:
            chunk = chunk to append to the content
        
        Returns:
            slice to chunk in the content
    
     **************************************************************************/
    
    T[] opCatAssign ( T[] chunk )
    {
        T[] dst = this.extend(chunk.length);
        
        dst[] = chunk[0 .. dst.length];
        
        return this[];
    }
    
    /**************************************************************************
    
        Appends element to the content, extending content where required.
        
        Params:
            element = element to append to the content
        
        Returns:
            slice to element in the content
    
     **************************************************************************/
    
    T[] opCatAssign ( T element )
    {
        T[] dst = this.extend(1);
        
        if (dst.length)
        {
            dst[0] = element;
        }
        
        return this[];
    }
    
    /**************************************************************************
    
        Cuts the last element from the current content. 
        
        Returns:
            element cut from the current content.
            
        In:
            The content must not be empty. 
    
     **************************************************************************/

    T cut ( )
    in
    {
        assert (super.length, "cannot cut last element: content is empty");
    }
    body
    {
        size_t n = super.length - 1;
 
        scope (success) super.length = n;
        
        return this[n];
    }
    
    /**************************************************************************
    
        Cuts the last n elements from the current content. If n is greater than
        the current content length, all elements in the content are cut. 
        
        Params:
            n = number of elements to cut from content, if available
        
        Returns:
            last n elements cut from the current content, if n is at most the
            content length or all elements from the current content otherwise.
    
     **************************************************************************/
    
    T[] cut ( size_t n )
    out (elements)
    {
        assert (elements.length <= n);
    }
    body
    {
        size_t end   = super.length,
        start = (end >= n)? end - n : 0;
        
        scope (success) super.length = start;
        
        return this[start .. end];
    }
    
    /**************************************************************************
    
        Cuts the last n elements from the current content. If n is greater than
        the current content length, all elements in the content are cut. 
        
        Params:
            n = number of elements to cut from content, if available
        
        Returns:
            last n elements cut from the current content, if n is at most the
            content length or all elements from the current content otherwise.
    
     **************************************************************************/

    T[] dump ( )
    {
        scope (success) super.length = 0;
        
        return this[];
    }
    
    /**************************************************************************
    
        Concatenates chunks and appends them to the content, extending the
        content where required.
        
        Params:
            chunks = chunks to concatenate and append to the content
        
        Returns:
            slice to concatenated chunks in the content which may be shorter
            than the chunks to concatenate if the content would have needed to
            be extended but content length limitation is enabled.
    
     **************************************************************************/
    
    T[] append ( U ... ) ( U chunks )
    {
        size_t start = super.length;
        
        Top: foreach (i, chunk; chunks)
        {
            static if (is (U[i] V : V[]) && is (V W : W[]))
            {
                foreach (chun; chunk)
                {
                    if (!this.append(chun)) break Top;                          // recursive call
                }
            }
            else static if (is (U[i] : T))
            {
                if (!this.opCatAssign(chunk).length) break;
            }
            else
            {
                static assert (is (typeof (this.append_(chunk))), "cannot append " ~ U[i].stringof ~ " to " ~ (T[]).stringof);
                
                if (!this.append_(chunk)) break;
            }
        }
        
        return this.tail(start);
    }
    
    /**************************************************************************
    
        Appends chunk to the content, extending the content where required.
        
        Params:
            chunks = chunk to append to the content
        
        Returns:
            true on success or false if the content would have needed to be
            extended but content length limitation is enabled.
    
     **************************************************************************/

    private bool append_ ( T[] chunk )
    {
        return chunk.length? this.opCatAssign(chunk).length >= chunk.length : true;
    }
    
    /**************************************************************************
    
        Increases the content length by n elements.
        
        Note that previously returned slices must not be used after this method
        has been invoked because the content buffer may be relocated, turning
        existing slices to it into dangling references.
        
        Params:
            n = number of characters to extend content by
        
        Returns:
            slice to the portion in content by which content has been extended
            (last n elements in content after extension)
    
     **************************************************************************/
    
    T[] extend ( size_t n )
    {
        return cast (T[]) super.extend_(n);
    }
    
    /**************************************************************************
    
        Returns:
            pointer to the content
    
     **************************************************************************/

    T* ptr ( )
    {
        return cast (T*) super.index_(0);
    }
    
    /**************************************************************************
    
        Sets all elements in data to the initial value of the element type.
        data.length is guaranteed to be dividable by the element size.
        
        Params:
            data = data to erase
        
     **************************************************************************/

    protected void erase ( void[] data )
    {
        (cast (T[]) data)[] = T.init;
    }
}

/******************************************************************************/

private abstract class AppendBufferImpl: IAppendBufferBase
{
    /**************************************************************************
    
        Content buffer
        
        We use ubyte[], not void[], because the GC scans void[] buffers for
        references.
        
        @see http://thecybershadow.net/d/Memory_Management_in_the_D_Programming_Language.pdf
        
        , page 30
    
     **************************************************************************/

    private ubyte[] content;
    
    /**************************************************************************
    
        Number of elements in content 
    
     **************************************************************************/

    private size_t n = 0;
    
    /**************************************************************************
    
        Element size
    
     **************************************************************************/

    private const size_t e;
    
    /**************************************************************************
    
        Limitation flag
    
     **************************************************************************/

    private bool limited_ = false;
    
    /**************************************************************************
    
        Content base pointer and length which are ensured to be invariant when
        limitation is enabled unless the capacity is changed.
    
     **************************************************************************/

    private struct LimitInvariants
    {
        private ubyte* ptr = null;
        size_t         len;
    }
    
    private LimitInvariants limit_invariants;
    
    /**************************************************************************
    
        Consistency checks for content length and number, limitation and content
        buffer location if limitation enabled.
    
     **************************************************************************/

    invariant
    {
        assert (!(this.content.length % this.e));
        assert (this.n * this.e <= this.content.length);
        
        with (this.limit_invariants) if (this.limited_)
        {
            assert (ptr is this.content.ptr);
            assert (len == this.content.length);
        }
        else
        {
            assert (ptr is null);
        }
    }
    
    /**************************************************************************
    
        Constructor
        
        Params:
            e = element size (non-zero)
            n = number of elements in content for preallocation (optional)
    
     **************************************************************************/

    protected this ( size_t e, size_t n = 0 )
    in
    {
        assert (e);
    }
    body
    {
        this.e = e;
        
        this.content = new ubyte[e * n];
    }
    
    /**************************************************************************
    
        Sets the number of elements in content to 0.
        
        Returns:
            previous number of elements.
        
     **************************************************************************/
    
    public size_t clear ( )
    {
        scope (success) this.n = 0;
        
        this.erase(this.content[0 .. this.n * this.e]);
        
        return this.n;
    }

    /**************************************************************************
    
        Enables or disables size limitation.
        
        Params:
            limited_ = true: enable size limitation, false: disable
            
        Returns:
            limited_
        
     **************************************************************************/

    public bool limited ( bool limited_ )
    {
        with (this.limit_invariants) if (limited_)
        {
            ptr = this.content.ptr;
            len = this.content.length;
        }
        else
        {
            ptr = null;
        }
        
        return this.limited_ = limited_;
    }
    
    /**************************************************************************
    
        Returns:
            true if size limitation is enabled or false if disabled
        
     **************************************************************************/

    public bool limited ( )
    {
        return this.limited_;
    }
    
    /**************************************************************************
    
        Returns:
            number of elements in content
    
     **************************************************************************/
    
    public size_t length ( )
    {
        return this.n;
    }

    /**************************************************************************

        Returns:
            size of currently allocated buffer in bytes.

     **************************************************************************/
    
    public size_t dimension ( )
    {
        return this.content.length;
    }
    
    /**************************************************************************

        Returns:
            available space (number of elements) in the content buffer, if
            limitation is enabled, or size_t.max otherwise.

    **************************************************************************/

    public size_t available ( )
    {
        return this.limited_? this.content.length / this.e - this.n : size_t.max;
    }

    /**************************************************************************
        
        Sets the number of elements in content (content length). If length is
        increased, spare elements will be appended. If length is decreased,
        elements will be removed at the end. If limitation is enabled, the
        new number of elements is truncated to capacity().
        
        Note that, unless limitaion is enabled, previously returned slices must
        not be used after this method has been invoked because the content
        buffer may be relocated, turning existing slices to it into dangling
        references.
        
        Params:
            n = new number of elements in content
        
        Returns:
            new number of elements, will be truncated to capacity() if
            limitation is enabled.
    
     **************************************************************************/
    
    public size_t length ( size_t n )
    out (n_new)
    {
        if (this.limited_)
        {
            assert (n_new <= n);
        }
        else
        {
            assert (n_new == n);
        }
    }
    body
    {
        size_t len = n * this.e;
        
        size_t old_len = this.content.length;
        
        if (this.content.length < len)
        {
            if (this.limited_)
            {
                len = this.content.length;
            }
            else
            {
                this.content.length = len;
            }
        }
        
        if (old_len < len)
        {
            this.erase(this.content[old_len .. len]);   
        }
        
        return this.n = len / this.e;
    }
    
    /**************************************************************************
    
        Returns:
            Actual content buffer length (number of elements). This value is
            always at least length().
    
     **************************************************************************/
    
    public size_t capacity ( )
    {
        return this.content.length / this.e;
    }
    
    /**************************************************************************
    
        Returns:
            the element size in bytes. The constructor guarantees it is > 0.
    
     **************************************************************************/
    
    public size_t element_size ( )
    {
        return this.e;
    }
    
    /**************************************************************************
        
        Sets the content buffer length, preserving the actual content and
        overriding/adjusting the limit if limitation is enabled.
        If the new buffer length is less than length(), the buffer length will
        be set to length() so that no element is removed.
        
        Note that previously returned slices must not be used after this method
        has been invoked because the content buffer may be relocated, turning
        existing slices to it into dangling references.
        
        Params:
            capacity = new content buffer length (number of elements).
        
        Returns:
            New content buffer length (number of elements). This value is always
            at least length().
        
     **************************************************************************/
    
    public size_t capacity ( size_t capacity )
    {
        /*
         *  Disable limitation and re-enable it on exit to avoid the invariant
         *  to fail. See comment on LimitInvariants struct above.
         */
        
        bool limited = this.limited_;
        
        this.limited_ = false;
        
        scope (exit) if (limited) this.limited(true);
        
        if (capacity < this.n)
        {
            capacity = this.n;
        }
        
        this.content.length = capacity * this.e;
        
        return capacity;
    }
    
    /**************************************************************************
    
        Sets capacity() to length().
        
        Note that previously returned slices must not be used after this method
        has been invoked because the content buffer may be relocated, turning
        existing slices to it into dangling references.
        
        Returns:
            previous capacity().
    
     **************************************************************************/
    
    public size_t minimize ( )
    {
        scope (success)
        {
            this.content.length = this.n * this.e;
        }
        
        return this.content.length / this.e;
    }

    /**************************************************************************
    
        Sets all elements in data to the initial value of the element type.
        data.length is guaranteed to be dividable by the element size.
        
        Params:
            data = data to erase
        
     **************************************************************************/

    abstract protected void erase ( void[] data );
    
    /**************************************************************************
    
        Returns:
            current content
        
     **************************************************************************/

    protected void[] slice_ ( )
    {
        return this.content[0 .. this.n * this.e];
    }
    
    /**************************************************************************
    
        Slices content. start and end index content elements with element size e
        (as passed to the constructor).
        start must be at most end and end must be at most the current number
        of elements in content.
        
        Params:
            start = index of start element
            end   = index of end element (exclusive)
        
        Returns:
            content[start * e .. end * e]
    
     **************************************************************************/
    
    protected void[] slice_ ( size_t start, size_t end )
    in
    {
        assert (start <= end, typeof (this).stringof ~ ": slice start behind end index");
        assert (end <= this.n, typeof (this).stringof ~ ": slice end out of range");
    }
    body
    {
        return this.content[start * this.e .. end * this.e];
    }
    
    /**************************************************************************
    
        Returns a pointer to the i-th element in content.
        
        Params:
            i = element index
        
        Returns:
            pointer to the i-th element in content
    
     **************************************************************************/

    protected void* index_ ( size_t i )
    in
    {
        assert (i <= this.n, typeof (this).stringof ~ ": index out of range");
    }
    body
    {
        return this.content.ptr + i * this.e;
    }
    
    /**************************************************************************
    
        Copies chunk to the content, setting the current number of elements in
        content to the number of elements in chunk.
        chunk.length must be dividable by the element size.
        
        Params:
            chunk = chunk to copy to the content
        
        Returns:
            slice to chunk in content
    
     **************************************************************************/

    protected void[] copy_ ( void[] chunk )
    in
    {
        assert (!(chunk.length % this.e), typeof (this).stringof ~ ": data alignment mismatch");
    }
    out (slice)
    {
        if (this.limited_)
        {
            assert (slice.length <= chunk.length);
        }
        else
        {
            assert (slice.length == chunk.length);
        }
    }
    body
    {
        this.n = 0;
        
        void[] content = this.extendBytes(chunk.length);
        
        assert (content.ptr is this.content.ptr);
        
        return content[] = cast (ubyte[]) chunk[0 .. content.length];
    }
    
    /**************************************************************************
    
        Copies chunk to content[start * e .. end * e].
        chunk.length must be (end - start) * e and end must be at most the
        current number of elements in content.
        
        Params:
            chunk = chunk to copy to the content
        
        Returns:
            slice to chunk in the content
    
     **************************************************************************/

    protected void[] copy_ ( void[] chunk, size_t start, size_t end )
    in
    {
        assert (!(chunk.length % this.e), typeof (this).stringof ~ ": data alignment mismatch");
        assert (start <= end,             typeof (this).stringof ~ ": slice start behind end index");
        assert (end <= this.n,            typeof (this).stringof ~ ": slice end out of range");
        assert (chunk.length == (end - start) * this.e, typeof (this).stringof ~ ": length mismatch of data to copy");
    }
    body
    {
        return this.content[start * this.e .. end * this.e] = cast (ubyte[]) chunk[];
    }
    
    /**************************************************************************
    
        Extends content by n elements. If limitation is enabled, n will be
        truncated to the number of available elements.
        
        Params:
            n = number of elements to extend content by
        
        Returns:
            Slice to the portion in content by which content has been extended
            (last n elements in content after extension).
    
     **************************************************************************/
    
    protected void[] extend_ ( size_t n )
    out (slice)
    {
        if (this.limited_)
        {
            assert (slice.length <= n * this.e);
        }
        else
        {
            assert (slice.length == n * this.e);
        }
    }
    body
    {
        return this.extendBytes(n * this.e);
    }
    
    /**************************************************************************
    
        Extends content by extent bytes.
        extent must be dividable by the element size e.
        
        Params:
            extent = number of bytes to extend content by
        
        Returns:
            slice to the portion in content by which content has been extended
            (last extent bytes in content after extension)
    
     **************************************************************************/

    private void[] extendBytes ( size_t extent )
    in
    {
        assert (!(extent % this.e));
    }
    out (slice)
    {
        assert (!(slice.length % this.e));
        
        if (this.limited_)
        {
            assert (slice.length <= extent);
        }
        else
        {
            assert (slice.length == extent);
        }
    }
    body
    {
        size_t oldlen = this.n * this.e,
               newlen = oldlen + extent;
        
        if (this.content.length < newlen)
        {
            if (this.limited_)
            {
                newlen = this.content.length;
            }
            else
            {
                this.content.length = newlen;
            }
        }
        
        this.n = newlen / this.e;
        
        return this.content[oldlen .. newlen];
    }
    
    /**************************************************************************
    
        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)
    
     **************************************************************************/

    protected override void dispose ( )
    {
        delete this.content;
        
        this.content = null;
    }
}

/******************************************************************************/

unittest
{
    scope ab = new AppendBuffer!(dchar)(10);
    
    assert (ab.length    == 0);
    assert (ab.capacity  == 10);
    assert (ab.dimension == 10 * dchar.sizeof);
    
    ab[] = "Die Kotze"d;
    
    assert (ab.length  == "Die Kotze"d.length);
    assert (ab[]       == "Die Kotze"d);
    assert (ab.capacity  == 10);
    assert (ab.dimension == 10 * dchar.sizeof);
    
    ab[5] =  'a';
    assert (ab.length  == "Die Katze"d.length);
    assert (ab[]       == "Die Katze"d);
    assert (ab[4 .. 9] == "Katze"d);
    assert (ab.capacity  == 10);
    assert (ab.dimension == 10 * dchar.sizeof);
    
    ab ~= ' ';
    
    assert (ab[]      == "Die Katze "d);
    assert (ab.length == "Die Katze "d.length);
    assert (ab.capacity  == 10);
    assert (ab.dimension == 10 * dchar.sizeof);

    ab ~= "tritt"d;
    
    assert (ab[]      == "Die Katze tritt"d);
    assert (ab.length == "Die Katze tritt"d.length);
    assert (ab.capacity  == "Die Katze tritt"d.length);
    assert (ab.dimension == "Die Katze tritt"d.length * dchar.sizeof);

    ab.append(" die"d, " Treppe"d, " krumm."d);
    
    assert (ab[]      == "Die Katze tritt die Treppe krumm."d);
    assert (ab.length == "Die Katze tritt die Treppe krumm."d.length);
    assert (ab.capacity  == "Die Katze tritt die Treppe krumm."d.length);
    assert (ab.dimension == "Die Katze tritt die Treppe krumm."d.length * dchar.sizeof);
    
    assert (ab.cut(4) == "umm."d);
    
    assert (ab.length == "Die Katze tritt die Treppe kr"d.length);
    assert (ab.capacity  == "Die Katze tritt die Treppe krumm."d.length);
    assert (ab.dimension == "Die Katze tritt die Treppe krumm."d.length * dchar.sizeof);
    
    assert (ab.cut() == 'r');
    
    assert (ab.length == "Die Katze tritt die Treppe k"d.length);
    assert (ab.capacity  == "Die Katze tritt die Treppe krumm."d.length);
    assert (ab.dimension == "Die Katze tritt die Treppe krumm."d.length * dchar.sizeof);
    
    ab.clear();
    
    assert (!ab.length);
    assert (ab[] == ""d);
    
    ab.extend(5);
    assert (ab.length == 5);
    
    ab[] = '~';
    assert (ab[] == "~~~~~"d);
}

