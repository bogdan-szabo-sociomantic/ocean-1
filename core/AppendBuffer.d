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

module ocean.core.AppendBuffer;

/******************************************************************************
 
    Template params:
        T = array element type
 
 ******************************************************************************/

class AppendBuffer ( T ) : AppendBufferImpl
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
        
        return dst[] = chunk[0 .. dst.length];
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
        
        return dst;
    }
    
    /**************************************************************************
    
        Concatenates chunks and appends them to the content, extending content
        where required.
        
        Params:
            chunks = chunks to concatenate and append to the content
        
        Returns:
            slice to concatenated chunks in the content
    
     **************************************************************************/
    
    T[] append ( T[][] chunks ... )
    {
        size_t start = super.length;
        
        foreach (chunk; chunks) if (chunk.length)
        {
            if (this.opCatAssign(chunk).length < chunk.length) break;
        }
        
        return this.opSlice(start, super.length);
    }

    /**************************************************************************
    
        Increases the content length by n elements.
        Note that previously returned slices must not be used after this method
        has been inwoked because the content buffer may be relocated, turning
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
}

/******************************************************************************/

package abstract class AppendBufferImpl
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

    private size_t e;
    
    private bool limited_ = false;
    
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
        
     **************************************************************************/
    
    public void clear ( )
    {
        this.n = 0;
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
        
        Sets the number of elements in content (content length)
        
        Params:
            n = new number of elements in content
        
        Returns:
            n
    
     **************************************************************************/
    
    public size_t length ( size_t n )
    {
        size_t len = n * this.e;
        
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
            Actual content buffer length (number of elements). This value is
            always at least length().
    
     **************************************************************************/
    
    public size_t capacity ( size_t capacity )
    {
        bool limited = this.limited_;
        
        this.limited_ = false;
        
        this.content.length = capacity * this.e;
        
        scope (exit) if (limited) this.limited(true);
        
        return this.n = capacity;
    }
    
    /**************************************************************************
    
        Sets the number of elements in content (content length)
        
        Params:
            n = new number of elements in content
        
        Returns:
            n
    
     **************************************************************************/
    
    public void minimize ( )
    {
        if (this.limited_)
        {
            this.content.length = this.n * this.e;
        }
    }

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
        assert (start <= end);
        assert (end <= this.n);
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
        assert (i <= this.n);
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
        assert (!(chunk.length % this.e), "alignment mismatch");
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
        assert (!(chunk.length % this.e), "alignment mismatch");
        assert (start <= end);
        assert (end <= this.n);
        assert (chunk.length == (end - start) * this.e, "length mismatch");
    }
    body
    {
        return this.content[start * this.e .. end * this.e] = cast (ubyte[]) chunk[];
    }
    
    /**************************************************************************
    
        Extends content by n elements.
        
        Params:
            n = number of elements to extend content by
        
        Returns:
            slice to the portion in content by which content has been extended
            (last n elements in content after extension)
    
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
}

/******************************************************************************/

unittest
{
    scope ab = new AppendBuffer!(dchar)(10);
    
    assert (ab.length == 0);
    
    ab[] = "Die Kotze"d;
    
    assert (ab.length  == "Die Kotze"d.length);
    assert (ab[]       == "Die Kotze"d);
    
    ab[5] =  'a';
    assert (ab.length  == "Die Katze"d.length);
    assert (ab[]       == "Die Katze"d);
    assert (ab[4 .. 9] == "Katze"d);
    
    ab ~= ' ';
    
    assert (ab[]      == "Die Katze "d);
    assert (ab.length == "Die Katze "d.length);
    
    ab ~= "tritt"d;
    
    assert (ab[]      == "Die Katze tritt"d);
    assert (ab.length == "Die Katze tritt"d.length);
    
    ab.append(" die"d, " Treppe"d, " krumm."d);
    
    assert (ab[]      == "Die Katze tritt die Treppe krumm."d);
    assert (ab.length == "Die Katze tritt die Treppe krumm."d.length);
    
    ab.clear();
    
    assert (!ab.length);
    assert (ab[] == ""d);
    
    ab.extend(5);
    assert (ab.length == 5);
    
    ab[] = '~';
    assert (ab[] == "~~~~~"d);
}

