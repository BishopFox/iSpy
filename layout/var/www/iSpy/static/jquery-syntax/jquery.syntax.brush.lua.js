// brush: "lua" aliases: []

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.register('lua', function(brush) {
	var keywords = ["and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"];
	
	var operators = ["+", "-", "*", "/", "%", "^", "#", "..", "=", "==", "~=", "<", ">", "<=", ">=", "?", ":"];
	
	var values = ["self", "true", "false", "nil"];
	
	brush.push(values, {klass: 'constant'});
	brush.push(keywords, {klass: 'keyword'});
	brush.push(operators, {klass: 'operator'});
	
	// Camelcase Types
	brush.push(Syntax.lib.camelCaseType);
	brush.push(Syntax.lib.cStyleFunction);
	
	brush.push({
		pattern: /\-\-.*$/gm,
		klass: 'comment',
		allow: ['href']
	});
	
	brush.push({
		pattern: /\-\-\[\[(\n|.)*?\]\]\-\-/gm,
		klass: 'comment',
		allow: ['href']
	});
	
	// Strings
	brush.push(Syntax.lib.singleQuotedString);
	brush.push(Syntax.lib.doubleQuotedString);
	brush.push(Syntax.lib.stringEscape);

	brush.push(Syntax.lib.hexNumber);
	brush.push(Syntax.lib.decimalNumber);

	brush.push(Syntax.lib.webLink);
});

