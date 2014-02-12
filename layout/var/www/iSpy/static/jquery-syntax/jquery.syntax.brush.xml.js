// brush: "xml" aliases: []

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.lib.xmlEntity = {pattern: /&\w+;/g, klass: 'entity'};
Syntax.lib.xmlPercentEscape = {pattern: /(%[0-9a-f]{2})/gi, klass: 'percent-escape', only: ['string']};

Syntax.register('xml-tag', function(brush) {
	brush.push({
		pattern: /<\/?((?:[^:\s>]+:)?)([^\s>]+)(\s[^>]*)?\/?>/g,
		matches: Syntax.extractMatches({klass: 'namespace'}, {klass: 'tag-name'})
	});
	
	brush.push({
		pattern: /([^=\s]+)=(".*?"|'.*?'|[^\s>]+)/g,
		matches: Syntax.extractMatches({klass: 'attribute', only: ['tag']}, {klass: 'string', only: ['tag']})
	});
	
	brush.push(Syntax.lib.xmlEntity);
	brush.push(Syntax.lib.xmlPercentEscape);
	
	brush.push(Syntax.lib.singleQuotedString);
	brush.push(Syntax.lib.doubleQuotedString);
});

Syntax.register('xml', function(brush) {
	brush.push({
		pattern: /(<!(\[CDATA\[)([\s\S]*?)(\]\])>)/gm,
		matches: Syntax.extractMatches(
			{klass: 'cdata', allow: ['cdata-content', 'cdata-tag']},
			{klass: 'cdata-tag'},
			{klass: 'cdata-content'},
			{klass: 'cdata-tag'}
		)
	});
	
	brush.push(Syntax.lib.xmlComment);
	
	brush.push({
		pattern: /<[^>\-\s]([^>'"!\/;\?@\[\]^`\{\}\|]|"[^"]*"|'[^']')*[\/?]?>/g,
		brush: 'xml-tag'
	});
	
	brush.push(Syntax.lib.xmlEntity);
	brush.push(Syntax.lib.xmlPercentEscape);
	
	brush.push(Syntax.lib.webLink);
});
