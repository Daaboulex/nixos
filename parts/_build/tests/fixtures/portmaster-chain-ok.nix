# Fixture: chain names as keeper rules data (must pass).
{
  rules = [
    {
      family = "iptables";
      chain = "PORTMASTER-INGEST-OUTPUT";
      rule = "-m mark --mark 0x1 -j RETURN";
    }
  ];
}
