/*
 * iSpy - JavaScript application
 */
(function() {

    /* iSpy Namespace */
    window.iSpy = {
        Models: {},
        Collections: {},
        Views: {},
    };

    /*
     * This is a template helper function to automatically pull the template
     * markup from the main DOM using jquery.
     */
    window.template = function(id) {
        return _.template( $('#' + id).html() );
    };


    iSpy.Models.ObjcClass = Backbone.Model.extend({

    });

    iSpy.Views.ObjcClass = Backbone.View.extend({

        tagName: 'li',

        template: template('ObjcClassTemplate'),

        events: {
        },

        render: function() {
            var template = this.template(this.model.toJSON());
            this.$el.html(template);
            return this;
        }

    });

    iSpy.Views.ObjcClasses = Backbone.View.extend({

        tagName: 'ul',

        render: function() {
            this.collection.each(this.addOne, this);
            return this;
        },

        /* Renders a single class view and appends it to the collection view */
        addOne: function(klass) {
            var klassView = new iSpy.Views.ObjcClass({ model: klass });
            this.$el.append(klassView.render().el);
        }

    });

    iSpy.Collections.ObjcClasses = Backbone.Collection.extend({
        model: iSpy.Models.ObjcClass,
    });





var klass = new iSpy.Models.ObjcClass({
    'title': 'NSString',
    size: 4
});

var klasses = new iSpy.Collections.ObjcClasses(
[
    {
        'title': 'NSString',
        size: 4
    },
    {
        'title': 'NSString',
        size: 6
    },
    {
        'title': 'NSArray',
        size: 12
    },
]);

var klassesView = new iSpy.Views.ObjcClasses({collection: klasses});
document.body.append(klassesView.render().el);


})();


$(document).ready(function() {

    /* Menu Setup */
    $.slidebars();
    jQuery('ul.nav li.dropdown').hover(function() {
        jQuery(this).find('.dropdown-menu').stop(true, true).delay(200).show();
    }, function() {
        jQuery(this).find('.dropdown-menu').stop(true, true).delay(200).hide();
    });

    /* WebSocket Setup */
    var jsonrpc_url = "ws://" + window.location.host + "/jsonrpc";
    console.log("[*] Connecting to json-rpc server -> " + jsonrpc_url);
    jsonrpc = new WebSocket(jsonrpc_url);

    /* WebSocket Opened */
    jsonrpc.onopen = function() {
        console.log("[*] Successfully connected to remote rpc server!");
        $("#activity-monitor").removeClass("fa-eye-slash");
        $("#activity-monitor").addClass("fa-refresh fa-spin");
    }

    /* WebSocket Message */
    jsonrpc.onmessage = function(emit) {
        console.log(emit);
        var msg = jQuery.parseJSON(emit.data);
        if ('messageType' in msg && msg['messageType'] == "obj_msgSend") {
            add_objc_msg(msg);
        }
    }

    /* WebSocket Closed */
    jsonrpc.onclose = function() {
        console.log("[!] Connection to server lost!");
        $("#activity-monitor").removeClass("fa-refresh fa-spin");
        $("#activity-monitor").addClass("fa-eye-slash");
    }

});