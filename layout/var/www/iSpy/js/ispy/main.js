var jsonrpc = undefined;
var msgSendState = false;

var enableMsgSend = {
    "messageType":"setMsgSendLoggingState",
    "messageData": {
        "state":"true"
    },
    "responseId":"response31337"
}

var disableMsgSend = {
    "messageType":"setMsgSendLoggingState",
    "messageData": {
        "state":"false"
    },
    "responseId":"response31337"
}

function escapeHtml(value) {
    return $('<div/>').text(value).html();
}

function add_objc_msg(msg) {
    argmsg = "";
    if ('args' in msg) {
        for (index = 0; index < msg.args.length; ++index) {
            argmsg = msg.args[index]['type'] + ": " + msg.args[index]['name'] + "<" + msg.args[index]['addr'] + ">";
            msgsend += argmsg + ", ";
        }
    }
    methodType = msg['isInstanceMethod'] ? "- ":"+ ";
    $('#objc-msg-send-table').prepend(
        $("<tr/>").append(
            $("<td/>").text($('#objc-msg-send-table tr').length + 1)
        ).append(
            $("<td/>").text(msg['class'])
        ).append(
            $("<td/>").text(methodType + msg['method'])
        ).append(
            $("<td/>").text(argmsg)
        ).append(
            $("<td/>").text("(" + msg['returnValue']['type'] + ")" + msg['returnValue']['value'])
        )
    );
}

$(document).ready(function() {

    $("#btnMsgSendState").click(function() {
        if (msgSendState) {
            jsonrpc.send(JSON.stringify(disableMsgSend));
            msgSendState = false;
        } else {
            jsonrpc.send(JSON.stringify(enableMsgSend));
            msgSendState = true;
        }

    });

    var jsonrpc_url = "ws://" + window.location.host + "/jsonrpc";
    console.log("[*] Connecting to json-rpc server -> " + jsonrpc_url);

    jsonrpc = new WebSocket(jsonrpc_url);

    jsonrpc.onopen = function() {
        console.log("[*] Successfully connected to remote rpc server!");
        $("#activity-monitor").removeClass("fa-eye-slash");
        $("#activity-monitor").addClass("fa-refresh fa-spin");
        console.log("[*] Sending the enableMsgSend message ...");

    }

    jsonrpc.onmessage = function(emit) {
        console.log(emit);
        var msg = jQuery.parseJSON(emit.data);
        if ('messageType' in msg && msg['messageType'] == "obj_msgSend") {
            add_objc_msg(msg);
        }
    }

    jsonrpc.onclose = function() {
        console.log("[!] Connection to server lost!");
        $("#activity-monitor").removeClass("fa-refresh fa-spin");
        $("#activity-monitor").addClass("fa-eye-slash");
    }

});