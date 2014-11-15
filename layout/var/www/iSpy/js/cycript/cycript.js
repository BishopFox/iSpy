/*
 * Cycript Modal and hotkey bindings
 *
 *  This executes in the parent frame's context
 *
 */
$(document).ready(function() {

    /* Lazy load the console */
    $('#cycript-modal').on('show.bs.modal', function() {
        if ($('#cycript-frame').attr("src") === undefined) {
            console.log("Loading cycript terminal ...");
            $('#cycript-frame').attr("src", window.location.origin + "/cycript.html");
        }
    });

    /* Pressed hotkey */
    $(document).keyup(function(e) {
        if (e.keyCode === 192) {
            console.log("[Hotkey] -> Cycript");
            $("#cycript-modal").modal('toggle');
        }
    });

});