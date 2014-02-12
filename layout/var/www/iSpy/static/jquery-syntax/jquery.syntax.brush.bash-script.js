// brush: "bash-script" aliases: []

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.register('bash-script', function(brush) {
	var operators = ["&&", "|", ";", "{", "}"];
	brush.push(operators, {klass: 'operator'});
	
	brush.push({
		pattern: /(?:^|\||;|&&)\s*((?:"([^"]|\\")+"|'([^']|\\')+'|\\\n|.|[ \t])+?)(?=$|\||;|&&)/gmi,
		matches: Syntax.extractMatches({brush: 'bash-statement'})
	});
});

Syntax.register('bash-statement', function(brush) {
	var keywords = ["break", "case", "continue", "do", "done", "elif", "else", "eq", "fi", "for", "function", "ge", "gt", "if", "in", "le", "lt", "ne", "return", "then", "until", "while"];
	brush.push(keywords, {klass: 'keyword'});
	
	var operators = [">", "<", "=", "`", "--", "{", "}", "(", ")", "[", "]"];
	brush.push(operators, {klass: 'operator'});
	
	brush.push({
		pattern: /\(\((.*?)\)\)/gmi,
		klass: 'expression',
		allow: ['variable', 'string', 'operator', 'constant']
	});
	
	brush.push({
		pattern: /`([\s\S]+?)`/gmi,
		matches: Syntax.extractMatches({brush: 'bash-script', debug: true})
	});
	
	brush.push(Syntax.lib.perlStyleComment);
	
	// Probably need to write a real parser here rather than using regular expressions, it is too fragile
	// and misses lots of edge cases (e.g. nested brackets, delimiters).
	brush.push({
		pattern: /^\s*((?:\S+?=\$?(?:\[[^\]]+\]|\(\(.*?\)\)|"(?:[^"]|\\")+"|'(?:[^']|\\')+'|\S+)\s*)*)((?:(\\ |\S)+)?)/gmi,
		matches: Syntax.extractMatches(
			{klass: 'env', allow: ['variable', 'string', 'operator', 'constant', 'expression']},
			{klass: 'function', allow: ['variable', 'string']}
		)
	});
	
	brush.push({
		pattern: /(\S+?)=/gmi,
		matches: Syntax.extractMatches({klass: 'variable'}),
		only: ['env']
	});
	
	brush.push({
		pattern: /\$\w+/g,
		klass: 'variable'
	});
	
	brush.push({pattern: /\s\-+\w+/g, klass: 'option'})
	
	brush.push(Syntax.lib.singleQuotedString);
	brush.push(Syntax.lib.doubleQuotedString);
	
	brush.push(Syntax.lib.decimalNumber);
	brush.push(Syntax.lib.hexNumber);
	
	brush.push(Syntax.lib.webLink);
});
