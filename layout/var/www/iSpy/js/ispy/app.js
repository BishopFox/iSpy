/*
 *  iSpy Main Entry Point
 */

iSpy.Events.on("ispy:connection-opened", function() {

    console.log("[iSpy] Connection opened; creating views and models");

    var ios_app = new iSpy.Models.iOSApp();
    var objc_classes = new iSpy.Models.ObjcClasses();

    /* Create the main views */
    var appIndex = new iSpy.Views.iOSAppIndex({model: ios_app});
    var classBrowserIndex = new iSpy.Views.ClassBrowserIndex({model: objc_classes});
    var cycriptIndex = new iSpy.Views.CycriptIndex();

    var router = new iSpy.Router();
    Backbone.history.start();



});
