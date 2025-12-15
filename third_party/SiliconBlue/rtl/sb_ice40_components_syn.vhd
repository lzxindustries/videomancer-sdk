--******************************************************
--Title:    sb_ice_components_syn.vhd 
--Author:   jglong
--Function: instantiate all the cells of the sb_ice_syn.v library 
--Company:  SiliconBlue Technologies, Inc.
--INIT:     Feb 18, 2008
--Revision History:
-- Aug06,2015 Correct SB_IO_I3C pin direction. Jayakumar Sundaram.
-- Aug07,2015 Add SB_DELAY_50NS and SB_FILTER_50NS. Brian Tai.
-- Aug18,2015 Added SCL_INPUT_FILTERED attrib to SB_I2C.Fix minor issues. Jayakumar Sundaram.
-- Aug28,2015 Remove primitives SB_DELAY_50NS and SB_FILTER_50NS. Brian Tai.
--******************************************************

library ieee ;
use ieee.std_logic_1164.all;

package COMPONENTS is
attribute syn_black_box : boolean;
attribute syn_lib_cell : boolean;
attribute xc_map : string;
attribute black_box_pad_pin : string;
attribute syn_black_box of components : package is true;
attribute syn_lib_cell of components : package is true;
attribute ROUTE_THROUGH_FABRIC : boolean;
attribute SDA_INPUT_DELAYED : boolean;
attribute SDA_OUTPUT_DELAYED : boolean;
attribute SCL_INPUT_FILTERED : boolean;
attribute SCL_FILTERED : boolean;
attribute I2C_CLK_DIVIDER : integer;
attribute I2C_FIFO_ENB : string;
attribute TEST_SPRAM : string;
component SB_CARRY 
          port( 
                CO : out std_logic  ;
                I0 : in  std_logic ;
                I1:  in  std_logic ;
                CI : in  std_logic 
               );
end component;

component SB_CARRY_IN_MUX
          generic ( C_INIT : bit_vector( 1  downto 0) )  ;
          port( 
                carry_init_out :  out std_logic ;
                carry_init_in  :  in  std_logic 
               );
end component;

component SB_LUT4
          generic ( LUT_INIT : bit_vector( 15  downto 0) ) ;
          port( 
                O  : out std_logic ;
                I0 : in  std_logic ;
                I1 : in  std_logic ;
                I2 : in  std_logic ;
                I3 : in  std_logic 
               );
end component;

component SB_DFF
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                D : in  std_logic 
               );
end component;

component SB_DFFSR
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                D : in  std_logic ;
                R : in  std_logic 
               );
end component;

component SB_DFFSS
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                D : in  std_logic ;
                S : in  std_logic 
               );
end component;

component SB_DFFR
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                D : in  std_logic ;
                R : in  std_logic 
               );
end component;

component SB_DFFS
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                D : in  std_logic ;
                S : in  std_logic 
               );
end component;

component SB_DFFE
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                E : in  std_logic ;
                D : in  std_logic 
               );
end component;

component SB_DFFESR
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                E : in  std_logic ;
                D : in  std_logic ;
                R : in  std_logic 
               );
end component;

component SB_DFFESS
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                E : in  std_logic ;
                D : in  std_logic ;
                S : in  std_logic 
               );
end component;

component SB_DFFER
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                E : in  std_logic ;
                D : in  std_logic ;
                R : in  std_logic 
               );
end component;

component SB_DFFES
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                E : in  std_logic ;
                D : in  std_logic ;
                S : in  std_logic 
               );
end component;

component SB_DFFN
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                D : in  std_logic 
               );
end component;

component SB_DFFNSR
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                D : in  std_logic ;
                R : in  std_logic 
               );
end component;

component SB_DFFNSS
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                D : in  std_logic ;
                S : in  std_logic 
               );
end component;

component SB_DFFNR
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                D : in  std_logic ;
                R : in  std_logic 
               );
end component;

component SB_DFFNS
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                D : in  std_logic ;
                S : in  std_logic 
               );
end component;

component SB_DFFNE
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                E : in  std_logic ;
                D : in  std_logic 
               );
end component;

component SB_DFFNESR
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                E : in  std_logic ;
                D : in  std_logic ;
                R : in  std_logic 
               );
end component;

component SB_DFFNESS
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                E : in  std_logic ;
                D : in  std_logic ;
                S : in  std_logic 
               );
end component;

component SB_DFFNER
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                E : in  std_logic ;
                D : in  std_logic ;
                R : in  std_logic 
               );
end component;

component SB_DFFNES
          port( 
                Q : out std_logic ;
                C : in  std_logic ;
                E : in  std_logic ;
                D : in  std_logic ;
                S : in  std_logic 
               );
end component;

component SB_RAM40_4K
          generic ( WRITE_MODE : integer := 0;
                    READ_MODE : integer := 0;
                    INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 15  downto 0) ;
                RCLK : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 10  downto 0) ;
                WCLK  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 10  downto 0) ;
                MASK  : in  std_logic_vector( 15  downto 0) ;
                WDATA : in  std_logic_vector( 15  downto 0)
               );
end component;


component SB_RAM40_4KNR
          generic ( WRITE_MODE : integer := 0;
                    READ_MODE : integer := 0;
                    INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 15  downto 0) ;
                RCLKN : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 10  downto 0) ;
                WCLK  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 10  downto 0) ;
                MASK  : in  std_logic_vector( 15  downto 0) ;
                WDATA : in  std_logic_vector( 15  downto 0)
               );
end component;


component SB_RAM40_4KNW
          generic ( WRITE_MODE : integer := 0;
                    READ_MODE : integer := 0;
                    INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 15  downto 0) ;
                RCLK : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 10  downto 0) ;
                WCLKN  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 10  downto 0) ;
                MASK  : in  std_logic_vector( 15  downto 0) ;
                WDATA : in  std_logic_vector( 15  downto 0)
               );
end component;


component SB_RAM40_4KNRNW
          generic ( WRITE_MODE : integer := 0;
                    READ_MODE : integer := 0;
                    INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 15  downto 0) ;
                RCLKN : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 10  downto 0) ;
                WCLKN  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 10  downto 0) ;
                MASK  : in  std_logic_vector( 15  downto 0) ;
                WDATA : in  std_logic_vector( 15  downto 0)
               );
end component;

component SB_RAM256x16
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 15  downto 0) ;
                RCLK : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 7  downto 0) ;
                WCLK  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 7  downto 0) ;
                MASK  : in  std_logic_vector( 15  downto 0) ;
                WDATA : in  std_logic_vector( 15  downto 0)
               );
end component;

component SB_RAM256x16NR
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 15  downto 0) ;
                RCLKN  : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 7  downto 0) ;
                WCLK : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 7  downto 0) ;
                MASK  : in  std_logic_vector( 15  downto 0) ;
                WDATA : in  std_logic_vector( 15  downto 0)
               );
end component;

component SB_RAM256x16NW
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 15  downto 0) ;
                RCLK : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 7  downto 0) ;
                WCLKN : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 7  downto 0) ;
                MASK  : in  std_logic_vector( 15  downto 0) ;
                WDATA : in  std_logic_vector( 15  downto 0)
               );
end component;

component SB_RAM256x16NRNW
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 15  downto 0) ;
                RCLKN : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 7  downto 0) ;
                WCLKN  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 7  downto 0) ;
                MASK  : in  std_logic_vector( 15  downto 0) ;
                WDATA : in  std_logic_vector( 15  downto 0)
               );
end component;


component SB_RAM512x8
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 7  downto 0) ;
                RCLK : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 8  downto 0) ;
                WCLK  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 8  downto 0) ;
                WDATA : in  std_logic_vector( 7  downto 0)
               );
end component;


component SB_RAM512x8NR
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 7  downto 0) ;
                RCLKN : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 8  downto 0) ;
                WCLK  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 8  downto 0) ;
                WDATA : in  std_logic_vector( 7  downto 0)
               );
end component;

component SB_RAM512x8NW
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 7  downto 0) ;
                RCLK : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 8  downto 0) ;
                WCLKN  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 8  downto 0) ;
                WDATA : in  std_logic_vector( 7  downto 0)
               );
end component;

component SB_RAM512x8NRNW
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 7  downto 0) ;
                RCLKN : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 8  downto 0) ;
                WCLKN  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 8  downto 0) ;
                WDATA : in  std_logic_vector( 7  downto 0)
               );
end component;


component SB_RAM1024x4
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 3  downto 0) ;
                RCLK : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 9  downto 0) ;
                WCLK  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 9  downto 0) ;
                WDATA : in  std_logic_vector( 3  downto 0)
               );
end component;

component SB_RAM1024x4NR
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 3  downto 0) ;
                RCLKN : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 9  downto 0) ;
                WCLK  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 9  downto 0) ;
                WDATA : in  std_logic_vector( 3  downto 0)
               );
end component;

component SB_RAM1024x4NW
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 3  downto 0) ;
                RCLK : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 9  downto 0) ;
                WCLKN  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 9  downto 0) ;
                WDATA : in  std_logic_vector( 3  downto 0)
               );
end component;

component SB_RAM1024x4NRNW
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 3  downto 0) ;
                RCLKN : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 9  downto 0) ;
                WCLKN  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 9  downto 0) ;
                WDATA : in  std_logic_vector( 3  downto 0)
               );
end component;


component SB_RAM2048x2
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 1  downto 0) ;
                RCLK : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 10  downto 0) ;
                WCLK  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 10  downto 0) ;
                WDATA : in  std_logic_vector( 1  downto 0)
               );
end component;

component SB_RAM2048x2NR
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 1  downto 0) ;
                RCLKN : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 10  downto 0) ;
                WCLK  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 10  downto 0) ;
                WDATA : in  std_logic_vector( 1  downto 0)
               );
end component;

component SB_RAM2048x2NW
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 1  downto 0) ;
                RCLK : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 10  downto 0) ;
                WCLKN  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 10  downto 0) ;
                WDATA : in  std_logic_vector( 1  downto 0)
               );
end component;

component SB_RAM2048x2NRNW
          generic ( INIT_0 : bit_vector( 255  downto 0) ;
                    INIT_1 : bit_vector( 255  downto 0) ; 
                    INIT_2 : bit_vector( 255  downto 0) ; 
                    INIT_3 : bit_vector( 255  downto 0) ; 
                    INIT_4 : bit_vector( 255  downto 0) ; 
                    INIT_5 : bit_vector( 255  downto 0) ;
                    INIT_6 : bit_vector( 255  downto 0) ;
                    INIT_7 : bit_vector( 255  downto 0) ;
                    INIT_8 : bit_vector( 255  downto 0) ;
                    INIT_9 : bit_vector( 255  downto 0) ;
                    INIT_A : bit_vector( 255  downto 0) ;
                    INIT_B : bit_vector( 255  downto 0) ;
                    INIT_C : bit_vector( 255  downto 0) ;
                    INIT_D : bit_vector( 255  downto 0) ;
                    INIT_E : bit_vector( 255  downto 0) ;
                    INIT_F : bit_vector( 255  downto 0) 
                  ) ;
          port( 
                RDATA : out std_logic_vector( 1  downto 0) ;
                RCLKN : in  std_logic ;
                RCLKE : in  std_logic ;
                RE    : in  std_logic ;
                RADDR : in  std_logic_vector( 10  downto 0) ;
                WCLKN  : in  std_logic ;
                WCLKE : in  std_logic ;
                WE    : in  std_logic ;
                WADDR : in  std_logic_vector( 10  downto 0) ;
                WDATA : in  std_logic_vector( 1  downto 0)
               );
end component;

component SB_IO
          generic ( PIN_TYPE    : bit_vector( 5  downto 0);
                    PULLUP   : bit; 
                    NEG_TRIGGER : bit; 
                    IO_STANDARD : string 
                  ) ;
          port( 
                PACKAGE_PIN        : inout std_logic ;
                LATCH_INPUT_VALUE  : in  std_logic ;
                CLOCK_ENABLE       : in  std_logic ;
                INPUT_CLK          : in  std_logic ;
                OUTPUT_CLK         : in  std_logic ;
                OUTPUT_ENABLE      : in  std_logic ;
                D_OUT_1            : in  std_logic ;
                D_OUT_0            : in  std_logic ;
                D_IN_1             : out std_logic ;
                D_IN_0             : out std_logic                 
               );
end component;

component SB_GB_IO
          generic ( PIN_TYPE    : bit_vector( 5  downto 0);
                    PULLUP   : bit; 
                    NEG_TRIGGER : bit; 
                    IO_STANDARD : string 
                  ) ;
          port( 
                PACKAGE_PIN          : inout std_logic ;
                LATCH_INPUT_VALUE    : in  std_logic ;
                CLOCK_ENABLE         : in  std_logic ;
                INPUT_CLK            : in  std_logic ;
                OUTPUT_CLK           : in  std_logic ;
                OUTPUT_ENABLE        : in  std_logic ;
                D_OUT_1              : in  std_logic ;
                D_OUT_0              : in  std_logic ;
                D_IN_1               : out std_logic ;
                D_IN_0               : out std_logic ;
                GLOBAL_BUFFER_OUTPUT : out std_logic                
               );
end component;

component SB_IO_DS
          generic ( PIN_TYPE    : bit_vector( 5  downto 0);
                    NEG_TRIGGER : bit; 
                    IO_STANDARD : string 
                  ) ;
          port( 
                PACKAGE_PIN        : inout std_logic ;
                PACKAGE_PIN_B      : inout std_logic ;
                LATCH_INPUT_VALUE  : in  std_logic ;
                CLOCK_ENABLE       : in  std_logic ;
                INPUT_CLK          : in  std_logic ;
                OUTPUT_CLK         : in  std_logic ;
                OUTPUT_ENABLE      : in  std_logic ;
                D_OUT_1            : in  std_logic ;
                D_OUT_0            : in  std_logic ;
                D_IN_1             : out std_logic ;
                D_IN_0             : out std_logic                 
               );
end component;

component SB_GB
          port( 
                GLOBAL_BUFFER_OUTPUT         : out std_logic ;
                USER_SIGNAL_TO_GLOBAL_BUFFER : in  std_logic 
               );
end component;

component SB_PLL40_CORE 
  generic (
       		--- Feedback
		FEEDBACK_PATH	 		 : string := "SIMPLE"; -- String (simple, delay, phase_and_delay, external)	
		DELAY_ADJUSTMENT_MODE_FEEDBACK 	 : string := "FIXED"; 
		DELAY_ADJUSTMENT_MODE_RELATIVE 	 : string := "FIXED"; 
		SHIFTREG_DIV_MODE 		: bit_vector(1 downto 0)	:= "00"; 	 --  0-->Divide by 4, 1-->Divide by 7, 3 -->Divide by 5	
	  	FDA_FEEDBACK 			: bit_vector(3 downto 0) 	:= "0000"; 	 --  Integer (0-15). 
		FDA_RELATIVE 			: bit_vector(3 downto 0)	:= "0000"; 	 --  Integer (0-15).   	
  		PLLOUT_SELECT			 : string := "GENCLK";

  		--- Use the spread sheet to populate the values below
		DIVF				: bit_vector(6 downto 0);  -- Determine a good default value
		DIVR				: bit_vector(3 downto 0);  -- Determine a good default value
		DIVQ				: bit_vector(2 downto 0);  -- Determine a good default value
		FILTER_RANGE			: bit_vector(2 downto 0);  -- Determine a good default value 

  		--- Additional C-Bits
  		ENABLE_ICEGATE			: bit := '0';

  		--- Test Mode Parameter 
  		TEST_MODE			: bit := '0';
		EXTERNAL_DIVIDE_FACTOR		: integer := 1 -- Not Used by model, Added for PLL config GUI
       );
  port (
        REFERENCECLK		: in std_logic;			    -- Driven by core logic
        PLLOUTCORE		: out std_logic;		    -- PLL output to core logic
        PLLOUTGLOBAL		: out std_logic;		    -- PLL output to global network
        EXTFEEDBACK		: in std_logic;			    -- Driven by core logic
	DYNAMICDELAY		: in std_logic_vector (7 downto 0); -- Driven by core logic
        LOCK			: out std_logic;	 	    -- Output of PLL
        BYPASS			: in std_logic;			    -- Driven by core logic
        RESETB			: in std_logic;			    -- Driven by core logic
        LATCHINPUTVALUE		: in std_logic;			    -- iCEGate Signal
  	-- Test Pins
  	SDO			: out std_logic;		    -- Output of PLL
  	SDI			: in std_logic;			    -- Driven by core logic
  	SCLK			: in std_logic			    -- Driven by core logic
       );
end component;

component  SB_PLL40_CORE_DUPLICATE 
	generic (	
		FEEDBACK_PATH 			: string 			:= "SIMPLE";	 -- String  (simple, delay, phase_and_delay, external) 
		DELAY_ADJUSTMENT_MODE_FEEDBACK  : string 			:= "FIXED"; 
		DELAY_ADJUSTMENT_MODE_RELATIVE 	: string			:= "FIXED"; 
		SHIFTREG_DIV_MODE 		: bit_vector(1 downto 0)	:= "00"; 	 --  0-->Divide by 4, 1-->Divide by 7, 3 -->Divide by 5	
		FDA_FEEDBACK 			: bit_vector(3 downto 0) 	:= "0000"; 	 --  Integer (0-15). 
		FDA_RELATIVE 			: bit_vector(3 downto 0)	:= "0000"; 	 --  Integer (0-15).    
		PLLOUT_SELECT 			: string 			:= "GENCLK";  
		DIVR 				: bit_vector(3 downto 0)	:= "0000"; 	
		DIVF 				: bit_vector(6 downto 0) 	:= "0000000"; 
		DIVQ 				: bit_vector(2 downto 0)	:= "000"; 		
		FILTER_RANGE 			: bit_vector(2 downto 0)        := "000"; 	
		ENABLE_ICEGATE			: bit				:= '0';
		TEST_MODE 			: bit				:= '0';
		EXTERNAL_DIVIDE_FACTOR 		: integer 				:= 1 		 --Not used by model. Added for PLL Config GUI.
 	 );

	port 	(
		REFERENCECLK			: in std_logic ; 		-- Driven by core logic
		PLLOUTCORE			: out std_logic; 		-- PLL output to core logic ( by normal routing) 
		PLLOUTGLOBAL	   		: out std_logic; 		-- PLL output to core logic  (by global network)
		EXTFEEDBACK  			: in std_logic;			-- Driven by core logic
		DYNAMICDELAY			: in std_logic_vector (7 downto 0);	-- Driven by core logic
		LOCK				: out std_logic; 		-- Output of PLL
		BYPASS				: in std_logic; 		-- Driven by core logic
		RESETB				: in std_logic; 		-- Driven by core logic
		SDI				: in std_logic; 		-- Driven by core logic. Test Pin
		SDO				: out std_logic;		-- Output to RB Logic Tile. Test Pin
		SCLK				: in std_logic; 		-- Driven by core logic. Test Pin
		LATCHINPUTVALUE 		: in std_logic 			-- iCEGate signal	
	       ); 
end component;			

component SB_PLL40_PAD

  generic (
  		--- Feedback
		FEEDBACK_PATH	 		 : string := "SIMPLE"; -- String (simple, delay, phase_and_delay, external)	
		DELAY_ADJUSTMENT_MODE_FEEDBACK 	 : string := "FIXED"; 
		DELAY_ADJUSTMENT_MODE_RELATIVE 	 : string := "FIXED"; 
		SHIFTREG_DIV_MODE 		: bit_vector(1 downto 0)	:= "00"; 	 --  0-->Divide by 4, 1-->Divide by 7, 3 -->Divide by 5
		FDA_FEEDBACK 			: bit_vector(3 downto 0) 	:= "0000"; 	 --  Integer (0-15). 
		FDA_RELATIVE 			: bit_vector(3 downto 0)	:= "0000"; 	 --  Integer (0-15).   	  
  		PLLOUT_SELECT			 : string := "GENCLK";

  		--- Use the spread sheet to populate the values below
		DIVF				: bit_vector(6 downto 0);  -- Determine a good default value
		DIVR				: bit_vector(3 downto 0);  -- Determine a good default value
		DIVQ				: bit_vector(2 downto 0);  -- Determine a good default value
		FILTER_RANGE			: bit_vector(2 downto 0);  -- Determine a good default value 

  		--- Additional C-Bits
  		ENABLE_ICEGATE			: bit := '0';

  		--- Test Mode Parameter 
  		TEST_MODE			: bit := '0';
		EXTERNAL_DIVIDE_FACTOR		: integer := 1 -- Not Used by model, Added for PLL config GUI
       );
  port ( 
        PACKAGEPIN		: inout std_logic;		    
        PLLOUTCORE		: out std_logic;		    -- PLL output to core logic
        PLLOUTGLOBAL		: out std_logic;		    -- PLL output to global network
        EXTFEEDBACK		: in std_logic;			    -- Driven by core logic
	DYNAMICDELAY		: in std_logic_vector (7 downto 0); -- Driven by core logic
        LOCK			: out std_logic;		    -- Output of PLL
        BYPASS			: in std_logic;			    -- Driven by core logic
        RESETB			: in std_logic;			    -- Driven by core logic
        LATCHINPUTVALUE		: in std_logic;			    -- iCEGate Signal
  	-- Test Pins
  	SDO			: out std_logic;		    -- Output of PLL
  	SDI			: in std_logic;			    -- Driven by core logic
  	SCLK			: in std_logic			    -- Driven by core logic
       );
  
end component;


component SB_PLL40_2_PAD

  generic (
  		--- Feedback
		FEEDBACK_PATH	 		 : string := "SIMPLE"; -- String (simple, delay, phase_and_delay, external)	
		DELAY_ADJUSTMENT_MODE_FEEDBACK 	 : string := "FIXED"; 
		DELAY_ADJUSTMENT_MODE_RELATIVE 	 : string := "FIXED"; 
		SHIFTREG_DIV_MODE 		: bit_vector(1 downto 0)	:= "00"; 	 --  0-->Divide by 4, 1-->Divide by 7, 3 -->Divide by 5
		FDA_FEEDBACK 			: bit_vector(3 downto 0) 	:= "0000"; 	 --  Integer (0-15). 
		FDA_RELATIVE 			: bit_vector(3 downto 0)	:= "0000"; 	 --  Integer (0-15).   	  
  		PLLOUT_SELECT_PORTB		 : string := "GENCLK";

  		--- Use the spread sheet to populate the values below
		DIVF				: bit_vector(6 downto 0);  -- Determine a good default value
		DIVR				: bit_vector(3 downto 0);  -- Determine a good default value
		DIVQ				: bit_vector(2 downto 0);  -- Determine a good default value
		FILTER_RANGE			: bit_vector(2 downto 0);  -- Determine a good default value 

  		--- Additional C-Bits
  		ENABLE_ICEGATE_PORTA		: bit := '0';
  		ENABLE_ICEGATE_PORTB		: bit := '0';

  		--- Test Mode Parameter 
  		TEST_MODE			: bit := '0';
		EXTERNAL_DIVIDE_FACTOR		: integer := 1 -- Not Used by model, Added for PLL config GUI
       );
  port ( 
        PACKAGEPIN		: inout std_logic;		    
        PLLOUTCOREA		: out std_logic;		    -- PLL output to core logic
        PLLOUTGLOBALA		: out std_logic;		    -- PLL output to global network
        PLLOUTCOREB		: out std_logic;		    -- PLL output to core logic
        PLLOUTGLOBALB		: out std_logic;		    -- PLL output to global network
        EXTFEEDBACK		: in std_logic;			    -- Driven by core logic
	DYNAMICDELAY		: in std_logic_vector (7 downto 0); -- Driven by core logic
        LOCK			: out std_logic;		    -- Output of PLL
        BYPASS			: in std_logic;			    -- Driven by core logic
        RESETB			: in std_logic;			    -- Driven by core logic
        LATCHINPUTVALUE		: in std_logic;			    -- iCEGate Signal
  	-- Test Pins
  	SDO			: out std_logic;		    -- Output of PLL
  	SDI			: in std_logic;			    -- Driven by core logic
  	SCLK			: in std_logic			    -- Driven by core logic
       );
  
end component;

component SB_PLL40_2F_CORE

  generic (
  		--- Feedback
		FEEDBACK_PATH	 		 : string := "SIMPLE"; -- String (simple, delay, phase_and_delay, external)	
		DELAY_ADJUSTMENT_MODE_FEEDBACK 	 : string := "FIXED"; 
		DELAY_ADJUSTMENT_MODE_RELATIVE 	 : string := "FIXED"; 
		SHIFTREG_DIV_MODE 		: bit_vector(1 downto 0)	:= "00"; 	 --  0-->Divide by 4, 1-->Divide by 7, 3 -->Divide by 5
		FDA_FEEDBACK 			: bit_vector(3 downto 0) 	:= "0000"; 	 --  Integer (0-15). 
		FDA_RELATIVE 			: bit_vector(3 downto 0)	:= "0000"; 	 --  Integer (0-15).    
  		PLLOUT_SELECT_PORTA		 : string := "GENCLK";
  		PLLOUT_SELECT_PORTB		 : string := "GENCLK";

  		--- Use the spread sheet to populate the values below
		DIVF				: bit_vector(6 downto 0);  -- Determine a good default value
		DIVR				: bit_vector(3 downto 0);  -- Determine a good default value
		DIVQ				: bit_vector(2 downto 0);  -- Determine a good default value
		FILTER_RANGE			: bit_vector(2 downto 0);  -- Determine a good default value 

  		--- Additional C-Bits
  		ENABLE_ICEGATE_PORTA		: bit := '0';
  		ENABLE_ICEGATE_PORTB		: bit := '0';

  		--- Test Mode Parameter 
  		TEST_MODE			: bit := '0';
		EXTERNAL_DIVIDE_FACTOR		: integer := 1 -- Not Used by model, Added for PLL config GUI
       );
  port ( 
        REFERENCECLK		: in std_logic;		    	    -- Driven by core logic
        PLLOUTCOREA		: out std_logic;		    -- PLL output to core logic
        PLLOUTGLOBALA		: out std_logic;		    -- PLL output to global network
        PLLOUTCOREB		: out std_logic;		    -- PLL output to core logic
        PLLOUTGLOBALB		: out std_logic;		    -- PLL output to global network
        EXTFEEDBACK		: in std_logic;			    -- Driven by core logic
	DYNAMICDELAY		: in std_logic_vector (7 downto 0); -- Driven by core logic
        LOCK			: out std_logic;		    -- Output of PLL
        BYPASS			: in std_logic;			    -- Driven by core logic
        RESETB			: in std_logic;			    -- Driven by core logic
        LATCHINPUTVALUE		: in std_logic;			    -- iCEGate Signal
  	-- Test Pins
  	SDO			: out std_logic;		    -- Output of PLL
  	SDI			: in std_logic;			    -- Driven by core logic
  	SCLK			: in std_logic			    -- Driven by core logic
       );
  
end component;

component SB_PLL40_2F_PAD

  generic (
  		--- Feedback
		FEEDBACK_PATH	 		 : string := "SIMPLE"; -- String (simple, delay, phase_and_delay, external)	
		DELAY_ADJUSTMENT_MODE_FEEDBACK 	 : string := "FIXED"; 
		DELAY_ADJUSTMENT_MODE_RELATIVE 	 : string := "FIXED"; 
		SHIFTREG_DIV_MODE 		: bit_vector(1 downto 0)	:= "00"; 	 --  0-->Divide by 4, 1-->Divide by 7, 3 -->Divide by 5
		FDA_FEEDBACK 			: bit_vector(3 downto 0) 	:= "0000"; 	 --  Integer (0-15). 
		FDA_RELATIVE 			: bit_vector(3 downto 0)	:= "0000"; 	 --  Integer (0-15).    
  		PLLOUT_SELECT_PORTA		 : string := "GENCLK";
  		PLLOUT_SELECT_PORTB		 : string := "GENCLK";

  		--- Use the spread sheet to populate the values below
		DIVF				: bit_vector(6 downto 0);  -- Determine a good default value
		DIVR				: bit_vector(3 downto 0);  -- Determine a good default value
		DIVQ				: bit_vector(2 downto 0);  -- Determine a good default value
		FILTER_RANGE			: bit_vector(2 downto 0);  -- Determine a good default value 

  		--- Additional C-Bits
  		ENABLE_ICEGATE_PORTA		: bit := '0';
  		ENABLE_ICEGATE_PORTB		: bit := '0';

  		--- Test Mode Parameter 
  		TEST_MODE			: bit := '0';
		EXTERNAL_DIVIDE_FACTOR		: integer := 1 -- Not Used by model, Added for PLL config GUI
       );
  port ( 
        PACKAGEPIN		: inout std_logic;	    	    
        PLLOUTCOREA		: out std_logic;		    -- PLL output to core logic
        PLLOUTGLOBALA		: out std_logic;		    -- PLL output to global network
        PLLOUTCOREB		: out std_logic;		    -- PLL output to core logic
        PLLOUTGLOBALB		: out std_logic;		    -- PLL output to global network
        EXTFEEDBACK		: in std_logic;			    -- Driven by core logic
	DYNAMICDELAY		: in std_logic_vector (7 downto 0); -- Driven by core logic
        LOCK			: out std_logic;		    -- Output of PLL
        BYPASS			: in std_logic;			    -- Driven by core logic
        RESETB			: in std_logic;			    -- Driven by core logic
        LATCHINPUTVALUE		: in std_logic;			    -- iCEGate Signal
  	-- Test Pins
  	SDO			: out std_logic;		    -- Output of PLL
  	SDI			: in std_logic;			    -- Driven by core logic
  	SCLK			: in std_logic			    -- Driven by core logic
       );
  
end component;

--------------------------------------------------------------------------------------------------
-- 					 SB_PLL40_PAD_DS 					--
--------------------------------------------------------------------------------------------------

component  SB_PLL40_PAD_DS  
	generic (	
		FEEDBACK_PATH 			: string 			:= "SIMPLE";	 -- String  (simple, delay, phase_and_delay, external) 
		DELAY_ADJUSTMENT_MODE_FEEDBACK  : string 			:= "FIXED"; 
		DELAY_ADJUSTMENT_MODE_RELATIVE 	: string			:= "FIXED"; 
		SHIFTREG_DIV_MODE 		: bit_vector(1 downto 0)	:= "00"; 	 --  0-->Divide by 4, 1-->Divide by 7, 3 -->Divide by 5	
		FDA_FEEDBACK 			: bit_vector(3 downto 0) 	:= "0000"; 	 --  Integer (0-15). 
		FDA_RELATIVE 			: bit_vector(3 downto 0)	:= "0000"; 	 --  Integer (0-15).    
		PLLOUT_SELECT 			: string 			:= "GENCLK";  
		DIVR 				: bit_vector(3 downto 0)	:= "0000"; 	
		DIVF 				: bit_vector(6 downto 0) 	:= "0000000"; 
		DIVQ 				: bit_vector(2 downto 0)	:= "000"; 		
		FILTER_RANGE 			: bit_vector(2 downto 0)        := "000"; 	
		ENABLE_ICEGATE			: bit				:= '0';
		TEST_MODE 			: bit				:= '0';
		EXTERNAL_DIVIDE_FACTOR 		: integer 			:= 1 		 --Not used by model. Added for PLL Config GUI.
 	 );

	port 	(
	       	PACKAGEPIN			: inout std_logic ; 		-- Reference clk (P) signal through PackagePin.   
	       	PACKAGEPINB			: inout std_logic ; 		-- Reference clk (N) signal through PackagePinB.   
		PLLOUTCORE			: out std_logic; 		-- PLL output to core logic (by normal routing)
		PLLOUTGLOBAL	   		: out std_logic; 		-- PLL output to core logic (by global network)
		EXTFEEDBACK  			: in std_logic;			-- Driven by core logic
		DYNAMICDELAY			: in std_logic_vector (7 downto 0);	-- Driven by core logic
		LOCK				: out std_logic; 		-- Output of PLL
		BYPASS				: in std_logic; 		-- Driven by core logic
		RESETB				: in std_logic; 		-- Driven by core logic
		SDI				: in std_logic; 		-- Driven by core logic. Test Pin
		SDO				: out std_logic;		-- Output to RB Logic Tile. Test Pin
		SCLK				: in std_logic; 		-- Driven by core logic. Test Pin
		LATCHINPUTVALUE 		: in std_logic 			-- iCEGate signal	
	       ); 
end component; 	

--------------------------------------------------------------------------------------------------
-- 					 SB_PLL40_2F_PAD_DS 					--
--------------------------------------------------------------------------------------------------

component  SB_PLL40_2F_PAD_DS  
	generic (	
		FEEDBACK_PATH 			: string 			:= "SIMPLE";	 -- String  (simple, delay, phase_and_delay, external) 
		DELAY_ADJUSTMENT_MODE_FEEDBACK  : string 			:= "FIXED"; 
		DELAY_ADJUSTMENT_MODE_RELATIVE 	: string			:= "FIXED"; 
		SHIFTREG_DIV_MODE 		: bit_vector(1 downto 0)	:= "00"; 	 --  0-->Divide by 4, 1-->Divide by 7, 3 -->Divide by 5	
		FDA_FEEDBACK 			: bit_vector(3 downto 0) 	:= "0000"; 	 --  Integer (0-15). 
		FDA_RELATIVE 			: bit_vector(3 downto 0)	:= "0000"; 	 --  Integer (0-15).   
		PLLOUT_SELECT_PORTA		: string 			:= "GENCLK";  
		PLLOUT_SELECT_PORTB		: string 			:= "GENCLK";  
		DIVR 				: bit_vector(3 downto 0)	:= "0000"; 	
		DIVF 				: bit_vector(6 downto 0) 	:= "0000000"; 
		DIVQ 				: bit_vector(2 downto 0)	:= "000"; 		
		FILTER_RANGE 			: bit_vector(2 downto 0)        := "000"; 	
		ENABLE_ICEGATE_PORTA		: bit				:= '0';
		ENABLE_ICEGATE_PORTB		: bit				:= '0';
		TEST_MODE 			: bit				:= '0';
		EXTERNAL_DIVIDE_FACTOR 		: integer			:= 1 		 --Not used by model. Added for PLL Config GUI.
 	 );

	port 	(
	       	PACKAGEPIN			: inout std_logic ; 		-- Reference clk (P) signal through PackagePin.   
	       	PACKAGEPINB			: inout std_logic ; 		-- Reference clk (N) signal through PackagePinB.   
		PLLOUTCOREA			: out std_logic; 		-- PLL A port output to core logic (by normal routing)
		PLLOUTGLOBALA	   		: out std_logic; 		-- PLL A port output to core logic (by global routing)
	        PLLOUTCOREB			: out std_logic; 		-- PLL B port output to core logic (by normal routing)
		PLLOUTGLOBALB	   		: out std_logic; 		-- PLL B port output to core logic (by global routing)
		EXTFEEDBACK  			: in std_logic;			-- Driven by core logic
		DYNAMICDELAY			: in std_logic_vector (7 downto 0);	-- Driven by core logic
		LOCK				: out std_logic; 		-- Output of PLL
		BYPASS				: in std_logic; 		-- Driven by core logic
		RESETB				: in std_logic; 		-- Driven by core logic
		SDI				: in std_logic; 		-- Driven by core logic. Test Pin
		SDO				: out std_logic;		-- Output to RB Logic Tile. Test Pin
		SCLK				: in std_logic; 		-- Driven by core logic. Test Pin
		LATCHINPUTVALUE 		: in std_logic 			-- iCEGate signal	
	       ); 
end component; 	

-- iCE40 MIPI Primitive  
--------------------------------------------------------------------------------------------------
-- 					SB_MIPI_RX_2LANE					--
--------------------------------------------------------------------------------------------------

component SB_MIPI_RX_2LANE  
	port (
		ENPDESER  		: in std_logic; 	  		-- Common Interface Pins 
  		PU			: in std_logic; 	  
		DP0			: in std_logic; 	  		-- Device Pin 
		DN0			: in std_logic; 	  	        -- Device Pin 
		D0RXHSEN		: in std_logic; 	   		-- Data0 Interface Pins 
		D0DTXLPP		: in std_logic; 	   
		D0DTXLPN		: in std_logic; 	  
		D0TXLPEN		: in std_logic; 	   	
		D0DRXLPP		: out std_logic; 	   
		D0DRXLPN		: out std_logic;  
		D0RXLPEN		: in std_logic; 	  
		D0DCDP			: out std_logic;  	 
		D0DCDN 			: out std_logic;  	 
		D0CDEN			: in std_logic; 
		D0HSDESEREN		: in std_logic; 
		D0HSRXDATA		: out std_logic_vector(7 downto 0); 
 		D0HSBYTECLKD		: out std_logic; 	
		D0SYNC			: out std_logic;  
		D0ERRSYNC		: out std_logic; 
		D0NOSYNC		: out std_logic; 
		DP1			: in std_logic;  			-- Device Pin 
		DN1			: in std_logic; 			-- Device Pin 
		D1RXHSEN		: in std_logic; 			-- Data1 Interface Pins 
		D1DRXLPP		: out std_logic; 
		D1DRXLPN		: out std_logic; 	
		D1RXLPEN		: in std_logic; 
		D1HSDESEREN		: in std_logic; 
		D1HSRXDATA		: out std_logic_vector(7 downto 0); 
		D1SYNC			: out std_logic; 
		D1ERRSYNC		: out std_logic; 
		D1NOSYNC		: out std_logic; 
		CKP			: in std_logic;          		-- Device Pin   
		CKN			: in std_logic;				-- Device Pin 
		CLKRXHSEN		: in std_logic; 	 		-- Clk interface Pins  
		CLKDRXLPP		: out std_logic; 	
		CLKDRXLPN		: out std_logic; 	
		CLKRXLPEN		: in std_logic; 	
		CLKHSBYTE		: out std_logic 
      	     ); 
end component; 

-- iCE40 HDMI Primitive  
--------------------------------------------------------------------------------------------------
-- 					SB_TMDS_deserializer					--
--------------------------------------------------------------------------------------------------

component SB_TMDS_deserializer  
	generic (
		FEEDBACK_PATH 			: string 			:= "PHASE_AND_DELAY";	 
		DELAY_ADJUSTMENT_MODE_FEEDBACK  : string 			:= "FIXED"; 
		DELAY_ADJUSTMENT_MODE_RELATIVE 	: string			:= "FIXED"; 
		SHIFTREG_DIV_MODE 		: bit_vector(1 downto 0)	:= "11"; 	 --  Divide by 5 mode 	
		FDA_FEEDBACK 			: bit_vector(3 downto 0) 	:= "0000"; 	 --  Integer (0-15). 
		FDA_RELATIVE 			: bit_vector(3 downto 0)	:= "0000"; 	 --  Integer (0-15).   
		PLLOUT_SELECT_PORTA		: string 			:= "GENCLK"; 	 --  Clkx5
		PLLOUT_SELECT_PORTB		: string 			:= "SHIFTREG_0deg";  -- Clkx1  
		DIVR 				: bit_vector(3 downto 0)	:= "0000"; 	    -- for TMDS clk at 40Mhz  	
		DIVF 				: bit_vector(6 downto 0) 	:= "0000000"; 
		DIVQ 				: bit_vector(2 downto 0)	:= "010"; 		
		FILTER_RANGE 			: bit_vector(2 downto 0)        := "011"; 	
		ENABLE_ICEGATE_PORTA		: bit				:= '0';
		ENABLE_ICEGATE_PORTB		: bit				:= '0';
		TEST_MODE 			: bit				:= '0';
		EXTERNAL_DIVIDE_FACTOR 		: integer			:= 1 		 --Not used by model. Added for PLL Config GUI.

	 	); 
	port 	(
		TMDSch0p 			: in std_logic;		   	     	--TMDS ch 0 differential input pos
		TMDSch0n			: in std_logic;         		--TMDS ch 0 differential input neg
		TMDSch1p			: in std_logic;              		--TMDS ch 1 differential input pos
		TMDSch1n			: in std_logic;              		--TMDS ch 1 differential input neg
		TMDSch2p			: in std_logic;              		--TMDS ch 2 differential input pos
		TMDSch2n			: in std_logic;              		--TMDS ch 2 differential input neg
		TMDSclkp			: in std_logic;              		--TMDS clock differential input pos
		TMDSclkn			: in std_logic;              		--TMDS clock differential input neg
								                        --Receiver controller interface
		RSTNdeser			: in std_logic;				--Reset deserailzier logics- active low
		RSTNpll				: in std_logic;                		--Reset deserializer PLL- active low
		EN				: in std_logic;                      	--Enable deserializer- active high
		PHASELch0 			: in std_logic_vector(3 downto 0);      --Clock phase delay compensation select for ch 0
		PHASELch1 			: in std_logic_vector(3 downto 0);      --Clock phase delay compensation select for ch 1
		PHASELch2 			: in std_logic_vector(3 downto 0);      --Clock phase delay compensation select for ch 2
		PLLlock				: out std_logic;               		-- PLL lock signal- active high
											-- PLL output  
		PLLOUTCOREclkx1  		: out std_logic; 			-- PLL 1x output on core network  
		PLLOUTGLOBALclkx1 		: out std_logic ; 			-- PLL 1x output on global network 	
		PLLOUTCOREclkx5			: out std_logic ; 			-- PLL 5x output on core network 
		PLLOUTGLOBALclkx5 		: out std_logic ; 			-- PLL 5x output on global network  
		RAWDATAch0  			: out std_logic_vector(9 downto 0); 	-- Recovered ch 0 10-bit data 
		RAWDATAch1  			: out std_logic_vector(9 downto 0); 	-- Recovered ch 1 10-bit data
		RAWDATAch2   			: out std_logic_vector(9 downto 0); 	-- Recovered ch 2 10-bit data
		EXTFEEDBACK	   		: in std_logic ; 			-- Driven by core logic. Not required HDMI mode.
		DYNAMICDELAY 			: in std_logic_vector(7 downto 0);  	-- Driven by core logic. Not required for HDMI mode.
		BYPASS				: in std_logic ; 			-- Driven by core logic. Not required for HDMI mode.
		LATCHINPUTVALUE 		: in std_logic ; 			-- iCEGate signal. Not required for HDMI mode
											-- Test Pins 	
		SDO				: out std_logic;  			-- Test Signal. Output of PLL.
		SDI				: in std_logic ; 			-- Test signal. Driven by core logic
		SCLK				: in std_logic  			-- Test Clk Signal. Driven by core logic
       		); 
end component;

--------------------------------------------
-- PRIM TYPE  :  MULTIPLIERS 
-- DEVICE     :  ICE40 SANFRNCISCO DEVICES
-------------------------------------------
--------------------------------------------
-- 		SB_MULT_8x8 
--------------------------------------------
component SB_MULT_8x8
	generic ( 
		DATAA_REG	: bit  	:= '0';	
		DATAB_REG 	: bit	:= '0';	
		DATAOUT_REG 	: bit 	:= '0';
		DATAA_SIGNED 	: bit  	:= '0';
		DATAB_SIGNED 	: bit  	:= '0';
		NEG_TRIGGER  	: bit 	:= '0' 
               ); 
	port   (
		DATAA   : in std_logic_vector( 7 downto 0); 
		DATAB   : in std_logic_vector( 7 downto 0); 
		CLK     : in std_logic;  
		CE      : in std_logic;  
		RESET   : in std_logic;                       -- Asynchronous Reset
 		DATAOUT : out std_logic_vector(15 downto 0)
	); 	
end component; 	

---------------------------------------------
-- 		SB_MULT_16x16 
---------------------------------------------
component SB_MULT_16x16
	generic ( 
		DATAA_REG	: bit  	:= '0';	
		DATAB_REG 	: bit	:= '0';
		PIPELINE_REG	: bit	:= '0';
		DATAOUT_REG 	: bit 	:= '0';
		DATAA_SIGNED 	: bit  	:= '0';
		DATAB_SIGNED 	: bit  	:= '0';
		NEG_TRIGGER  	: bit 	:= '0' 
               ); 
	port   (
		DATAA   : in std_logic_vector( 15 downto 0); 
		DATAB   : in std_logic_vector( 15 downto 0); 
		CLK     : in std_logic; 
		CE      : in std_logic;  
		RESET   : in std_logic;                       -- Asynchronous Reset 
 		DATAOUT : out std_logic_vector(31 downto 0)
	); 	
end component;
component SB_RAM40_16K 
  generic ( 
	   WRITE_MODE : integer := 0; 
	   READ_MODE  : integer := 0; 

	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000"; 

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000"; 

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000"; 

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 15  downto 0) ;
		RCLK  : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 12  downto 0) ;
		WCLK  : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 12  downto 0) ;
		MASK  : in  std_logic_vector( 15  downto 0) ;
		WDATA : in  std_logic_vector( 15  downto 0)
	       );
	  
end component;

component SB_RAM40_16KNR is
  generic ( 
	   WRITE_MODE : integer := 0; 
           READ_MODE  : integer := 0; 

	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000"; 

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 15  downto 0) ;
		RCLKN : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 12  downto 0) ;
		WCLK  : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 12  downto 0) ;
		MASK  : in  std_logic_vector( 15  downto 0) ;
		WDATA : in  std_logic_vector( 15  downto 0)
	       );
end component;

component SB_RAM40_16KNW is
  generic ( 
	   WRITE_MODE : integer := 0; 
	   READ_MODE  : integer := 0; 

	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 15  downto 0) ;
		RCLK  : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 12  downto 0) ;
		WCLKN : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 12  downto 0) ;
		MASK  : in  std_logic_vector( 15  downto 0) ;
		WDATA : in  std_logic_vector( 15  downto 0)
	       );
end component;

component SB_RAM40_16KNRNW is
  generic ( 
	   WRITE_MODE : integer := 0; 
           READ_MODE  : integer := 0; 

	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
           ) ;
	  port( 
		RDATA : out std_logic_vector( 15  downto 0) ;
		RCLKN : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 12  downto 0) ;
		WCLKN : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 12  downto 0) ;
		MASK  : in  std_logic_vector( 15  downto 0) ;
		WDATA : in  std_logic_vector( 15  downto 0)
	       );
end component;

component SB_RAM1024x16 
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 15  downto 0) ;
		RCLK  : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 9  downto 0) ;
		WCLK  : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 9  downto 0) ;
		MASK  : in  std_logic_vector( 15  downto 0) ;
		WDATA : in  std_logic_vector( 15  downto 0)
	       );
	  
end component;

component SB_RAM1024x16NR is
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 15  downto 0) ;
		RCLKN : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 9  downto 0) ;
		WCLK  : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 9  downto 0) ;
		MASK  : in  std_logic_vector( 15  downto 0) ;
		WDATA : in  std_logic_vector( 15  downto 0)
	       );
end component;

component SB_RAM1024x16NW is
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 15  downto 0) ;
		RCLK  : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 9  downto 0) ;
		WCLKN : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 9  downto 0) ;
		MASK  : in  std_logic_vector( 15  downto 0) ;
		WDATA : in  std_logic_vector( 15  downto 0)
	       );
end component;

component SB_RAM1024x16NRNW is
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 15  downto 0) ;
		RCLKN : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 9  downto 0) ;
		WCLKN : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 9  downto 0) ;
		MASK  : in  std_logic_vector( 15  downto 0) ;
		WDATA : in  std_logic_vector( 15  downto 0)
	       );
end component;

component SB_RAM2048x8 is
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 7  downto 0) ;
		RCLK  : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 10  downto 0) ;
		WCLK  : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 10  downto 0) ;
		WDATA : in  std_logic_vector( 7  downto 0)
	       );
end component;

component SB_RAM2048x8NR is
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 7  downto 0) ;
		RCLKN : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 10  downto 0) ;
		WCLK  : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 10  downto 0) ;
		WDATA : in  std_logic_vector( 7  downto 0)
	       );
end component;

component SB_RAM2048x8NW is
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 7  downto 0) ;
		RCLK  : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 10  downto 0) ;
		WCLKN : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 10  downto 0) ;
		WDATA : in  std_logic_vector( 7  downto 0)
	       );
end component;

component SB_RAM2048x8NRNW 
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 7  downto 0) ;
		RCLKN : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 10  downto 0) ;
		WCLKN : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 10  downto 0) ;
		WDATA : in  std_logic_vector( 7  downto 0)
	       );
end component;

component SB_RAM4096x4 
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 3  downto 0) ;
		RCLK  : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 11  downto 0) ;
		WCLK  : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 11  downto 0) ;
		WDATA : in  std_logic_vector( 3  downto 0)
	       );
end component;

component SB_RAM4096x4NR is
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 3  downto 0) ;
		RCLKN : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 11  downto 0) ;
		WCLK  : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 11  downto 0) ;
		WDATA : in  std_logic_vector( 3  downto 0)
	       );
end component;

component SB_RAM4096x4NW is
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 3  downto 0) ;
		RCLK  : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 11  downto 0) ;
		WCLKN : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 11  downto 0) ;
		WDATA : in  std_logic_vector( 3  downto 0)
	       );
end component;


component SB_RAM4096x4NRNW is
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 3  downto 0) ;
		RCLKN : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 11  downto 0) ;
		WCLKN : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 11  downto 0) ;
		WDATA : in  std_logic_vector( 3  downto 0)
	       );
end component;

component SB_RAM8192x2 is
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
   	        RDATA : out std_logic_vector( 1  downto 0) ;
		RCLK  : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 12  downto 0) ;
		WCLK  : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 12  downto 0) ;
		WDATA : in  std_logic_vector( 1  downto 0)
	       );
end component;

component SB_RAM8192x2NR is
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 1  downto 0) ;
		RCLKN : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 12  downto 0) ;
		WCLK  : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 12  downto 0) ;
		WDATA : in  std_logic_vector( 1  downto 0)
	       );
end component;

component SB_RAM8192x2NW 
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 1  downto 0) ;
		RCLK  : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 12  downto 0) ;
		WCLKN : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 12  downto 0) ;
		WDATA : in  std_logic_vector( 1  downto 0)
	       );
end component;

component SB_RAM8192x2NRNW is
  generic ( 
	   INIT_0 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_1 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_2 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_3 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_4 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_5 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_6 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_7 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_8 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_9 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
	   INIT_F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";

           INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
           INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000" 
	    ) ;
	  port( 
		RDATA : out std_logic_vector( 1  downto 0) ;
		RCLKN : in  std_logic ;
		RCLKE : in  std_logic := 'H';
		RE    : in  std_logic := 'H';
		RADDR : in  std_logic_vector( 12  downto 0) ;
		WCLKN : in  std_logic ;
		WCLKE : in  std_logic := 'H';
		WE    : in  std_logic := 'H';
		WADDR : in  std_logic_vector( 12  downto 0) ;
		WDATA : in  std_logic_vector( 1  downto 0)
	       );
end component;

component SB_MAC16 is
 	generic ( 
		 NEG_TRIGGER 			: bit 		:='0'; 
		 C_REG				: bit 		:='0'; 		-- C0
		 A_REG				: bit 		:='0'; 	    	-- C1 
		 B_REG				: bit 		:='0';		-- C2
		 D_REG 				: bit 		:='0';		-- C3
		 TOP_8x8_MULT_REG		: bit 		:='0'; 	   	-- C4
		 BOT_8x8_MULT_REG		: bit 		:='0';	   	-- C5
		 PIPELINE_16x16_MULT_REG1	: bit 		:='0';		-- C6
		 PIPELINE_16x16_MULT_REG2	: bit 		:='0';		-- C7

		 TOPOUTPUT_SELECT      		: bit_vector(1 downto 0) := "00" ;	-- COMB, ACCUM_REG, MULT_8x8, MULT_16x16 //{C9,C8}   = 00, 01, 10, 11
		 TOPADDSUB_LOWERINPUT  		: bit_vector(1 downto 0) := "00" ; 	-- DATA, MULT_8x8, MULT_16x16, SIGNEXT 	 //{C11,C10} = 00, 01, 10, 11
		 TOPADDSUB_UPPERINPUT  		: bit 			 := '0'  ; 	-- ACCUM_REG, DATAC 		 	 // C12 = 0, 1
		 TOPADDSUB_CARRYSELECT 		: bit_vector(1 downto 0) := "00" ; 	-- LOGIC0,LOGIC1,ACCUMCI,GENERATED_CARRY //{C14, C13} =00, 01, 10, 11

		 BOTOUTPUT_SELECT		: bit_vector(1 downto 0) := "00" ; 	--COMB, ACCUM_REG, MULT_8x8, MULT_16x16  // {C16,C15} =00, 01, 10, 11
		 BOTADDSUB_LOWERINPUT 		: bit_vector(1 downto 0) := "00" ; 	--DATA, MULT_8x8, MULT_16x16, SIGNEXTIN //  {C18,C17} =00, 01, 10, 11
		 BOTADDSUB_UPPERINPUT 		: bit 			 := '0'  ;  	--ACCUM_REG, DATAD   			//  C19 = 0, 1
		 BOTADDSUB_CARRYSELECT 		: bit_vector(1 downto 0) := "00" ; 	--LOGIC0, LOGIC1, ACCUMCI, CI  		//  {C21, C20}=00,01,10,11
		 MODE_8x8 			: bit 			 := '0' ; 	-- C22 

		 A_SIGNED 			: bit 			 := '0' ;  	-- C23
		 B_SIGNED 			: bit 			 := '0'   	-- C24
	);
	port	(

		A		: in 	std_logic_vector(15 downto 0) ;  
		B		: in    std_logic_vector(15 downto 0) ; 	
		C		: in 	std_logic_vector(15 downto 0) ; 
		D		: in 	std_logic_vector(15 downto 0) ; 
		O		: out 	std_logic_vector(31 downto 0) ;
		CLK		: in 	std_logic ; 
		CE		: in 	std_logic ; 
		IRSTTOP 	: in 	std_logic ; 
	    	IRSTBOT 	: in 	std_logic ; 
		ORSTTOP 	: in 	std_logic ; 
		ORSTBOT 	: in 	std_logic ; 
		AHOLD 		: in	std_logic ; 
		BHOLD		: in 	std_logic ; 
		CHOLD		: in 	std_logic ; 
		DHOLD		: in 	std_logic ; 
		OHOLDTOP	: in 	std_logic ; 
		OHOLDBOT	: in 	std_logic ; 
		OLOADTOP	: in	std_logic ; 
		OLOADBOT	: in 	std_logic ; 
		ADDSUBTOP	: in 	std_logic ; 
		ADDSUBBOT	: in 	std_logic ;
		CO		: out 	std_logic ;
		CI		: in 	std_logic ;  
		ACCUMCI		: in 	std_logic ; 
		ACCUMCO        	: out 	std_logic ;
		SIGNEXTIN	: in	std_logic ; 
		SIGNEXTOUT      : out 	std_logic  				
	); 

end component;

component SB_IO_DLY is 
	generic	(

		NEG_TRIGGER 		: bit				:='0';
		PIN_TYPE		: bit_vector (5 downto 0)	:="000000";
		PULLUP			: bit				:='0';
		IO_STANDARD		: string			:="SB_LVCMOS";
		INDELAY_VAL		: bit_vector (5 downto 0) 	:="000000";
		OUTDELAY_VAL 		: bit_vector (5 downto 0) 	:="000000"
	);	
	port 	(
		PACKAGE_PIN 		: inout std_ulogic; 
		LATCH_INPUT_VALUE 	: in 	std_logic; 
		CLOCK_ENABLE		: in 	std_logic; 
		INPUT_CLK		: in 	std_logic; 
		OUTPUT_CLK		: in 	std_logic; 
		OUTPUT_ENABLE		: in 	std_logic :='H'; 
		D_OUT_1			: in 	std_logic;   
		D_OUT_0			: in 	std_logic;  
		D_IN_1			: out 	std_logic; 
		D_IN_0			: out 	std_logic; 
		SCLK			: in 	std_logic; 	
		SDI			: in 	std_logic; 	
		C_R_SEL			: in 	std_logic;  
		SDO			: out 	std_logic 
	 );


end component; 
 
component SB_MIPI_TX_4LANE  
	generic	( 		
		DIVR 			: bit_vector( 4 downto 0)  	:= "11111" ;      	-- Ref Clk divider
		DIVF 			: bit_vector( 7 downto 0)  	:= "11110000"; 		-- Feedback divider
		DIVQ 			: bit_vector( 1 downto 0)  	:= "00";       		-- VCO divider
		TEST_MODE 		: bit 				:= '0';
		TEST_BITS 		: bit_vector( 3 downto 0) 	:= "1001"
	); 
	port 	( 
			--Common Interface Pins
		PU			: in 	std_logic ; 
		LBEN			: in 	std_logic ; 
 		ROUTCAL			: in 	std_logic_vector(1 downto 0) ; 
 		ENPDESER		: in	std_logic ; 	
	       	PDCKG			: in	std_logic ; 
			-- DATA0 Interface pins
		DP0			: inout	std_ulogic ; 	
		DN0			: inout std_ulogic ; 
 		D0OPMODE		: in	std_logic ;  
 		D0DTXLPP		: in	std_logic ; 
 		D0DTXLPN		: in 	std_logic ; 
 		D0TXLPEN		: in	std_logic ;  	
 		D0DRXLPP		: out	std_logic ; 
	  	D0DRXLPN		: out 	std_logic ; 
 		D0RXLPEN		: in 	std_logic ; 
 		D0DCDP			: out 	std_logic ; 
		D0DCDN			: out 	std_logic ; 
 		D0CDEN			: in	std_logic ; 		
  		D0TXHSPD		: in	std_logic ; 
 		D0TXHSEN		: in 	std_logic ; 
   		D0HSTXDATA		: in 	std_logic_vector( 7 downto 0) ; 
  		D0HSSEREN		: in	std_logic ; 	 
 		D0RXHSEN		: in	std_logic ; 
  		D0HSDESEREN		: in 	std_logic ; 	
 	 	D0HSRXDATA		: out 	std_logic_vector( 7 downto 0) ; 
 		D0HSBYTECLKD		: out 	std_logic ; 
 		D0SYNC			: out 	std_logic ; 
 		D0ERRSYNC		: out 	std_logic ; 
	      	D0HSBYTECLKSNOSYNC	: out 	std_logic ; 
			-- DATA1 Interface pins
		DP1			: inout std_ulogic ; 
		DN1			: inout std_ulogic ;  
 		D1DTXLPP		: in 	std_logic ; 
 		D1DTXLPN		: in	std_logic ; 
  		D1TXLPEN		: in 	std_logic ; 
 		D1DRXLPP		: out 	std_logic ;
	  	D1DRXLPN		: out 	std_logic ; 
 		D1RXLPEN		: in	std_logic ;
 		D1DCDP			: out 	std_logic ; 
		D1DCDN			: out  	std_logic ; 
 		D1CDEN			: in	std_logic ; 
  		D1TXHSPD		: in 	std_logic ; 
 		D1TXHSEN		: in	std_logic ;  
		D1HSTXDATA		: in 	std_logic_vector( 7 downto 0) ; 
  		D1HSSEREN		: in	std_logic ; 
 		D1RXHSEN		: in 	std_logic ;
  		D1HSDESEREN		: in 	std_logic ; 
	 	D1HSRXDATA		: out   std_logic_vector( 7 downto 0) ; 
 		D1SYNC			: out 	std_logic ; 
 		D1ERRSYNC		: out 	std_logic ; 
 		D1NOSYNC		: out 	std_logic ; 
			-- DATA2 Interface pins
		DP2			: inout std_ulogic ;
		DN2			: inout std_ulogic ; 
 		D2DTXLPP		: in	std_logic ; 
 		D2DTXLPN		: in 	std_logic ; 
  		D2TXLPEN		: in 	std_logic ; 
 		D2DRXLPP		: out 	std_logic ; 
	  	D2DRXLPN		: out 	std_logic ; 
 		D2RXLPEN		: in 	std_logic ; 
 		D2DCDP			: out 	std_logic ; 
		D2DCDN			: out 	std_logic ; 
 		D2CDEN			: in	std_logic ;
  		D2TXHSPD		: in	std_logic ; 
 		D2TXHSEN		: in	std_logic ; 		 
    	 	D2HSTXDATA		: in	std_logic_vector( 7 downto 0) ; 
  		D2HSSEREN		: in	std_logic ; 
 		D2RXHSEN		: in	std_logic ; 
  		D2HSDESEREN		: in	std_logic ; 
 	 	D2HSRXDATA		: out 	std_logic_vector( 7 downto 0) ; 
 		D2SYNC			: out 	std_logic ; 
 		D2ERRSYNC		: out 	std_logic ;
 		D2NOSYNC		: out 	std_logic ; 
			-- DATA3 Interface pins
		DP3			: inout std_ulogic ; 
		DN3			: inout std_ulogic ;
 		D3DTXLPP		: in 	std_logic ; 
 		D3DTXLPN		: in	std_logic ; 
  		D3TXLPEN		: in 	std_logic ; 
 		D3DRXLPP		: out 	std_logic ; 
	  	D3DRXLPN		: out 	std_logic ;
 		D3RXLPEN		: in	std_logic ; 
 		D3DCDP			: out 	std_logic ; 
		D3DCDN			: out 	std_logic ; 
 		D3CDEN			: in	std_logic ; 
  		D3TXHSPD		: in	std_logic ; 
 		D3TXHSEN		: in	std_logic ;  
  	 	D3HSTXDATA		: in 	std_logic_vector( 7 downto 0) ; 
  		D3HSSEREN		: in	std_logic ; 
 		D3RXHSEN		: in	std_logic ; 
  		D3HSDESEREN		: in	std_logic ; 
 	 	D3HSRXDATA		: out 	std_logic_vector( 7 downto 0) ; 
 		D3SYNC			: out 	std_logic ;	
 		D3ERRSYNC		: out	std_logic ; 
 		D3NOSYNC		: out 	std_logic ; 
			-- CLOCK Interface pins
		CKP			: inout std_ulogic ;  
		CKN			: inout std_ulogic ; 
 		CLKDTXLPP		: in 	std_logic ; 
 		CLKDTXLPN		: in	std_logic ; 
  		CLKTXLPEN		: in 	std_logic ; 
	  	CLKDRXLPP		: out 	std_logic ; 
	  	CLKDRXLPN		: out 	std_logic ; 
  		CLKRXLPEN		: in	std_logic ; 
  		CLKTXHSPD		: in	std_logic ; 
 		CLKTXHSEN		: in	std_logic ; 
	       	CLKTXHSGATE		: in	std_logic ; 
  		CLKRXHSEN		: in	std_logic ; 
	     	CLKHSBYTE		: out 	std_logic ; 
			-- Universal MIPI PLL Interface pins
 		PLLPU			: in 	std_logic ; 
 		PLLREF			: in	std_logic ; 
 		PLLLOCK			: out 	std_logic ; 
			-- Universal MIPI PLL Serial Configuration Register Interface pins
 		PLLCFGSRDI		: in	std_logic ; 
 		PLLCFGSRRESET		: in	std_logic ; 
 		PLLCFGSRCLK		: in	std_logic ; 
 		PLLCFGSRDO		: out 	std_logic 
	);

end component; 

COMPONENT SB_I2C
   GENERIC (
      -- Channels and Quads Attr
    I2C_SLAVE_INIT_ADDR : String :=  "0b1111100001";
    BUS_ADDR74   : String := "0b0110" );
PORT (
 		SBCLKI			: in 	std_logic ; 
 		SBRWI			: in 	std_logic ; 
 		SBSTBI			: in 	std_logic ; 
 		SBADRI7			: in 	std_logic ; 
 		SBADRI6			: in 	std_logic ; 
 		SBADRI5			: in 	std_logic ; 
 		SBADRI4			: in 	std_logic ; 
 		SBADRI3			: in 	std_logic ; 
 		SBADRI2			: in 	std_logic ; 
 		SBADRI1			: in 	std_logic ; 
 		SBADRI0			: in 	std_logic ; 
 		SBDATI7			: in 	std_logic ; 
 		SBDATI6			: in 	std_logic ; 
 		SBDATI5			: in 	std_logic ; 
 		SBDATI4			: in 	std_logic ; 
 		SBDATI3			: in 	std_logic ; 
 		SBDATI2			: in 	std_logic ; 
 		SBDATI1			: in 	std_logic ; 
 		SBDATI0			: in 	std_logic ; 
 		SCLI			: in 	std_logic ; 
 		SDAI			: in 	std_logic ; 

 		SBDATO7			: out 	std_logic ; 
 		SBDATO6			: out 	std_logic ; 
 		SBDATO5			: out 	std_logic ; 
 		SBDATO4			: out 	std_logic ; 
 		SBDATO3			: out 	std_logic ; 
 		SBDATO2			: out 	std_logic ; 
 		SBDATO1			: out 	std_logic ; 
 		SBDATO0			: out 	std_logic ; 
 		SBACKO			: out 	std_logic ; 
 		I2CIRQ			: out 	std_logic ;
 		I2CWKUP			: out 	std_logic;
 		SCLO			: out 	std_logic ; 
 		SCLOE			: out 	std_logic ; 
 		SDAO			: out 	std_logic ; 
 		SDAOE			: out 	std_logic  

        );
END COMPONENT;

COMPONENT SB_SPI
   GENERIC (
      -- Channels and Quads Attr
    BUS_ADDR74   : String := "0b0101" );
PORT (
                SBCLKI                  : in    std_logic ;
                SBRWI                   : in    std_logic ;
                SBSTBI                  : in    std_logic ;
                SBADRI7                 : in    std_logic ;
                SBADRI6                 : in    std_logic ;
                SBADRI5                 : in    std_logic ;
                SBADRI4                 : in    std_logic ;
                SBADRI3                 : in    std_logic ;
                SBADRI2                 : in    std_logic ;
                SBADRI1                 : in    std_logic ;
                SBADRI0                 : in    std_logic ;
                SBDATI7                 : in    std_logic ;
                SBDATI6                 : in    std_logic ;
                SBDATI5                 : in    std_logic ;
                SBDATI4                 : in    std_logic ;
                SBDATI3                 : in    std_logic ;
                SBDATI2                 : in    std_logic ;
                SBDATI1                 : in    std_logic ;
                SBDATI0                 : in    std_logic ;
                MI                      : in    std_logic ;
                SI                      : in    std_logic ;
                SCKI                    : in    std_logic ;
                SCSNI                   : in    std_logic ;

                SBDATO7                 : out   std_logic ;
                SBDATO6                 : out   std_logic ;
                SBDATO5                 : out   std_logic ;
                SBDATO4                 : out   std_logic ;
                SBDATO3                 : out   std_logic ;
                SBDATO2                 : out   std_logic ;
                SBDATO1                 : out   std_logic ;
                SBDATO0                 : out   std_logic ;
                SBACKO                  : out   std_logic ;
                SPIIRQ                  : out   std_logic ;
				SPIWKUP			: out  std_logic;
                SO                      : out   std_logic ;
                SOE                     : out   std_logic ;
                MO                      : out   std_logic ;
                MOE                     : out   std_logic ;
                SCKO                    : out   std_logic ;
                SCKOE                   : out   std_logic ;
                MCSNO3                  : out   std_logic ;
                MCSNO2                  : out   std_logic ;
                MCSNO1                  : out   std_logic ;
                MCSNO0                  : out   std_logic ;
                MCSNOE3                 : out   std_logic ;
                MCSNOE2                 : out   std_logic ;
                MCSNOE1                 : out   std_logic ;
                MCSNOE0                 : out   std_logic 
    );
END COMPONENT;

COMPONENT SB_HSOSC
          port(
                CLKM : out std_logic  ;
                ENACLKM : in  std_logic 
               );
END COMPONENT;

COMPONENT SB_LSOSC
          port(
                CLKK : out std_logic  ;
                ENACLKK : in  std_logic
               );
END COMPONENT;


COMPONENT  SB_HFOSC   
	generic( 
	CLKHF_DIV: string:="0b00" ); 
			port(
					CLKHF : out std_logic;
					CLKHFEN  :in std_logic;
					CLKHFPU : in std_logic
    );
end COMPONENT ;


COMPONENT  SB_LFOSC   
			port(
			CLKLF : out std_logic;
			CLKLFEN  :in std_logic;
			CLKLFPU : in std_logic
				);
end COMPONENT;


COMPONENT  SB_RGB_DRV  
	generic(
	RGB0_CURRENT: string:="0b000000"; 
	RGB1_CURRENT: string:="0b000000";
	RGB2_CURRENT: string:="0b000000");   
			port(
				RGB0: out std_logic;  
				RGB1: out std_logic;
				RGB2: out std_logic;
				RGBLEDEN  :in std_logic;
				RGB0PWM  :in std_logic;
				RGB1PWM:in std_logic;
				RGB2PWM :in std_logic;
				RGBPU : in std_logic
				);
end COMPONENT ;


COMPONENT SB_IR_DRV   
	generic(
	IR_CURRENT: string:="0b0000000000" ); 
			port(
				IRLED : out std_logic;
				IRLEDEN  :in std_logic;
				IRPU  :in std_logic;						 
				IRPWM : in std_logic
    );
end COMPONENT ;

COMPONENT SB_LEDD_IP   
			port(
			PWMOUT0 : out std_logic;	
			PWMOUT1 : out std_logic;
			PWMOUT2 : out std_logic;
			LEDDON : out std_logic; 
			LEDDCS:in std_logic;
			LEDDCLK:in std_logic;
			LEDDDAT7:in std_logic;
			LEDDDAT6:in std_logic;
			LEDDDAT5:in std_logic;
			LEDDDAT4:in std_logic;
			LEDDDAT3:in std_logic;
			LEDDDAT2:in std_logic;
			LEDDDAT1:in std_logic;
			LEDDDAT0:in std_logic;
			LEDDADDR3:in std_logic;
			LEDDADDR2:in std_logic;
			LEDDADDR1:in std_logic;
			LEDDADDR0:in std_logic;
			LEDDDEN:in std_logic;
			LEDDEXE:in std_logic;
			LEDDRST:in std_logic
				);
end COMPONENT ;

component SB_IO_OD
          generic ( PIN_TYPE    : bit_vector( 5  downto 0);
                    --PULLUP   : bit; 
                    NEG_TRIGGER : bit 
                    --IO_STANDARD : string 
                  ) ;
          port( 
               DOUT1 		    : in std_logic;
				DOUT0 		    : in std_logic;
				CLOCKENABLE		: in std_logic;
				LATCHINPUTVALUE	: in std_logic;
				INPUTCLK			: in std_logic;
				DIN1				: out std_logic;
				DIN0				: out std_logic;
				OUTPUTENABLE		: in std_logic	:='H';
				OUTPUTCLK			: in std_logic;
				PACKAGEPIN			: inout	std_logic                 
               );
end component;


COMPONENT SB_LED_DRV_CUR 
			Port ( 
				EN : in  STD_LOGIC;
				LEDPU : out  STD_LOGIC);
end COMPONENT;


COMPONENT  SB_RGBA_DRV  
 generic ( 
			CURRENT_MODE :string := "0b0";
			RGB0_CURRENT :string := "0b000000";
		    RGB1_CURRENT :string := "0b000000";
		    RGB2_CURRENT :string := "0b000000"
);
port (
        RGB0PWM : in std_logic;
		 RGB1PWM : in std_logic;
		 RGB2PWM : in std_logic;
		 CURREN : in std_logic;
		 RGBLEDEN : in std_logic;
        RGB0 : out std_logic;
		 RGB1 : out std_logic;
		 RGB2 : out std_logic
	);	 
end COMPONENT;

---------------------------------------------------------------------------
--   BlackBox : SB_IR400_DRV
---------------------------------------------------------------------------
COMPONENT  SB_IR400_DRV  
 generic ( 
	   CURRENT_MODE :string := "0b0";
	   IR400_CURRENT :string := "0b00000000"
);
port (
        CURREN : in std_logic;
		 IRLEDEN : in std_logic;
		 IRPWM : in std_logic;
        IRLED : out std_logic
	);	 
end COMPONENT;


---------------------------------------------------------------------------
--   BlackBox : SB_BARCODE_DRV
---------------------------------------------------------------------------
COMPONENT  SB_BARCODE_DRV  
 generic ( 
		CURRENT_MODE :string := "0b0";
		BARCODE_CURRENT :string := "0b0000"
);
port (
        BARCODEEN: in std_logic;
		CURREN: in std_logic;
		BARCODEPWM : in std_logic;
        BARCODE : out std_logic
	);	 
end COMPONENT;

-----------------------------------------------------------------
-- BLACK BOX : IRIP (RxTx) 
------------------------------------------------------------------ 
COMPONENT  SB_IR_IP  
port (
         ADRI3: in std_logic;
		 ADRI2: in std_logic;
		 ADRI1: in std_logic;
		 ADRI0 : in std_logic;
		 CLKI: in std_logic;
		 CSI: in std_logic;
		 DENI: in std_logic;
		 WEI : in std_logic;
		 EXE: in std_logic;
		 LEARN : in std_logic;
		 RST: in std_logic;
		 IRIN : in std_logic;
		 WDATA7: in std_logic;
		 WDATA6: in std_logic;
		 WDATA5: in std_logic;
		 WDATA4: in std_logic;
		 WDATA3: in std_logic;
		 WDATA2: in std_logic;
		 WDATA1: in std_logic;	
		 WDATA0 : in std_logic;
         BUSY:out std_logic;
		 DRDY:out std_logic;
		 ERR : out std_logic;
		 IROUT : out std_logic;
		 RDATA7: out std_logic;	
		 RDATA6: out std_logic;
		 RDATA5: out std_logic;
		 RDATA4: out std_logic;
		 RDATA3: out std_logic;
		 RDATA2: out std_logic;
		 RDATA1: out std_logic;
		 RDATA0 : out std_logic
	);	 
end COMPONENT;

-------------------------------------------------- 
-- BLACKBOX :	SB_I2C_FIFO  
--------------------------------------------------- 
COMPONENT  SB_I2C_FIFO  
 generic ( 
	   I2C_SLAVE_ADDR :string := "0b1111100001"
);
port (
         CLKI: in std_logic;
		 CSI: in std_logic;
		 STBI: in std_logic;
		 WEI: in std_logic;
		 ADRI3: in std_logic;
		 ADRI2: in std_logic;
		 ADRI1: in std_logic;
		 ADRI0 : in std_logic;
		 DATI9: in std_logic;
		 DATI8: in std_logic;
		 DATI7: in std_logic;
		 DATI6: in std_logic;
		 DATI5: in std_logic;
		 DATI4: in std_logic;
		 DATI3: in std_logic;
		 DATI2: in std_logic;
		 DATI1: in std_logic;
		 DATI0 : in std_logic;
		 FIFORST : in std_logic;
		 SCLI : in std_logic;
		 SDAI : in std_logic;
         ACKO: out std_logic;
		 I2CIRQ: out std_logic;
		 I2CWKUP: out std_logic;
		 SRWO : out std_logic;
		 DATO9: out std_logic;
		 DATO8: out std_logic;
		 DATO7: out std_logic;
		 DATO6: out std_logic;
		 DATO5: out std_logic;
		 DATO4: out std_logic;
		 DATO3: out std_logic;
		 DATO2: out std_logic;
		 DATO1: out std_logic;
		 DATO0 : out std_logic;
		 SCLO: out std_logic;
		 SCLOE : out std_logic;
		 SDAO: out std_logic;
		 SDAOE : out std_logic;
		 TXFIFOAEMPTY : out std_logic;
		 TXFIFOEMPTY: out std_logic;
		 TXFIFOFULL: out std_logic;
		 RXFIFOAFULL: out std_logic;
		 RXFIFOFULL: out std_logic;
		 RXFIFOEMPTY: out std_logic;
		 MRDCMPL : out std_logic
	);	 
end COMPONENT;

COMPONENT SB_LEDDA_IP   
			port(
			PWMOUT0 : out std_logic;	
			PWMOUT1 : out std_logic;
			PWMOUT2 : out std_logic;
			LEDDON : out std_logic; 
			LEDDCS:in std_logic;
			LEDDCLK:in std_logic;
			LEDDDAT7:in std_logic;
			LEDDDAT6:in std_logic;
			LEDDDAT5:in std_logic;
			LEDDDAT4:in std_logic;
			LEDDDAT3:in std_logic;
			LEDDDAT2:in std_logic;
			LEDDDAT1:in std_logic;
			LEDDDAT0:in std_logic;
			LEDDADDR3:in std_logic;
			LEDDADDR2:in std_logic;
			LEDDADDR1:in std_logic;
			LEDDADDR0:in std_logic;
			LEDDDEN:in std_logic;
			LEDDEXE:in std_logic;
			LEDDRST:in std_logic
				);
end COMPONENT ;

COMPONENT  SB_IR500_DRV
GENERIC (
	   CURRENT_MODE :string := "0b0";
	   IR500_CURRENT :string := "0b000000000000"
);
port (
IRLEDEN: in std_logic;
IRPWM: in std_logic;
CURREN: in std_logic;
IRLED1: out std_logic;
IRLED2: out std_logic
  );
end component;


COMPONENT  SB_RGB_IP
port (
CLK: in std_logic;
RST: in std_logic;
PARAMSOK: in std_logic;
RGBCOLOR: in std_logic_vector (3 downto 0); 
BRIGHTNESS: in std_logic_vector (3 downto 0); 
BREATHRAMP: in std_logic_vector (3 downto 0); 
BLINKRATE: in std_logic_vector (3 downto 0); 
REDPWM: out std_logic;
GREENPWM:out std_logic;
BLUEPWM:out std_logic
  );
end component;

component SB_IO_I3C
          generic ( PIN_TYPE    : bit_vector( 5  downto 0);
                    PULLUP   : bit := '0'; 
		    WEAK_PULLUP : bit := '0';
                    NEG_TRIGGER : bit := '0' ; 
                    IO_STANDARD : string :="SB_LVCMOS"
                  ) ;
          port( 
                PACKAGE_PIN        : inout std_logic ;
                LATCH_INPUT_VALUE  : in  std_logic ;
                CLOCK_ENABLE       : in  std_logic ;
                INPUT_CLK          : in  std_logic ;
                OUTPUT_CLK         : in  std_logic ;
                OUTPUT_ENABLE      : in  std_logic ;
                D_OUT_1            : in  std_logic ;
                D_OUT_0            : in  std_logic ;
	  	PU_ENB		   : in  std_logic ;
	  	WEAK_PU_ENB	   : in  std_logic ; 
                D_IN_1             : out std_logic ;
                D_IN_0             : out std_logic                 
               );
end component; 

component SB_SPRAM256KA
port (
	ADDRESS : in  std_logic_vector (13 downto 0);
	DATAIN : in std_logic_vector (15 downto 0);
	MASKWREN : in std_logic_vector(3 downto 0);
	WREN,CHIPSELECT,CLOCK,STANDBY,SLEEP,POWEROFF : in std_logic;
	DATAOUT : out  std_logic_vector(15 downto 0)
);
end component;


attribute syn_black_box of all : component is true;
attribute syn_lib_cell of all : component is true;
attribute black_box_pad_pin of SB_IO_DLY : component is "PACKAGE_PIN";
attribute black_box_pad_pin of SB_IO_I3C : component is "PACKAGE_PIN";
attribute black_box_pad_pin of SB_MIPI_TX_4LANE : component is "DP3,DN3,DP2,DN2,DP1,DN1,DP0,DN0,CKP,CKN";
attribute black_box_pad_pin of SB_IO_OD : component is "PACKAGEPIN";
attribute black_box_pad_pin of SB_RGB_DRV : component is "RGB0,RGB1,RGB2";
attribute black_box_pad_pin of SB_IR_DRV : component is "IRLED";
attribute ROUTE_THROUGH_FABRIC of SB_LFOSC : component is true;
attribute ROUTE_THROUGH_FABRIC of SB_HFOSC : component is true;
attribute SDA_INPUT_DELAYED of SB_I2C : component is true;
attribute SDA_OUTPUT_DELAYED of SB_I2C : component is false;
attribute SCL_INPUT_FILTERED of SB_I2C : component is false;
attribute black_box_pad_pin of SB_BARCODE_DRV : component is "BARCODE";
attribute black_box_pad_pin of SB_RGBA_DRV : component is "RGB0,RGB1,RGB2";
attribute black_box_pad_pin of SB_IR400_DRV : component is "IRLED";
attribute black_box_pad_pin of SB_IR500_DRV : component is "IRLED1,IRLED2";
attribute SDA_INPUT_DELAYED of SB_I2C_FIFO : component is true;
attribute SDA_OUTPUT_DELAYED of SB_I2C_FIFO : component is false;
attribute I2C_CLK_DIVIDER of SB_I2C_FIFO : component is 0;
attribute I2C_FIFO_ENB of SB_I2C_FIFO : component is "ENABLED";
attribute TEST_SPRAM of SB_SPRAM256KA : component is "";
end COMPONENTS;




