ActiveDirectory = Npm.require('activedirectory');
Future = Npm.require('fibers/future')
assert = Npm.require('assert')

if !Meteor.settings.ldap
  throw new Error('"ldap" not found in Meteor.settings')

class UserQuery
  constructor: (username) -> 
    @ad = ActiveDirectory({
      url: Meteor.settings.ldap.url,
      baseDN: Meteor.settings.ldap.baseDn,
      username: Meteor.settings.ldap.bindCn,
      password: Meteor.settings.ldap.bindPassword
      attributes: {
        user: ["dn"].concat(Meteor.settings.ldap.autopublishFields),
        },
      tlsOptions: Meteor.settings.ldap.tlsOptions || {}
       });
    @username = @sanitize_for_search(username)

  sanitize_for_search: (s) ->
    # Escape search string for LDAP according to RFC4515
    s = s.replace('\\', '\\5C')
    s = s.replace('\0', '\\00')
    s = s.replace('*','\\2A' )
    s = s.replace('(','\\28' )
    s = s.replace(')','\\29' )
    return s

  findUser: () -> 
    userFuture = new Future
    username = @username

    @ad.findUser @username, (err, userObj) ->
      if err
        if Meteor.settings.ldap.debug
          console.log 'ERROR: ' + JSON.stringify(err)
        userFuture.return false
        return
      if !userObj
        if Meteor.settings.ldap.debug
          console.log 'User: ' + username + ' not found.'
        userFuture.return false
      else
        if Meteor.settings.ldap.debug
          console.log JSON.stringify(userObj)
        userFuture.return userObj

    userObj = userFuture.wait()
    if not userObj
      throw new (Meteor.Error)(403, 'Invalid username') 
    
    @userObj = userObj
  
  authenticate: (password) ->
    authenticateFuture = new Future
    @ad.authenticate @userObj.dn, password, (err, auth) ->
      if err
        if Meteor.settings.ldap.debug
          console.log 'ERROR: ' + JSON.stringify(err)
        authenticateFuture.return false
        return
      if auth
        if Meteor.settings.ldap.debug
          console.log 'Authenticated!'
        authenticateFuture.return true
      else
        if Meteor.settings.ldap.debug
          console.log 'Authentication failed!'
        authenticateFuture.return false 
      return
    success = authenticateFuture.wait() 
    if not success or password == ''
      throw new (Meteor.Error)(403, 'Invalid credentials')
    @authenticated = success
    return success

  getGroupMembershipForUser: () ->
    groupsFuture = new Future
    @ad.getGroupMembershipForUser @userObj.dn, (err, groups) ->
      if err
        console.log('ERROR: ' +JSON.stringify(err));
        groupsFuture.return false
        return 
      if not groups
        console.log('User: ' + @userObj.dn + ' not found.')
        groupsFuture.return false
      else 
        if Meteor.settings.ldap.debug
          console.log('Groups found for ' + @userObj.dn + ': '+ JSON.stringify(groups))
        groupsFuture.return groups
      return
    return groupsFuture.wait()

  isUserMemberOf: (groupName) ->
    isMemberFuture = new Future
    @ad.isUserMemberOf @userObj.dn, groupName, (err, isMember) ->
      if err
        console.log 'ERROR: ' + JSON.stringify(err)
        isMemberFuture.return false
        return
      if Meteor.settings.ldap.debug
        console.log @userObj.displayName + ' isMemberOf ' + groupName + ': ' + isMember
      isMemberFuture.return isMember
      return
    return isMemberFuture.wait()

  queryMembershipAndAddToMeteor: (callback) ->
    for groupName in Meteor.settings.ldap.groupMembership
        ad = @ad
        userObj = @userObj
        do (groupName) ->
          ad.isUserMemberOf userObj.dn, groupName, (err, isMember) ->
            do (groupName) ->
              if err
                if Meteor.settings.ldap.debug
                  console.log 'ERROR: ' + JSON.stringify(err)
              else
                if Meteor.settings.ldap.debug
                  console.log userObj.dn + ' isMemberOf ' + groupName + ': ' + isMember
                callback(groupName,isMember)


Accounts.registerLoginHandler 'ldap', (request) ->
  return undefined if !request.ldap

  # 1. create query
  user_query = new UserQuery(request.username)
  if Meteor.settings.ldap.debug
    console.log 'LDAP authentication for ' + request.username

  user_query.findUser() # Allows both sAMAccountName and email

  # 2. authenticate user
  authenticated = user_query.authenticate(request.pass)
  if Meteor.settings.ldap.debug
    console.log('* AUTHENTICATED:',authenticated)

  # 3. update database
  userId = undefined
  userObj = user_query.userObj
  userObj.username = request.username
  user = Meteor.users.findOne(dn: userObj.dn)
  if user
    userId = user._id
    Meteor.users.update userId, $set: userObj
  else
    userId = Meteor.users.insert(userObj)
  if Meteor.settings.ldap.autopublishFields
    Accounts.addAutopublishFields
      forLoggedInUser: Meteor.settings.ldap.autopublishFields
      forOtherUsers: Meteor.settings.ldap.autopublishFields
  stampedToken = Accounts._generateStampedLoginToken()
  hashStampedToken = Accounts._hashStampedToken(stampedToken)
  Meteor.users.update userId, $push: 'services.resume.loginTokens': hashStampedToken
  
  # 4. update membership of groups (asynchronously, as this can be really slow)
  user_query.queryMembershipAndAddToMeteor Meteor.bindEnvironment (groupName,isMember) ->
    if isMember
      Meteor.users.update userId, $addToSet: 'memberOf': groupName
      Meteor.users.update userId, $pull: 'notMemberOf': groupName
    else
      Meteor.users.update userId, $pull: 'memberOf': groupName
      Meteor.users.update userId, $addToSet: 'notMemberOf': groupName

  {
    userId: userId
    token: stampedToken.token
    tokenExpires: Accounts._tokenExpiration(hashStampedToken.when)
  }
