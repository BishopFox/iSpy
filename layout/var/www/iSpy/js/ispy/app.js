/*
 *  iSpy Application
 */


// Helper function to add a pretty CSS3 fade
function renderViewWithFade(view) {
    $("#page-content-wrapper").addClass('fadeIn');
    $("#page-content-wrapper").html(view.render().el);
    setTimeout(function() {
        $("#page-content-wrapper").removeClass('fadeIn');
    }, 500);
}

function renderTemplateWithFade(template) {
    $("#page-content-wrapper").addClass('fadeIn');
    $("#page-content-wrapper").html(template());
    setTimeout(function() {
        $("#page-content-wrapper").removeClass('fadeIn');
    }, 500);
}


iSpy.Events.on("ispy:connection-opened", function() {
    console.log("[iSpy] Connection opened, starting router");
    new iSpy.Router();
    Backbone.history.start();
});

/* Index Page */
iSpy.Events.on('router:index', function() {
    $("#context-menu").html("");
    var view = new iSpy.Views.iOSAppView({model: window.iSpy.instances.ios_app});
    renderViewWithFade(view);
});

/* Class Browser */
iSpy.Events.on('router:classbrowser', function() {
    /* Bind search to context menu */
    $("#context-menu").html(Handlebars.templates.ObjcClassBrowserContextMenu());
    $("#objc-class-search").on('input', function(evt) {
        iSpy.Events.trigger('classbrowser:search', $("#objc-class-search").val());
    });

    /* Render the outer template and the ClassList view */
    renderTemplateWithFade(Handlebars.templates.ObjcClassBrowser);
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
            threshold: 0.4,
            location: 0,
            distance: 100,
            maxPatternLength: 32,
            keys: ["attributes.name",]
        };
        var fuse = new Fuse(window.iSpy.instances.objc_classes.models, options);
        var result_collection = new iSpy.Collections.ObjcClasses(fuse.search(needle));
        if (0 < result_collection.length) {
            var view = new iSpy.Views.ObjcClassList({collection: result_collection});
            view.render();
        } else {
            $("#objc-class-list").html(Handlebars.templates.SearchNoResults());
        }
    }
});

/* View class */
iSpy.Events.on('classbrowser:viewclass', function(class_name) {
    $("#context-menu").html("");
    var model = new iSpy.Models.ObjcClass({name: class_name});
    model.fetch();

    renderViewWithFade(view);
});


/* File Browser */
iSpy.Events.on('router:filebrowser', function() {
    $("#context-menu").html("");
    var view = new iSpy.Views.FileBrowserView();
    renderViewWithFade(view);
});

/* 404 - Default if no route exists */
iSpy.Events.on('router:notfound', function() {
    renderTemplateWithFade(Handlebars.templates.NotFound);
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
