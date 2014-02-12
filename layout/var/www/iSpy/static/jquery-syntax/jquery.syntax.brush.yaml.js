// brush: "yaml" aliases: []

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.register('yaml', function(brush) {
	brush.push({
		pattern: /^\s*#.*$/gm,
		klass: 'comment',
		allow: ['href']
	});
	
	brush.push(Syntax.lib.singleQuotedString);
	brush.push(Syntax.lib.doubleQuotedString);
	
	brush.push({
		pattern: /(&|\*)[a-z0-9]+/gi,
		klass: 'constant'
	});
	
	brush.push({
		pattern: /(.*?):/gi,
		matches: Syntax.extractMatches({klass: 'keyword'})
	});
	
	brush.push(Syntax.lib.webLink);
});

