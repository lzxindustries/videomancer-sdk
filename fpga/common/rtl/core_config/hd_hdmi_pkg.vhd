library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package core_config_pkg is
  constant C_ENABLE_ANALOG   : boolean := false;
  constant C_ENABLE_HDMI     : boolean := true;
  constant C_ENABLE_DUAL    : boolean := false;
  constant C_ENABLE_SD       : boolean := false;
  constant C_ENABLE_HD       : boolean := true;
end package core_config_pkg;