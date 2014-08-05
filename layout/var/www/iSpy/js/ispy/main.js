var jsonrpc = undefined;

$(document).ready(function() {

    var jsonrpc_url = "ws://" + window.location.host + "/jsonrpc";
    console.log("[*] Connecting to json-rpc server -> " + jsonrpc_url);

    jsonrpc = new WebSocket(jsonrpc_url);

    jsonrpc.onopen = function() {
        console.log("[*] Successfully connected to remote rpc server!");
        //$("#activity-monitor").removeClass("fa-eye-slash");
        //$("#activity-monitor").addClass("fa-refresh fa-spin");
    }

    jsonrpc.onmessage = function(emit) {
        console.log(emit);
    }

    jsonrpc.onclose = function() {
        console.log("[!] Connection to server lost!");
        //$("#activity-monitor").removeClass("fa-refresh fa-spin");
        //$("#activity-monitor").addClass("fa-eye-slash");
    }

});