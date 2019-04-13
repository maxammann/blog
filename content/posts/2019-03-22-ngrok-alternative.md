---
layout: post
title: "Ngrok alternative for the linux geek"
date: 209-03-22
---

Sometimes you want to expose a port running on localhost to the internet. The use of NAT with IPv4
or firewalls make it difficult to expose a port. Sometimes you also lack the permission to do so. So
maybe your IT will not like this ;)

There are commercial platforms which offer this as a service like [Ngrok](https://ngrok.com/). This
is easy to setup as a JavaScript developer but can be a hassle if you are not familiar with npm.
Also this solution falls short if you care about privacy or signed a NDA (and have to care about it).

This problem is not that complicated that it needs enterprise software. In fact you can do this with
common Unix tools. All you need is `ssh`, `socat` and a server running a SSH server. This server should be able to expose posts to the internet.
SSH will provide is with a reverse tunnel and `socat` will proxy the tunnel to the internet.

Run the following command on your local computer to expose port 8080:
```
ssh -R 12345:localhost:8080 $SERVER_HOST 
```

Not you should be able to run `curl http://localhost:12345` on the remote server.
Unfortunately SSH will bind to localhost. Therefore it is not yet possible to accces the port 12345
from outside.

Use the following command to solve that, by proxying requests from the internet to localhost:

```
socat tcp-listen:12345,reuseaddr,fork,bind=$PUBLIC_IP tcp:localhost:12345
```
(Hint: `$PUBLIC_IP` is the IP of the interface which faces the internet)

You can also skip the second command if you have root access on the server. Then you can allow
clients to specify which IP they bind to when creating the reverse tunnel.

>GatewayPorts
>
>Specifies whether remote hosts are allowed to connect to ports forwarded for the client.  By default, sshd(8) binds remote port forwardings to the loopback address.  This
>prevents other remote hosts from connecting to forwarded ports.  GatewayPorts can be used to specify that sshd should allow remote port forwardings to bind to non-loopback
>addresses, thus allowing other hosts to connect.  The argument may be no to force remote port forwardings to be available to the local host only, yes to force remote port
>forwardings to bind to the wildcard address, or **clientspecified** to allow the client to select the address to which the forwarding is bound.  The default is no.

*From sshd_config manual*

Just set `GatewayPorts` to `clientspecified` and use the following command for the tunnel:
```
ssh -R $PUBLIC_IP:12345:localhost:12345 $SERVER_HOST 
```
(Hint: `$PUBLIC_IP` and `$SERVER_HOST` can be the same)



Projects I discovered while writing:
- [socker-tunnel](https://github.com/ericbarch/socket-tunnel)
- [localtunnel](https://github.com/localtunnel/localtunnel)
- [pagekite.net](http://pagekite.net/support/quickstart/)
- [similar guite](https://dev.to/k4ml/poor-man-ngrok-with-tcp-proxy-and-ssh-reverse-tunnel-1fm)
- [servo.net](https://serveo.net/)



