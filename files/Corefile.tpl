.:53 {
    #Because some distros have a localhost dns setup, we need to be picky on the interface we
    #listen to. we can't just use 0.0.0.0, it will fail.
    bind ${bind_address}
    auto {
        directory /opt/coredns/zonefiles (.*) {1}
        reload 5s
    }
    reload 5s
    loop
    nsid ${hostname}
    prometheus ${bind_address}:9153
    health ${bind_address}:8080
    errors
    log
}