// The iOSApp Index View
// -----------------------
iSpy.Views.iOSAppIndex = Backbone.View.extend({

    el: '#page-wrapper',

    template: Handlebars.templates.iosapp,

    initialize: function() {
        console.log("[Views|iOSAppIndex] initialize");
        iSpy.Events.on('iosapp:index', this.indexEvent, this);
        this.model.on('change', this.render, this);
    },

    indexEvent: function() {
        console.log("[Views|iOSAppIndex] indexEvent fired, fecthing data for model");
        this.render();
        this.model.fetch();
    },

    render: function() {
        console.log("[Views|iOSAppIndex] Rendering template to page");
        console.log(this.model.toJSON());
        var template = this.template(this.model.toJSON());
        this.$el.html(template);
        return this;
    },

});
