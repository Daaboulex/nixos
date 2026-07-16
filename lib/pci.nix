# pci — PCI address validation shared by vfio, displays, and multiseat.
#
# Two accepted shapes, kept distinct on purpose:
#   isValidPciAddr          domain pinned to 0000 — vfio's parsePciAddr
#                           hardcodes domain=0, so any other domain would
#                           silently mis-parse; reject at eval time.
#   isValidPciAddrAnyDomain any 4-hex domain — multiseat only tags udev,
#                           which carries the domain through verbatim.
{
  isValidPciAddr = addr: builtins.match "0000:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\\.[0-7]" addr != null;
  isValidPciAddrAnyDomain =
    addr: builtins.match "[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\\.[0-7]" addr != null;
}
