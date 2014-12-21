// iSpy Router
// ----------
iSpy.Router = Backbone.Router.extend({

    routes: {
        '': 'index',
        'iosapp': 'iosApp',
        'classbrowser': 'classBrowser',
        'classbrowser/:className': 'viewClass',
        'filebrowser': 'fileBrowser',
        '*other': 'notfound',
    },

    index: function() {
        this.iosApp();
    },

    iosApp: function() {
        if (window.iSpy.instances.ios_app === undefined) {
            window.iSpy.instances.ios_app = new iSpy.Models.iOSApp();
        }
        console.log("[Router] -> iOSApp");
        iSpy.Events.trigger('router:index');
    },

    classBrowser: function() {
        if (window.iSpy.instances.objc_classes === undefined) {
            window.iSpy.instances.objc_classes = new iSpy.Collections.ObjcClasses();
            window.iSpy.instances.objc_classes.fetchAll();
        }
        console.log("[Router] -> Class Browser");
        iSpy.Events.trigger('router:classbrowser');
    },

    viewClass: function(className) {
        if (window.iSpy.instances.objc_classes === undefined) {
            window.iSpy.instances.objc_classes = new iSpy.Collections.ObjcClasses();
            window.iSpy.instances.objc_classes.fetchAll();
        }
        console.log("[Router] -> View Class");
        iSpy.Events.trigger('classbrowser:viewclass', className);
    },

    fileBrowser: function() {
        console.log("[Router] -> FileBrowser");
        iSpy.Events.trigger('router:filebrowser');
    },

    notfound: function(other) {
        console.log("[Router] -> Not Found");
        iSpy.Events.trigger('router:notfound', other);
    },

});

