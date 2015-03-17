getNick = require 'app/util/nick'
_ = require 'lodash'

###*
 * Load file with given id into RealtimeManager instance.
 *
 * @param {RealtimeManager} manager
 * @param {string} id - file id to load
 * @param {function(err: object, result: object)} callback - to be called with loaded document.
###
loadCollaborationFile = (manager, id, callback) ->

  options = { id, preventEvent: yes }

  manager.getFile id, (err, doc) ->
    return callback err  if err

    manager.setRealtimeDoc doc
    manager.isReady = yes
    callback null, doc


###*
 * Creates a file in RealtimeManager instance with given title.
 *
 * @param {RealtimeManager} manager
 * @param {string} title
 * @param {function(err: object, result: object)} callback
###
createCollaborationFile = (manager, title, callback) ->

  options = { title, preventEvent: yes }

  manager.createFile title, (err, file) ->
    return callback err  if err

    callback null, file


###*
 * Deletes a file in RealtimeManager instance with given title.
 *
 * @param {RealtimeManager} manager
 * @param {string} title
 * @param {function(err: object)} callback
###
deleteCollaborationFile = (manager, title, callback) ->

  options = { title, preventEvent: yes }

  manager.deleteFile options, (err) ->
    if err
    then callback err
    else callback null


###*
 * Checks if the given RealtimeManager instance has an active session.
 *
 * @param {RealtimeManager} manager
 * @param {string} title
 * @param {function(isActive: boolean)} callback
###
isSessionActive = (manager, title, callback) ->

  options = { title, preventEvent: yes }

  manager.fetchFileByTitle options, (err, file) ->
    return callback no  if err

    if file.result.items.length > 0
    then callback yes, file.result.items[0]
    else callback no


###*
 * Returns the identifier of a file with given SocialChannel id.
 *
 * TODO: this method needs to return different results
 *       depending on the status of a user
 *       if he/she is a host or not.
 *
 * @param {string} id
 * @return {string} fileId
###
getFileIdentifier = (id) -> "#{getNick()}.#{id}"


###*
 * Returns a user, index tuple for given predicate value
 * from participants.
 *
 * Example:
 *     sessionId = 'xyz'
 *     {targetUser} = getTargetUser rtm, 'sessionId', sessionId
 *
 * @param {(object|Array)} participants
 * @param {string} field
 * @param {string} predicateValue
###
getTargetUser = (participants, field, predicateValue) ->

  targetIndex  = null
  targetUser   = null
  participants = participants.asArray()  if participants.asArray?

  for p, index in participants when p?[field] is predicateValue
    targetIndex = index
    targetUser  = p.nickname
    break

  return { targetUser, targetIndex }


###*
 * Returns an object with the necessary google drive maps and lists are set.
 *
 * TODO: `initialSnapshot` may be irrelevant here.
 *
 * @param {RealtimeManager} manager
 * @param {string} channelId
 * @param {object} initialSnapshot
###
getReferences = (manager, channelId, initialSnapshot) ->

  nickname          = getNick()
  watchMapName      = "#{nickname}WatchMap"
  snapshotName      = "#{nickname}Snapshot"
  defaultPermission = { default: 'edit' }

  refs =
    participants      : getFromManager manager, 'participants', 'list', []
    changes           : getFromManager manager, 'changes', 'list', []
    permissions       : getFromManager manager, 'permissions', 'map', {}
    broadcastMessages : getFromManager manager, 'broadcastMessages', 'list', []
    pingTime          : getFromManager manager, 'pingTime', 'list', []
    watchMap          : getFromManager manager, watchMapName, 'map', {}
    snapshot          : getFromManager manager, snapshotName, 'map', initialSnapshot

  manager.bindRealtimeListeners refs.changes, 'list'
  manager.bindRealtimeListeners refs.broadcastMessages, 'list'
  manager.bindRealtimeListeners refs.watchMap, 'map'
  manager.bindRealtimeListeners refs.permissions, 'map'

  return refs


###*
 * Returns the collection from RealtimeManager instance with given name.
 * If collection is not created, this function will try to create a new
 * collection with given `defaultType` and `defaultValue` parameters.
 * If you are not gonna pass those values make sure that collection with the
 * given name is present.
 *
 * Example:
 *     # get collection syntax:
 *     participants = getFromManager rtm, 'participants'
 *     # get collection with default values in case that collection does not exist.
 *     participants = getFromManager rtm, 'participants', 'list', []
 *
 * @param {RealtimeManager} manager
 * @param {string} name
 * @param {string} defaultType - for now just 'list' and 'map'
 * @param {(object|Array)} - array for 'list', object for 'map'
 * @return {object} collection
###
getFromManager = (manager, name, defaultType, defaultValue) ->

  collection   = manager.getFromModel name
  collection or= manager.create defaultType, name, defaultValue

  return collection


###*
 * Updates logged in user's participant representation
 * from collaborators collection from RealtimeManager instance.
 *
 * @param {RealtimeManager} manager
 * @param {object} participants
###
registerCollaborationSessionId = (manager, participants) ->

  collaborators = manager.getCollaborators()
  for collaborator in collaborators when collaborator.isMe
    for user, index in participants.asArray() when user.nickname is getNick()
      newData = _.assign {}, user
      newData.sessionId = collaborator.sessionId
      participants.remove index
      participants.insert index, newData
      break


###*
 * Removes a user with given nickname from manager's participants collection.
 *
 * @param {object} participants
 * @param {string} nickname
 * @api private
###
removeParticipantFromParticipantList = (participants, nickname) ->

  return console.warn 'participants is not set'  unless participants

  for p, index in participants.asArray() when p.nickname is nickname
    participants.remove index
    break


###*
 * Removes a user with given nickname from maps of RealtimeManager instance.
 *
 * @param {RealtimeManager} manager
 * @param {string} nickname
 * @api private
###
removeParticipantFromMaps = (manager, nickname) ->

  myWatchMapName = "#{nickname}WatchMap"
  mySnapshotName = "#{nickname}Snapshot"

  manager.delete 'map', myWatchMapName
  manager.delete 'map', mySnapshotName


###*
 * Removes a user with given nickname from
 * participant map of RealtimeInstance.
 *
 * @param {object} permissions
 * @param {string} nickname
 * @api private
###
removeParticipantFromPermissions = (permissions, nickname) ->

  permissions.delete nickname


###*
 * Removes user with given nickname from manager and references.
 *
 * @param {RealtimeManager} permissions
 * @param {object} references - collections of collaboration.
 * @param {string} nickname
 * @api private
###
removeFromManager = (manager, references, nickname) ->

  removeParticipantFromParticipantList references.participants, nickname
  removeParticipantFromMaps manager, nickname
  removeParticipantFromPermissions references.permissions, nickname


###*
 * Ensures that given user with name and index is removed
 * from given participants list.
 *
 * @param {Object} participants
 * @param {string} nickname
 * @param {number} index
###
ensureParticipantLeft = (participants, nickname, index) ->

  # check the user is still at same index, so we won't remove someone else.
  user = participants.get index

  if user.nickname is nickname
    participants.remove index
  else
    # TODO: this part doesn't solve the problem.
    # Needs improvement. ~Umut
    for p, index in participants.asArray() when p.nickname is nickname
      participants.remove index


module.exports = {
  loadCollaborationFile
  createCollaborationFile
  deleteCollaborationFile
  isSessionActive
  getFileIdentifier
  getReferences
  registerCollaborationSessionId
  getTargetUser
  removeFromManager
  ensureParticipantLeft
}
