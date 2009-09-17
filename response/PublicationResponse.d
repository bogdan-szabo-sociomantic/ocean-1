module PublicationResponse;

import sociomantic.response.AbstractResponse,
       sociomantic.compress.Gzip;

       
       
class PublicationResponse : AbstractResponse
{

       
        public char[] pub_id;                 // publication id

        
        private const char[] path  =  
            "/srv/www/htdocs/en.scientificcommons.org/publication/";
        
        
        
        public this ( char[] pub_id )
        {
                this.pub_id = pub_id;

        }
        
        
        
        public Buffer response()
        {
                // uncompress xhtml
                auto gzip   = new Gzip(this.path ~ pub_id ~ ".co");
                auto gbuffer = gzip.readFile;
                
                // tranform xhtml to xml
                auto buffer = transformToXML(gbuffer);
                
                return buffer;
        }
        

        
        private Buffer transformToXML( GrowBuffer gbuffer )
        {
                auto input  = XMLDocument;
                auto output = XMLDocument;
                auto print  = XMLPrinter;
                
                // cast buffer into char[] and strip unwanted tags
                char[] stripped  =  removeTags ( cast(char[])gbuffer.slice );
                input.parse ( stripped );
                
                // attach output header
                output.header();
                
                auto result = output.root.element(null, "response")
                                         .attribute(null, "xmlns", "http//www.magazineone.com/namespace/2008-08-15")
                                         .element(null, "result");
                
                // nodeID
                auto nodeID = input.query.descendant["div"].filter(
                               (input.Node n){return n.hasAttribute("id","publication_id");});
                                         
                // get publication details
                auto nodeCore = input.query.descendant["table"].filter(
                               (input.Node n){return n.hasAttribute("class","publication");});
                
                auto searchNode = nodeCore.nodes[0].query.descendant["td"];
                
                auto title      = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_title");});
                auto creator    = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_creator");});
                auto date       = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_date");});
                auto description = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_description");});
                auto identifier = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_identifier");});
                auto source     = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_source");});
                auto format     = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_format");});
                auto publisher  = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_publisher");});
                auto contributor  = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_contributor");});
                auto repository  = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_repository");});
                auto subject    = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_subject");});
                auto type       = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_type");});
                auto language   = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_language");});
                auto relation   = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_relation");});
                auto coverage   = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_coverage");});
                auto rights   = searchNode.filter((input.Node n){return n.hasAttribute("class","dc_rights");});
                //similar_publications
                
                result.element(null, "id", toEntity(Util.trim(nodeID.nodes[0].value)));
                result.element(null, "title", toEntity(Util.trim(title.nodes[0].value)));
                //result.element(null, "date", toEntity(Util.trim(date.nodes[0].value)));
                
                auto buffer = new Buffer(print(output));
                
                return buffer;
        }


        
} // class PublicationResponse
            


            
            
