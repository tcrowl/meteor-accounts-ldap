Package.describe({
  'summary': 'Meteor account login via LDAP using activedirectory.js',
  'version': '0.1.4',
  'git' : 'https://github.com/tdamsma/meteor-accounts-ldap',
  'name' : 'tdamsma:meteor-accounts-ldap'
});

Npm.depends({'activedirectory' : '0.7.0'});

Package.on_use(function (api) {
  api.use(['coffeescript'], 'server');
  api.use(['accounts-base'], ['client', 'server']);
  api.imply('accounts-base', ['client', 'server']);
  api.use(['templating','jquery'], 'client');
  api.add_files([
    'ldap_client.html',
    'ldap_client.js'], 'client');
  api.add_files('ldap_server.coffee', 'server');
});
