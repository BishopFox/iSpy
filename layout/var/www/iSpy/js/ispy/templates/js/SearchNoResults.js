(function() {
  var template = Handlebars.template, templates = Handlebars.templates = Handlebars.templates || {};
templates['SearchNoResults'] = template({"compiler":[6,">= 2.0.0-beta.1"],"main":function(depth0,helpers,partials,data) {
  return "<div class=\"text-center\">\n    <h4>\n        <span class=\"fa-stack fa-lg\">\n            <i class=\"fa fa-search fa-stack-1x\"></i>\n            <i class=\"fa fa-ban fa-stack-2x text-danger\"></i>\n        </span>\n        No Results\n    </h4>\n</div>";
  },"useData":true});
})();