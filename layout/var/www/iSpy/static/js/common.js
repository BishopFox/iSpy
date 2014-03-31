// Don't reference these directly. Instead, use:
// 	  var myClassDump    = getCachedClassDump();
// 	  var myProtocolDump = getCachedProtocolDump(); 
var cachedClassDump;
var cachedProtocolDump;
var classBrowseHistory = [];
var classBrowseHistoryPos = 0;

// The next two functions are a cached interface to the JSON objects representing the class and protocol dumps
function getCachedClassDump() {
	if(cachedClassDump === undefined) {
		cachedClassDump = JSON.parse(localStorage.getItem("classData"));
	}
	return cachedClassDump;
}
function getCachedProtocolDump() {
	if(cachedProtocolDump === undefined) {
		cachedProtocolDump = JSON.parse(localStorage.getItem("protocolData"));
	}
	return cachedProtocolDump;
}

// connects to the iSpy websocket on the iDevice
function socket_connect(port) {
	var webSocketPort = port;
	var webSocketURL = 'ws://' + window.location.hostname + ':' + webSocketPort;
	var s = new WebSocket(webSocketURL);
	return s;
}

function prettifyDOMElement(element) {
	$(element).html(prettyPrintOne($(element).html()));
}

function showHideHistoryButtons() {
	if(classBrowseHistoryPos == classBrowseHistory.length - 1)
		$(historyForward).attr("disabled","true");
	else
		$(historyForward).removeAttr("disabled");
	
	if(classBrowseHistoryPos == 0)
		$(historyBack).attr("disabled","true");
	else
		$(historyBack).removeAttr("disabled");
}



function renderClassInfoIntoPopup(className, destinationElement) {
	var scratch = $(document.createElement('div'));
	var element = destinationElement;
	console.log(className);
	
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
	});
}


function old_renderClassInfoIntoPopup(className, selfRef, optionalDestinationElement) {
	var destinationElement = "#popoverContent";
	if(optionalDestinationElement !== undefined) {
		destinationElement = optionalDestinationElement;
	}
	var that = selfRef;
	$(destinationElement).empty();
	var scratch = $(document.createElement('div'));
	//var className = $(that).attr("data-className");
	
	$.ajax({
		url: "/api/classDumpClass/" + className,
		timeout: 30000,
		dataType: "json",
	}).done(function(classDict) {
		renderClassDataAndAppendToDOMElement(className, $(scratch), function () {
			$(destinationElement).html(prettyPrintOne($(scratch).html()));
			$(destinationElement + "div").removeClass("hide");
			
			// Set things up so that a click anywhere except an <a> element will dismiss the popover.
			$(window).on('click', function (e) {
				if(e.target.parentElement.nodeName != 'A') { 
					//$(that).popover('hide');
					$(window).off('click');
				} else {
					$(window).off('click');
					className = e.target.parentElement.text;
					className = className.replace(/\ \*/,"").replace(/[\<\>\^]/g, "");
					console.log("Fetching class " + className);
					renderClassInfoIntoPopup(className, that);
				}
			});

			// we want a nice pointer when hovering over class names
			$(".classContextInfo").hover(function() {
				$(this).css('cursor','pointer');
			}, function() {
				$(this).css('cursor','auto');
			});
		}, classDict);
	});
}

function setupContextHelpHandler(alignment) {
	if(!alignment)
		alignment = "right";

	// When we click on a class name, popup a description of that class
	$(".classContextInfo").popover( {
		trigger: "click",
		template: '<div class="popover"><div class="arrow"></div><div class="popover-inner"><h3 class="popover-title"></h3><div class="popover-content"><p><?prettify?><pre id="popoverContent" class="prettyprint"></pre></p></div></div></div>',
		content: function() {
			console.log("Fetching class " + $(this).attr("data-className"));
			renderClassInfoIntoPopup($(this).attr("data-className"), this);
		},
		html: true,
		animation: true,
		placement: alignment,
		title: function () {return $(this).attr("data-className");}
	});
}

function renderClassDataAndAppendToDOMElement(className, parentHtmlElement, callbackFunc, classDict) {
	// Create a DIV into which we'll place the ivar/prop/method info for this class.
	var classDiv = $(document.createElement('div')); 
	var implementationDiv = $(document.createElement('div'));
	var detailsDiv = $(document.createElement('div'));
	var iVarDiv = $(document.createElement('div'));
	var propertyDiv = $(document.createElement('div'));
	var methodDiv = $(document.createElement('div'));

	// Join all the elements up in the correct order
	var classInfo;
	if(classDict && classDict["superClass"]) {
		classInfo = '@interface <a class="classContextInfo" data-className="' + className + '" style="padding-top: 40px">' + className + "</a> : ";
		classInfo = classInfo + '<a class="classContextInfo" data-className="' + classDict["superClass"] + '">' + classDict["superClass"] + "</a>";
		var numProtocols = classDict["protocols"].length;
		if(numProtocols) {
			classInfo = classInfo + " <";
			$.each(classDict["protocols"], function (key, protocolName) {
				numProtocols--;
				classInfo = classInfo + '<a class="classContextInfo" data-protocolName="' + protocolName + '">' + protocolName + '</a>';
				if(numProtocols)
					classInfo = classInfo + ', ';
			});
			classInfo = classInfo + '&gt;\n';
		}
	} else {
		classInfo = '@interface <a class="classContextInfo" data-className="' + className + '" style="padding-top: 40px">' + className + "</a>;\n";
	}

	$(implementationDiv).append(classInfo);
	$(detailsDiv).append("{\n");
	$(detailsDiv).append(iVarDiv);
	$(detailsDiv).append("}\n");
	$(detailsDiv).append(propertyDiv);
	$(detailsDiv).append(methodDiv);
	$(detailsDiv).append('@end\n\n');
	$(detailsDiv).addClass("prettyprint");
	$(detailsDiv).addClass("hide");
	$(detailsDiv).addClass("classDetails");
	$(detailsDiv).attr("style", "padding-bottom: 20pt;");
	$(detailsDiv).attr("id", "details_" + className);
	$(classDiv).append(implementationDiv);
	$(classDiv).append(detailsDiv);
	$(classDiv).attr("id", "class_" + className);
	$(parentHtmlElement).prepend(classDiv);

	// Render the iVars
	if(classDict["ivars"]) {
		$.each(classDict["ivars"], function(mk, iVarData) {
			$.each(iVarData, function (iVar, type) {
				var actualType = type.replace(/\ \*/,"").replace(/[\<\>\^]/g, "");
				type = type.replace(/>/, "&gt;").replace(/</, "&lt;");
				$(iVarDiv).append("    " + "<a class='classContextInfo' data-className='" + actualType + "'>" + type + "</a> " + iVar + ";\n");
			});
		});
	}

	if(classDict["properties"]){
		$.each(classDict["properties"], function(mk, propertyData) {
			$.each(propertyData, function (property, attributes) {
				var propClass = attributes.replace(/\(.*\)\ /,"").replace(/\ \*/,"");
				var propAttrs = attributes.match(/\(.*\)\ /);
				$(propertyDiv).append("@property " + propAttrs + "<a class='classContextInfo' data-className='" + propClass.replace(/[\<\>\^]/g, "") + "'>" + propClass + "</a> " + property + ";\n");
			});
		});
	}

	if(classDict["methods"]) {
		$.each(classDict["methods"], function(index, m) {
			if(m["isInstanceMethod"] == 1)
				$(methodDiv).append("-");
			else
				$(methodDiv).append("+");
			var a = $(document.createElement('a'));
			var actualType = m["returnType"].replace(/\ \*/,"");
			$(a).attr("data-className", actualType );
			$(a).html(m["returnType"]);
			$(a).addClass("classContextInfo");
			$(methodDiv).append("(");
			$(methodDiv).append(a);
			$(methodDiv).append(")");
			var methodDesc = "";
			if(m["parameters"].length > 0) {
				var paramNum = 1;
				$.each(m["parameters"], function(index, p) {
					if(paramNum > 1)
						methodDesc += " ";
					methodDesc = methodDesc + p["name"] + ":(" + p["type"] + ")arg" + paramNum;
					paramNum++;
				});
				$(methodDiv).append(methodDesc + ";\n");	
			} else {
				$(methodDiv).append(m["name"] + ";\n");
			}
		});
	}
	$(".classDetails").removeClass("hide");
	callbackFunc();
	
	// Return to the caller. 
	// Once all the methods, ivars, and properties have been rendered
	// the DIV will be prettified and the callback function will called.
}

function renderProtocolDataAndAppendToDOMElement(protocolName, parentHtmlElement, callbackFunc, protocolDict) {
	// Create a DIV into which we'll place the ivar/prop/method info for this Protocol.
	var protocolDiv = $(document.createElement('div'));
	var propertyDiv = $(document.createElement('div'));
	var detailsDiv = $(document.createElement('div'));
	var requiredDiv = $(document.createElement('div'));
	var optionalDiv = $(document.createElement('div'));

	console.log("renderProtocolDataAndAppendToDOMElement");
	console.log(protocolDict);

	// Join all the elements up in the correct order
	var protocolInfo;
	protocolInfo = '@protocol <a protocol="protocolContextInfo" data-protocolName="' + protocolName + '" style="padding-top: 40px">' + protocolName + "</a> &lt;NSObject&gt;\n";
	$(requiredDiv).append("@required\n");
	$(optionalDiv).append("@optional\n");

	// Properties
	$.each(protocolDict['properties'], function(mk, propertyData) {
		$.each(propertyData, function (property, attributes) {
			var propClass = attributes.replace(/\(.*\)\ /,"").replace(/\ \*/,"");
			var propAttrs = attributes.match(/\(.*\)\ /);
			var escapedClass = propClass.replace(/>/, "&gt;").replace(/</, "&lt;");
			$(propertyDiv).append("@property " + propAttrs + "<a class='classContextInfo' data-className='" + propClass.replace(/[\<\>\^]/g, "") + "'>" + escapedClass + "</a> " + property + ";\n");
		});
	});

	// Adoptees
	if(protocolDict["adoptees"].length > 0) {
		protocolInfo = protocolInfo + "// Adoptees:\n";
		$.each(protocolDict['adoptees'], function(mk, adopteeData) {
			protocolInfo = protocolInfo + "//   " + adopteeData + "\n";
		});
	}

	// Methods
	// "methods":[{"instance":"1","returnType":"void","methodName":"connection:handleInvocation:isReply:","parameters":[["id","id","char"]],"required":"0"}]
	var numRequiredMethods = 0;
	var numOptionalMethods = 0;
	$.each(protocolDict['methods'], function(index, m) {
		var methodDiv = $(document.createElement('div'));
		if(m["instance"] == 1)
			$(methodDiv).append("-");
		else
			$(methodDiv).append("+");
		var a = $(document.createElement('a'));
		var actualType = m["returnType"].replace(/\ \*/,"");
		$(a).attr("data-protocolName", actualType );
		$(a).html(m["returnType"]);
		$(a).addClass("protocolContextInfo");
		$(methodDiv).append("(");
		$(methodDiv).append(a);
		$(methodDiv).append(")");
		var methodDesc = "";
		if(m["parameters"].length > 0) {
			var paramNum = 1;
			var params = m["methodName"].split(":");
			$.each(m["parameters"][0], function(index, p) {
				if(paramNum > 1)
					methodDesc += " ";
				methodDesc = methodDesc + params[paramNum-1] + ":(" + p + ")arg" + paramNum;
				paramNum++;
			});
			$(methodDiv).append(methodDesc + ";\n");	
		} else {
			$(methodDiv).append(m["methodName"] + ";\n");
		}
		if(m["required"] == "1") {
			$(requiredDiv).append(methodDiv);
			numRequiredMethods = numRequiredMethods + 1;
		} else {
			numOptionalMethods = numOptionalMethods + 1;
			$(optionalDiv).append(methodDiv);
		}
	});

	$(detailsDiv).append(protocolInfo);
	$(detailsDiv).append(propertyDiv);
	if(numRequiredMethods)
		$(detailsDiv).append(requiredDiv);
	if(numOptionalMethods)
		$(detailsDiv).append(optionalDiv);
	$(detailsDiv).append('@end\n\n');
	$(detailsDiv).addClass("prettyprint");
	$(detailsDiv).addClass("hide");
	$(detailsDiv).addClass("protocolDetails");
	$(detailsDiv).attr("style", "padding-bottom: 20pt;");
	$(detailsDiv).attr("id", "details_" + protocolName);
	$(protocolDiv).append(detailsDiv);
	$(protocolDiv).attr("id", "protocol_" + protocolName);
	$(parentHtmlElement).append(protocolDiv);
	
	$(".protocolDetails").removeClass("hide");
	callbackFunc();
}

// Be nice, pass a 1 or 0. Expect bugs for non-binary values of boolState.
// Don't call it twice. This is horrible. 3am hack. Sorry.
var originalInstanceState = -1;
function set_instance_tracker_state(boolState) {
	originalInstanceState = get_instance_tracker_state();
	
	POSTBody = "item=" + "instanceTracking" + "&state=" + boolState;
	$.post("/api/monitor/status", POSTBody);
}

// This is crazy and could make your head exploit with its awfulness.
function get_instance_tracker_state() {
	var retVal = false;

	$.ajax({
		url: '/api/monitor/status',
		dataType: "json",
		async: false
	}).done(function (data) {
		retVal = data["instanceState"];
	});
	console.log("Instance tracker status: " + retVal);
	return retVal;
}

// bwaahaha
function restore_instance_tracker_state() {
	if(originalInstanceState == -1)
		return;

	POSTBody = "item=" + "instanceTracking" + "&state=" + originalInstanceState;
	$.post("/api/monitor/status", POSTBody);

	originalInstanceState = -1;
}

// this dynamically scales the log window to fit vertically in the browser window
// call like resolveFullHeight("#elementName")
function resolveFullHeight(element) {
	$(element).css("height", "auto");
	var h_window = $(window).height(),
		h_document = $(document).height(),
		fullHeight_top = $(element).position().top,
		est_footerHeight = 0;
	var h_fullHeight = h_document - fullHeight_top - 100;
	return h_fullHeight;
}


// Pads a number with leading zeros
function pad(num, size) {
	var s = num+"";
	while (s.length < size) s = "0" + s;
	return s;
}

// Disable DataTables' automatic filter - it chews up the CPU on large datasets.
// Instead we force the user to press enter to submit a search.
if(jQuery.fn.dataTableExt) {
	jQuery.fn.dataTableExt.oApi.fnFilterOnReturn = function (oSettings) {
		var _that = this;
	  
		this.each(function (i) {
			$.fn.dataTableExt.iApiIndex = i;
			var $this = this;
			var anControl = $('input', _that.fnSettings().aanFeatures.f);
			anControl.unbind('keyup').bind('keypress', function (e) {
				if (e.which == 13) {
					$.fn.dataTableExt.iApiIndex = i;
					_that.fnFilter(anControl.val());
				}
			});
			return this;
		});
		return this;
	};
}


