/*
    iSpy Global Namespace
*/
window.iSpy = {
    Models: {},
    Collections: {},
    Views: {},
    Router: {},
    Events: _.extend({}, Backbone.Events),
};

(function($) {

    /* WebSocket Setup within the iSpy namespace */
    var sync_url = "ws://" + window.location.host + "/jsonrpc";
    console.log("[*] Connecting to sync url -> " + sync_url);
    iSpy.SyncSocket = new WebSocket(sync_url);

    iSpy.SyncSocket.onopen = function() {
        console.log("[*] Successfully connected to remote rpc server!");
        $("#activity-monitor").removeClass("fa-eye-slash");
        $("#activity-monitor").addClass("fa-refresh fa-spin");
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
            console.log("[SyncSocket] Recieved an error message: " + JSON.stringify(message["JSON"]));
            iSpy.Events.trigger("ispy:error", message["JSON"]);
            alert("ERROR: "+ message["JSON"]);
        } else {
            console.log("[SyncSocket] Malformed JSON message from server; invalid status.");
        }
    }

    iSpy.SyncSocket.onclose = function() {
        console.log("[!] Connection to server lost!");
        $("#activity-monitor").removeClass("fa-refresh fa-spin");
        $("#activity-monitor").addClass("fa-eye-slash");
        iSpy.Events.trigger("ispy:connection-lost");
    }

})(jQuery);

/* Little helper template function */
window.mktemplate = function(id) {
    return _.template( $('#' + id).html() );
};
