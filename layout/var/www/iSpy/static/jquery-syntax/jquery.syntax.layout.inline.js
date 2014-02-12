//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.layouts.inline = function(options, code, container) {
	var inline = jQuery('<code class="syntax highlighted"></code>');
	inline.append(code.children());
	
	var container = jQuery('<span class="syntax-container">');
	container.append(inline);
	
	return container;
};
