library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package core_config_pkg is
  constant C_ENABLE_ANALOG   : boolean := false; 
  constant C_ENABLE_HDMI     : boolean := false; 
  constant C_ENABLE_DUAL    : boolean := true; 
  constant C_ENABLE_SD       : boolean := true; 
  constant C_ENABLE_HD       : boolean := false; 
end package core_config_pkg;