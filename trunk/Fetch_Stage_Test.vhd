library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Global.All;

entity Fetch_Stage_Test is
end Fetch_Stage_Test;

architecture Test of Fetch_Stage_Test is
	
	component Fetch_Stage
		port (
			clk: in std_logic;
			reset: in std_logic;
			force_jump: in std_logic;
			pc_for_jump: in std_logic_vector(PC_BITS-1 downto 0);
			instruction: out std_logic_vector(PARALLELISM-1 downto 0);
			pc: out std_logic_vector(PC_BITS-1 downto 0)		
		);
	end component;
	
	-- in
	signal clk: std_logic := '0';
	signal reset: std_logic := '0';
	signal force_jump: std_logic := '0';
	signal pc_for_jump: std_logic_vector(PC_BITS-1 downto 0) := (others => '0');
	
	-- out
	signal instruction: std_logic_vector(PARALLELISM-1 downto 0);
	signal pc: std_logic_vector(PC_BITS-1 downto 0);			
	
	begin
		Fetch_Stage_uut: Fetch_Stage
			port map (
				clk => clk,
				reset => reset,
				force_jump => force_jump,
				pc_for_jump => pc_for_jump,
				instruction => instruction,
				pc => pc
			);
			
		clk_process: process begin
			clk <= '0';
			wait for TIME_UNIT/2;
			clk <= '1';
			wait for TIME_UNIT/2;
		end process;
		
		force_jump_process: 
		process begin
			wait for TIME_UNIT*10;
			force_jump <= '1';
			wait for TIME_UNIT;
			force_jump <= '0';
		end process;
		
		reset_process: process begin
			reset <= '1';
			wait for TIME_UNIT*2;
			reset <= '0';
			wait;
		end process;
		
	end Test;

