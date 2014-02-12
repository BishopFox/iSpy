// brush: "ruby" aliases: []

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.lib.rubyStyleFunction = {pattern: /(?:def\s+|\.)([a-z_][a-z0-9_]+)/gi, matches: Syntax.extractMatches({klass: 'function'})};

// We need to emulate negative lookbehind
Syntax.lib.rubyStyleSymbol = {pattern: /([:]?):\w+/g, klass: 'constant', matches: function (match, expr) {
	if (match[1] != '') return [];
	
	return [new Syntax.Match(match.index, match[0].length, expr, match[0])];
}};

Syntax.register('ruby', function(brush) {
	var keywords = ["alias", "and", "begin", "break", "case", "class", "def", "define_method", "defined?", "do", "else", "elsif", "end", "ensure", "false", "for", "if", "in", "module", "next", "not", "or", "raise", "redo", "rescue", "retry", "return", "then", "throw", "undef", "unless", "until", "when", "while", "yield", "block_given?"];
	
	var operators = ["+", "*", "/", "-", "&", "|", "~", "!", "%", "<", "=", ">"];
	var values = ["self", "super", "true", "false", "nil"];
	
	var access = ["private", "protected", "public"];
	
	brush.push(access, {klass: 'access'});
	brush.push(values, {klass: 'constant'});

	// Percent operator statements
	brush.push({
		pattern: /(\%[\S])(\{[\s\S]*?\})/g,
		matches: Syntax.extractMatches({klass: 'function'}, {klass: 'constant'})
	});
	
	brush.push({
		pattern: /`[^`]+`/g,
		klass: 'string'
	});
	
	brush.push({
		pattern: /\#\{([^\}]*)\}/g,
		matches: Syntax.extractMatches({
			brush: 'ruby',
			only: ['string']
		}),
	});
	
	// Regular expressions
	brush.push(Syntax.lib.perlStyleRegularExpression);
	
	brush.push({pattern: /(@+|\$)[\w]+/g, klass: 'variable'});
	
	brush.push(Syntax.lib.camelCaseType);
	brush.push(keywords, {klass: 'keyword'});
	brush.push(operators, {klass: 'operator'});
	
	brush.push(Syntax.lib.rubyStyleSymbol);
	
	// Comments
	brush.push(Syntax.lib.perlStyleComment);
	brush.push(Syntax.lib.webLink);
	
	// Strings
	brush.push(Syntax.lib.singleQuotedString);
	brush.push(Syntax.lib.doubleQuotedString);
	brush.push(Syntax.lib.stringEscape);
	
	// Numbers
	brush.push(Syntax.lib.decimalNumber);
	brush.push(Syntax.lib.hexNumber);
	
	// Functions
	brush.push(Syntax.lib.rubyStyleFunction);
	brush.push(Syntax.lib.cStyleFunction);
	
	// brush.processes['function'] = Syntax.lib.webLinkProcess("ruby", true);
	// brush.processes['type'] = Syntax.lib.webLinkProcess("ruby", true);
});

