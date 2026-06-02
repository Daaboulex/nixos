# Fixture: an UNGUARDED cross-module reference. check-dangling-refs MUST flag it.
# (Consumer module spawns the `yazi` binary with no provider guard.)
{ config, lib, ... }:
{
  programs.neovim.extraLuaConfig = ''
    { '<leader>fy', function() vim.cmd('tabnew | terminal yazi ' .. vim.fn.expand('%:p:h')) end, desc = 'Yazi' },
  '';
}
