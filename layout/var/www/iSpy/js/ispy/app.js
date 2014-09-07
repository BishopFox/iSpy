/*
 *  iSpy Main Entry Point
 */

iSpy.Events.on("ispy:connection-opened", function() {

    console.log("[iSpy] Connection opened; creating views and models");

    var ios_app = new iSpy.Models.iOSApp();

    /* Create the main views */
    new iSpy.Views.iOSAppIndex({model: ios_app});
    new iSpy.Views.ClassDumpIndex();
    new iSpy.Views.CycriptIndex();

    new iSpy.Router();
    Backbone.history.start();

});
