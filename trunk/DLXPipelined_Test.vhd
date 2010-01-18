--------------------------------------------------------------------------------------
-- Dettagli relativi alla implementazione del DLX Pipelined in VHDL in:
-- 
-- "Progetto di Processore Pipelined in VHDL", Andrea Bucaletti, AA 2008/09
-- "Gestione su scheda FPGA di processore pipelined", Domenico Di Carlo, AA 2008/09
--
--------------------------------------------------------------------------------------

 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Global.all;
--use work.Fixed_32.all;
use work.Float_32.all;

entity DLXPipelined_Test is
end DLXPipelined_Test;

architecture Test of DLXPipelined_Test is
	component DLXPipelined
	port (
		-- clock e reset
		clk: in std_logic;
		reset: in std_logic;
		
		-- pc lungo la pipe
		pc_fetch: inout std_logic_vector(PC_BITS-1 downto 0);
		pc_decode: inout std_logic_vector(PC_BITS-1 downto 0);
		pc_execute: inout std_logic_vector(PC_BITS-1 downto 0);
		pc_memory: inout std_logic_vector(PC_BITS-1 downto 0);
		pc_writeback: inout std_logic_vector(PC_BITS-1 downto 0);		
		
		-- istruzioni lungo la pipe
		instruction_fetch: inout std_logic_vector(PARALLELISM-1 downto 0);
		instruction_decode: inout std_logic_vector(PARALLELISM-1 downto 0);
		instruction_execute: inout std_logic_vector(PARALLELISM-1 downto 0);		
		instruction_memory: inout std_logic_vector(PARALLELISM-1 downto 0);		
		instruction_writeback: inout std_logic_vector(PARALLELISM-1 downto 0);		
		
		--segnali per il btb
		btb_fetch_pc_dest: inout std_logic_vector(PC_BITS-1 downto 0);
		btb_fetch_tkn: inout std_logic;
		btb_fetch_rd : inout std_logic;
		btb_pred_ok: inout std_logic;
		btb_exe_wr: inout std_logic;	
		btb_exe_pc_dest: inout std_logic_vector(PC_BITS-1 downto 0);
		btb_exe_tkn: inout std_logic;
		
		-- stadio di fetch
		
		-- stadio di decode
		dec_instruction_format: inout std_logic_vector(2 downto 0);
		dec_register_a: inout std_logic_vector(PARALLELISM-1 downto 0);
		dec_register_b: inout std_logic_vector(PARALLELISM-1 downto 0);
		
		-- stadio di execute
		exe_instruction_format: inout std_logic_vector(2 downto 0);
		exe_alu_exit: inout std_logic_vector(PARALLELISM-1 downto 0);
		exe_register_b: inout std_logic_vector(PARALLELISM-1 downto 0);
		exe_force_jump: inout std_logic;
		exe_pc_for_jump: inout std_logic_vector(PC_BITS-1 downto 0);
		
		-- stadio di memory
		mem_instruction_format: inout std_logic_vector(2 downto 0);
		mem_data_out: inout std_logic_vector(PARALLELISM-1 downto 0);
		mem_dest_register: inout std_logic_vector(4 downto 0); -- numero rd per forwarding unit
		mem_dest_register_data: inout std_logic_vector(PARALLELISM-1 downto 0); -- dati registro destinazione per 
																										-- forwarding unit
		
		-- stadio di writeback
		wb_instruction_format: inout std_logic_vector(2 downto 0);
		wb_dest_register: inout std_logic_vector(4 downto 0);
		wb_dest_register_data: inout std_logic_vector(PARALLELISM-1 downto 0);
		wb_dest_register_type: inout std_logic;
		
		-- uscite di debug
		register_file_debug: out register_file_type;
		fp_register_file_debug: out register_file_type
	);
	end component;
	
	signal clk: std_logic := '0';
	signal reset: std_logic := '0';
	
	signal pc_fetch: std_logic_vector(PC_BITS-1 downto 0);
	signal pc_decode: std_logic_vector(PC_BITS-1 downto 0);
	signal pc_execute: std_logic_vector(PC_BITS-1 downto 0);
	signal pc_memory: std_logic_vector(PC_BITS-1 downto 0);
	signal pc_writeback: std_logic_vector(PC_BITS-1 downto 0);
	
	--segnali per il btb
	signal btb_exe_tkn: std_logic;
	signal btb_fetch_pc_dest: std_logic_vector(PC_BITS-1 downto 0);
	signal btb_fetch_tkn: std_logic;
	signal btb_fetch_rd : std_logic;
	signal btb_pred_ok: std_logic;
	signal btb_exe_wr: std_logic;
	signal btb_exe_pc_dest: std_logic_vector(PC_BITS-1 downto 0);
	
	signal instruction_fetch: std_logic_vector(PARALLELISM-1 downto 0);
	signal instruction_decode: std_logic_vector(PARALLELISM-1 downto 0);
	signal instruction_execute: std_logic_vector(PARALLELISM-1 downto 0);
	signal instruction_memory: std_logic_vector(PARALLELISM-1 downto 0);
	signal instruction_writeback: std_logic_vector(PARALLELISM-1 downto 0);
	
	signal dec_instruction_format: std_logic_vector(2 downto 0);
	signal dec_register_a: std_logic_vector(PARALLELISM-1 downto 0);
	signal dec_register_b: std_logic_vector(PARALLELISM-1 downto 0);
	
	signal exe_instruction_format: std_logic_vector(2 downto 0);
	signal exe_alu_exit: std_logic_vector(PARALLELISM-1 downto 0);
	signal exe_register_b: std_logic_vector(PARALLELISM-1 downto 0);
	signal exe_force_jump: std_logic;
	signal exe_pc_for_jump: std_logic_vector(PC_BITS-1 downto 0);
	
	signal mem_instruction_format: std_logic_vector(2 downto 0);
	signal mem_data_out: std_logic_vector(PARALLELISM-1 downto 0);
	signal mem_dest_register: std_logic_vector(4 downto 0);
	signal mem_dest_register_data: std_logic_vector(PARALLELISM-1 downto 0); 
	
	signal wb_dest_register: std_logic_vector(4 downto 0);
	signal wb_dest_register_data: std_logic_vector(PARALLELISM-1 downto 0);
	signal wb_dest_register_type: std_logic;
	signal wb_instruction_format: std_logic_vector(2 downto 0);
	
	signal register_file_debug: register_file_type;
	signal fp_register_file_debug: register_file_type;
	
	-- segnali HR
	
	type real_array is array(integer range <>) of real;
	signal fp_register_file_debug_HR: real_array(fp_register_file_debug'low to fp_register_file_debug'high); 
	
	begin
		DLXPipelined_uut: DLXPipelined
			port map (
				clk => clk,
				reset => reset,
				
				pc_fetch => pc_fetch,
				pc_decode => pc_decode,
				pc_execute => pc_execute,
				pc_memory => pc_memory,
				pc_writeback => pc_writeback,
				
				--segnali per il btb
				btb_fetch_pc_dest => btb_fetch_pc_dest,
				btb_fetch_tkn => btb_fetch_tkn,
				btb_fetch_rd => btb_fetch_rd,
				btb_pred_ok => btb_pred_ok,
				btb_exe_wr => btb_exe_wr,
				btb_exe_pc_dest => btb_exe_pc_dest,
				btb_exe_tkn => btb_exe_tkn,	
				
				instruction_fetch => instruction_fetch,
				instruction_decode => instruction_decode,
				instruction_execute => instruction_execute,
				instruction_memory => instruction_memory,
				instruction_writeback => instruction_writeback,
				
				dec_instruction_format => dec_instruction_format,
				dec_register_a => dec_register_a,
				dec_register_b => dec_register_b,
				
				exe_instruction_format => exe_instruction_format,
				exe_alu_exit => exe_alu_exit,
				exe_register_b => exe_register_b,				
				exe_force_jump => exe_force_jump,
				exe_pc_for_jump => exe_pc_for_jump,
				
				mem_instruction_format => mem_instruction_format,
				mem_data_out => mem_data_out,
				mem_dest_register => mem_dest_register,
				mem_dest_register_data => mem_dest_register_data,
				
				wb_dest_register => wb_dest_register,
				wb_dest_register_data => wb_dest_register_data,
				wb_dest_register_type => wb_dest_register_type,
				wb_instruction_format => wb_instruction_format,
				
				register_file_debug => register_file_debug,
				fp_register_file_debug => fp_register_file_debug
			);
		
		clk_process: process begin
			clk <= '0';
			wait for TIME_UNIT/2;
			clk <= '1';
			wait for TIME_UNIT/2;
		end process;
		
		stimulus_process: process begin
			reset <= '1';
			wait for TIME_UNIT*2.25;
			reset <= '0';
			wait;
		end process;
		
		signals: process(fp_register_file_debug) begin
			for i in fp_register_file_debug_HR'low to fp_register_file_debug_HR'high loop
				fp_register_file_debug_HR(i) <= to_real(fp_register_file_debug(i));
			end loop;
		end process;
		
	end Test;
