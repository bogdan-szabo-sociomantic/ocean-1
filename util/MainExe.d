/******************************************************************************

    Keeps the path of a running executable
    
    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved
    
    version:        December 2009: Initial release
    
    authors:        David Eckardt
    
    --
    
    Usage:
    
        import src.core.util.MainExe;
        
        void main ( char[][] args )
        {
            MainExe mainexe;
            
            // set to path of running executable
            
            mainexe.set(args[0]);
            
            // get absolute directory path of running executable
            
            char[] exepath = mainexe.get();
            
            // get absolute path of file "config.ini" located in subdirectory
            // "etc" of the running executable's directory
           
            char[] cfgpath = mainexe.prepend(["etc", "config.ini"]);
        }
    
 ******************************************************************************/

module util.MainExe;

/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.sys.Environment;

private import tango.io.FilePath;

private import PathUtil = tango.util.PathUtil: normalize;

/******************************************************************************

    MainExe structure

 ******************************************************************************/

struct MainExe
{
    /**************************************************************************
     
         Directory of the executable
     
     **************************************************************************/
    
    private char[] dir;
    
    /**************************************************************************
         
         Sets the executable path.
         
         Params:
              exepath = executable path
               
         Returns:
              base directory
             
     **************************************************************************/
    
    public char[] set ( char[] exepath )
    {
        scope path = new FilePath(exepath);
        
        this.dir = PathUtil.normalize(path.absolute(Environment.cwd()).path());
        
        return this.get();
    }
    
    /**************************************************************************
    
        Returns the base directory.
        
        Returns:
             base directory
             
     **************************************************************************/
    
    public char[] get ( )
    {
        return this.dir.dup;
    }
    
    /**************************************************************************
    
        Prepends the absolute base directory to "path" and joins the path.
        
        Params:
             path = input path
              
        Returns:
             joined path with prepended absolute base directory
             
     **************************************************************************/
    
    public char[] prepend ( char[][] path )
    {
        return FilePath.join(this.dir ~ path);
    }
}