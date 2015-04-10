Package.describe({
  'summary': 'Meteor account login via LDAP',
  'version': '0.4.0',
  'git' : 'https://github.com/tdamsma/meteor-accounts-ldap',
  'name' : 'meteor-accounts-ldap'
});

Npm.depends({'activedirectory' : '0.6.3' , 'connect' : '2.19.3'});

Package.on_use(function (api) {
  api.use(['coffeescript','routepolicy', 'webapp'], 'server');
  api.use(['accounts-base', 'underscore'], ['client', 'server']);
  api.imply('accounts-base', ['client', 'server']);
  //api.use('srp', ['client_functions', 'server']);
  api.use(['ui', 'templating', 'jquery', 'spacebars'], 'client');
  api.export('LDAP','server');
  api.add_files([
    'ldap_client.html',
    'ldap_client.js'], 'client');
  api.add_files('ldap_server.coffee', 'server');
});
