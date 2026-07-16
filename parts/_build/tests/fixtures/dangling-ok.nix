# Fixture: the SAME reference, properly GUARDED on the provider's enable.
# check-dangling-refs MUST pass it (self-heals when yazi is disabled).
{ config, lib, ... }:
{
  programs.neovim.extraLuaConfig = ''
    ${lib.optionalString config.myModules.home.yazi.enable ''
      { '<leader>fy', function() vim.cmd('tabnew | terminal yazi ' .. vim.fn.expand('%:p:h')) end, desc = 'Yazi' },
    ''}
  '';
}
