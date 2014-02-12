// brush: "diff" aliases: ["patch"]

//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.register('diff', function(brush) {
	brush.push({pattern: /^\+\+\+.*$/gm, klass: 'add'});
	brush.push({pattern: /^\-\-\-.*$/gm, klass: 'del'});
	
	brush.push({pattern: /^@@.*@@/gm, klass: 'offset'});
	
	brush.push({pattern: /^\+[^\+]{1}.*$/gm, klass: 'insert'});
	brush.push({pattern: /^\-[^\-]{1}.*$/gm, klass: 'remove'});
	
	brush.postprocess = function (options, html, container) {
		$('.insert', html).closest('.source').addClass('insert-line');
		$('.remove', html).closest('.source').addClass('remove-line');
		$('.offset', html).closest('.source').addClass('offset-line');
		
		return html;
	};
});

