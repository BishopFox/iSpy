
var ws = undefined;


function getCookie(name) {
    var value = "; " + document.cookie;
    var parts = value.split("; " + name + "=");
    if (parts.length == 2) {
        return parts.pop().split(";").shift();
    }
}

$(document).ready(function() {

    var rpc_url = "ws://" + window.location.hostname + ":" + getCookie('rpc-lport');
    console.log("[*] Connecting to json-rpc server -> " + rpc_url);

    ws = new WebSocket(rpc_url);

    ws.onopen = function() {
        console.log("[*] Successfully connected to remote rpc server!");
        $("#activity-monitor").removeClass("fa-eye-slash");
        $("#activity-monitor").addClass("fa-refresh fa-spin");
    }

    ws.onmessage = function(emit) {
        console.log(emit);
    }

    ws.onclose = function() {
        console.log("[!] Connection to server lost!");
        $("#activity-monitor").removeClass("fa-refresh fa-spin");
        $("#activity-monitor").addClass("fa-eye-slash");
    }

});
