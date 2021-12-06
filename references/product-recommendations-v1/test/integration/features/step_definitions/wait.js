//* jslint node: true */
'use strict';

module.exports = function () {

  this.Given(/^I wait (.*) milli-seconds$/, function(ms, callback) {
    setTimeout(function() { callback(); }, ms);
  });
};