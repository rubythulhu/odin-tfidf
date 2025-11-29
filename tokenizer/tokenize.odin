package tfidf_tokenizer

import "../stemmer"
import "core:mem"
import "core:slice"
import "core:strings"

Token_List :: []string

Tokenizer :: #type proc(texts: ..string) -> (results: Token_List)

// used by tokenize_helper
Finalizer :: #type proc(_: string) -> string
ID_FINALIZER :: proc(word: string) -> string { return word }
DEFAULT_TOKENIZER: Tokenizer : tokenize_stemmed

// basic tokenizer, does no stemming
tokenize :: proc(texts: ..string) -> Token_List {
	tokens := make([dynamic]string)
	defer delete(tokens)

	for text in texts {
		tokenize_helper(&tokens, text)
	}
	return slice.clone(tokens[:])
}

// tokenizer with porter2 stemmer
tokenize_stemmed :: proc(texts: ..string) -> Token_List {
	arena_mem := make([]u8, 256)
	defer delete(arena_mem)
	arena: mem.Arena
	mem.arena_init(&arena, arena_mem)
	defer mem.arena_free_all(&arena)

	return tokenize_stemmed_shared_arena(&arena, ..texts)
}

// use this to share the stemmer's arena between multiple documents,
// by passing a custom tokenizer to add_document_by_tokens()
tokenize_stemmed_shared_arena :: proc(arena: ^mem.Arena, texts: ..string) -> Token_List {
	tokens := make([dynamic]string)
	defer delete(tokens)

	context.user_ptr = arena
	for text in texts {
		tokenize_helper(&tokens, text, proc(word: string) -> string {
			arena := (^mem.Arena)(context.user_ptr)
			stemmed := stemmer.porter2_stem_shared_arena(word, arena)
			mem.arena_free_all(arena)
			return stemmed
		})
	}
	return slice.clone(tokens[:])
}

destroy_tokens :: proc(tokens: Token_List) {
	for tok in tokens { delete(tok) }
	delete(tokens)
}


// helper used by tokenizers, does basic tokenizing, but allows
// you to pass a custom proc to modify the tokenized words. you
// might use this to create a non-english stemmed tokenizer
tokenize_helper :: proc(toks: ^[dynamic]string, text: string, finalize: Finalizer = ID_FINALIZER) {
	tokens := make([dynamic]string)
	lc_text := strings.to_lower(text)
	defer delete(lc_text)
	if len(text) == 0 {
		return
	}
	from := -1
	max := len(lc_text) - 1
	for ch, i in lc_text {
		is_sep := strings.is_separator(ch)
		is_max := i == max
		to := i
		if is_max && !is_sep {
			to = i + 1
		}
		substr := lc_text[from + 1:to]

		if is_max || is_sep {
			token := strings.clone(finalize(substr))
			append(toks, token)
			from = i
		}
	}
}
