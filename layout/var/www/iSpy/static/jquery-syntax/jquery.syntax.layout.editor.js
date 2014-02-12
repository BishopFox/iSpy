//	This file is part of the "jQuery.Syntax" project, and is distributed under the MIT License.
//	Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
//	See <jquery.syntax.js> for licensing details.

Syntax.Editor = function(container, text) {
	this.container = container;
	this.current = this.getLines();
}

// This function generates an array of accumulated line offsets e.g.
// If line 8 is actually in child element 6, indices[8] = -2
Syntax.Editor.prototype.getLines = function() {
	var children = this.container.childNodes, lines = [], offsets = [];
	
	// Sometimes, e.g. when deleting text, children elements are not complete lines.
	// We need to accumulate incomplete lines (1), and then append them to the 
	// start of the next complete line (2)
	var text = "", startChild = 0;
	for (var i = 0; i < children.length; i += 1) {
		var childLines = Syntax.innerText([children[i]]).split('\n');
		
		if (childLines.length > 1) {
			childLines[0] = text + childLines[0]; // (2)
			text = childLines.pop();
		} else {
			text += childLines[0]; // (1)
			continue;
		}
		
		for (var j = 0; j < childLines.length; j += 1) {
			offsets.push(startChild - lines.length);
			lines.push(childLines[j]);
		}
		
		startChild = i + 1;
	}
	
	// Final line, any remaining text
	if (text != "") {
		offsets.push(startChild - lines.length);
		lines.push(text);
	} else {
		startChild -= 1;
	}
	
	offsets.push(startChild);
	
	Syntax.log("getLines", offsets, lines, children);
	
	return {lines: lines, offsets: offsets};
}

// This function updates the editor's internal state with regards to lines changed.
// This can be lines added, removed or modified partially. This function returns
// a list of lines which are different between the previous set of lines and the
// updated set of lines.
// This algorithm is not a general diff algorithm because we expect three cases only:
//		1: A single line was modified (most common case)
//		2: Some lines were removed (selection -> delete)
//		3: Some lines were added (paste)
Syntax.Editor.prototype.updateChangedLines = function() {
	var result = {};
	
	var updated = this.getLines();
	
	// Find the sequence of lines at the start preceeding the change:
	var i = 0, j = 0;
	while (i < this.current.lines.length && j < updated.lines.length) {
		if (this.current.lines[i] == updated.lines[j]) {
			i += 1;
			j += 1;
		} else {
			break;
		}
	}
	
	// The length of the initial segment which hasn't changed:
	result.start = j;
	
	// Find the sequence of lines at the end proceeding the change:
	i = this.current.lines.length, j = updated.lines.length;
	while (i > result.start && j > result.start) {
		if (this.current.lines[i-1] == updated.lines[j-1]) {
			i -= 1;
			j -= 1;
		} else {
			break;
		}
	}
	
	// The index of the remaining portion which hasn't changed:
	result.end = j;
	// The index to the original set of lines which were the same:
	result.originalEnd = i;
	
	// Did we add or remove some lines?
	result.difference = updated.lines.length - this.current.lines.length;
	
	// This should be augmented to improve the above.
	while (result.start > 0) {
		if (updated.offsets[result.start] == updated.offsets[result.start-1])
			break;
		
		result.start -= 1;
	}
	
	if (result.difference > 0) {
		while (result.end < (updated.lines.length-1)) {
			if (updated.offsets[result.end-1] == updated.offsets[result.end])
				break;
			
			result.end += 1;
			result.originalEnd += 1;
		}
	}
	
	// Update the internal state for the next update.
	this.current = updated;
	this.changed = result;
	
	return result;
}

Syntax.Editor.prototype.textForLines = function(start, end) {
	return this.current.lines.slice(start, end).join('\n') + '\n';
}

Syntax.Editor.prototype.updateLines = function(changed, newLines) {
	// We have two cases to handle, either we are replacing lines
	//	(1a) Replacing old lines with one more more new lines (update)
	//	(1b) Replacing old lines with zero new lines (removal)
	// Or we are inserting lines
	//	(2a) We are inserting lines at the start of the element
	//	(2b) We are inserting lines after an existing element.
	
	if (changed.start != changed.end) {
		// When text is deleted, at most two elements can remain:
		//	(1) Whatever was partially remaining on the first line.
		//	(2) Whatever was partially remaining on the last line.
		// All other lines have already been removed by the container.
		// changed.difference tells us how many elements have already been removed.
		
		// Cases (1a) and (1b)
		var start = changed.start, end = changed.end;
		
		start += this.current.offsets[start];
		end += this.current.offsets[end];
		
		var oldLines = Array.prototype.slice.call(this.container.childNodes, start, end);
		
		$(oldLines).replaceWith(newLines);
	} else {
		if (changed.start == 0)
			$(this.container).prepend(newLines);
		else {
			var start = changed.start;
			
			start += this.current.offsets[start];
			
			$(this.container.childNodes[start]).after(newLines);
		}
	}
}

// http://jsfiddle.net/TjXEG/1/
Syntax.Editor.getCharacterOffset = function(element) {
	var caretOffset = 0;
	if (typeof window.getSelection != "undefined") {
		var range = window.getSelection().getRangeAt(0);
		var preCaretRange = range.cloneRange();
		preCaretRange.selectNodeContents(element);
		preCaretRange.setEnd(range.endContainer, range.endOffset);
		caretOffset = preCaretRange.toString().length;
	} else if (typeof document.selection != "undefined" && document.selection.type != "Control") {
		var textRange = document.selection.createRange();
		var preCaretTextRange = document.body.createTextRange();
		preCaretTextRange.moveToElementText(element);
		preCaretTextRange.setEndPoint("EndToEnd", textRange);
		caretOffset = preCaretTextRange.text.length;
	}
	return caretOffset;
};

Syntax.Editor.getNodesForCharacterOffsets = function(offsets, node) {
	var treeWalker = document.createTreeWalker(
		node,
		NodeFilter.SHOW_TEXT,
		function(node) {
			return NodeFilter.FILTER_ACCEPT;
		},
		false
	);
	
	var nodes = [], charCount = 0, i = 0;
	while (i < offsets.length && treeWalker.nextNode()) {
		var end = charCount + treeWalker.currentNode.length;

		while (i < offsets.length && offsets[i] < end) {
			nodes.push([treeWalker.currentNode, charCount, end]);

			i += 1;
		}

		charCount = end;
	}
	
	return nodes;
};

Syntax.Editor.prototype.getClientState = function() {
	var state = {};
	
	var selection = window.getSelection();
	
	if (selection.rangeCount > 0)
		state.range = selection.getRangeAt(0);
	
	if (state.range) {
		state.startOffset = Syntax.Editor.getCharacterOffset(this.container);
	}
	
	return state;
};

Syntax.Editor.prototype.setClientState = function(state) {
	if (state.startOffset) {
		var nodes = Syntax.Editor.getNodesForCharacterOffsets([state.startOffset], this.container);
		
		var range = document.createRange();
		range.setStart(nodes[0][0], state.startOffset - nodes[0][1]);
		range.setEnd(nodes[0][0], state.startOffset - nodes[0][1]);
		
		var selection = window.getSelection();
		selection.removeAllRanges();
		selection.addRange(range);
	}
};

Syntax.layouts.editor = function(options, code/*, container*/) {
	var container = jQuery('<div class="editor syntax highlighted" contentEditable="true">');
	
	container.append(code.children());
	
	var editor = new Syntax.Editor(container.get(0));
		
	var updateContainer = function(lineHint) {
		// Need to save cursor position/selection
		var clientState = editor.getClientState();
		var changed = editor.updateChangedLines();
		
		// Sometimes there are problems where multiple spans exist on the same line.
		if (changed.difference < 0 && changed.start > 0)
			changed.start -= 1;
		
		var text = editor.textForLines(changed.start, changed.end);
		
		if (changed.start == changed.end) {
			editor.updateLines(changed, []);
		} else {
			// Lines have been added, update the highlighting.
			Syntax.highlightText(text, options, function(html) {
				editor.updateLines(changed, html.children().get());
			
				// Restore cusor position/selection if possible
				editor.setClientState(clientState);
			});
		}
	};
	
	// 'blur keyup paste mouseup'
	container.bind('keyup', function(){
		updateContainer();
	});
	
	container.bind('paste', function(event){
		updateContainer();
	});
	
	container.bind('keydown', function(event){
		if (event.keyCode == 9) {
			event.preventDefault();
			document.execCommand('insertHTML', false, "    ");
		}
		else if (event.keyCode == 13) {
			event.preventDefault();
			document.execCommand('insertHTML', false, "\n");
		}
	});
	
	return jQuery('<div class="syntax-container">').append(container);
};
