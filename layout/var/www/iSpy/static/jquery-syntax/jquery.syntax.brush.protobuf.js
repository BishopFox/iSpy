// brush: "protobuf" aliases: []

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.register('protobuf', function(brush) {
	var keywords = ["enum", "extend", "extensions", "group", "import", "max", "message", "option", "package", "returns", "rpc", "service", "syntax", "to", "default"];
	brush.push(keywords, {klass: 'keyword'})
	
	var values = ["true", "false"];
	brush.push(values, {klass: 'constant'});
	
	var types = ["bool", "bytes", "double", "fixed32", "fixed64", "float", "int32", "int64", "sfixed32", "sfixed64", "sint32", "sint64", "string", "uint32", "uint64"];
	brush.push(types, {klass: 'type'});
	
	var access = ["optional", "required", "repeated"]
	brush.push(access, {klass: 'access'});
		
	brush.push(Syntax.lib.camelCaseType);
	
	// Highlight names of fields
	brush.push({
		pattern: /\s+(\w+)\s*=\s*\d+/g,
		matches: Syntax.extractMatches({
			klass: 'variable'
		})
	});
	
	// Comments
	brush.push(Syntax.lib.cStyleComment);
	brush.push(Syntax.lib.webLink);
	
	// Strings
	brush.push(Syntax.lib.singleQuotedString);
	brush.push(Syntax.lib.doubleQuotedString);
	brush.push(Syntax.lib.stringEscape);
	
	// Numbers
	brush.push(Syntax.lib.decimalNumber);
	brush.push(Syntax.lib.hexNumber);
});

