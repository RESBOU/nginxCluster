export do
  template: './configFile.ejs'
  config: '/etc/nginx/cluster.conf'
  reload: 'sudo systemctl reload nginx.service'
