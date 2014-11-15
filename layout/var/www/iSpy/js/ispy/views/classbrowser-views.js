


iSpy.Views.ObjcClassBrowserView = Backbone.View.extend({

    tagName: 'div',

    template: Handlebars.templates.ObjcClassBrowser,

    initialize: function() {
        this.collection.on('classListChange', this.render, this);
    },

    render: function() {
        /*
        this.collection.each(function(objcClass) {
            var objcClassView = new iSpy.Views.ObjcClassListView({model: objcClass});
            this.$el.append(objcClassView.render().el);
        }, this);
        */
        var template = this.template({'objc_classes': this.collection.toJSON()});
        this.$el.html(template);
        return this;
    },

});

iSpy.Views.ObjcClassListView = Backbone.View.extend({

    tagName: 'div',

    template: Handlebars.templates.ObjcClassListItem,

    render: function() {
        var template = this.template(this.model.toJSON());
        this.$el.html(template);
        return this;
    },
});
