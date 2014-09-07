// The Cycript Index View
// -----------------------
iSpy.Views.CycriptIndex = Backbone.View.extend({

    el: '#page-wrapper',

    template: mktemplate("cycript-index"),

    initialize: function() {
        console.log("[Views|CycriptIndex] initialize");
        iSpy.Events.on('cycript:index', this.render, this);
    },

    render: function() {
        console.log("[Views|CycriptIndex] Rendering template to page");
        var template = this.template();
        this.$el.html(template);
        $("#butterflyWrapper").attr("command", decodeURIComponent(document.location.search.substring(1)));
        return this;
    },

});
