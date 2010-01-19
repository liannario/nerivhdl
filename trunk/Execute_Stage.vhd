
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Global.all;
--use work.Fixed_32.all;
use work.Float_32.all;
use work.Btb.all; 

entity Execute_Stage is
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
		register_b_out: out std_logic_vector(PARALLELISM-1 downto 0);
		alu_exit: out std_logic_vector(PARALLELISM-1 downto 0);
		force_jump: out std_logic;
		pc_for_jump: out std_logic_vector(PC_BITS-1 downto 0);
		--segnali per il btb
		tkn_in_btb: in std_logic;
		wr_btb: out std_logic;
		pred_ok_btb: out std_logic;
		pc_dest_btb: out std_logic_vector(PC_BITS-1 downto 0);
		--segnali per statistiche btb
		num_branch_pred_ok: out std_logic_vector(PC_BITS-1 downto 0);
		num_branch_pred_not_ok: out std_logic_vector(PC_BITS-1 downto 0);
		
		-- forwaring unit 
		rd_mem: in std_logic_vector(4 downto 0);
		rd_wb: in std_logic_vector(4 downto 0);
		register_data_from_mem: in std_logic_vector(PARALLELISM-1 downto 0);
		register_data_from_wb: in std_logic_vector(PARALLELISM-1 downto 0);
		instruction_format_mem: in std_logic_vector(2 downto 0);
		instruction_format_wb: in std_logic_vector(2 downto 0)
	);
end Execute_Stage;

architecture Arch1_Execute_Stage of Execute_Stage is
	
	signal pc_buffer: std_logic_vector(PC_BITS-1 downto 0);
	signal instruction_buffer: std_logic_vector(PARALLELISM-1 downto 0) := (others => '1');
	signal instruction_format_buffer: std_logic_vector(2 downto 0) := IF_NOP;
	--segnali per il btb
	signal tkn_buffer: std_logic;
		
	signal register_a_buffer: std_logic_vector(PARALLELISM-1 downto 0);
	signal register_b_buffer: std_logic_vector(PARALLELISM-1 downto 0);
	
	alias a_opcode_high is instruction_buffer(31 downto 26); -- codice operativo istruzioni tipo I e J
	alias a_opcode_low is instruction_buffer(5 downto 0); -- codice operativo istruzioni tipo R
	alias a_rs1 is instruction_buffer(25 downto 21); -- registro sorgente istruzioni tipo I o R
	alias a_rs2 is instruction_buffer(20 downto 16); -- registro sorgente istruzioni tipo R o dest di tipo I
	alias a_immediate_16 is instruction_buffer(15 downto 0); -- immediato di tipo I
	alias a_immediate_26 is instruction_buffer(25 downto 0); -- immediato di tipo J
	
	begin
	
		-- operazioni sincrone: campionamento degli ingressi
		sync: process begin
			wait until clk = '1' and clk'event;
			pc_buffer <= pc_in;
			instruction_buffer <= instruction_in;
			instruction_format_buffer <= instruction_format_in;
			register_a_buffer <= register_a_in;
			register_b_buffer <= register_b_in;
			--segnali per il btb
			tkn_buffer <= tkn_in_btb;
		end process;
		
		
		-- operazioni asincrone: operazioni alu e forwarding unit
		async: process(a_opcode_high, a_opcode_low, a_immediate_16, a_immediate_26, pc_buffer,
							a_rs1, a_rs2, instruction_buffer, instruction_format_buffer, register_a_buffer, 
							register_b_buffer, rd_mem, rd_wb, register_data_from_mem,
							register_data_from_wb, instruction_format_wb, instruction_format_mem, tkn_buffer)
		variable var_register_a, var_register_b: std_logic_vector(PARALLELISM-1 downto 0);
		--segnali per statistiche btb
		variable num_branch_pred_ok_buffer: integer := 0;
		variable num_branch_pred_not_ok_buffer: integer := 0;
		begin
			
			var_register_a := register_a_buffer;
			var_register_b := register_b_buffer;
			
			-- forwarding unit
			if instruction_format_buffer = IF_R then -- forwarding istruzioni di tipo R
				if instruction_format_wb = IF_R or instruction_format_wb = IF_I or instruction_format_wb = IF_J then -- forwarding da WB
					if rd_wb = a_rs1 then 
						var_register_a := register_data_from_wb;
					end if;
					if rd_wb = a_rs2 then
						var_register_b := register_data_from_wb;
					end if;
				end if;
				if instruction_format_mem = IF_R or instruction_format_mem = IF_I or instruction_format_mem = IF_J then -- forward da MEM
					if rd_mem = a_rs1 then 
						var_register_a := register_data_from_mem;
					end if;
					if rd_mem = a_rs2 then
						var_register_b := register_data_from_mem;
					end if;
				end if;
			elsif instruction_format_buffer = IF_I or instruction_format_buffer = IF_IF then -- forwarding istruzioni di tipo I
																														-- o IF
				if instruction_format_wb = IF_R or instruction_format_wb = IF_I or instruction_format_wb = IF_J then -- forwarding da WB
					if rd_wb = a_rs1 then
						var_register_a := register_data_from_wb;
					end if;
				end if;
				if instruction_format_mem = IF_R or instruction_format_mem = IF_I or instruction_format_mem = IF_J then -- forwarding da MEM
					if rd_mem = a_rs1 then
						var_register_a := register_data_from_mem;
					end if;
				end if;
			elsif instruction_format_buffer = IF_F then -- forwarding istruzioni di tipo F. Viene fatto solo se
																	  -- negli stadi di wb o di mem sono presenti altre istuzioni
																	  -- di tipo F o IF
				if instruction_format_wb = IF_F or instruction_format_wb = IF_IF then -- forwarding da WB
					if rd_wb = a_rs1 then 
						var_register_a := register_data_from_wb;
					end if;
					if rd_wb = a_rs2 then
						var_register_b := register_data_from_wb;
					end if;
				end if;
				if instruction_format_mem = IF_F or instruction_format_mem = IF_IF then -- forward da MEM
					if rd_mem = a_rs1 then 
						var_register_a := register_data_from_mem;
					end if;
					if rd_mem = a_rs2 then
						var_register_b := register_data_from_mem;
					end if;
				end if;
			end if;
			
			-- Se l'istruzione corrente è una SW, è necessario fare un controllo
			-- anche sul registro di destinazione.
			if a_opcode_high = I_SW then
				if a_rs2 = rd_wb and ( instruction_format_wb = IF_R or instruction_format_wb = IF_I ) then
					var_register_b := register_data_from_wb;
				end if;
				if a_rs2 = rd_mem and ( instruction_format_mem = IF_R or instruction_format_mem = IF_I ) then
					var_register_b := register_data_from_mem;
				end if;
			end if;
			
			-- Se l'istruzione corrente è una SF, è necessario fare un controllo
			-- anche sul registro di destinazione.
			if a_opcode_high = IF_SF then
				if a_rs2 = rd_wb and ( instruction_format_wb = IF_F or instruction_format_wb = IF_IF ) then
					var_register_b := register_data_from_wb;
				end if;
				if a_rs2 = rd_mem and ( instruction_format_mem = IF_F or instruction_format_mem = IF_IF ) then
					var_register_b := register_data_from_mem;
				end if;			
			end if;
			
			-- fine forwarding unit

			register_b_out <= var_register_b;
			--segnali per il btb
			wr_btb <= '0';
			
			-- operazioni alu
			if instruction_format_buffer = IF_R then -- istruzioni di tipo R
				force_jump <= '0';
				pc_for_jump <= (others => '0');
				case a_opcode_low is
					when R_ADD =>
						alu_exit <= var_register_a + var_register_b;
					when R_AND =>
						alu_exit <= var_register_a and var_register_b;
					when R_OR =>
						alu_exit <= var_register_a or var_register_b;
					when R_SEQ =>
						if var_register_a = var_register_b then
							alu_exit <= conv_std_logic_vector(1, PARALLELISM);
						else
							alu_exit <= (others => '0');
						end if;
					when R_SLE =>
						if conv_integer(var_register_a) <= conv_integer(var_register_b) then
							alu_exit <= conv_std_logic_vector(1, PARALLELISM);
						else
							alu_exit <= (others => '0');
						end if;
					when R_SLL =>
						alu_exit <= to_stdlogicvector(to_bitvector(var_register_a) sll conv_integer(var_register_b));
					when R_SLT =>
						if conv_integer(var_register_a) < conv_integer(var_register_b) then
							alu_exit <= conv_std_logic_vector(1, PARALLELISM);
						else
							alu_exit <= (others => '0');
						end if;
					when R_SNE =>
						if var_register_a /= var_register_b then
							alu_exit <= conv_std_logic_vector(1, PARALLELISM);
						else
							alu_exit <= (others => '0');
						end if;
					when R_SRA =>
						alu_exit <= to_stdlogicvector(to_bitvector(var_register_a) sra conv_integer(var_register_b));
					when R_SRL =>
						alu_exit <= to_stdlogicvector(to_bitvector(var_register_a) srl conv_integer(var_register_b));
					when R_SUB =>
						alu_exit <= var_register_a - var_register_b;
					when R_XOR =>
						alu_exit <= var_register_a xor var_register_b;
					when others =>
						alu_exit <= (others => '0');
				end case;
			elsif instruction_format_buffer = IF_J then -- istruzioni di tipo J
				case a_opcode_high is
					when J_J | J_JAL =>
						-- jump e jump and link stessa uscita della alu, in caso
						-- di jump normale la ignorerò nello stato di WB
						pc_for_jump <= pc_buffer + to_stdlogicvector(to_bitvector(sxt(a_immediate_26, PC_BITS)) sra 2) + 1;
						force_jump <= '1';
						alu_exit <= (pc_buffer & PC_EXT) + 4;
					when others =>
						pc_for_jump <= (others => '0');
						force_jump <= '0';
						alu_exit <= (others => '0');
				end case;
			elsif instruction_format_buffer = IF_I then -- istruzioni di tipo I
				force_jump <= '0';
				pc_for_jump <= (others => '0');
				case a_opcode_high is
					when I_ADDI =>
						alu_exit <= var_register_a + sxt(a_immediate_16, PARALLELISM);
					when I_ANDI =>
						alu_exit <= var_register_a and ext(a_immediate_16, PARALLELISM);
					when I_BEQZ =>
						pc_dest_btb <= pc_buffer + to_stdlogicvector(to_bitvector(sxt(a_immediate_16, PC_BITS)) sra 2) + 1;
						if conv_integer(var_register_a) = 0 then -- branch da prendere
							--segnali per il btb
							wr_btb <= '1';
							pc_for_jump <= pc_buffer + to_stdlogicvector(to_bitvector(sxt(a_immediate_16, PC_BITS)) sra 2) + 1;
							if(tkn_buffer = TAKEN) then -- e preso
								pred_ok_btb <= PRED_OK;
								if(pc_buffer'event) then num_branch_pred_ok_buffer := num_branch_pred_ok_buffer + 1; end if;
							else -- e non preso
								force_jump <= '1';
								pred_ok_btb <= PRED_NOT_OK;	
								if(pc_buffer'event) then num_branch_pred_not_ok_buffer := num_branch_pred_not_ok_buffer + 1; end if;
							end if;
						else -- branch da non prendere
							wr_btb <= '1';							
							if(tkn_buffer = UNTAKEN) then	-- e non preso
								pred_ok_btb <= PRED_OK;		
								pc_for_jump <= pc_buffer + to_stdlogicvector(to_bitvector(sxt(a_immediate_16, PC_BITS)) sra 2) + 1;		
								if(pc_buffer'event) then num_branch_pred_ok_buffer := num_branch_pred_ok_buffer + 1; end if;
							else -- e preso
								force_jump <= '1';
								pred_ok_btb <= PRED_NOT_OK;								
								pc_for_jump <= pc_buffer + 1;
								if(pc_buffer'event) then num_branch_pred_not_ok_buffer := num_branch_pred_not_ok_buffer + 1; end if;
							end if;
						end if;
						alu_exit <= (others => '0');
					when I_BNEZ =>
						pc_dest_btb <= pc_buffer + to_stdlogicvector(to_bitvector(sxt(a_immediate_16, PC_BITS)) sra 2) + 1;
						if conv_integer(var_register_a) /= 0 then -- branch da prendere
							--segnali per il btb
							wr_btb <= '1';
							pc_for_jump <= pc_buffer + to_stdlogicvector(to_bitvector(sxt(a_immediate_16, PC_BITS)) sra 2) + 1;		
							if(tkn_buffer = TAKEN) then -- e preso
								pred_ok_btb <= PRED_OK;	
								if(pc_buffer'event) then num_branch_pred_ok_buffer := num_branch_pred_ok_buffer + 1; end if;
							else -- e non preso
								force_jump <= '1';
								pred_ok_btb <= PRED_NOT_OK;	
								if(pc_buffer'event) then num_branch_pred_not_ok_buffer := num_branch_pred_not_ok_buffer + 1; end if;
							end if;
						else -- branch da non prendere
							wr_btb <= '1';
							if(tkn_buffer = UNTAKEN) then	-- e non preso
								pred_ok_btb <= PRED_OK;	
								pc_for_jump <= pc_buffer + to_stdlogicvector(to_bitvector(sxt(a_immediate_16, PC_BITS)) sra 2) + 1;
								if(pc_buffer'event) then num_branch_pred_ok_buffer := num_branch_pred_ok_buffer + 1; end if;
							else -- e preso
								force_jump <= '1';
								pred_ok_btb <= PRED_NOT_OK;								
								pc_for_jump <= pc_buffer + 1;
								if(pc_buffer'event) then num_branch_pred_not_ok_buffer := num_branch_pred_not_ok_buffer + 1; end if;
							end if;
						end if; 
						alu_exit <= (others => '0');						
					when I_JALR =>
						force_jump <= '1';
						pc_for_jump <= var_register_a(31 downto 2);
						alu_exit <= (pc_buffer & PC_EXT) + 4;
					when I_JR =>
						force_jump <= '1';
						pc_for_jump <= var_register_a(31 downto 2);
						alu_exit <= (others => '0');						
					when I_LHI =>
						-- load half word
						alu_exit <= (others => '0');
					when I_LW =>
						alu_exit <= var_register_a + sxt(a_immediate_16, PARALLELISM);
					when I_SEQI =>
						if var_register_a = sxt(a_immediate_16, PARALLELISM) then
							alu_exit <= conv_std_logic_vector(1, PARALLELISM);
						else
							alu_exit <= (others => '0');
						end if;
					when I_SLEI =>						
						if conv_integer(var_register_a) <= conv_integer(sxt(a_immediate_16, PARALLELISM)) then
							alu_exit <= conv_std_logic_vector(1, PARALLELISM);
						else
							alu_exit <= (others => '0');
						end if;
					when I_SLLI =>
						alu_exit <= to_stdlogicvector(to_bitvector(var_register_a) sll conv_integer(a_immediate_16));
					when I_SLTI =>
						if conv_integer(var_register_a) < conv_integer(sxt(a_immediate_16, PARALLELISM)) then
							alu_exit <= conv_std_logic_vector(1, PARALLELISM);
						else
							alu_exit <= (others => '0');
						end if;
					when I_SNEI =>
						if var_register_a /= sxt(a_immediate_16, PARALLELISM) then
							alu_exit <= conv_std_logic_vector(1, PARALLELISM);
						else
							alu_exit <= (others => '0');
						end if;
					when I_SRAI =>
						alu_exit <= to_stdlogicvector(to_bitvector(var_register_a) sra conv_integer(a_immediate_16));
					when I_SRLI =>
						alu_exit <= to_stdlogicvector(to_bitvector(var_register_a) srl conv_integer(a_immediate_16));
					when I_SUBI =>
						alu_exit <= var_register_a - sxt(a_immediate_16, PARALLELISM);
					when I_SW =>
						alu_exit <= var_register_a + sxt(a_immediate_16, PARALLELISM);
					when I_XORI =>
						alu_exit <= var_register_a xor ext(a_immediate_16, PARALLELISM);
					when others =>
						alu_exit <= (others => '0');
				end case;
			elsif instruction_format_buffer = IF_F then
				pc_for_jump <= (others => '0');				
				force_jump <= '0';
				case a_opcode_low is
					when F_ADDF =>
						alu_exit <= (others => '0');
--						alu_exit <= add_f_synth(var_register_a, var_register_b);					
					when F_SUBF =>
						alu_exit <= (others => '0');
--						alu_exit <= sub_f_synth(var_register_a, var_register_b);					
					when F_MULT =>
						alu_exit <= (others => '0');					
--						alu_exit <= mul_f_synth(var_register_a, var_register_b);					
					when F_DIVF =>
						alu_exit <= (others => '0');					
--						alu_exit <= div_f_synth(var_register_a, var_register_b);
					when others =>
						alu_exit <= (others => '0');					
				end case;
			elsif instruction_format_buffer = IF_IF then
				pc_for_jump <= (others => '0');				
				force_jump <= '0';				
				case a_opcode_high is
					when IF_LF =>
						alu_exit <= var_register_a + sxt(a_immediate_16, PARALLELISM);
					when IF_SF =>
						alu_exit <= var_register_a + sxt(a_immediate_16, PARALLELISM); 
					when others =>
						alu_exit <= (others => '0');
				end case;						
			else -- nop. uscita portata a 0
				pc_for_jump <= (others => '0');				
				force_jump <= '0';
				alu_exit <= (others => '0');
			end if;
			-- fine operazioni alu
			--segnali per statistiche btb
			num_branch_pred_ok <= conv_std_logic_vector(num_branch_pred_ok_buffer, PC_BITS);
			num_branch_pred_not_ok <= conv_std_logic_vector(num_branch_pred_not_ok_buffer, PC_BITS);
		end process;
		
		instruction_format_out <= instruction_format_buffer;
		instruction_out <= instruction_buffer;
		pc_out <= pc_buffer;
		
	end Arch1_Execute_Stage;