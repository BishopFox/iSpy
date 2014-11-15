/*
 *  iSpy Application
 */

iSpy.Events.on("ispy:connection-opened", function() {
    console.log("[iSpy] Connection opened, starting router");
    new iSpy.Router();
    Backbone.history.start();
});

iSpy.Events.on('router:index', function() {
    $("#context-menu").html("");
    var ios_app = new iSpy.Models.iOSApp();
    var view = new iSpy.Views.iOSAppView({model: ios_app});
    $("#page-content-wrapper").html(view.render().el);
});

iSpy.Events.on('router:classbrowser', function() {

    $("#context-menu").html(Handlebars.templates.ObjcClassBrowserContextMenu());

    var objc_classes = new iSpy.Collections.ObjcClasses();
    var view = new iSpy.Views.ObjcClassBrowserView({collection: objc_classes});
    $("#page-content-wrapper").html(view.render().el);
});
