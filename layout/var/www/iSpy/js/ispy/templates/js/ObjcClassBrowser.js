(function() {
  var template = Handlebars.template, templates = Handlebars.templates = Handlebars.templates || {};
templates['ObjcClassBrowser'] = template({"compiler":[6,">= 2.0.0-beta.1"],"main":function(depth0,helpers,partials,data) {
  return "<h1 class=\"page-header\">\n    <i class=\"fa fa-fw fa-code\"></i>\n    Class Browser\n</h1>\n<div class=\"row\">\n    <div id=\"objc-class-list\" class=\"list-group col-md-4\">\n        <p class=\"text-center\">\n            <i class=\"fa fa-fw fa-refresh fa-spin\"></i>\n            Loading ...\n        </p>\n    </div>\n    <div id=\"\" class=\"col-md-8\">\n    </div>\n</div>";
  },"useData":true});
})();