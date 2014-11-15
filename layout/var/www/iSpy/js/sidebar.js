$(document).ready(function() {

    $("#menu-toggle").click(function(e) {
        e.preventDefault();
        $("#wrapper").toggleClass("toggled");

        if ($("#menu-toggle-lbl1").hasClass("fa-chevron-left")) {
            $("#menu-toggle-lbl1").removeClass("fa-chevron-left");
            $("#menu-toggle-lbl2").removeClass("fa-bars");
            $("#menu-toggle-lbl1").addClass("fa-bars");
            $("#menu-toggle-lbl2").addClass("fa-chevron-right");
        } else {
            $("#menu-toggle-lbl1").removeClass("fa-bars");
            $("#menu-toggle-lbl2").removeClass("fa-chevron-right");
            $("#menu-toggle-lbl1").addClass("fa-chevron-left");
            $("#menu-toggle-lbl2").addClass("fa-bars");
        }
    });

});