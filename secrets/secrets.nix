let
  macbookPro92 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKNNRByzb2fEVJCBO+8zSMNrg538BVYUlAFH6V4cTcbH";
in
{
  "wifi.age".publicKeys = [ macbookPro92 ];
}
