//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

// This layout doesn't work correctly in IE6, but is fine in all other tested browsers.
Syntax.layouts.fixed = function(options, code, container) {
	var fixed = jQuery('<div class="fixed syntax highlighted">'), line = 1, space = /^\s*$/;
	var toolbar = jQuery('<div class="toolbar">');

	var rawCode = container.clone();
	rawCode.addClass("raw syntax highlighted");

	var codeTable = document.createElement('table');
	
	var codeTableBody = document.createElement('tbody');
	codeTable.appendChild(codeTableBody);
	
	var numbersColumn = jQuery('<div class="numbers-column">');
	var codeColumn = jQuery('<div class="code-column">');
	
	// Source code
	code.children().each(function() {
		var lineNumber = document.createElement('div');
		lineNumber.className = "line ln" + line
		lineNumber.innerHTML = line;
		numbersColumn.append(lineNumber);
		
		var lineCode = document.createElement('td');
		lineCode.className = "source "  + this.className;
		
		if (line % 2) {
			lineCode.className += " alt";
		}
		
		if (lineCode == 1) {
			lineNumber.className += " first"
		}
		
		// Thanks to Michael for suggesting the obvious :)
		lineCode.appendChild(this);
		
		var tr = document.createElement('tr');
		tr.appendChild(lineCode);
		codeTableBody.appendChild(tr);
		
		line = line + 1;
	});
	
	codeColumn.append(codeTable);
	
	fixed.append(numbersColumn);
	fixed.append(codeColumn);
	
	a = jQuery('<a href="#">View Raw Code</a>');
	a.click(function (event) {
		event.preventDefault();
		
		if (jQuery(fixed).is(':visible')) {
			rawCode.height(jQuery(fixed).height());
			jQuery(fixed).replaceWith(rawCode);
		} else {
			jQuery(rawCode).replaceWith(fixed);
		}
	});
	
	toolbar.append(a);
	toolbar.append('<a href="http://www.oriontransfer.co.nz/software/jquery-syntax" target="oriontransfer">?</a>');
	
	return jQuery('<div class="syntax-container">').append(toolbar).append(fixed);
};
