package tfidf

import "core:strings"
import "core:slice"

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
			  stemmed := stem(substr)
				append(toks, stemmed)
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

// Porter2 English Stemmer
// Based on https://snowballstem.org/algorithms/english/stemmer.html

stem :: proc(word: string) -> string {
	if len(word) <= 2 {
		return strings.clone(word)
	}

	// Check exceptions first
	switch word {
	case "skis": return strings.clone("ski")
	case "skies": return strings.clone("sky")
	case "dying": return strings.clone("die")
	case "lying": return strings.clone("lie")
	case "tying": return strings.clone("tie")
	case "idly": return strings.clone("idl")
	case "gently": return strings.clone("gentl")
	case "ugly": return strings.clone("ugli")
	case "early": return strings.clone("earli")
	case "only": return strings.clone("onli")
	case "singly": return strings.clone("singl")
	case "sky", "news", "howe", "atlas", "cosmos", "bias", "andes":
		return strings.clone(word)
	}

	// Work with a mutable copy
	w := strings.clone(word)

	// Mark y's as Y if they're consonants
	w = mark_ys(w)

	// Step 0: Remove apostrophes
	w = step0(w)

	// Step 1a
	w = step1a(w)

	// Check post-1a exceptions
	switch w {
	case "inning", "outing", "canning", "herring", "earring", "proceed", "exceed", "succeed":
		return w
	}

	// Step 1b
	w = step1b(w)

	// Step 1c
	w = step1c(w)

	// Step 2
	w = step2(w)

	// Step 3
	w = step3(w)

	// Step 4
	w = step4(w)

	// Step 5
	w = step5(w)

	// Lowercase all Y's
	w = strings.to_lower(w)

	return w
}

is_vowel :: proc(ch: u8) -> bool {
	return ch == 'a' || ch == 'e' || ch == 'i' || ch == 'o' || ch == 'u' || ch == 'y' || ch == 'Y'
}

is_consonant :: proc(ch: u8) -> bool {
	return !is_vowel(ch)
}

contains_vowel :: proc(s: string) -> bool {
	for ch in s {
		if is_vowel(u8(ch)) {
			return true
		}
	}
	return false
}

mark_ys :: proc(word: string) -> string {
	if len(word) == 0 {
		return word
	}
	w := strings.clone(word)
	bytes := transmute([]u8)w

	// First character
	if bytes[0] == 'y' {
		bytes[0] = 'Y'
	}

	// Mark y as Y if it comes after a vowel
	for i in 1..<len(bytes) {
		if bytes[i] == 'y' && is_vowel(bytes[i-1]) {
			bytes[i] = 'Y'
		}
	}

	return w
}

get_r1 :: proc(word: string) -> int {
	// Special cases
	if strings.has_prefix(word, "gener") ||
	   strings.has_prefix(word, "commun") ||
	   strings.has_prefix(word, "arsen") {
		return 5
	}

	// Find first non-vowel after first vowel
	found_vowel := false
	for ch, i in word {
		if is_vowel(u8(ch)) {
			found_vowel = true
		} else if found_vowel {
			return i + 1
		}
	}
	return len(word)
}

get_r2 :: proc(word: string) -> int {
	r1 := get_r1(word)
	if r1 >= len(word) {
		return len(word)
	}

	found_vowel := false
	for i in r1..<len(word) {
		if is_vowel(word[i]) {
			found_vowel = true
		} else if found_vowel {
			return i + 1
		}
	}
	return len(word)
}

is_short_syllable :: proc(word: string, pos: int) -> bool {
	// At beginning: vowel followed by non-vowel
	if pos == 1 && len(word) >= 2 {
		return is_vowel(word[0]) && is_consonant(word[1])
	}

	// In middle: non-vowel, vowel, non-vowel (not w, x, Y)
	if pos >= 2 && pos < len(word) {
		return is_consonant(word[pos-2]) &&
		       is_vowel(word[pos-1]) &&
		       is_consonant(word[pos]) &&
		       word[pos] != 'w' && word[pos] != 'x' && word[pos] != 'Y'
	}

	return false
}

is_short_word :: proc(word: string) -> bool {
	r1 := get_r1(word)
	if r1 != len(word) {
		return false
	}
	return is_short_syllable(word, len(word) - 1)
}

ends_with_double :: proc(word: string) -> bool {
	if len(word) < 2 {
		return false
	}
	last := word[len(word)-1]
	prev := word[len(word)-2]
	if last != prev {
		return false
	}
	return last == 'b' || last == 'd' || last == 'f' || last == 'g' ||
	       last == 'm' || last == 'n' || last == 'p' || last == 'r' || last == 't'
}

replace_suffix :: proc(word: string, suffix: string, replacement: string, min_r: int) -> (string, bool) {
	if !strings.has_suffix(word, suffix) {
		return word, false
	}
	if len(word) - len(suffix) < min_r {
		return word, false
	}
	stem := word[:len(word) - len(suffix)]
	result := strings.concatenate({stem, replacement})
	delete(word)
	return result, true
}

step0 :: proc(word: string) -> string {
	w := word
	if strings.has_suffix(w, "'s'") {
		return w[:len(w)-3]
	}
	if strings.has_suffix(w, "'s") {
		return w[:len(w)-2]
	}
	if strings.has_suffix(w, "'") {
		return w[:len(w)-1]
	}
	return w
}

step1a :: proc(word: string) -> string {
	w := word

	// sses -> ss
	if strings.has_suffix(w, "sses") {
		return w[:len(w)-2]
	}

	// ied, ies -> i or ie
	if strings.has_suffix(w, "ied") || strings.has_suffix(w, "ies") {
		stem := w[:len(w)-3]
		if len(stem) > 1 {
			return strings.concatenate({stem, "i"})
		} else {
			return strings.concatenate({stem, "ie"})
		}
	}

	// us, ss -> unchanged
	if strings.has_suffix(w, "us") || strings.has_suffix(w, "ss") {
		return w
	}

	// s -> delete if vowel before
	if strings.has_suffix(w, "s") {
		stem := w[:len(w)-1]
		if contains_vowel(stem) {
			return stem
		}
	}

	return w
}

step1b :: proc(word: string) -> string {
	w := word
	r1 := get_r1(w)

	// eed, eedly -> ee (if in R1)
	if strings.has_suffix(w, "eedly") {
		if len(w) - 5 >= r1 {
			return w[:len(w)-3]
		}
		return w
	}
	if strings.has_suffix(w, "eed") {
		if len(w) - 3 >= r1 {
			return w[:len(w)-1]
		}
		return w
	}

	// ed, edly, ing, ingly -> delete (if stem contains vowel)
	endings := []string{"ingly", "edly", "ing", "ed"}
	for ending in endings {
		if strings.has_suffix(w, ending) {
			stem := w[:len(w) - len(ending)]
			if contains_vowel(stem) {
				// Apply further modifications
				delete(w)

				if strings.has_suffix(stem, "at") ||
				   strings.has_suffix(stem, "bl") ||
				   strings.has_suffix(stem, "iz") {
					return strings.concatenate({stem, "e"})
				}

				if ends_with_double(stem) {
					return stem[:len(stem)-1]
				}

				if is_short_word(stem) {
					return strings.concatenate({stem, "e"})
				}

				return stem
			}
			return w
		}
	}

	return w
}

step1c :: proc(word: string) -> string {
	w := word

	if len(w) <= 2 {
		return w
	}

	if (w[len(w)-1] == 'y' || w[len(w)-1] == 'Y') && is_consonant(w[len(w)-2]) {
		bytes := transmute([]u8)w
		bytes[len(bytes)-1] = 'i'
		return w
	}

	return w
}

step2 :: proc(word: string) -> string {
	w := word
	r1 := get_r1(w)

	replacements := []struct{suffix: string, replacement: string, special: bool} {
		{"ational", "ate", false},
		{"tional", "tion", false},
		{"enci", "ence", false},
		{"anci", "ance", false},
		{"abli", "able", false},
		{"entli", "ent", false},
		{"izer", "ize", false},
		{"ization", "ize", false},
		{"ation", "ate", false},
		{"ator", "ate", false},
		{"alism", "al", false},
		{"aliti", "al", false},
		{"alli", "al", false},
		{"fulness", "ful", false},
		{"ousli", "ous", false},
		{"ousness", "ous", false},
		{"iveness", "ive", false},
		{"iviti", "ive", false},
		{"biliti", "ble", false},
		{"bli", "ble", false},
		{"fulli", "ful", false},
		{"lessli", "less", false},
		{"ogi", "og", true}, // Special: needs 'l' before
		{"li", "", true},    // Special: needs valid li-ending
	}

	for rep in replacements {
		if strings.has_suffix(w, rep.suffix) {
			stem := w[:len(w) - len(rep.suffix)]

			// Check R1
			if len(stem) < r1 {
				continue
			}

			// Special cases
			if rep.suffix == "ogi" {
				if len(stem) > 0 && stem[len(stem)-1] == 'l' {
					delete(w)
					return strings.concatenate({stem, rep.replacement})
				}
				continue
			}

			if rep.suffix == "li" {
				if len(stem) > 0 {
					last := stem[len(stem)-1]
					valid_li := last == 'c' || last == 'd' || last == 'e' || last == 'g' ||
					            last == 'h' || last == 'k' || last == 'm' || last == 'n' ||
					            last == 'r' || last == 't'
					if valid_li {
						delete(w)
						return stem
					}
				}
				continue
			}

			delete(w)
			return strings.concatenate({stem, rep.replacement})
		}
	}

	return w
}

step3 :: proc(word: string) -> string {
	w := word
	r1 := get_r1(w)
	r2 := get_r2(w)

	replacements := []struct{suffix: string, replacement: string, r2_only: bool} {
		{"ational", "ate", false},
		{"tional", "tion", false},
		{"alize", "al", false},
		{"icate", "ic", false},
		{"iciti", "ic", false},
		{"ical", "ic", false},
		{"ful", "", false},
		{"ness", "", false},
		{"ative", "", true},
	}

	for rep in replacements {
		if strings.has_suffix(w, rep.suffix) {
			stem := w[:len(w) - len(rep.suffix)]

			min_r := r1
			if rep.r2_only {
				min_r = r2
			}

			if len(stem) >= min_r {
				delete(w)
				return strings.concatenate({stem, rep.replacement})
			}
		}
	}

	return w
}

step4 :: proc(word: string) -> string {
	w := word
	r2 := get_r2(w)

	suffixes := []string{
		"al", "ance", "ence", "er", "ic", "able", "ible", "ant",
		"ement", "ment", "ent", "ism", "ate", "iti", "ous", "ive", "ize",
	}

	for suffix in suffixes {
		if strings.has_suffix(w, suffix) {
			stem := w[:len(w) - len(suffix)]
			if len(stem) >= r2 {
				delete(w)
				return stem
			}
			return w
		}
	}

	// Special case for "ion"
	if strings.has_suffix(w, "ion") {
		stem := w[:len(w)-3]
		if len(stem) >= r2 && len(stem) > 0 {
			last := stem[len(stem)-1]
			if last == 's' || last == 't' {
				delete(w)
				return stem
			}
		}
	}

	return w
}

step5 :: proc(word: string) -> string {
	w := word
	r1 := get_r1(w)
	r2 := get_r2(w)

	// Delete 'e'
	if strings.has_suffix(w, "e") {
		stem := w[:len(w)-1]
		if len(stem) >= r2 {
			delete(w)
			return stem
		}
		if len(stem) >= r1 && !is_short_syllable(stem, len(stem)) {
			delete(w)
			return stem
		}
	}

	// Delete 'l' if in R2 and preceded by 'l'
	if strings.has_suffix(w, "ll") {
		stem := w[:len(w)-1]
		if len(stem) >= r2 {
			delete(w)
			return stem
		}
	}

	return w
}
