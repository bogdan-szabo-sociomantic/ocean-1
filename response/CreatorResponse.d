module CreatorResponse;

import sociomantic.response.AbstractResponse,
       sociomantic.compress.Gzip;



class CreatorResponse : AbstractResponse
{


        public char[] creator_id;                 // string identifier of author


        private const char[] path  =
            "/srv/www/htdocs/en.scientificcommons.org/creator/";



        public this ( char[] creator_id )
        {
                this.creator_id = creator_id;
        }



        public Buffer response()
        {
                // uncompress xhtml
                auto gzip   = new Gzip(this.path ~ creator_id ~ ".co");
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

                // get left content box
                auto nodeRoot = input.query.descendant["div"].filter(
                                (input.Node n){return n.hasAttribute("id","content_nav_box");});

                result.element(null, "author", nodeRoot["div"]["h1"].nodes[0].value);
                result.element(null, "time", nodeRoot["div"]["p"].nodes[1].value);
                result.element(null, "number", nodeRoot["div"]["p"].nodes[3].value);

                auto friendNode = result.element(null, "socialNetwork");

                foreach(friend; nodeRoot["div"]["ul"]["li"]["a"])
                {
                    friendNode.element(null, "friend", friend.value)
                              .attribute(null, "href", friend.getAttribute("href").value);
                }

                // get main content box
                auto nodeCore = input.query.descendant["div"].filter(
                               (input.Node n){return n.hasAttribute("class","content_element");});

                auto pubNode = result.element(null, "publications");

                foreach(nodeTree; nodeCore)
                {
                    auto elements = nodeTree.query["p"];

                    auto title       = elements.nodes[0];
                    auto authors     = elements.nodes[1];

                    auto node = pubNode.element(null, "publication")
                                       .attribute(null, "id", nodeTree.getAttribute("id").value)
                                       .attribute(null, "href", title.query["a"].attribute.nodes[0].value);

                    node.element(null, "title", toEntity(Util.trim(title.query["a"].nodes[0].value)));

                    auto nodeA = node.element(null, "authors");
                    foreach ( p; authors.query["a"])
                    {
                        nodeA.element(null, "author", Util.trim(p.value))
                             .attribute(null, "href", p.getAttribute("href").value);
                    }

                    if ( elements.count > 2 ){
                        auto description = elements.nodes[2];
                        node.element(null, "description", toEntity(Util.trim(description.value)));
                    }

                }

                auto buffer = new Buffer(print(output));

                return buffer;
        }



} // class PublicationResponse