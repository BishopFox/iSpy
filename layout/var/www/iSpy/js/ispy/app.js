/*
 *  iSpy Application
 */

iSpy.Events.on("ispy:connection-opened", function() {
    console.log("[iSpy] Connection opened, starting router");
    new iSpy.Router();
    Backbone.history.start();
});

/* Index Page */
iSpy.Events.on('router:index', function() {
    $("#context-menu").html("");
    if (window.iSpy.instances.ios_app === undefined) {
        window.iSpy.instances.ios_app = new iSpy.Models.iOSApp();
    }
    var view = new iSpy.Views.iOSAppView({model: window.iSpy.instances.ios_app});
    $("#page-content-wrapper").addClass('fadeIn');
    $("#page-content-wrapper").html(view.render().el);
    setTimeout(function() {
        $("#page-content-wrapper").removeClass('fadeIn');
    }, 500);

});

/* Class Browser */
iSpy.Events.on('router:classbrowser', function() {

    /* Bind search to context menu */
    $("#context-menu").html(Handlebars.templates.ObjcClassBrowserContextMenu());
    $("#objc-class-search").on('input', function(evt) {
        iSpy.Events.trigger('classbrowser:search', $("#objc-class-search").val());
    });

    /* Render the outer page */
    $("#page-content-wrapper").addClass('fadeIn');
    $("#page-content-wrapper").html(Handlebars.templates.ObjcClassBrowser());
    setTimeout(function() {
        $("#page-content-wrapper").removeClass('fadeIn');
    }, 500);

    /* Render the list view */
    if (window.iSpy.instances.objc_classes === undefined) {
        window.iSpy.instances.objc_classes = new iSpy.Collections.ObjcClasses();
        window.iSpy.instances.objc_classes.fetchAll();
    }

    var view = new iSpy.Views.ObjcClassList({collection: window.iSpy.instances.objc_classes});
    view.render();

});

/* Fuzzy search via fuse.js */
iSpy.Events.on('classbrowser:search', function(needle) {
    if ( !needle ) {
        var view = new iSpy.Views.ObjcClassList({collection: window.iSpy.instances.objc_classes});
        view.render();
    } else {
        var options = {
            caseSensitive: false,
            includeScore: false,
            shouldSort: true,
            threshold: 0.6,
            location: 0,
            distance: 100,
            maxPatternLength: 32,
            keys: ["attributes.name",]
        };
        var objc_classes = window.iSpy.instances.objc_classes;
        var fuse = new Fuse(objc_classes.models, options);
        var result_collection = new iSpy.Collections.ObjcClasses(fuse.search(needle));
        console.log(result_collection);
        var view = new iSpy.Views.ObjcClassList({collection: result_collection});
        view.render();
    }
});


/* 404 - Default if no route exists */
iSpy.Events.on('router:notfound', function() {
    $("#context-menu").html("");

    $("#page-content-wrapper").addClass('fadeIn');
    $("#page-content-wrapper").html(Handlebars.templates.NotFound());
    setTimeout(function() {
        $("#page-content-wrapper").removeClass('fadeIn');
    }, 500);

});

/*
 * Cycript Modal and hotkey bindings
 *
 *  This executes in the parent frame's context
 *
 */
$(document).ready(function() {

    /* Lazy load the console */
    $('#cycript-modal').on('show.bs.modal', function() {
        if ($('#cycript-frame').attr("src") === undefined) {
            console.log("Loading cycript terminal ...");
            $('#cycript-frame').attr("src", window.location.origin + "/cycript.html");
        }
    });

    /* Pressed hotkey */
    $(document).keyup(function(e) {
        if (e.keyCode === 192) {
            console.log("[Hotkey] -> Cycript");
            $("#cycript-modal").modal('toggle');
        }
    });

});
