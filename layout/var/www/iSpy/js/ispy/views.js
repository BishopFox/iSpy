/*
 * Application Views
 */

iSpy.Views.AppSummary = Backbone.View.extend({

    el: '#main-content',

    template: template('AppSummaryTemplate'),

    initialize: function() {
        iSpyEvents.on('appsummary:page', this.render, this);
    },

    render: function() {
        var template = this.template();
        this.$el.html(template);
        return this;
    }

});

iSpy.Views.ClassDump = Backbone.View.extend({

    el: '#main-content',

    template: template('ClassDumpTemplate'),

    initialize: function() {
        iSpyEvents.on('classdump:page', this.render, this);
    },

    render: function() {
        var template = this.template();
        this.$el.html(template);
        return this;
    }

});

iSpy.Views.NotFound = Backbone.View.extend({

    el: '#main-content',

    template: template('NotFoundTemplate'),

    initialize: function() {
        iSpyEvents.on('notfound:page', this.render, this);
    },

    render: function() {
        var template = this.template();
        this.$el.html(template);
        return this;
    }

});


/*
 * Objective-C Class
 */
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

iSpy.Views.ObjcRuntime = Backbone.View.extend({

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