function ClassRenderer(className, callback) {
	// a class name is required
	if(className === undefined)
		return null;

	this.settings = $.extend({
		className: className,
		callback: function () {
			// do nothing by default
		}
	}, options );
}

ClassRenderer.prototype.settings = {
	callback: undefined,
	syntaxHighlighting: true
};

ClassRenderer.prototype.renderHTML = function() {
	var scratch = $(document.createElement('div'));
	var element = destinationElement;
	console.log("Rendering class " + className + " into " + this);
	
	var originalThis = this; // we'll want to use this inside the AJAX's done() function

	$.ajax({
		url: "/api/classDumpClass/" + className,
		timeout: 30000,
		dataType: "json",
	}).done(function(classDict) {
		renderClassDataAndAppendToDOMElement(className, $(scratch), function () {
			$(element).html(prettyPrintOne($(scratch).html()));
			$(element + " div").removeClass("hide");

			// Set things up so that a click anywhere except an <a> element will dismiss the popover.
			$(element).off('click');
			$(element).on('click', function (e) {
				if(e.target.parentElement.nodeName == 'A') {
					className = e.target.parentElement.text;
					className = className.replace(/\ \*/,"").replace(/[\<\>\^]/g, "");

					console.log("Fetching class " + className);
					console.log("Adding class " + className + " to history.");
					classBrowseHistory.length = classBrowseHistoryPos + 1; // truncate our previous "forward" history. We're making a new one.
					classBrowseHistory.push(className);
					classBrowseHistoryPos = classBrowseHistory.length - 1;
					showHideHistoryButtons();
					renderClassInfoIntoPopup(className, destinationElement);
				}
			});

			// we want a nice pointer when hovering over class names
			$(".classContextInfo").hover(function() {
				$(this).css('cursor','pointer');
			}, function() {
				$(this).css('cursor','auto');
			});
		}, classDict);
		
		// call the user-supplied callback, if present
		if(this.callback !== undefined)
			this.callback();
	});
}
