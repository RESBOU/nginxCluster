require! {
  randomlisten
  fs
  ribcage
  ejs
  'child_process': { exec }
  leshdash: { values }
  lweb3: lweb
  'lweb3/transports/server/tcp': { tcpServer }
}

env = do
  settings:
    template: './configFile.ejs'
    config: '/etc/nginx/cluster.conf'
    reload: 'sudo systemctl reload nginx.service'
    
    port: 2010
    
    verboseInit: true
    
    module:
      express4:
        port: 8091
      logger:
        addContext:
          tags:
            module: "nginxCluster"
            
        outputs:
          Console: { }


randomlisten (err,port) ->
  env.settings.module.express4.port = port
  
  ribcage.init env, (err,env) ->
    log = env.log
    
    env.app.get '*', (req,res) -> res.status(500).render 'index.ejs'
    env.app.post '*', (req,res) -> res.status(500).render 'index.ejs'
    
    server = new tcpServer port: env.settings.port, verbose: true
    server.addProtocol new lweb.protocols.query.serverServer!

    log 'listening at ' + env.settings.port, {}, 'init', 'ok'

    servers = { }

    template = String fs.readFileSync env.settings.template

    renderConfig = (servers)->
      if (not servers or servers.length is 0) then servers = [{ name: 'cluster offline', ip: 'localhost', port: port }]
        
      content = ejs.render template, servers: servers
      fs.writeFileSync env.settings.config, content
      exec env.settings.reload, (error,stdout,stderr) ->
        if error then return log "error reloading nginx: #{ String error }", {}, "error"
        if stderr then return log "error reloading nginx: #{ stderr }", {}, "error"
        log "nginx reloaded", {}, "reload"
    renderConfig()
    server.onQuery add: true, (msg, reply, { client }) ->
      data = { ip: client.socket.remoteAddress } <<< msg.add
      log "add web server: #{ data.name }", {}, 'addServer'
      reply.end add: 'ok'

      servers[ data.name ] = data
      renderConfig values servers
      #client.addProtocol new lweb.protocols.query.client!    
      #client.query ping: new Date().getTime(), (msg) -> true

      client.once 'end', ->
        log "del server: #{ data.name }", {}, 'delServer'
        delete servers[ data.name ]
        renderConfig values servers
