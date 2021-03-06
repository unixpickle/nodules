path = require 'path'
fs = require 'fs'

class ProcessLogger
  constructor: (@dir, @stream, @streamName, @info) ->
    @startDate = new Date().toString()
    @stream.on 'data', (data) => @handleData data
    @stream.on 'close', => @handleClose()
    @output = null
      
  getOutputPath: -> path.join @dir, "#{@streamName}.log.#{@startDate}.txt"
    
  handleData: (data) ->
    if not @output?
      @output = fs.createWriteStream @getOutputPath()
      @output.on 'error', (e) =>
        console.log 'error on log file: ' + e.toString()
        @output = null
      @output.on 'open', => chownWithInfo @getOutputPath(), @info
    @output.write data
  
  handleClose: ->
    @output?.end?()
    @stream = null
  
  cancel: ->
    @handleClose()
    @output = null

exports.ProcessLogger = ProcessLogger
exports.logProcess = (task, info) ->
  if info.logstreams.length is 0
    # we don't want the process streams to buffer internally
    task.stderr.on 'data', ->
    task.stdout.on 'data', -> 
    return
  
  logDir = info.path
  fullPath = path.join logDir, 'log'
  createIfNotExists fullPath, info, (err) ->
    return console.log err if err?
    if 'stderr' in info.logstreams
      new ProcessLogger fullPath, task.stderr, 'stderr', info
    else task.stderr.on 'data', (d) -> # prevent internal buffering
    if 'stdout' in info.logstreams
      new ProcessLogger fullPath, task.stdout, 'stdout', info
    else task.stdout.on 'data', -> # prevent internal buffering

createIfNotExists = (path, info, cb) ->
  fs.exists path, (exists) ->
    if exists then cb null
    else
      fs.mkdir path, (err) ->
        return cb err if not (info.uid? or info.gid?) or err?
        chownWithInfo path, info, cb

chownWithInfo = (path, info, cb) ->
  ownerUID = info.uid ? process.getuid()
  ownerGID = info.gid ? process.getgid()
  fs.chown path, ownerUID, ownerGID, cb
