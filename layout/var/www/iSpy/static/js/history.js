function History(options) {
	 this.settings = $.extend({
		// These are the defaults.
		UIDropdownElement: undefined,
		UIDropdownDisplayElement: undefined,
		UIDropdownDisplayText: "&nbsp;",
		UIDataElement: undefined,
		UIBackButton: undefined,
		UIForwardButton: undefined
	}, options );
	
	this.clear();
	this.initializeClickHandlers();
}

History.prototype.history = [];
History.prototype.pos = -1;
History.prototype.settings = {};

History.prototype.clear = function() {
	this.history = [];
	this.pos = -1;
	if(this.settings.UIDropdownElement !== undefined)
		$(this.settings.UIDropdownElement).find("li").remove();
	
	this.setDisplayText(this.settings.UIDropdownDisplayText);
	this.disableButton(this.settings.UIBackButton);
	this.disableButton(this.settings.UIForwardButton);
}

History.prototype.setDisplayText = function(text) {
	if(text === undefined)
		return;
	$(this.settings.UIDropdownDisplayElement).html(text);
}

History.prototype.add = function(className) {
	this.history.push(className);
	this.pos++;
}

History.prototype.truncate = function() {
	this.history.length = this.pos + 1;
}

History.prototype.setUIDropdownId = function(element) {
	this.settings.UIDropdownElement = element;
}

History.appendClassToUIDropdown = function(className) {
	if(UIDropdownElement == undefined)
		return;

	var li = $(document.createElement('li'));
	var a  = $(document.createElement('a'));

	$(a).html(className);
	$(a).attr("role", "menuitem");
	$(a).attr("href", "#");
	$(a).on("click", function () {
		// hide the menu and display the class in the panel.
	});

	$(li).attr("role", "presentation");
	$(li).append(a);
	
	$(this.settings.UIDropdownElement).append(li);
}

History.prototype.clearUIDropdown = function() {
	$(this.UIDropdownElement).clear();
}

History.prototype.disableButton = function(btn) {
	if(btn === undefined)
		return;
	$(btn).attr("disabled","true");	
}

History.prototype.enableButton = function(btn) {
	if(btn === undefined)
		return;
	$(btn).removeAttr("disabled");	
}

History.prototype.initializeClickHandlers = function() {
	$(this.settings.UIBackButton).on("click", function () {
		if(this.pos)
			this.pos--;
		this.updateUIButtons();
		//renderClassInfoIntoPopup(classBrowseHistory[classBrowseHistoryPos], "#dumpArea");
	});

	$(this.settings.UIForwardButton).on("click", function () {
		if(this.pos < this.history.length - 1)
			pos++;
		this.updateUIButtons();
		//renderClassInfoIntoPopup(classBrowseHistory[classBrowseHistoryPos], "#dumpArea");
	});	
}

History.prototype.updateUIButtons = function() {
	if(this.pos == this.history.length - 1)
		this.disableButton($(this.settings.UIForwardButton));
	else
		this.enableButton($(this.settings.UIForwardButton));
	
	if(this.pos == 0)
		this.disableButton($(this.settings.UIBackButton));
	else
		this.enableButton($(this.settings.UIBackButton));
}

