/*
 * Application
 */
iSpy.Models.App = Backbone.Model.extend({
    defaults: {
        classdump: [],
        
    },


});

/*
 * Objective-C
 */
iSpy.Models.ObjcClass = Backbone.Model.extend({
    defaults: {
        name: null,
        methods: [],
        properties: [],
        ivars: [],
    },


});

iSpy.Models.ObjcMethod = Backbone.Model.extend({
    defaults: {
        instanceMethod: false,
        parameters: [],
    },


});
