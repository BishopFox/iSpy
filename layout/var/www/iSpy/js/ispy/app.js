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
    var ios_app = new iSpy.Models.iOSApp();
    var view = new iSpy.Views.iOSAppView({model: ios_app});
    $("#page-content-wrapper").addClass('fadeIn');
    $("#page-content-wrapper").html(view.render().el);
    setTimeout(function() {
        $("#page-content-wrapper").removeClass('fadeIn');
    }, 500);

});

/* Class Browser */
iSpy.Events.on('router:classbrowser', function() {

    $("#context-menu").html(Handlebars.templates.ObjcClassBrowserContextMenu());

    var objc_classes = new iSpy.Collections.ObjcClasses();

    var view = new iSpy.Views.ObjcClassBrowserView({collection: objc_classes});

    $("#page-content-wrapper").addClass('fadeIn');
    $("#page-content-wrapper").html(view.render().el);

    setTimeout(function() {
        $("#page-content-wrapper").removeClass('fadeIn');
    }, 500);

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