(function() {
    'use strict';

    /* Create the main views */
    new iSpy.Views.iOSAppIndex();
    new iSpy.Views.ClassDumpIndex();

    /* Fire up the router */
    new iSpy.Router();
    Backbone.history.start();

})();