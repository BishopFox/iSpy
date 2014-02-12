// brush: "go" aliases: []

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.register('go', function(brush) {
	var keywords = ["break", "default", "func", "interface", "select", "case", "defer", "go", "map", "struct", "chan", "else", "goto", "package", "switch", "const", "fallthrough", "if", "range", "type", "continue", "for", "import", "return", "var"];
	
	var types = [
		/u?int\d*/g,
		/float\d+/g,
		/complex\d+/g,
		"byte",
		"uintptr",
		"string",
	];
	
	var operators = ["+", "&", "+=", "&=", "&&", "==", "!=", "-", "|", "-=", "|=", "||", "<", "<=", "*", "^", "*=", "^=", "<-", ">", ">=", "/", "<<", "/=", "<<=", "++", "=", ":=", ",", ";", "%", ">>", "%=", ">>=", "--", "!", "...", ".", ":", "&^", "&^="];
	
	var values = ["true", "false", "iota", "nil"];
	
	var functions = ["append", "cap", "close", "complex", "copy", "imag", "len", "make", "new", "panic", "print", "println", "real", "recover"];
	
	brush.push(values, {klass: 'constant'});
	brush.push(types, {klass: 'type'});
	brush.push(keywords, {klass: 'keyword'});
	brush.push(operators, {klass: 'operator'});
	brush.push(functions, {klass: 'function'});
	
	brush.push(Syntax.lib.cStyleFunction);
	
	brush.push(Syntax.lib.camelCaseType);
	
	brush.push(Syntax.lib.cStyleComment);
	brush.push(Syntax.lib.cppStyleComment);
	brush.push(Syntax.lib.webLink);
	
	// Strings
	brush.push(Syntax.lib.singleQuotedString);
	brush.push(Syntax.lib.doubleQuotedString);
	brush.push(Syntax.lib.stringEscape);
	
	// Numbers
	brush.push(Syntax.lib.decimalNumber);
	brush.push(Syntax.lib.hexNumber);
});
