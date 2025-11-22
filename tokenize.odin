package tfidf

tokenizer :: proc(name, document: string) -> []string {
	tokenize :: proc(toks: ^[dynamic]string, text: string) {
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
				if len(substr) > 2 {
					append(toks, strings.clone(substr))
				}
				from = i
			}
		}
	}
	tokens := make([dynamic]string)
	defer delete(tokens)
	tokenize(&tokens, name)
	tokenize(&tokens, document)
	return slice.clone(tokens[:])
}
