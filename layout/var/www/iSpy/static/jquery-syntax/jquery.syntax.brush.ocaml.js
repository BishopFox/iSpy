// brush: "ocaml" aliases: ["ml", "sml", "fsharp"]

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

// This brush is based loosely on the following documentation:
// http://msdn.microsoft.com/en-us/library/dd233230.aspx

Syntax.register('ocaml', function(brush) {
	var keywords = ["abstract", "and", "as", "assert", "begin", "class", "default", "delegate", "do", "done", "downcast", "downto", "elif", "else", "end", "exception", "extern", "finally", "for", "fun", "function", "if", "in", "inherit", "inline", "interface", "internal", "lazy", "let", "match", "member", "module", "mutable", "namespace", "new", "null", "of", "open", "or", "override", "rec", "return", "static", "struct", "then", "to", "try", "type", "upcast", "use", "val", "when", "while", "with", "yield", "asr", "land", "lor", "lsl", "lsr", "lxor", "mod", "sig", "atomic", "break", "checked", "component", "const", "constraint", "constructor", "continue", "eager", "event", "external", "fixed", "functor", "global", "include", "method", "mixin", "object", "parallel", "process", "protected", "pure", "sealed", "trait", "virtual", "volatile", "val"];
	
	var types = ["bool", "byte", "sbyte", /\bu?int\d*\b/g, "nativeint", "unativeint", "char", "string", "decimal", "unit", "void", "float32", "single", "float64", "double", "list", "array", "exn", "format", "fun", "option", "ref"];
	
	var operators = ["!", "<>", "%", "&", "*", "+", "-", "->", "/", "::", ":=", ":>", ":?", ":?>", "<", "=", ">", "?", "@", "^", "_", "`", "|", "~", "'", "[<", ">]", "<|", "|>", "[|", "|]", "(|", "|)", "(*", "*)", "in"];
	
	var values = ["true", "false"];
	
	var access = ["private", "public"];
	
	brush.push(access, {klass: 'access'});
	brush.push(values, {klass: 'constant'});
	brush.push(types, {klass: 'type'});
	brush.push(keywords, {klass: 'keyword'});
	brush.push(operators, {klass: 'operator'});
	
	// http://caml.inria.fr/pub/docs/manual-ocaml/manual011.html#module-path
	// open [module-path], new [type]
	brush.push({
		pattern: /(?:open|new)\s+((?:\.?[a-z][a-z0-9]*)+)/gi,
		matches: Syntax.extractMatches({klass: 'type'})
	});
	
	// Functions
	brush.push({
		pattern: /(?:\.)([a-z_][a-z0-9_]+)/gi,
		matches: Syntax.extractMatches({klass: 'function'})
	});
	
	// Avoid highlighting keyword arguments as camel-case types.
	brush.push({
		pattern: /(?:\(|,)\s*(\w+\s*=)/g,
		matches: Syntax.extractMatches({
			klass: 'keyword-argument'
		})
	});
	
	// We need to modify cStyleFunction because "(*" is a comment token.
	brush.push({
		pattern: /([a-z_][a-z0-9_]*)\s*\((?!\*)/gi,
		matches: Syntax.extractMatches({klass: 'function'})
	});
	
	// Types
	brush.push(Syntax.lib.camelCaseType);
	
	// Web Links
	brush.push(Syntax.lib.webLink);
	
	// Comments
	brush.push({
		pattern: /\(\*[\s\S]*?\*\)/g,
		klass: 'comment'
	});
	
	// Strings
	brush.push(Syntax.lib.doubleQuotedString);
	brush.push(Syntax.lib.stringEscape);
	
	// Numbers
	brush.push(Syntax.lib.decimalNumber);
	brush.push(Syntax.lib.hexNumber);
});
