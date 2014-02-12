// brush: "io" aliases: []

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.register('io', function(brush) {
	brush.push(Syntax.lib.cStyleFunction);
	
	var keywords = ["return"];
	
	var operators = ["::=", ":=", "or", "and", "@", "+", "*", "/", "-", "&", "|", "~", "!", "%", "<", "=", ">", "[", "]", "new", "delete"];
	
	brush.push(keywords, {klass: 'keywords'});
	brush.push(operators, {klass: 'operator'});
	
	// Extract space delimited method invocations
	brush.push({
		pattern: /\b([ \t]+([a-z]+))/gi,
		matches: Syntax.extractMatches({index: 2, klass: 'function'})
	});
	
	brush.push({
		pattern: /\)([ \t]+([a-z]+))/gi,
		matches: Syntax.extractMatches({index: 2, klass: 'function'})
	});
	
	// Objective-C classes
	brush.push(Syntax.lib.camelCaseType);
	
	brush.push(Syntax.lib.perlStyleComment);
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

