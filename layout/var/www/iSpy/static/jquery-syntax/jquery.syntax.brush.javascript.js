// brush: "javascript" aliases: ["js", "actionscript"]

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.register('javascript', function(brush) {
	var keywords = ["function", "break", "case", "catch", "continue", "default", "delete", "do", "else", "for", "if", "in", "instanceof", "new", "return", "super", "switch", "throw", "true", "try", "typeof", "var", "while", "with", "prototype"];
	
	var operators = ["+", "*", "/", "-", "&", "|", "~", "!", "%", "<", "=", ">"];
	var values = ["this", "true", "false", "null"];
	
	brush.push(values, {klass: 'constant'});
	brush.push(keywords, {klass: 'keyword'});
	brush.push(operators, {klass: 'operator'});
	
	// Regular expressions
	brush.push(Syntax.lib.perlStyleRegularExpression);
	
	// Camel Case Types
	brush.push(Syntax.lib.camelCaseType);
	
	// Comments
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
	
	// Functions
	brush.push(Syntax.lib.cStyleFunction);
});

