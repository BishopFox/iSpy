// brush: "super-collider" aliases: ["sc"]

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.register('super-collider', function(brush) {
	var keywords = ["const", "arg", "classvar", "var"];
	brush.push(keywords, {klass: 'keyword'});
	
	var operators = ["`", "+", "@", ":", "*", "/", "-", "&", "|", "~", "!", "%", "<", "=", ">"];
	brush.push(operators, {klass: 'operator'});
	
	var values = ["thisFunctionDef", "thisFunction", "thisMethod", "thisProcess", "thisThread", "this", "super", "true", "false", "nil", "inf"];
	brush.push(values, {klass: 'constant'});
	
	brush.push(Syntax.lib.camelCaseType);
	
	// Single Characters
	brush.push({
		pattern: /\$(\\)?./g,
		klass: "constant"
	});
	
	// Symbols
	brush.push({
		pattern: /\\[a-z_][a-z0-9_]*/gi,
		klass: "symbol"
	});
	
	brush.push({
		pattern: /'[^']+'/g,
		klass: "symbol"
	});
	
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
	brush.push({
		pattern: /(?:\.)([a-z_][a-z0-9_]*)/gi, 
		matches: Syntax.extractMatches({klass: 'function'})
	});
	
	brush.push(Syntax.lib.cStyleFunction);
});
