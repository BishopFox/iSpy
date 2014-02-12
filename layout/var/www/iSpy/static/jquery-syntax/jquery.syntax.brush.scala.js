// brush: "scala" aliases: []

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.brushes.dependency('scala', 'xml');

Syntax.register('scala', function(brush) {
	var keywords = ["abstract", "do", "finally", "import", "object", "return", "trait", "var", "case", "catch", "class", "else", "extends", "for", "forSome", "if", "lazy", "match", "new", "override", "package", "private", "sealed", "super", "try", "type", "while", "with", "yield", "def", "final", "implicit", "protected", "throw", "val"];
	brush.push(keywords, {klass: 'keyword'});
	
	var operators = ["_", ":", "=", "=>", "<-", "<:", "<%", ">:", "#", "@"];
	brush.push(operators, {klass: 'operator'});
	
	var constants = ["this", "null", "true", "false"];
	brush.push(constants, {klass: 'constant'});
	
	// Strings
	brush.push({
		pattern: /"""[\s\S]*?"""/g,
		klass: 'string'
	});
	
	brush.push(Syntax.lib.doubleQuotedString);
	
	// Functions
	brush.push({
		pattern: /(?:def\s+|\.)([a-z_][a-z0-9_]+)/gi, 
		matches: Syntax.extractMatches({klass: 'function'})
	});
	
	brush.push(Syntax.lib.camelCaseType);
	
	// Types
	brush.push(Syntax.lib.cStyleFunction);
	
	// Comments
	brush.push(Syntax.lib.cStyleComment);
	brush.push(Syntax.lib.cppStyleComment);
	
	brush.derives('xml');
});

