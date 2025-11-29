package tfidf

import tokenizer "./tokenizer"
import "core:math"
import "core:slice"
import "core:strings"

Token_List :: tokenizer.Token_List
Tokenizer :: tokenizer.Tokenizer
DEFAULT_TOKENIZER :: tokenizer.DEFAULT_TOKENIZER

Document :: struct {
	id:     int,
	name:   string,
	tokens: []string,
	vec:    []f32,
	// let the user store whatever data they want
	meta:   rawptr,
}

destroy_document :: proc(doc: ^Document) {
	delete(doc.name)
	for tok in doc.tokens {
		delete(tok)
	}
	delete(doc.tokens)
	delete(doc.vec)
}


Vocab :: struct {
	word_to_index: map[string]int,
	words:         []string,
	doc_frequency: []int, // how many docs contain each word
	total_docs:    int,
}
destroy_vocab :: proc(voc: ^Vocab) {
	delete(voc.word_to_index)
	delete(voc.words)
	delete(voc.doc_frequency)
}

Tfidf :: struct {
	vocab: Vocab,
	docs:  [dynamic]Document,
	idf:   []f32,
}

destroy_tfidf :: proc(tfidf: ^Tfidf) {
	for &doc in tfidf.docs {
		destroy_document(&doc)
	}
	delete(tfidf.docs)
	destroy_vocab(&tfidf.vocab)
	delete(tfidf.idf)
}

init_tfidf :: proc(tfidf: ^Tfidf) {
	tfidf.docs = make([dynamic]Document)
}

make_tfidf :: proc() -> (tfidf: Tfidf) {
	init_tfidf(&tfidf)
	return tfidf
}

@(private = "package")
build_vocabulary :: proc(tfidf: ^Tfidf) {
	tfidf.vocab.word_to_index = make(map[string]int)
	word_index := 0

	for doc in tfidf.docs {
		for token in doc.tokens {
			if token not_in tfidf.vocab.word_to_index {
				tfidf.vocab.word_to_index[token] = word_index
				word_index += 1
			}
		}
	}

	tfidf.vocab.doc_frequency = make([]int, len(tfidf.vocab.word_to_index))
	tfidf.vocab.words = make([]string, len(tfidf.vocab.word_to_index))
	tfidf.vocab.total_docs = len(tfidf.docs)

	for doc in tfidf.docs {
		seen := make(map[string]bool)
		defer delete(seen)
		for token in doc.tokens {
			if token not_in seen {
				idx := tfidf.vocab.word_to_index[token]
				tfidf.vocab.words[idx] = token
				tfidf.vocab.doc_frequency[idx] += 1
				seen[token] = true
			}
		}
	}
}

@(private = "package")
calculate_idf :: proc(tfidf: ^Tfidf) {
	tfidf.idf = make([]f32, len(tfidf.vocab.word_to_index))

	for i in 0 ..< len(tfidf.idf) {
		df := f32(tfidf.vocab.doc_frequency[i])
		total := f32(tfidf.vocab.total_docs)
		tfidf.idf[i] = math.ln((total + 1.0) / (df + 1.0))
	}
}

@(private = "package")
build_doc_vectors :: proc(tfidf: ^Tfidf, doc: ^Document) {
	doc.vec = make([]f32, len(tfidf.vocab.word_to_index))
	tf := make(map[int]int)
	defer delete(tf)

	for token in doc.tokens {
		idx := tfidf.vocab.word_to_index[token]
		tf[idx] += 1
	}

	doclen := f32(len(doc.tokens))
	for idx, ct in tf {
		doc.vec[idx] = (f32(ct) / doclen) * tfidf.idf[idx]
	}
	sum_sq: f32 = 0
	for val in doc.vec {
		sum_sq += val * val
	}
	normalized := math.sqrt(sum_sq)
	if normalized > 0 {
		for &val in doc.vec {
			val /= normalized
		}
	}
}

@(private = "package")
query_vectors :: proc(tfidf: ^Tfidf, tokens: Token_List) -> (vec: []f32) {

	vec = make([]f32, len(tfidf.vocab.word_to_index))
	tf := make(map[int]int)
	defer delete(tf)

	for token in tokens {
		if idx, ok := tfidf.vocab.word_to_index[token]; ok {
			tf[idx] += 1
		}
	}
	qlen := f32(len(tokens))
	for idx, ct in tf {
		vec[idx] = (f32(ct) / qlen) * tfidf.idf[idx]
	}
	sum_sq: f32 = 0
	for val in vec {
		sum_sq += val * val
	}
	normalized := math.sqrt(sum_sq)
	if normalized > 0 {
		for &val in vec {
			val /= normalized
		}
	}
	return
}

@(private = "package")
dot_product :: proc(a, b: []f32) -> (dot: f32) {
	for i in 0 ..< len(a) {
		dot += a[i] * b[i]
	}
	return
}

add_document :: proc {
	add_document_by_text,
	add_document_by_tokens,
}

add_document_by_text :: proc(
	tfidf: ^Tfidf,
	id: int,
	name: string,
	document_text: string,
	meta: rawptr = nil,
	tokenize: Tokenizer = DEFAULT_TOKENIZER,
) {
	document_tokens := tokenize(name, document_text)
	defer delete(document_tokens)
	add_document_by_tokens(tfidf, id, name, document_tokens, meta)
}

add_document_by_tokens :: proc(tfidf: ^Tfidf, id: int, name: string, document_tokens: Token_List, meta: rawptr = nil) {
	id := len(tfidf.docs)
	doc := Document {
		id     = id,
		name   = strings.clone(name),
		tokens = slice.clone(document_tokens[:]),
		meta   = meta,
	}
	append(&tfidf.docs, doc)
}

build_index :: proc(tfidf: ^Tfidf) {
	build_vocabulary(tfidf)
	calculate_idf(tfidf)
	for &doc in tfidf.docs {
		build_doc_vectors(tfidf, &doc)
	}
}

Search_Result :: struct {
	score: f32,
	name:  string,
	id:    int,
	meta:  rawptr,
}

destroy_search_result :: proc(res: ^Search_Result) {
	delete(res.name)
}
destroy_search_results :: proc(res: ^[]Search_Result) {
	for &r in res { destroy_search_result(&r) }
	delete(res^)
}


search :: proc {
	search_text,
	search_tokens,
}

search_text :: proc(
	tfidf: ^Tfidf,
	query: string,
	result_count := 10,
	tokenize: Tokenizer = DEFAULT_TOKENIZER,
) -> (
	results: []Search_Result,
) {
	tokens := tokenize(query)
	defer destroy(tokens)
	return search_tokens(tfidf, tokens, result_count)
}

search_tokens :: proc(tfidf: ^Tfidf, query_tokens: Token_List, result_count := 10) -> (results: []Search_Result) {
	ndocs := len(tfidf.docs)
	vec := query_vectors(tfidf, query_tokens)
	defer delete(vec)
	scores := make([]Search_Result, ndocs)
	defer delete(scores)

	for doc, i in tfidf.docs {
		score := dot_product(vec, doc.vec)
		scores[i] = {
			score = score,
			name  = doc.name,
			id    = doc.id,
			meta  = doc.meta,
		}
	}

	nres := len(scores)
	ct := result_count > nres ? nres : result_count
	slice.sort_by(scores, proc(i, j: Search_Result) -> bool {
		return i.score > j.score
	})
	results = slice.clone(scores[:ct])
	for &res in results {
		res.name = strings.clone(res.name)
	}

	return
}

destroy :: proc {
	destroy_document,
	destroy_vocab,
	destroy_tfidf,
	destroy_search_results,
	tokenizer.destroy_tokens,
}
