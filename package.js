Package.describe({
  'summary': 'Meteor account login via LDAP using activedirectory.js',
  'version': '0.1.1',
  'git' : 'https://github.com/kevinbrowntech/meteor-accounts-ldap',
  'name' : 'tdamsma:meteor-accounts-ldap'
});

Npm.depends({'activedirectory' : '0.6.3' , 'connect' : '2.19.3'});

Package.on_use(function (api) {
  api.use(['coffeescript@1.0.6','routepolicy@1.0.5', 'webapp@1.2.0'], 'server');
  api.use(['accounts-base@1.2.0', 'underscore@1.0.3'], ['client', 'server']);
  api.imply('accounts-base', ['client', 'server']);
  //api.use('srp', ['client_functions', 'server']);
  api.use(['ui@1.0.6', 'templating@1.1.1', 'jquery@1.11.3_2', 'spacebars@1.0.6'], 'client');
  //api.export('LDAP','server');
  api.add_files([
    'ldap_client.html',
    'ldap_client.js'], 'client');
  api.add_files('ldap_server.coffee', 'server');
});
