we needed a dynamic nginx load balancer for clusters, and didn't want to pay for nginx plus
this thing receives connections from nginxLoadBalancerClient, edits nginx backend config, and reloads nginx
once the connection is dropped, it edits the nginx config again
