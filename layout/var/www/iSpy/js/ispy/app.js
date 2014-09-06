(function() {
    'use strict';

    // kick things off by creating the `iSpy`
    new iSpy.Views.iOSAppIndex();
    new iSpy.Views.ClassDumpIndex();

    new iSpy.Router();
    Backbone.history.start();

})();