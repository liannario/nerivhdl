
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Global.all;


entity DLXPipelined is
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
		
		--segnali per il btb
		-- predizione lungo la pipe
		tkn_decode: inout std_logic;
		tkn_execute: inout std_logic;
		
		-- istruzioni lungo la pipe
		instruction_fetch: inout std_logic_vector(PARALLELISM-1 downto 0);
		instruction_decode: inout std_logic_vector(PARALLELISM-1 downto 0);
		instruction_execute: inout std_logic_vector(PARALLELISM-1 downto 0);		
		instruction_memory: inout std_logic_vector(PARALLELISM-1 downto 0);		
		instruction_writeback: inout std_logic_vector(PARALLELISM-1 downto 0);
		
		-- stadio di fetch
		--segnali per il btb
		btb_fetch_pc_dest: inout std_logic_vector(PC_BITS-1 downto 0);
		btb_fetch_tkn: inout std_logic;
		btb_fetch_rd : inout std_logic;
		btb_pred_ok: inout std_logic;
		btb_exe_wr: inout std_logic;
		btb_exe_pc_dest: inout std_logic_vector(PC_BITS-1 downto 0);
		
		
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
end DLXPipelined;

architecture Arch1_DLXPipelined of DLXPipelined is
	--segnali per il btb
	component Btb_component
    port(
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
	end component;
	
	component Fetch_Stage
		port (
			-- uscite standard
			clk: in std_logic;
			reset: in std_logic;
			force_jump: in std_logic;
			pc_for_jump: in std_logic_vector(PC_BITS-1 downto 0);
			instruction: out std_logic_vector(PARALLELISM-1 downto 0);
			pc: out std_logic_vector(PC_BITS-1 downto 0);
			--segnali per il btb
			pc_dest_btb: in std_logic_vector(PC_BITS-1 downto 0);
			tkn_btb_in: in std_logic;
			--tkn_btb_out: out std_logic;
			rd_btb: out std_logic
		);	
	end component;
	
	component Decode_Stage
		port (
			-- porte standard
			clk: in std_logic;
			reset: in std_logic;
			data_from_WB: in std_logic_vector(PARALLELISM-1 downto 0); -- dati da scrivere provenienti dallo stadio di WB
			dest_register_from_WB: in std_logic_vector(REGISTER_ADDR_LEN-1 downto 0); -- registro di destinazione del write_back
			dest_register_type_WB: in std_logic;
			pc_in: in std_logic_vector(PC_BITS-1 downto 0);
			pc_out: out std_logic_vector(PC_BITS-1 downto 0);
			instruction_out: out std_logic_vector(PARALLELISM-1 downto 0);
			instruction_in: in std_logic_vector(PARALLELISM-1 downto 0);
			instruction_format: out std_logic_vector(2 downto 0);
			register_a: out std_logic_vector(PARALLELISM-1 downto 0);
			register_b: out std_logic_vector(PARALLELISM-1 downto 0);
			force_jump: in std_logic;
			--segnali per il btb
			tkn_in: in std_logic;
			tkn_out: out std_logic;
			
			-- porte di debug
			register_file_debug: out register_file_type;
			fp_register_file_debug: out register_file_type			
		);	
	end component;
	
	component Execute_Stage
		port (
			clk: in std_logic;
			pc_in: in std_logic_vector(PC_BITS-1 downto 0);
			pc_out: out std_logic_vector(PC_BITS-1 downto 0);
			instruction_format_in: in std_logic_vector(2 downto 0);
			instruction_format_out: out std_logic_vector(2 downto 0);
			instruction_in: in std_logic_vector(PARALLELISM-1 downto 0);
			instruction_out: out std_logic_vector(PARALLELISM-1 downto 0);
			register_a_in: in std_logic_vector(PARALLELISM-1 downto 0);
			register_b_in: in std_logic_vector(PARALLELISM-1 downto 0);
			alu_exit: out std_logic_vector(PARALLELISM-1 downto 0);
			register_b_out: out std_logic_vector(PARALLELISM-1 downto 0);
			force_jump: out std_logic;
			pc_for_jump: out std_logic_vector(PC_BITS-1 downto 0);
			--segnali per il btb
			tkn_in: in std_logic;
			wr_btb: out std_logic;
			pred_ok_ex: out std_logic;
			pc_dest_btb: out std_logic_vector(PC_BITS-1 downto 0);
			
			-- forwaring unit 
			rd_mem: in std_logic_vector(4 downto 0);
			rd_wb: in std_logic_vector(4 downto 0);
			register_data_from_mem: in std_logic_vector(PARALLELISM-1 downto 0);
			register_data_from_wb: in std_logic_vector(PARALLELISM-1 downto 0);
			instruction_format_mem: in std_logic_vector(2 downto 0);
			instruction_format_wb: in std_logic_vector(2 downto 0)
		);
	end component;
	
	component Memory_Stage
		port (
			clk: in std_logic;
			pc_in: in std_logic_vector(PC_BITS-1 downto 0);
			pc_out: out std_logic_vector(PC_BITS-1 downto 0);
			instruction_format_in: in std_logic_vector(2 downto 0);
			instruction_format_out: out std_logic_vector(2 downto 0);
			instruction_in: in std_logic_vector(PARALLELISM-1 downto 0);
			instruction_out: out std_logic_vector(PARALLELISM-1 downto 0);		
			memory_data_register: in std_logic_vector(PARALLELISM-1 downto 0);
			alu_exit_in: in std_logic_vector(PARALLELISM-1 downto 0);
			data_out: out std_logic_vector(PARALLELISM-1 downto 0);
			
			-- forwarding unit
			dest_register: out std_logic_vector(4 downto 0);
			dest_register_data: out std_logic_vector(PARALLELISM-1 downto 0)
		);	
	end component;

	component WriteBack_Stage
		port (
			clk: in std_logic;
			pc_in: in std_logic_vector(PC_BITS-1 downto 0);
			pc_out: out std_logic_vector(PC_BITS-1 downto 0);
			instruction_format_in: in std_logic_vector(2 downto 0);
			instruction_format_out: out std_logic_vector(2 downto 0);
			instruction_in: in std_logic_vector(PARALLELISM-1 downto 0);
			instruction_out: out std_logic_vector(PARALLELISM-1 downto 0);
			data_in: in std_logic_vector(PARALLELISM-1 downto 0);
		
			-- forwarding unit & registro da scrivere
			dest_register: out std_logic_vector(REGISTER_ADDR_LEN-1 downto 0);
			dest_register_data: out std_logic_vector(PARALLELISM-1 downto 0);
			dest_register_type: out std_logic
		);
	end component;
	-- SEGNALI DELLO STADIO DI FETCH

	-- SEGNALI DELLO STATO DI DECODE

	
	begin
		--segnali per il btb
		Btb_component_inst: Btb_component PORT MAP (
          wr => btb_exe_wr,
          rd => btb_fetch_rd,
          pc_if => pc_fetch,
          pc_ex => pc_execute,
          pc_dest_ex => btb_exe_pc_dest,
          pred_ok_ex => btb_pred_ok,
          reset => reset,
          tkn_if => btb_fetch_tkn,
          pc_dest_if => btb_fetch_pc_dest
        );
		  
		Fetch_Stage_inst: Fetch_Stage
			port map (
				clk => clk,
				reset => reset,
				force_jump => exe_force_jump,
				pc_for_jump => exe_pc_for_jump,
				instruction => instruction_fetch,
				pc => pc_fetch,
				--segnali per il btb
				pc_dest_btb	=> btb_fetch_pc_dest,
				tkn_btb_in => btb_fetch_tkn,
				--tkn_btb_out => tkn_decode,
				rd_btb => btb_fetch_rd
			);
		
		Decode_Stage_inst: Decode_Stage
			port map (
				clk => clk,
				reset => reset,
				data_from_WB => wb_dest_register_data,
				dest_register_from_WB => wb_dest_register,
				dest_register_type_WB => wb_dest_register_type,
				pc_in => pc_fetch,
				pc_out => pc_decode,
				instruction_in => instruction_fetch,
				instruction_out => instruction_decode,
				instruction_format => dec_instruction_format,
				register_a => dec_register_a,
				register_b => dec_register_b,
				force_jump => exe_force_jump,
				register_file_debug => register_file_debug,
				fp_register_file_debug => fp_register_file_debug,
				--segnali per il btb
				tkn_in => btb_fetch_tkn,
				tkn_out => tkn_execute
			);
		
		Execute_Stage_inst: Execute_Stage
			port map (
				clk => clk,
				pc_in => pc_decode,
				pc_out => pc_execute,
				instruction_format_in => dec_instruction_format,
				instruction_format_out => exe_instruction_format,
				instruction_in => instruction_decode,
				instruction_out => instruction_execute,
				register_a_in => dec_register_a,
				register_b_in => dec_register_b,
				alu_exit => exe_alu_exit,
				register_b_out => exe_register_b,
				force_jump => exe_force_jump,
				pc_for_jump => exe_pc_for_jump,
				--segnali per il btb
				tkn_in => tkn_execute,
				pred_ok_ex => btb_pred_ok,
				wr_btb => btb_exe_wr,
				pc_dest_btb => btb_exe_pc_dest,
				
				-- forwaring unit 
				rd_mem => mem_dest_register,
				rd_wb => wb_dest_register,
				register_data_from_mem => mem_dest_register_data,
				register_data_from_wb => wb_dest_register_data,
				instruction_format_mem => mem_instruction_format,
				instruction_format_wb => wb_instruction_format			
			);
		
		Memory_Stage_inst: Memory_Stage
			port map (
				clk => clk,
				pc_in => pc_execute,
				pc_out => pc_memory,
				instruction_format_in => exe_instruction_format,
				instruction_format_out => mem_instruction_format,
				instruction_in => instruction_execute,
				instruction_out => instruction_memory,	
				memory_data_register => exe_register_b,
				alu_exit_in => exe_alu_exit,
				data_out => mem_data_out,
				
				-- forwarding unit
				dest_register => mem_dest_register,
				dest_register_data => mem_dest_register_data
			);
		
		WriteBack_Stage_inst: WriteBack_Stage
		port map (
			clk => clk,
			pc_in => pc_memory,
			pc_out => pc_writeback,
			instruction_format_in => mem_instruction_format,
			instruction_format_out => wb_instruction_format,
			instruction_in => instruction_memory,
			instruction_out => instruction_writeback,
			data_in => mem_data_out,
		
			-- forwarding unit & registro da scrivere
			dest_register => wb_dest_register,
			dest_register_data => wb_dest_register_data,
			dest_register_type => wb_dest_register_type
		);
	end Arch1_DLXPipelined;

