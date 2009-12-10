----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:46:42 12/10/2009 
-- Design Name: 
-- Module Name:    Btb_component - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Global.all;
use work.Btb.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Btb_component is
    Port ( wr : in  STD_LOGIC;
           rd : in  STD_LOGIC;
           pc_if : in  std_logic_vector(PC_BITS-1 downto 0);
           pc_ex : in  std_logic_vector(PC_BITS-1 downto 0);
           pc_dest_ex : in  std_logic_vector(PC_BITS-1 downto 0);
           pred_ok_ex : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           tkn_if : out  STD_LOGIC;
           pc_dest_if : out  std_logic_vector(PC_BITS-1 downto 0));
end Btb_component;

architecture Behavioral of Btb_component is
	
	signal Btb_inst : btb_cache; -- Btb_inst(0)(0).tag_pc <= (others => '0'); Funziona
	
begin
	
	a_reset : process(reset)
	begin
	
		if(reset = '1') then
			for i in 0 to SLOTS_NUM-1 loop
				for j in 0 to WAYS_NUM-1 loop
					Btb_inst(i)(j).tag_pc <= (others => '0');
					Btb_inst(i)(j).dest_pc <= (others => '0');
					Btb_inst(i)(j).pred <= (others => '0');
					Btb_inst(i)(j).status <= '0';
					Btb_inst(i)(j).repl <= '0';
				end loop;
			end loop;
		end if;
		
	end process;
	
	
	
end Behavioral;

