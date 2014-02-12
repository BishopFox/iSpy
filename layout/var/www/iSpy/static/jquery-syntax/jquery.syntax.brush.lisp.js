// brush: "lisp" aliases: ['scheme', 'clojure']

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.lib.lispStyleComment = {pattern: /(;+) .*$/gm, klass: 'comment', allow: ['href']};

// This syntax is intentionally very sparse. This is because it is a general syntax for Lisp like languages.
// It might be a good idea to make specific dialects (e.g. common lisp, scheme, clojure, etc)
Syntax.register('lisp', function(brush) {
	brush.push(['(', ')'], {klass: 'operator'});
	
	brush.push(Syntax.lib.lispStyleComment);
	
	brush.push(Syntax.lib.hexNumber);
	brush.push(Syntax.lib.decimalNumber);
	brush.push(Syntax.lib.webLink);
	
	brush.push({
		pattern: /\(\s*([^\s\(\)]+)/gmi,
		matches: Syntax.extractMatches({klass: 'function'})
	});
	
	brush.push({
		pattern: /#[a-z]+/gi,
		klass: 'constant'
	})
	
	// Strings
	brush.push(Syntax.lib.multiLineDoubleQuotedString);
	brush.push(Syntax.lib.stringEscape);
});

