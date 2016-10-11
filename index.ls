require! {
  os
  util
  ribcage
  leshdash
}

env = do
  settings:
    verboseInit: true
    
    module:
      logger:
        addContext:
          tags:
            module: "nginxCluster"
            
        outputs:
          Console: { }
          Redis: { }
          
ribcage.init env, (err,env) ->

  env.log 'lalalaal', {}
  
