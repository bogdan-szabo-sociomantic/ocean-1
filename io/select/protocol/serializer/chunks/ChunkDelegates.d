module ocean.io.select.protocol.serializer.chunks.ChunkDelegates;


struct ChunkDelegates
{
    public alias void delegate ( char[] ) GetValueDg;
    
    public alias void delegate ( char[], char[] ) GetPairDg;
    
    public alias char[] delegate ( ) PutValueDg;

    public alias char[][] delegate ( ) PutListDg;
}
