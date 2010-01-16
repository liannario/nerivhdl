--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   16:26:49 01/15/2010
-- Design Name:   
-- Module Name:   C:/Xilinx_projects/DLXSourceCodeVHDL_BTB/DLX 11.1 Rewrite/DLXPipe/Btb_component_Test.vhd
-- Project Name:  DLXPipe
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: Btb_component
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;
use IEEE.std_logic_arith.all;
use work.Global.all;
use work.Btb.all;
 
ENTITY Btb_component_Test IS
END Btb_component_Test;
 
ARCHITECTURE behavior OF Btb_component_Test IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT Btb_component
    PORT(
         wr : IN  std_logic;
         rd : IN  std_logic;
         pc_if : IN  std_logic_vector(29 downto 0);
         pc_ex : IN  std_logic_vector(29 downto 0);
         pc_dest_ex : IN  std_logic_vector(29 downto 0);
         pred_ok_ex : IN  std_logic;
         reset : IN  std_logic;
         tkn_if : INOUT  std_logic;
         pc_dest_if : INOUT  std_logic_vector(29 downto 0)
        );
    END COMPONENT;
    
	--clock
	signal clk: std_logic := '0';

   --Inputs
   signal wr : std_logic := '0';
   signal rd : std_logic := '0';
   signal pc_if : std_logic_vector(29 downto 0) := (others => '0');
   signal pc_ex : std_logic_vector(29 downto 0) := (others => '0');
   signal pc_dest_ex : std_logic_vector(29 downto 0) := (others => '0');
   signal pred_ok_ex : std_logic := '0';
   signal reset : std_logic := '0';


 	--Outputs
   signal tkn_if : std_logic;
   signal pc_dest_if : std_logic_vector(29 downto 0);
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   Btb_component_uut: Btb_component PORT MAP (
          wr => wr,
          rd => rd,
          pc_if => pc_if,
          pc_ex => pc_ex,
          pc_dest_ex => pc_dest_ex,
          pred_ok_ex => pred_ok_ex,
          reset => reset,
          tkn_if => tkn_if,
          pc_dest_if => pc_dest_if
        );
 
    
   clk_process: process begin
			clk <= '0'; 
			wait for TIME_UNIT/2;
			clk <= '1';
			wait for TIME_UNIT/2;
		end process;
 

   -- Stimulus process
   reset_proces: process
   begin		
      
		reset <= '0';
		wait for TIME_UNIT;
		-- hold reset state for 100ms.
		reset <= '1';
      wait for TIME_UNIT*2;
		reset <= '0';
		wait;
   end process;

	write_btb: process
   begin		
      
		wait for TIME_UNIT*5;
		
		wr <= '0';
		wait for TIME_UNIT;
		wr <= '1';
		pc_ex <= conv_std_logic_vector(0, 30);
		pc_dest_ex <= conv_std_logic_vector(1000, 30);
		pred_ok_ex <= PRED_OK;
		
		wait for TIME_UNIT*3;
		
		wr <= '0';
		wait for TIME_UNIT;
		wr <= '1';
		pc_ex <= conv_std_logic_vector(64, 30);
		pc_dest_ex <= conv_std_logic_vector(4450, 30);
		pred_ok_ex <= PRED_NOT_OK;
		
		wait for TIME_UNIT*3;
		
		wr <= '0';
		wait for TIME_UNIT;
		wr <= '1';
		pc_ex <= conv_std_logic_vector(128, 30);
		pc_dest_ex <= conv_std_logic_vector(2000, 30);
		pred_ok_ex <= PRED_NOT_OK;
		
		wait for TIME_UNIT;
		wr <= '0';
		wait;
		
   end process;
END;
