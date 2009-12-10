library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Global.all;

entity Decode_Stage_Test is
end Decode_Stage_Test;

architecture Test of Decode_Stage_Test is
	component Decode_Stage
		port (
			-- porte standard
			clk: in std_logic;
			reset: in std_logic;
			data_from_WB: in std_logic_vector(PARALLELISM-1 downto 0); -- dati da scrivere provenienti dallo stadio di WB
			dest_register_from_WB: in std_logic_vector(REGISTER_ADDR_LEN-1 downto 0); -- registro di destinazione del write_back
			pc_in: in std_logic_vector(PC_BITS-1 downto 0);
			pc_out: out std_logic_vector(PC_BITS-1 downto 0);
			instruction_in: in std_logic_vector(PARALLELISM-1 downto 0);
			instruction_out: out std_logic_vector(PARALLELISM-1 downto 0);
			instruction_format: out std_logic_vector(1 downto 0);
			register_a: out std_logic_vector(PARALLELISM-1 downto 0);
			register_b: out std_logic_vector(PARALLELISM-1 downto 0);
		
			-- porte di debug
			register_file_debug: out register_file_type
		);
	end component;
	
	signal clk:  std_logic := '0';
	signal reset: std_logic := '0';
	signal data_from_WB: std_logic_vector(PARALLELISM-1 downto 0) := (others => '0'); -- dati da scrivere provenienti dallo stadio di WB
	signal dest_register_from_WB: std_logic_vector(REGISTER_ADDR_LEN-1 downto 0) := (others => '0'); -- registro di destinazione del write_back
	
	signal pc_in: std_logic_vector(PC_BITS-1 downto 0) := (others => '0');
	signal pc_out: std_logic_vector(PC_BITS-1 downto 0);
	
	signal instruction_in: std_logic_vector(PARALLELISM-1 downto 0) := (others => '0');
	signal instruction_out: std_logic_vector(PARALLELISM-1 downto 0);
	
	signal instruction_format: std_logic_vector(1 downto 0);
	signal register_a: std_logic_vector(PARALLELISM-1 downto 0);
	signal register_b: std_logic_vector(PARALLELISM-1 downto 0);

	signal register_file_debug: register_file_type;
	
	type instruction_array_type is array(integer range <>) of std_logic_vector(31 downto 0);
	constant instruction_array_inst: instruction_array_type(0 to 31) := (
																				X"00430820",
																				X"00430824",
																				X"00430825",
																				X"00430828",
																				X"0043082C",
																				X"00430804",
																				X"0043082A",
																				X"00430829",
																				X"00430807",
																				X"00430806",
																				X"00430822",
																				X"00430826",
																				X"2021000A",
																				X"3021000A",
																				X"1020FFCE",
																				X"4C200000",
																				X"48200000",
																				X"3C01000A",
																				X"8C41000A",
																				X"6021000A",
																				X"7021000A",
																				X"5021000A",
																				X"6821000A",
																				X"6421000A",
																				X"5C21000A",
																				X"2821000A",
																				X"AC41000A",
																				X"3821000A",
																				X"8C01000A",
																				X"1420FF92",
																				X"0BFFFF8E",
																				X"0FFFFF8A"
																		);
	
	begin
		Decode_Stage_uut: Decode_Stage
			port map (
				clk => clk,
				reset => reset,
				data_from_WB => data_from_WB,
				dest_register_from_WB => dest_register_from_WB,
				pc_in => pc_in,
				pc_out => pc_out,
				instruction_in => instruction_in,
				instruction_out => instruction_out,
				instruction_format => instruction_format,
				register_a => register_a,
				register_b => register_b,
				register_file_debug => register_file_debug
			);
		
		clk_process: process begin
			clk <= '0';
			wait for TIME_UNIT/2;
			clk <= '1';
			wait for TIME_UNIT/2;
		end process;
		
		stimulus: process begin
			for i in 0 to instruction_array_inst'length loop
				instruction_in <= instruction_array_inst(i);
				wait for TIME_UNIT;
			end loop;
		end process;
		
	end Test;

