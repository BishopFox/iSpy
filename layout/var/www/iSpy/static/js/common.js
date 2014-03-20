var numClasses = 0;
var classCounter = 0;
var classList = {};
var classType = {};
var contextClassName = ""; // janky

// connects to the iSpy websocket on the iDevice
function socket_connect(port) {
	var webSocketPort = port;
	var webSocketURL = 'ws://' + window.location.hostname + ':' + webSocketPort;
	var s = new WebSocket(webSocketURL);
	return s;
}

function setupContextHelpHandler(alignment) {
	if(!alignment)
		alignment = "right";

	// When we click on a class name, popup a description of that class
	$(".classContextInfo").popover( {
		trigger: "click",
		template: '<div class="popover"><div class="arrow"></div><div class="popover-inner"><h3 class="popover-title"></h3><div class="popover-content"><p><?prettify?><pre id="popoverContent" class="prettyprint"></pre></p></div></div></div>',
		content: function() {
			var that = this;
			$("#popoverContent").empty();
			var scratch = $(document.createElement('div'));
			
			getRenderedClassHTML($(that).attr("data-className"), $(scratch), function () {
				$("#popoverContent").html($(scratch).html());
				$("#popoverContent div").removeClass("hide");
				
				// Set things up so that a click on the document body will dismiss any popovers.
				$('#popoverContent').on('click', function (e) {
					$(that).popover('hide');
					$('#popovercontent').off('click');
				});
			});
		},
		html: true,
		animation: true,
		placement: alignment,
		title: function () {return $(this).attr("data-className");}
	});
}

function prettifyRenderedClassHTML(htmlElement, contentElement, callbackFunc) {
	$(htmlElement).html(prettyPrintOne($(htmlElement).html()));
	$(".classDetails").removeClass("hide");
	callbackFunc();
}

function getRenderedClassHTML(className, parentHtmlElement, callbackFunc, classDict) {
	// Create a DIV into which we'll place the ivar/prop/method info for this class.
	var classDiv = $(document.createElement('div')); 
	var implementationDiv = $(document.createElement('div'));
	var detailsDiv = $(document.createElement('div'));
	var iVarDiv = $(document.createElement('div'));
	var propertyDiv = $(document.createElement('div'));
	var methodDiv = $(document.createElement('div'));

	// Join all the elements up in the correct order
	var classInfo;
	if(classDict) {
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
		classInfo = '@interface <a class="classContextInfo" data-className="' + className + '" style="padding-top: 40px">' + className + "</a>\n";
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
	//$(classDiv).append('');
	$(classDiv).append(implementationDiv);
	$(classDiv).append(detailsDiv);
	$(classDiv).attr("id", "class_" + className);
	$(parentHtmlElement).append(classDiv);
	
	// Maintain state
	var iVarsComplete = false;
	var propertiesComplete = false;
	var methodsComplete = false;
	var allComplete = false;

	// Render the iVars
	$.ajaxQueue({
		url: "/api/iVarsForClass/" + className,
		timeout: 120000,
		dataType: "json"
	}).done(function(iVars, t, j) {
		if(iVars) {
			$.each(iVars, function(mk, iVarData) {
				$.each(iVarData, function (iVar, type) {
					var actualType = type.replace(/\ \*/,"").replace(/[\<\>\^]/g, "");
					type = type.replace(/>/, "&gt;").replace(/</, "&lt;");
					$(iVarDiv).append("    " + "<a class='classContextInfo' data-className='" + actualType + "'>" + type + "</a> " + iVar + ";\n");
				});
			});
		}
	}).fail(function (j,t,e) {
		//console.log("iVarsForClass empty: " + className + " - " + t + " - " + e);
		iVarsComplete = true;
	}).always(function () {
		iVarsComplete = true;
		if(iVarsComplete && propertiesComplete && methodsComplete && !allComplete) {
			allComplete = true;
			prettifyRenderedClassHTML(classDiv, detailsDiv, callbackFunc);
		}
	});

	// Render the properties
	$.ajaxQueue({
		url: "/api/propertiesForClass/" + className,
		timeout: 120000,
		dataType: "json"
	}).done(function(properties, t, j) {
		if(properties){
			$.each(properties, function(mk, propertyData) {
				$.each(propertyData, function (property, attributes) {
					var propClass = attributes.replace(/\(.*\)\ /,"").replace(/\ \*/,"");
					var propAttrs = attributes.match(/\(.*\)\ /);
					$(propertyDiv).append("@property " + propAttrs + "<a class='classContextInfo' data-className='" + propClass.replace(/[\<\>\^]/g, "") + "'>" + propClass + "</a> " + property + ";\n");
				});
			});
		}
	}).fail(function (j,t,e) {
		//console.log("propertiesForClass empty: " + className + " - " + t + " - " + e);
		propertiesComplete = true;
	}).always(function () {
		propertiesComplete = true;
		if(iVarsComplete && propertiesComplete && methodsComplete && !allComplete) {
			allComplete = true;
			prettifyRenderedClassHTML(classDiv, detailsDiv, callbackFunc);
		}
	});

	// Render the methods
	$.ajaxQueue({
		url: "/api/methodsForClass/" + className,
		timeout: 120000,
		dataType: "json"
	}).done(function(methods) {
		if(methods) {
			$.each(methods, function(index, m) {
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
	}).fail(function (j,t,e) {
		//console.log("methodsForClass empty: " + className + " - " + t + " - " + e);
		methodsComplete = true;
	}).always(function () {
		methodsComplete = true;
		if(iVarsComplete && propertiesComplete && methodsComplete && !allComplete) {
			allComplete = true;
			prettifyRenderedClassHTML(classDiv, detailsDiv, callbackFunc);
		}
	});

	// Return to the caller. 
	// Once all the methods, ivars, and properties have been rendered
	// the DIV will be prettified and the callback function will called.
}


function getRenderedProtocolHTML(protocolName, parentHtmlElement, callbackFunc, protocolDict) {
	// Create a DIV into which we'll place the ivar/prop/method info for this Protocol.
	var protocolDiv = $(document.createElement('div')); 
	var implementationDiv = $(document.createElement('div'));
	var detailsDiv = $(document.createElement('div'));
	var iVarDiv = $(document.createElement('div'));
	var propertyDiv = $(document.createElement('div'));
	var methodDiv = $(document.createElement('div'));

	// Join all the elements up in the correct order
	var protocolInfo;
	if(protocolDict) {
		protocolInfo = '@interface <a protocol="protocolContextInfo" data-protocolName="' + protocolName + '" style="padding-top: 40px">' + protocolName + "</a> : ";
		protocolInfo = protocolInfo + '<a protocol="protocolContextInfo" data-protocolName="' + protocolDict["superprotocol"] + '">' + protocolDict["superprotocol"] + "</a>";
		var numProtocols = protocolDict.length;
		if(numProtocols) {
			protocolInfo = protocolInfo + " <";
			$.each(protocolDict, function (key, protocolName) {
				numProtocols--;
				protocolInfo = protocolInfo + '<a protocol="protocolContextInfo" data-protocolName="' + protocolName + '">' + protocolName + '</a>';
				if(numProtocols)
					protocolInfo = protocolInfo + ', ';
			});
			protocolInfo = protocolInfo + '&gt;\n';
		}
	} else {
		protocolInfo = '@interface <a protocol="protocolContextInfo" data-protocolName="' + protocolName + '" style="padding-top: 40px">' + protocolName + "</a>\n";
	}
	$(implementationDiv).append(protocolInfo);
	$(detailsDiv).append("{\n");
	$(detailsDiv).append(iVarDiv);
	$(detailsDiv).append("}\n");
	$(detailsDiv).append(propertyDiv);
	$(detailsDiv).append(methodDiv);
	$(detailsDiv).append('@end\n\n');
	$(detailsDiv).addprotocol("prettyprint");
	$(detailsDiv).addprotocol("hide");
	$(detailsDiv).addprotocol("protocolDetails");
	$(detailsDiv).attr("style", "padding-bottom: 20pt;");
	$(detailsDiv).attr("id", "details_" + protocolName);
	//$(protocolDiv).append('');
	$(protocolDiv).append(implementationDiv);
	$(protocolDiv).append(detailsDiv);
	$(protocolDiv).attr("id", "protocol_" + protocolName);
	$(parentHtmlElement).append(protocolDiv);
	
	// Maintain state
	var iVarsComplete = false;
	var propertiesComplete = false;
	var methodsComplete = false;
	var allComplete = false;

	// Render the iVars
	$.ajaxQueue({
		url: "/api/iVarsForprotocol/" + protocolName,
		timeout: 120000,
		dataType: "json"
	}).done(function(iVars, t, j) {
		if(iVars) {
			$.each(iVars, function(mk, iVarData) {
				$.each(iVarData, function (iVar, type) {
					var actualType = type.replace(/\ \*/,"").replace(/[\<\>\^]/g, "");
					type = type.replace(/>/, "&gt;").replace(/</, "&lt;");
					$(iVarDiv).append("    " + "<a protocol='protocolContextInfo' data-protocolName='" + actualType + "'>" + type + "</a> " + iVar + ";\n");
				});
			});
		}
	}).fail(function (j,t,e) {
		//console.log("iVarsForprotocol empty: " + protocolName + " - " + t + " - " + e);
		iVarsComplete = true;
	}).always(function () {
		iVarsComplete = true;
		if(iVarsComplete && propertiesComplete && methodsComplete && !allComplete) {
			allComplete = true;
			prettifyRenderedprotocolHTML(protocolDiv, detailsDiv, callbackFunc);
		}
	});

	// Render the properties
	$.ajaxQueue({
		url: "/api/propertiesForprotocol/" + protocolName,
		timeout: 120000,
		dataType: "json"
	}).done(function(properties, t, j) {
		if(properties){
			$.each(properties, function(mk, propertyData) {
				$.each(propertyData, function (property, attributes) {
					var propprotocol = attributes.replace(/\(.*\)\ /,"").replace(/\ \*/,"");
					var propAttrs = attributes.match(/\(.*\)\ /);
					$(propertyDiv).append("@property " + propAttrs + "<a protocol='protocolContextInfo' data-protocolName='" + propprotocol.replace(/[\<\>\^]/g, "") + "'>" + propprotocol + "</a> " + property + ";\n");
				});
			});
		}
	}).fail(function (j,t,e) {
		//console.log("propertiesForprotocol empty: " + protocolName + " - " + t + " - " + e);
		propertiesComplete = true;
	}).always(function () {
		propertiesComplete = true;
		if(iVarsComplete && propertiesComplete && methodsComplete && !allComplete) {
			allComplete = true;
			prettifyRenderedprotocolHTML(protocolDiv, detailsDiv, callbackFunc);
		}
	});

	// Render the methods
	$.ajaxQueue({
		url: "/api/methodsForprotocol/" + protocolName,
		timeout: 120000,
		dataType: "json"
	}).done(function(methods) {
		if(methods) {
			$.each(methods, function(index, m) {
				if(m["isInstanceMethod"] == 1)
					$(methodDiv).append("-");
				else
					$(methodDiv).append("+");
				var a = $(document.createElement('a'));
				var actualType = m["returnType"].replace(/\ \*/,"");
				$(a).attr("data-protocolName", actualType );
				$(a).html(m["returnType"]);
				$(a).addprotocol("protocolContextInfo");
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
	}).fail(function (j,t,e) {
		//console.log("methodsForprotocol empty: " + protocolName + " - " + t + " - " + e);
		methodsComplete = true;
	}).always(function () {
		methodsComplete = true;
		if(iVarsComplete && propertiesComplete && methodsComplete && !allComplete) {
			allComplete = true;
			prettifyRenderedprotocolHTML(protocolDiv, detailsDiv, callbackFunc);
		}
	});

	// Return to the caller. 
	// Once all the methods, ivars, and properties have been rendered
	// the DIV will be prettified and the callback function will called.
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


