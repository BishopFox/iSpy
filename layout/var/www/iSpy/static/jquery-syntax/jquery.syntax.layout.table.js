//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.layouts.table = function(options, code, container) {
	var table = jQuery('<table class="syntax highlighted"></table>'), tr = null, td = null, a = null, line = 1;
	var tbody = document.createElement('tbody');
	var toolbar = jQuery('<div class="toolbar"></div>');
	
	var rawCode = container.clone();
	rawCode.addClass("raw syntax highlighted");
	
	// Source code
	code.children().each(function() {
		tr = document.createElement('tr');
		tr.className = "line ln" + line;
		
		if (line % 2) {
			tr.className += " alt";
		}
		
		td = document.createElement('td');
		td.className = "number";
		
		number = document.createElement('span');
		number.innerHTML = line;
		td.appendChild(number);
		tr.appendChild(td);
		
		td = document.createElement('td');
		td.className = "source";
		
		td.appendChild(this);
		tr.appendChild(td);
		
		tbody.appendChild(tr);
		line = line + 1;
	});
	
	table.append(tbody);
	
	a = jQuery('<a href="#">View Raw Code</a>');
	a.click(function (event) {
		event.preventDefault();
		
		if (jQuery(table).is(':visible')) {
			rawCode.height(jQuery(table).height());
			jQuery(table).replaceWith(rawCode);
		} else {
			jQuery(rawCode).replaceWith(table);
		}
	});
	
	toolbar.append(a);
	toolbar.append('<a href="http://www.oriontransfer.co.nz/software/jquery-syntax" target="oriontransfer">?</a>');
	
	return jQuery('<div class="syntax-container">').append(toolbar).append(table);
};
