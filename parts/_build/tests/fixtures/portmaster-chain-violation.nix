# Fixture: a module hand-rolling Portmaster chain surgery (must be flagged).
{
  systemd.services.bad.script = ''
    iptables -t mangle -I PORTMASTER-INGEST-OUTPUT 1 -j RETURN
  '';
}
