module AbstractResponse;


package import tango.text.xml.Document,
               tango.text.xml.DocEntity,
               tango.text.xml.DocPrinter;

package import tango.text.Text;

package import tango.io.Buffer;
               
class AbstractResponse
{
        

        public Document!(char) XMLDocument ( )
        {
                return new Document!(char);
        }

        
        
        public DocPrinter!(char) XMLPrinter ( )
        {
                return new DocPrinter!(char);
        }

        

        public char[] removeTags( char[] xhtml )
        {
                auto text = new Text!(char);
                
                int start = Util.locatePattern(xhtml, "<head>");
                int end = Util.locatePattern(xhtml, "</head>");
                
                text.append(xhtml);
                text.select(start, end-start+8);
                text.remove;
                xhtml = text.toString;
                
                start = Util.locatePattern(xhtml, "<form");
                end = Util.locatePattern(xhtml, "</form>");
                
                text.select(start, end-start+8);
                text.remove;
                
                return text.toString;    
        }        
        

} // interface AbstractResponse

