// brush: "ooc" aliases: []

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.register('ooc', function(brush) {
	var keywords = ["class", "interface", "implement", "abstract", "extends", "from", "const", "final", "static", "import", "use", "extern", "inline", "proto", "break", "continue", "fallthrough", "operator", "if", "else", "for", "while", "do", "switch", "case", "as", "in", "version", "return", "include", "cover", "func"];
	
	var types = ["Int", "Int8", "Int16", "Int32", "Int64", "Int80", "Int128", "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "UInt80", "UInt128", "Octet", "Short", "UShort", "Long", "ULong", "LLong", "ULLong", "Float", "Double", "LDouble", "Float32", "Float64", "Float128", "Char", "UChar", "WChar", "String", "Void", "Pointer", "Bool", "SizeT", "This"];
	
	var operators = ["+", "-", "*", "/", "+=", "-=", "*=", "/=", "=", ":=", "==", "!=", "!", "%", "?", ">", "<", ">=", "<=", "&&", "||", "&", "|", "^", ".", "~", "..", ">>", "<<", ">>>", "<<<", ">>=", "<<=", ">>>=", "<<<=", "%=", "^=", "@"];
	
	var values = ["this", "super", "true", "false", "null", /[A-Z][A-Z0-9_]+/g];
	
	brush.push(values, {klass: 'constant'});
	brush.push(types, {klass: 'type'});
	brush.push(keywords, {klass: 'keyword'});
	brush.push(operators, {klass: 'operator'});
	
	// Hex, Octal and Binary numbers :)
	brush.push({
		pattern: /0[xcb][0-9a-fA-F]+/g,
		klass: 'constant'
	});
	
	brush.push(Syntax.lib.decimalNumber);
	
	// ClassNames (CamelCase)
	brush.push(Syntax.lib.camelCaseType);
	brush.push(Syntax.lib.cStyleType);
	brush.push(Syntax.lib.cStyleFunction);
	
	brush.push(Syntax.lib.cStyleComment);
	brush.push(Syntax.lib.cppStyleComment);
	
	brush.push(Syntax.lib.webLink);
	
	// Strings
	brush.push(Syntax.lib.singleQuotedString);
	brush.push(Syntax.lib.doubleQuotedString);
	brush.push(Syntax.lib.stringEscape);
	
	brush.processes['function'] = Syntax.lib.webLinkProcess("http://docs.ooc-lang.org/search.html?q=");
});

