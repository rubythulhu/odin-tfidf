package tfidf_demo

import tfidf ".."
import "core:fmt"
import "core:mem"
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
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		track.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
		context.allocator = mem.tracking_allocator(&track)
		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				total: int
				for _, entry in track.allocation_map {
					total += entry.size
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
				fmt.eprintf("-> %v bytes total\n", total)
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}
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
	fmt.eprintfln("%#v", res)
	for r, i in res {
		if r.score > 0 { fmt.printfln("* [id:% 3d, score: %.3f] %s", r.id, r.score, r.name) }
	}
}
