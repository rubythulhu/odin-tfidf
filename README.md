# Odin TF/IDF library

Simple & Quick TF/IDF implementation for Odin extracted from one of my projects because i needed it for a second project. Supports supplying your own tokenizer.

## Usage

```odin
package my_prog

import srch "path/to/tfidf"
import "core:fmt"

main :: proc() {
  tfidf := srch.make_tfidf()
  // tfidf := srch.make_tfidf(my_tokenizer) to use your own tokenizer
  // tokenizer has type `proc(name, document: string) -> []string`
	defer srch.destroy(&tfidf)

	// add documents. id and name are returned in results. name is indexed along with the contents.
	srch.add_document(&tfidf, 3, "A Document", "im not even sure what's in this doc")
	srch.add_document(&tfidf, 4, "Not A Document", "this one is definitely not a document")
	srch.add_document(&tfidf, 5, "The Überdoc", "the document above all other documents")

	// meta param is optional but lets you store an arbitrary rawptr to whatever data you want,
	// potentially the original doc as a whole if you have it in-memory
	DocType :: struct { name: string, contents: string }
	docs := [3]DocType{
	  {"My Document", "my document has contents"},
		{"Your Document", "they are better than your document's contents"},
		{"Their Document", "but their document is way better than my document and your document combined"}
	}

	for &doc, i in docs {
	  srch.add_document(&tfidf, i, doc.name, doc.contents, &doc)
	}


	// build tf/idf for all documents
	srch.build_index(&tfidf)

	// search and get top 2 results
	results := srch.search(&tfidf, "my document search terms", 4)
	defer srch.destroy(&results)
	fmt.printfln("%#v", results)
}
```
