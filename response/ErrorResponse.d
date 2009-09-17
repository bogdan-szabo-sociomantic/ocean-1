module ErrorResponse;

import sociomantic.response.AbstractResponse;



class ErrorResponse : AbstractResponse
{

       
        public Buffer response()
        {
                // create xml error document
                auto doc   = XMLDocument;
                auto print = XMLPrinter;
                
                // attach an xml header 
                doc.header;
                
                // attach an element with some attributes, plus
                // a child element with an attached data value
                auto node = doc.root.element   (null, "Error");
                
                node.element   (null, "Code", "404");
                node.element   (null, "Message", "The specified resource does not exist");
                
                // attach doc to buffer
                auto buffer = new Buffer(print(doc));
                
                return buffer;
        }
        
            
            
} // class Error