require! {
  fs
  ribcage
  ejs
  'child_process': { exec }
  leshdash: { values }
  lweb3: lweb
  'lweb3/transports/server/nssocket': { nssocketServer }
}

env = do
  settings:

    template: './configFile.ejs'
    config: '/etc/nginx/cluster.conf'
    reload: 'sudo systemctl reload nginx.service'
    
    port: 2010
    
    verboseInit: true
    
    module:
      logger:
        addContext:
          tags:
            module: "nginxCluster"
            
        outputs:
          Console: { }
          
ribcage.init env, (err,env) ->
  log = env.log
  
  server = new nssocketServer port: env.settings.port
  server.addProtocol new lweb.protocols.query.serverServer!

  log 'listening at ' + env.settings.port, {}, 'init', 'ok'

  servers = { }

  template = String fs.readFileSync env.settings.template
  
  renderConfig = ->
    content = ejs.render template, servers: values servers
    fs.writeFileSync env.settings.config, content
    exec env.settings.reload, (error,stdout,stderr) ->
      if error then return log "error reloading nginx: #{ String error }", {}, "error"
      if stderr then return log "error reloading nginx: #{ stderr }", {}, "error"
      log "nginx reloaded", {}, "reload"
  
  server.onQuery add: true, (msg, reply, { client }) ->
    data = msg.add
    log "add web server: #{ data.name }", {}, 'addServer'
    reply.end add: 'ok'

    servers[ data.name ] = data
    
    renderConfig()
    #client.addProtocol new lweb.protocols.query.client!    
    #client.query ping: new Date().getTime(), (msg) -> true
    
    client.once 'end', ->
      log "del server: #{ data.name }", {}, 'delServer'
      delete servers[ data.name ]
      renderConfig()  
