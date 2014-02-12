// brush: "kai" aliases: []

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.register('kai', function(brush) {
	brush.push(['(', ')', '[', ']', '{', '}'], {klass: 'operator'});
	
	brush.push(Syntax.lib.perlStyleComment);
	
	brush.push(Syntax.lib.decimalNumber);
	brush.push(Syntax.lib.webLink);
	
	brush.push({
		pattern: /\(([^\s\(\)]+)/gi,
		matches: Syntax.extractMatches({klass: 'function'})
	});
	
	brush.push({
		pattern: /`[a-z]*/gi,
		klass: 'constant'
	})
	
	// Strings
	brush.push(Syntax.lib.multiLineDoubleQuotedString);
	brush.push(Syntax.lib.stringEscape);
});

