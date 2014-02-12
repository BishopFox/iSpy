// brush: "assembly" aliases: ["asm"]

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.register('assembly', function(brush) {
	brush.push(Syntax.lib.cStyleComment);
	brush.push(Syntax.lib.cppStyleComment);
	
	brush.push({pattern: /\.[a-zA-Z_][a-zA-Z0-9_]*/gm, klass: 'directive'});
	
	brush.push({pattern: /^[a-zA-Z_][a-zA-Z0-9_]*:/gm, klass: 'label'});
	
	brush.push({
		pattern: /^\s*([a-zA-Z]+)/gm,
		matches: Syntax.extractMatches({klass: 'function'})
	});
	
	brush.push({pattern: /(-[0-9]+)|(\b[0-9]+)|(\$[0-9]+)/g, klass: 'constant'});
	brush.push({pattern: /(\-|\b|\$)(0x[0-9a-f]+|[0-9]+|[a-z0-9_]+)/gi, klass: 'constant'});
	
	brush.push({pattern: /%\w+/g, klass: 'register'});
	
	// Strings
	brush.push(Syntax.lib.singleQuotedString);
	brush.push(Syntax.lib.doubleQuotedString);
	brush.push(Syntax.lib.stringEscape);
	
	// Numbers
	brush.push(Syntax.lib.decimalNumber);
	brush.push(Syntax.lib.hexNumber);
	
	// Comments
	brush.push(Syntax.lib.perlStyleComment);
	brush.push(Syntax.lib.webLink);
});
