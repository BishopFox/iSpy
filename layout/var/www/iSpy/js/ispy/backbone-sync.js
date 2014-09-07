/*
 *   We create our custom CRUD here. This function is only responsible for sending data
 *   to the server, iSpy.SyncSocket.onmessage is responsible for handling responses from
 *   the server, which may or may not have been triggered by a request sent from here.
 */

Backbone.sync = function(method, model, options) {

    console.log("[Backone.Sync] method | model | options ");
    console.log(method);
    console.log(model);
    console.log(options);

    if (method === "read") {
        var readMessage = JSON.stringify(model.rpcRead);
        console.log("[Backone.Sync:Read] -> " + readMessage);
        iSpy.SyncSocket.send(readMessage);
    }

};
