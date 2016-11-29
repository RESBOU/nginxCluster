require! {
  path
  randomlisten
  fs
  ribcage
  ejs
  'child_process': { exec }
  leshdash: { values, each }
  lweb3: lweb
  'lweb3/transports/server/tcp': { tcpServer }
}

env = do
  settings:
    template: './configFile.ejs'
    configFolder: '/etc/nginx/conf.d/'
    reload: 'sudo systemctl reload nginx.service'

    clusters: <[ core admin ]>
      
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
    
    server = new tcpServer port: env.settings.port, verbose: false
    server.addProtocol new lweb.protocols.query.serverServer!

    log 'listening at ' + env.settings.port, {}, 'init', 'ok'


    template = String fs.readFileSync env.settings.template

    renderConfig = (clusterName) ->
      servers = values clusters[ clusterName ]
      if (not servers or servers.length is 0) then servers = [{ name: 'cluster offline', ip: 'localhost', port: port }]
      
      content = ejs.render template, servers: servers
      file = path.join(env.settings.configFolder, clusterName + '.conf')
      
      fs.writeFileSync file, content
      
      exec env.settings.reload, (error,stdout,stderr) ->
        if error then return log "error reloading nginx: #{ String error }", {}, "error"
        if stderr then return log "error reloading nginx: #{ stderr }", {}, "error"
        log "nginx reloaded", {}, "reload"


    clusters = { }
    
    # emtpy all configs (in the future you should wait a few seconds,
    # to receive reconnects if you were restarted, and then render)
    each env.settings.clusters, (clusterName) ->
      renderConfig clusterName
    
    server.onQuery add: true, (msg, reply, { client }) ->
      data = { ip: client.socket.remoteAddress } <<< msg.add
      reply.end data
      log "add server '#{data.name}' (#{data.ip}:#{data.port}) to cluster '#{ data.cluster }'", data, addServer: data.cluster

      if not servers = clusters[ data.cluster ] then servers = clusters[ data.cluster ] = {  }
      servers[ data.name ] = data
      
      renderConfig data.cluster
      
      #client.addProtocol new lweb.protocols.query.client!    
      #client.query ping: new Date().getTime(), (msg) -> true

      client.once 'end', ->
        log "del server: #{ data.name }", {}, delServer: data.cluster
        delete servers[ data.name ]
        renderConfig data.cluster
