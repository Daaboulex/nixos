# blockDevice -- map a fileSystems/crypttab device spec onto the udev match that
# selects the same device. Returns null for a spec no udev key can express, so a
# caller fails closed rather than emitting a rule that silently matches nothing.
{
  udevMatch =
    spec:
    let
      dm = builtins.match "/dev/mapper/(.+)" spec;
      partUuid = builtins.match "(PARTUUID=|/dev/disk/by-partuuid/)(.+)" spec;
      uuid = builtins.match "(UUID=|/dev/disk/by-uuid/)(.+)" spec;
      label = builtins.match "(LABEL=|/dev/disk/by-label/)(.+)" spec;
    in
    if dm != null then
      ''ENV{DM_NAME}=="${builtins.elemAt dm 0}"''
    else if partUuid != null then
      ''ENV{ID_PART_ENTRY_UUID}=="${builtins.elemAt partUuid 1}"''
    else if uuid != null then
      ''ENV{ID_FS_UUID}=="${builtins.elemAt uuid 1}"''
    else if label != null then
      ''ENV{ID_FS_LABEL}=="${builtins.elemAt label 1}"''
    else
      null;
}
