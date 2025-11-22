# Odin TF/IDF library

Simple & Quick TF/IDF implementation for Odin extracted from one of my projects because i needed it for a second project. Supports supplying your own tokenizer.

## Usage

```odin
import srch "path/to/tfidf"

main :: proc() {
  tfidf := srch.make_tfidf()
  // tfidf := srch.make_tfidf(my_tokenizer) to use your own tokenizer
  // tokenizer has type `proc(name, document: string) -> []string`
	defer srch.destroy(&tfidf)
	
	// add documents. id and name are returned in results. name is indexed along with the contents.
	srch.add_document(&t, 1, "My Document", "my document has contents")
	srch.add_document(&t, 2, "Your Document", "they are better than your document's contents")
	srch.add_document(&t, 5, "Their Document", "but their document is way better than my document and your document combined")
	
	// build tf/idf for all documents
	srch.build_index(&tfidf)
	
	// search and get top 2 results
	results := srch.search(tfidf, "my document search terms", 2)
	defer srch.destroy(&results)
	fmt.println("%#v", results)
}
```
