# pci — PCI address validation shared by vfio and displays. Domain pinned to
# 0000 on purpose: vfio's parsePciAddr hardcodes domain=0, so any other domain
# would silently mis-parse; reject at eval time.
{
  isValidPciAddr = addr: builtins.match "0000:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\\.[0-7]" addr != null;
}
