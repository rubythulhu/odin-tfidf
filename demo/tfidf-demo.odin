package tfidf_demo

import tfidf ".."
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

IDEAS :: `
- coffee maker
- rubber duck
- stack overflow
- code quality
- pull request
- clean code
- legacy code
- production server
- commit message
`


main :: proc() {
	args := os.args
	if len(args) < 2 {
		fmt.eprintln("please provide a search query. some sample terms:")
		fmt.eprint(IDEAS)

		return
	}
	t := tfidf.make_tfidf()
	defer tfidf.destroy(&t)
	docs := #load_directory("./documents")
	fmt.print("Scanning: ")
	ct := 0
	start := time.now()
	l := 0
	for doc, i in docs {
		ct += 1
		fmt.printf("%s%s", i > 0 ? ", " : "", doc.name)
		tfidf.add_document(&t, i, doc.name, transmute(string)doc.data)
		l += len(doc.data)
	}
	tfidf.build_index(&t)
	end := time.now()
	ela := time.diff(start, end)
	fmt.printfln("\n\nScanned %d documents (%d bytes) in %s", ct, l, ela)
	qry := strings.join(args[1:], " ")
	defer delete(qry)

	start = time.now()
	fmt.printfln("\nSearching for: %s\n", qry)
	end = time.now()
	ela = time.diff(start, end)
	res := tfidf.search(&t, qry)
	defer tfidf.destroy(&res)
	fmt.printfln("Search time: %s\n", ela)
	for r, i in res {
		if r.score > 0 { fmt.printfln("* [id:% 3d, score: %.3f] %s", r.id, r.score, r.name) }
	}


}
