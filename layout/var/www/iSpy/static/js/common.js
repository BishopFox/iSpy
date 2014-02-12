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
		template: '<div class="popover" style="width: 700px"><div class="arrow"></div><div class="popover-inner"><h3 class="popover-title"></h3><div class="popover-content"><p><?prettify?><pre id="popoverContent" class="prettyprint"></pre></p></div></div></div>',
		content: function() {
			var that = this;
			$("#popoverContent").empty();
			var scratch = $(document.createElement('div'));
			
			getRenderedClassHTML($(that).attr("data-className"), $(scratch), function () {
				$("#popoverContent").html($(scratch).html());
				$("#popoverContent div").removeClass("hide");
				
				// Set things up so that a click on the document body will dismiss any popovers.
				$('#popoverContent').on('click', function (e) {
					/*if($(this).is("classContextInfo") && this == that)
						return;
					if($("#popoverContent").html().match($(that).attr("data-className"))) {*/
						$(that).popover('hide');
						$('#popovercontent').off('click');
					//}
				});
			});
		},
		html: true,
		animation: true,
		placement: alignment,
		title: function () {return $(this).attr("data-className");}
	});

	// we want a nice pointer when hovering over class names
	$(".classContextInfo").hover(function() {
		$(this).css('cursor','pointer');
	}, function() {
		$(this).css('cursor','auto');
	});
}

function prettifyRenderedClassHTML(htmlElement, callbackFunc) {
	$(htmlElement).html(prettyPrintOne($(htmlElement).html()));
	callbackFunc();
}

function getRenderedClassHTML(className, parentHtmlElement, callbackFunc) {
	// Create a DIV into which we'll place the ivar/prop/method info for this class.
	var classDiv = $(document.createElement('div')); 
	var implementationDiv = $(document.createElement('div'));
	var detailsDiv = $(document.createElement('div'));
	var iVarDiv = $(document.createElement('div'));
	var propertyDiv = $(document.createElement('div'));
	var methodDiv = $(document.createElement('div'));

	// Join all the elements up in the correct order
	$(implementationDiv).append(prettyPrintOne('<a name="' + className + '" style="padding-top: 40px">@interface ' + className + "</a>"));
	$(detailsDiv).append("// Instance variables\n{\n");
	$(detailsDiv).append(iVarDiv);
	$(detailsDiv).append("}\n// Properties\n");
	$(detailsDiv).append(propertyDiv);
	$(detailsDiv).append("// Methods\n");
	$(detailsDiv).append(methodDiv);
	$(detailsDiv).append(prettyPrintOne('@end'));
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
	$.ajax({
		url: "/api/iVarsForClass/" + className,
		timeout: 120000,
		dataType: "json"
	}).done(function(iVars, t, j) {
		if(iVars) {
			$.each(iVars, function(mk, iVarData) {
				$.each(iVarData, function (iVar, type) {
					var actualType = type.replace(/\ \*/,"");
					if(classType[actualType] == true)
						$(iVarDiv).append("    " + "<a href='#" + actualType + "'>" + type + "</a> " + iVar + ";\n");
					else
						$(iVarDiv).append("    " + "<a class='classContextInfo' data-className='" + actualType + "'>" + type + "</a> " + iVar + ";\n");
				});
			});
		}
	}).fail(function (j,t,e) {
		console.log("Fail: " + className + " - " + t + " - " + e);
	}).always(function () {
		iVarsComplete = true;
		if(iVarsComplete && propertiesComplete && methodsComplete && !allComplete) {
			allComplete = true;
			prettifyRenderedClassHTML(classDiv, callbackFunc);
		}
	});

	// Render the properties
	$.ajax({
		url: "/api/propertiesForClass/" + className,
		timeout: 120000,
		dataType: "json"
	}).done(function(properties, t, j) {
		if(properties){
			$.each(properties, function(mk, propertyData) {
				$.each(propertyData, function (property, attributes) {
					var propClass = attributes.replace(/\(.*\)\ /,"").replace(/\ \*/,"");
					var propAttrs = attributes.match(/\(.*\)\ /);
					if(classType[propClass] == true)
						$(propertyDiv).append("@property " + propAttrs + "<a href='#" + propClass + "'>" + propClass + "</a> " + property + ";\n");
					else
						$(propertyDiv).append("@property " + propAttrs + "<a class='classContextInfo' data-className='" + propClass + "'>" + propClass + "</a> " + property + ";\n");
				});
			});
		}
	}).fail(function (j,t,e) {
		console.log("Fail: " + className + " - " + t + " - " + e);
	}).always(function () {
		propertiesComplete = true;
		if(iVarsComplete && propertiesComplete && methodsComplete && !allComplete) {
			allComplete = true;
			prettifyRenderedClassHTML(classDiv, callbackFunc);
		}
	});

	// Render the methods
	$.ajax({
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
				if(classType[actualType] == true) { 
					$(a).attr("data-className", actualType );
					$(a).html(m["returnType"]);
					$(a).addClass("classContextInfo");
				} else {
					$(a).attr("href", "#" + actualType );
					$(a).html(m["returnType"]);
				}
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
		console.log("Fail: " + className + " - " + t + " - " + e);
	}).always(function () {
		methodsComplete = true;
		if(iVarsComplete && propertiesComplete && methodsComplete && !allComplete) {
			allComplete = true;
			prettifyRenderedClassHTML(classDiv, callbackFunc);
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

