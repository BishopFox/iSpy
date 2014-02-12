var iSpyDBVersion = 0; // this will be dynamically determined
var dbIsInitialized = false;
var whitelistIsInitializedFor = { 
	"classes": false,
	"methods": false,
	"parameters": false,
	"ivars": false,
	"properties": false,
	"symbols": false 
};
var ajaxFinished = false;
var db;
var upgradeEvent;
var pleaseWaitWasRendered = false;
var appBundleID = undefined;
var appBundleID = undefined;
var wasUpgraded = undefined;

// IndexedDB is an abomination. RAM is cheap. Aw yeah.
var iSpyClassesByName = {};
var iSpyClassesById = {};
var iSpyMethodsByName = {};
var iSpyMethodsById = {};
var iSpyMethodsByClassId = {};
var iSpyParametersByName = {};
var iSpyParametersById = {};
var iSpyParametersByMethodId = {};
var iSpyIVarsByName = {};
var iSpyIVarsById = {};
var iSpyIVarsByClassId = {};
var iSpyPropertiesById = {};
var iSpyPropertiesByName = {};
var iSpySymbolsByName = {};
var iSpySymbolsById = {};

var blacklistedMethods = [];

var fatalErrMsg = "Something went horribly wrong. At this stage you should:\n1. Remove iSpy.db from the apps's \"Documents/\" directory iDevice.\n2. Restart the app.\n3. Reload this page and try again.\nThe browser's javascript console might have more data.";

function UI_callbackFunction() {};

// If you're using IE6 this probably won't work
function supports_html5_storage() {
	try {
		return 'localStorage' in window && window['localStorage'] !== null;
	} catch (e) {
		return false;
	}
}


// Give this function a class name and it'll return pretty HTML describing the class.
function render_classdump_html_for_class(className) {
	var cls = iSpyClassesByName[className];
	var classDumpContent = "";

	if( cls["isAppClass"] != 1)
		return classDumpContent;
	
	classId = cls["id"];
	//console.log(className);

	classDumpContent += "<span onclick=\"$('#" + className + "_detail').removeClass('hide')\"><i id=\"" + className + "_i\" class=\"fa fa-plus-square-o\"></i> @interface " + className + "</span>\n";
	classDumpContent += '<div id="' + className + '_detail" class="hide">{\n';
	
	// Get the list of ivars
	for (var key in cls["ivars"]) {
		iv = cls["ivars"][key]; 
		classDumpContent += "    " + iv["type"].replace("<", "&lt;").replace(">", "&gt;") + " " + iv["name"] + ";\n"; 
	}
	classDumpContent += "}\n";

	// Get the list of properties
	for (var key in cls["properties"]) {
		p = cls["properties"][key]; 
		classDumpContent += "@property " + p["attributes"].replace("<", "&lt;").replace(">", "&gt;") + " " + p["name"] + ";\n"; 
	}

	// methods
	var counter=0;
	for (var methodName in cls["methods"]) {
		m = cls["methods"][methodName];
		if(m["isInstanceMethod"] == 1)
			classDumpContent += "-";
		else
			classDumpContent += "+";
		classDumpContent += "(" + m["returnType"].replace("<", "&lt;").replace(">", "&gt;") + ")";

		// parameters
		count = 0;
		for(var param in m["parameters"]) {
			p = m["parameters"][param];
			count++;
			classDumpContent += " " + p["name"] + ":(" + p["type"].replace("<", "&lt;").replace(">", "&gt;") + ")" + "arg" + count;
		}
		if(count == 0)
			classDumpContent += " " + m["name"];
		
		classDumpContent += ";\n";
	}
	classDumpContent += "@end\n\n</div>";
	return classDumpContent;
}

var optionsCount = 0;
function render_classdump_html_for_class2(className) {
	var cls = iSpyClassesByName[className];
	var classDumpContent = "";
	

	if( cls["isAppClass"] != 1)
		return classDumpContent;
	
	classId = cls["id"];
	//console.log(className);
	
	var div = $(document.createElement('div'));

	var detail = $(document.createElement('div'));
	$(detail).addClass("animated hide fadeIn");
	$(detail).append("    " + "// Instance variables\n");
	$(detail).append("    " + "{\n");

	var span = $(document.createElement('span'));
	
	var btnGroup = $(document.createElement('div'));
	$(btnGroup).addClass("btn-group");

	var button = $(document.createElement('a'));
	$(button).addClass("btn");
	$(button).addClass("btn-link");
	$(button).append("@interface " + className + "\n");
	$(button).on("click", function (event) {
		$(detail).toggleClass("hide");
	});

	$(button).hover(function() {
		$(this).css('cursor','pointer');
		$(button).toggleClass("btn-link");
		$(button).next().toggleClass("hide");
	}, function() {
		$(this).css('cursor','auto');
		$(button).toggleClass("btn-link");
		$(button).next().toggleClass("hide");
	});

	var options = $(document.createElement('div'));
	$(options).addClass("dropdown");
	var btnDropDown = $(document.createElement('a'));
	$(options).append(btnDropDown);
	$(btnDropDown).addClass("btn");
	$(btnDropDown).addClass("dropdown-toggle");
	$(btnDropDown).addClass("hide");
	$(btnDropDown).attr("data-toggle", "dropdown");
	$(btnDropDown).attr("role", "button");
	$(btnDropDown).attr('href', '#');
	
	$(btnDropDown).hover(function() {
		$(this).css('cursor','pointer');
		$(button).toggleClass("btn-link");
		$(button).next().toggleClass("hide");
	}, function() {
		$(this).css('cursor','auto');
		$(button).toggleClass("btn-link");
		$(button).next().toggleClass("hide");
	});

	var caret = $(document.createElement('span'));
	$(caret).addClass("caret");
	$(btnDropDown).append(caret);

	
	var ul = $(document.createElement('ul'));
	var li = $(document.createElement('li'));
	
	$(li).append("Foobar!");
	$(ul).append(li);
	$(ul).addClass("dropdown-menu");
	$(ul).attr('role', 'menu');
	$(options).append(ul);
	console.log(options);
	
	$(btnGroup).append(button);
	//$(btnGroup).append(btnDropDown);
	$(btnGroup).append(options);
	$(span).append(btnGroup);

	$(div).append(span);
	$(div).append(detail);
	
	// Get the list of ivars
	for (var key in cls["ivars"]) {
		iv = cls["ivars"][key]; 
		$(detail).append("    " + "    " + iv["type"].replace("<", "&lt;").replace(">", "&gt;") + " " + iv["name"] + ";\n"); 
	}
	$(detail).append("    " + "}\n");

	// Get the list of properties
	$(detail).append("    " + "// Properties\n");
	for (var key in cls["properties"]) {
		p = cls["properties"][key]; 
		$(detail).append("    " + "@property " + p["attributes"].replace("<", "&lt;").replace(">", "&gt;") + " " + p["name"] + ";\n"); 
	}

	// methods
	$(detail).append("    " + "// Methods\n");
	var counter=0;
	for (var methodName in cls["methods"]) {
		m = cls["methods"][methodName];
		if(m["isInstanceMethod"] == 1)
			$(detail).append("    " + "-");
		else
			$(detail).append("    " + "+");
		$(detail).append("(" + m["returnType"].replace("<", "&lt;").replace(">", "&gt;") + ")");

		// parameters
		count = 0;
		for(var param in m["parameters"]) {
			p = m["parameters"][param];
			count++;
			$(detail).append(" " + p["name"] + ":(" + p["type"].replace("<", "&lt;").replace(">", "&gt;") + ")" + "arg" + count);
		}
		if(count == 0)
			$(detail).append(" " + m["name"]);
		
		$(detail).append(";\n");
	}
	$(detail).append("@end\n\n");

	return div;
}


// Return the app's bundle ID. Will be blocking/synchronous on the first run. 
// After that it's fast and cached.
function get_app_appBundleID() {
	// If it's cached, just return it
	if( ! (appBundleID === undefined))
		return appBundleID;

	// Not cached? Go fetch it. This is BLOCKING.
	$.ajax({ 		
		url: "/api/info/summary",
		async: false,
		error: function (j, t, e) {
			console.log("SJAX error: " + e);
			appBundleID = undefined;
			return undefined;
		},
		success: function(result) {	
			var x = $.parseJSON(result);
			console.log(x["Bundle ID"]);
			appBundleID = x["Bundle ID"];
			return appBundleID;
		}
	});
	return appBundleID;
}


// The clue is in the function name
function cache_all_the_things_because_indexeddb_is_fucking_horrific() {
	console.log("Caching all the things");
	// We first build arrays of the data (classes/methods/parameters/ivars/etc)
	// This is the part that extracts class information from IndexedDB.
	// Each of these jobs runs in parallel in a worker thread.

	// Classes
	var cHandle = $.indexedDB(get_app_appBundleID()).objectStore("classes");
	var cIndex = cHandle.index("id");
	console.log(cHandle);
	console.log(cIndex);
	if(cHandle === undefined || cIndex === undefined || cIndex.length <= 0) {
		things_are_out_of_sync();
		return;
	}
	cIndex.each(function (cItem) {
		iSpyClassesById[cItem.value.id] = iSpyClassesByName[cItem.value.name] = cItem.value;
		iSpyClassesByName[cItem.value.name]["methods"] = {};
		iSpyClassesByName[cItem.value.name]["ivars"] = {};
		iSpyClassesByName[cItem.value.name]["properties"] = {};
	}).done(function () {
		console.log("class precaching complete.");
		whitelistIsInitializedFor["classes"] = true;
		try_to_populate_class_structure(); // will only work if all the data gatehring stages are finished
	});
	
	// Methods
	var mHandle = $.indexedDB(get_app_appBundleID()).objectStore("methods");
	var mIndex = mHandle.index("name");
	if(mHandle === undefined || mIndex === undefined || mIndex.length <= 0) {
		things_are_out_of_sync();
		return;
	}
	mIndex.each(function(mItem) {
		iSpyMethodsById[mItem.value.id] = iSpyMethodsByName[mItem.value.name] = mItem.value;
		iSpyMethodsByName[mItem.value.name]["parameters"] = {};
	}).done(function () {
		console.log("method precaching complete.");
		whitelistIsInitializedFor["methods"] = true;
		try_to_populate_class_structure(); // will only work if all the data gatehring stages are finished
	});

	// parameters
	var paramHandle = $.indexedDB(get_app_appBundleID()).objectStore("parameters");
	var paramIndex = paramHandle.index("name");
	if(paramHandle === undefined || paramIndex === undefined || paramIndex.length <= 0) {
		things_are_out_of_sync();
		return;
	}
	paramIndex.each(function(paramItem) {
		iSpyParametersByName[paramItem.value.name] = paramItem.value;
	}).done(function () {
		console.log("parameter precaching complete.");
		whitelistIsInitializedFor["parameters"] = true;
		try_to_populate_class_structure(); // will only work if all the data gatehring stages are finished
	});
	
	// IVars
	var iHandle = $.indexedDB(get_app_appBundleID()).objectStore("ivars");
	var iIndex = iHandle.index("name");
	if(iHandle === undefined || iIndex === undefined || iIndex.length <= 0) {
		things_are_out_of_sync();
		return;
	}
	iIndex.each(function(iItem) {
			iSpyIVarsByName[iItem.value.name] = iItem.value;
	}).done(function () {
		console.log("ivar precaching complete.");
		whitelistIsInitializedFor["ivars"] = true;
		try_to_populate_class_structure(); // will only work if all the data gatehring stages are finished
	});

	// properties
	var prHandle = $.indexedDB(get_app_appBundleID()).objectStore("properties");
	var prIndex = prHandle.index("name");
	if(prHandle === undefined || prIndex === undefined || prIndex.length <= 0) {
		things_are_out_of_sync();
		return;
	}
	prIndex.each(function(prItem) {
		iSpyPropertiesByName[prItem.value.name] = prItem.value;
	}).done(function () {
		console.log("property precaching complete.");
		whitelistIsInitializedFor["properties"] = true;
		try_to_populate_class_structure(); // will only work if all the data gatehring stages are finished
	});

	console.log("Ok, the workers are rolling. try_to_populate_class_structure() will eventually run...");
}


/* This populates the iSpyClassesByName hash so that you can do:
		iSpyClassesByName["a_class_name"]["methods"]["a_method_name"]["parameters"]["a_param_name"]["name"]
																								   ["type"], etc
        or
        iSpyClassesByName["a_class_name"]["ivars"]["ivar_name"]["name"]
        													   ["type"], etc
	It's fast to build this cache, and it's lightning fast to use it. Much more suitable than indexedDB.
	It runs immediately after the 1st stage where we extract the IndexedDB data.
*/
function try_to_populate_class_structure() {
	if( ! (	whitelistIsInitializedFor["classes"] &&
			whitelistIsInitializedFor["methods"] &&
			whitelistIsInitializedFor["properties"] &&
			whitelistIsInitializedFor["parameters"] &&
			whitelistIsInitializedFor["ivars"] ))
	{
		console.log("try_to_populate_class_structure() not ready");
		return;
	}

	console.log("try_to_populate_class_structure: Ready!");
	console.log("Parameters");
	// Add each parameter to its respective method
	for (var paramName in iSpyParametersByName) {
		parentMethodId = iSpyParametersByName[paramName]["methodId"];
		parentMethodName = iSpyMethodsById[parentMethodId]["name"];
		iSpyMethodsByName[parentMethodName]["parameters"][paramName] = iSpyParametersByName[paramName];
	}

	console.log("Methods");
	// Add each method to its respective class
	for (var methodName in iSpyMethodsByName) {
		parentClassId = iSpyMethodsByName[methodName]["classId"];
		parentClassName = iSpyClassesById[parentClassId]["name"];
		iSpyClassesByName[parentClassName]["methods"][methodName] = iSpyMethodsByName[methodName];
	};

	// Add each ivar to its respective class
	console.log("Ivars");
	for (var ivarName in iSpyIVarsByName) {
		parentClassId = iSpyIVarsByName[ivarName]["classId"];
		parentClassName = iSpyClassesById[parentClassId]["name"];
		iSpyClassesByName[parentClassName]["ivars"][ivarName] = iSpyIVarsByName[ivarName];
	};

	// Add each method to its respective class
	console.log("Properties");
	for (var propertyName in iSpyPropertiesByName) {
		parentClassId = iSpyPropertiesByName[propertyName]["classId"];
		parentClassName = iSpyClassesById[parentClassId]["name"];
		iSpyClassesByName[parentClassName]["properties"][propertyName] = iSpyPropertiesByName[propertyName];
	};

	console.log("try_to_populate_class_structure: Done. Calling UI callback function is there is one.");
	UI_callbackFunction();
}

// Return a transaction handle for the supplied store_name. 
// Mode can be "readonly" or "readwrite".
function getObjectStore(store_name, mode) {
	var tx = db.transaction(store_name, mode);
	return tx.objectStore(store_name);
}


// Get the current filesystem timestamp of the iSpy.db file
function getBundleModifiedDateFromServer() {
	// this is a BLOCKING synchronous call
	var dbModDate="";

	$.ajax({ 	
			url: "/api/dbdate",
			async: false,
			timeout: 120000, // 2 minutes
			error: function (j, t, e) {
				console.log("SJAX error fetching the DB's modification date: " + e);
			},
			success: function(result) {		
				dbModDate = result;
			}
	});			
	return dbModDate;
}


// creates a hash map of all class/method/propery/ivar data
function loadDBCache() {
	cache_all_the_things_because_indexeddb_is_fucking_horrific();
	dbIsInitialized = true;
}

function save_class_dump_html(htmlForClassDump) {
	localStorage[get_app_appBundleID() + "_htmlForClassDump"] = htmlForClassDump;
}

function load_class_dump_html() {
	return localStorage[get_app_appBundleID() + "_htmlForClassDump"];
}

// Open the database for this app and handles repopulation, caching, etc.
function openDB(callbackFunc) {
	var fatalErrorMsg = "Oi, There was an error.";
	
	console.log("openDB: Entry point.");
	
	if(callbackFunc && (typeof callbackFunc == "function"))
		UI_callbackFunction = callbackFunc;
	
	// We need HTML5 storage
	if( ! supports_html5_storage() ) {
		alert(errMsg);
		console.log(errMsg)
		return;
	}

	// eg. com.provider.applicationname
	var appBundleID = get_app_appBundleID();
	var iSpyDBVersion = localStorage[appBundleID + "_version"];
	if(iSpyDBVersion === undefined) {
		iSpyDBVersion = localStorage[appBundleID + "_version"] = 1;
	}
 
	// Check the date of our data compared to the date of the remote data
	var localBundleDate = localStorage[appBundleID + "_date"];
	var remoteBundleDate = getBundleModifiedDateFromServer();
	console.log("openDB: local date: " + localBundleDate + " // Remote date: " + remoteBundleDate);
	console.log("openDB: Using DB version: " + iSpyDBVersion);
	
	// force recreation of the DB if the remote iSpy.db is newer than our local cache
	if(localBundleDate != remoteBundleDate) {
		console.log("openDB: date mismatch. Bumping iSpyVersion in order to force refresh.");
		iSpyDBVersion++;
	}

	// try to open the DB
	console.log("openDB: calling indexedDB.open(" + appBundleID + ", " + iSpyDBVersion + ")");
	var req = indexedDB.open(appBundleID, iSpyDBVersion);
	req.onerror = function (event) {
		console.log("openDB: onerror: Error initializing the DB.");
		// Is the DB version more recent than the one we tried to open?
		if(event.target.error.name == "VersionError") {
			console.log("openDB: onerror: Needs a refresh.");
			console.log("openDB: onerror: DB Version is: " + this.result.db.version);
			localStorage[appBundleID + "_version"] = this.result.db.version + 1;
			console.log("openDB: onerror: Calling openDB() again...");
			openDB(callbackFunc);
		} else {
			console.log("openDB: onerror: DB Error: " + event.target.error);
			alert(fatalErrorMsg);
		}
		console.log("openDB: onerror: Abandon ship.");
		return;
	}

	// This will be called either (a) when the browser successfully  opens a handle to the requested version of
	// IndexedDB, or (b) after a database upgrade via "onupgradeneeded", which will trigger an "onsuccess" event.
	req.onsuccess = function (event) {
		db = this.result;
		localStorage[appBundleID + "_version"] = db.version;
		console.log("openDB: onsuccess: was called");

		// If the DB was opened successfully, populate the local browser cache of classes/methods/etc
		console.log("openDB: onsuccess: Looks good. Populating the DB cache...");
		loadDBCache();
		console.log("openDB: onsuccess: finished");
    }

	req.onupgradeneeded = function (event) {
		localStorage[get_app_appBundleID() + "_version"] = event.newVersion;
		localStorage[get_app_appBundleID() + "_htmlForClassDump"] = "";
		upgradeEvent = event;
		db = event.target.result;
		
		// refresh the data in the DB
		console.log("openDB: onupgradeneeded: calling importSQLData()")
		importSQLData(event, remoteBundleDate);
		console.log("openDB: onupgradeneeded: returned from importSQLData()");
	}
	console.log("openDB: fell off the end.");
}

// Takes JSON data and stuffs it into a browser IndexedDB.
function importSQLData(upgradeEvent, bundleDate) {
	const tables = [ "classes", "methods", "parameters", "ivars", "properties", "symbols"];

	// Delete all the tables (if they exist)
	$.each(tables, function(id) {
		if(db.objectStoreNames.contains(tables[id]))
			db.deleteObjectStore(tables[id]);
	});
	
	// Drop some log
	console.log("importSQLData: Let's do it!");
	console.log("importSQLData: Old version: " + upgradeEvent.oldVersion);
	console.log("importSQLData: New version: " + upgradeEvent.newVersion);
	console.log("importSQLData: Fetching AJAX class data...");
	
	// Do SJAX query to get JSON blob containing class/method/parameter/etc information
	$.ajax({ 	
		url: "/api/getSQLDBContent",
		async: false, // eewwwwww
		timeout: 120000, // 2 minutes
		error: function (j, t, e) {
			console.log("SJAX error: ");
			console.log(e);
			console.log(t);
			console.log(j);
		},
		success: function(result) {		
			var objectStore;
			
			console.log("importSQLData: AJAX request fired success()")
			console.log("importSQLData: Parsing JSON...");
			data = $.parseJSON(result);
			
			console.log("importSQLData: Creating object stores...");
			
			// Populate classes
			console.log("importSQLData: Adding classes");
			objectStore = upgradeEvent.currentTarget.result.createObjectStore("classes", { keyPath: "name", autoIncrement: false });
			objectStore.createIndex("id", "id", { unique: true });
			$.each(data.classes, function (id) {
				if(data["classes"][id])
					objectStore.add(data["classes"][id]);
			});
			
			// Populate methods
			console.log("importSQLData: Adding methods");
			objectStore = upgradeEvent.currentTarget.result.createObjectStore("methods", { keyPath: "id", autoIncrement: false });
			objectStore.createIndex("name", "name", { unique: false });
			objectStore.createIndex("classId", "classId", { unique: false });
			$.each(data.methods, function (id) {
				if(data["methods"][id])
					objectStore.add(data["methods"][id]);
			});
					
			// Populate parameters
			console.log("importSQLData: Adding parameters");
			objectStore = upgradeEvent.currentTarget.result.createObjectStore("parameters", { keyPath: "id", autoIncrement: false });
			objectStore.createIndex("name", "name", { unique: false });
			objectStore.createIndex("classId", "classId", { unique: false });
			objectStore.createIndex("methodId", "methodId", { unique: false });
			$.each(data.parameters, function (id) {
				if(data["parameters"][id])
					objectStore.add(data["parameters"][id]);
			});
					
			// Populate ivars
			console.log("importSQLData: Adding ivars");
			objectStore = upgradeEvent.currentTarget.result.createObjectStore("ivars", { keyPath: "id", autoIncrement: false });
			objectStore.createIndex("name", "name", { unique: false });
			objectStore.createIndex("classId", "classId", { unique: false });
			$.each(data.ivars, function (id) {
				if(data["ivars"][id])
					objectStore.add(data["ivars"][id]);
			});

			// Populate ivars
			console.log("importSQLData: Adding properties");
			objectStore = upgradeEvent.currentTarget.result.createObjectStore("properties", { keyPath: "id", autoIncrement: false });
			objectStore.createIndex("name", "name", { unique: false });
			objectStore.createIndex("classId", "classId", { unique: false });
			$.each(data.ivars, function (id) {
				if(data["properties"][id])
					objectStore.add(data["properties"][id]);
			});

			// Populate symbols
			console.log("importSQLData: Adding symbols");
			var objectStore;
			objectStore = upgradeEvent.currentTarget.result.createObjectStore("symbols", { keyPath: "id", autoIncrement: false });
			objectStore.createIndex("name", "name", { unique: false });				
			$.each(data.symbols, function (id) {
				if(data["symbols"][id])
					objectStore.add(data["symbols"][id]);
			});

			// Update database version and store the timestamp of iSpy.db on the iDevice.
			// The saved timestamp will be compared to the iDevice's version every time the browser page loads.
			// If the timestamp changes, the browser will force the local IndexedDB cache to be recreated.
			// This way, you can simply delete iSpy.db to cause the data to get refreshed across the board: the app
			// will re-examine its classes, methods, ivars, etc etc, and repopulate the iSpy.db, which will be picked
			// up by this javascript code :)
			localStorage[appBundleID + "_version"] = upgradeEvent.newVersion; //db.version;
			localStorage[appBundleID + "_date"] = bundleDate;

			console.log("importSQLData: AJAX data has finished importing into the IndexedDB");
			console.log("importSQLData: Calling openDB()");
			openDB();
		}
	});
	console.log("importSQLData: Returning.");
}




