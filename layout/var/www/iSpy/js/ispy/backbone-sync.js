/*
    We create our custom CRUD here. This function is only responsible for sending data
    to the server, iSpy.SyncSocket.onmessage is responsible for handling responses from
    the server, which may or may not have been triggered by a request sent from here.
*/
Backbone.sync = function(method, model, options) {
    console.log("[Sync] method: " + method + " model: " + model + "options: " + options);
    iSpy.SyncSocket.send();
};
