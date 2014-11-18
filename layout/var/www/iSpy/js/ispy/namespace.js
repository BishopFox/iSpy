/*
    iSpy Global Namespace
*/
window.iSpy = {
    Models: {},
    Collections: {},
    Views: {},
    Router: {},
    Events: _.extend({}, Backbone.Events),
    instances: {},
};

/* Template Helper Functions */
Handlebars.registerHelper('toHex', function(number) {
  return "0x" + parseInt(number, 10).toString(16);
});

/*
    WebSockets
*/
(function($) {

    /* WebSocket Setup within the iSpy namespace */
    var sync_url = "ws://" + window.location.host + "/jsonrpc";
    console.log("[*] Connecting to sync url -> " + sync_url);
    iSpy.SyncSocket = new WebSocket(sync_url);

    iSpy.SyncSocket.onopen = function() {
        console.log("[*] Successfully connected to remote rpc server!");
        $("#activity-monitor-log").prepend(new Date() + " - Connection established\n");
        $("#activity-monitor").removeClass("fa-eye-slash");
        $("#activity-monitor").addClass("fa-eye");
        iSpy.Events.trigger("ispy:connection-opened");
    }

    iSpy.SyncSocket.onmessage = function(emit) {
        console.log(emit);
        var message = $.parseJSON(emit.data);
        if ( ! ('status' in message)) {
            console.log("[SyncSocket] Malformed JSON message from server; no status.");
        } else if (message['status'] === "OK") {
            console.log("[SyncSocket] Trigger event 'ispy:" + message["messageType"] + "' with");
            console.log(message["JSON"]);
            iSpy.Events.trigger("sync:" + message["messageType"], message["JSON"]);
        } else if (message['status'] === "error") {
            console.log("[SyncSocket] Recieved an error: " + message["error"]);
            $("#activity-monitor-log").prepend(new Date() + " - " + $('<div/>').text(message["error"]).html() + "\n");
            iSpy.Events.trigger("ispy:error", message["error"]);
        } else {
            console.log("[SyncSocket] Malformed JSON message from server; invalid status.");
        }
    }

    iSpy.SyncSocket.onclose = function() {
        console.log("[!] Connection to server lost");
        $("#activity-monitor").removeClass("fa-plug");
        $("#activity-monitor-title").removeClass("fa-circle-o-notch fa-spin");
        $("#activity-monitor").addClass("fa-eye-slash");
        $("#activity-monitor-title").addClass("fa-warning");
        $("#activity-monitor-log").prepend(new Date() + " - Connection lost\n");
        iSpy.Events.trigger("ispy:connection-lost");
        $("#activity-monitor-modal").modal('show');
    }

})(jQuery);


/*
 *   We create our custom CRUD here. This function is only responsible for sending data
 *   to the server, iSpy.SyncSocket.onmessage is responsible for handling responses from
 *   the server, which may or may not have been triggered by a request sent from here.
 */
Backbone.sync = function(method, model, options) {
    //console.log("[Backbone|Sync] " + method + "|" + model + "|" + options);
    if (method === "read") {
        for (var index = 0; index < model.rpcRead.length; ++index) {
            var readMessage = model.rpcRead[index];
            readMessage['operation'] = method;
            console.log("[Backone.Sync:Read] -> " + JSON.stringify(readMessage));
            iSpy.SyncSocket.send(JSON.stringify(readMessage));
        }
    }

};
