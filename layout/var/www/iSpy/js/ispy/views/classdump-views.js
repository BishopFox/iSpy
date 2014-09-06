// The Class Index View
// -----------------------
iSpy.Views.ClassDumpIndex = Backbone.View.extend({

    el: '#page-wrapper',

    template: mktemplate("classdump-index"),

    initialize: function() {
        iSpyEvents.on('classdump:index', this.render, this);
    },

    render: function() {
        var template = this.template();
        console.log("Rendering ClassDumpIndex: " + template);
        this.$el.html(template);
        return this;
    },

});