library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Global.all;
--use work.Fixed_32.all;
use work.Float_32.all;

entity Decode_Stage is
	port (
		-- porte standard
		clk: in std_logic;
		reset: in std_logic;
		force_jump: in std_logic;		
		data_from_WB: in std_logic_vector(PARALLELISM-1 downto 0); -- dati da scrivere provenienti dallo stadio di WB
		dest_register_from_WB: in std_logic_vector(REGISTER_ADDR_LEN-1 downto 0); -- registro di destinazione del write_back
		dest_register_type_WB: in std_logic; -- tipo del registro da scrivere. 0 => R, 1 => F
		pc_in: in std_logic_vector(PC_BITS-1 downto 0);
		pc_out: out std_logic_vector(PC_BITS-1 downto 0);
		instruction_in: in std_logic_vector(PARALLELISM-1 downto 0);
		instruction_out: out std_logic_vector(PARALLELISM-1 downto 0);
		instruction_format: out std_logic_vector(2 downto 0);
		register_a: out std_logic_vector(PARALLELISM-1 downto 0);
		register_b: out std_logic_vector(PARALLELISM-1 downto 0);
		--segnali per il btb
		tkn_in: in std_logic;
		tkn_out: out std_logic;
		
		-- porte di debug
		register_file_debug: out register_file_type;
		fp_register_file_debug: out register_file_type
	);
end Decode_Stage;

architecture Arch1_Decode_Stage of Decode_Stage is
	
	-- register file 
	signal register_file_inst: register_file_type := (others => X"00000000" );
	
	-- floting point register file
	signal fp_register_file_inst: register_file_type := ( others => to_float(0.0) );
	
	-- segnali in ingresso sincroni
	signal pc_buffer: std_logic_vector(PC_BITS-1 downto 0);
	signal instruction_buffer: std_logic_vector(PARALLELISM-1 downto 0) := (others => '1');
	--segnali per il btb
	signal tkn_buffer: std_logic;
	
	-- alias istruzioni
	alias a_opcode_high is instruction_buffer(31 downto 26); -- codice operativo alto
	alias a_opcode_low is instruction_buffer(5 downto 0); -- codice operativo basso
	alias a_rs1 is instruction_buffer(25 downto 21); -- rs1 tipo R
	alias a_rs2_rd is instruction_buffer(20 downto 16); -- rs2 tipo R o rd tipo I
	
	begin
		-- azioni sincrone: campiono gli ingressi e scrivo i dati provenienti dal write back
			
		sync: process begin
			wait until clk = '1' and clk'event;
			
			-- pc e istruzione dallo stadio di fetch
			pc_buffer <= pc_in;
			instruction_buffer <= instruction_in;
			--segnali per il btb
			tkn_buffer <= tkn_in;
			
			-- scrittura del registro dal WB. NOTA: non si fa la scrittura sul registro 0
			if dest_register_type_WB = '0' then -- registri tipo R
				if conv_integer(dest_register_from_WB) = 0 then
					register_file_inst(0) <= (others => '0');
				else
					register_file_inst(conv_integer(dest_register_from_WB)) <= data_from_WB;
				end if;
			else -- registri tipo F
				fp_register_file_inst(conv_integer(dest_register_from_WB)) <= data_from_WB;
			end if;
		end process;
		
		-- azioni asincrone: decodifica del tipo di istruzione, se il reset è attivo
		-- in uscita va instruction nop. NB: Salti e branch comportano uno stallo della pipe
		-- che viene automaticamente inserito se il force_jump è attivo
		async: process(register_file_inst,a_opcode_high,reset,instruction_buffer,force_jump) 
		begin
			if reset = '1' or force_jump = '1' then
				instruction_format <= IF_NOP;
				instruction_out <= (others => '1');				
			else
				if a_opcode_high = OPCODE_HIGH_R then -- tipo R 
					instruction_format <= IF_R;
				elsif a_opcode_high = OPCODE_HIGH_F then -- tipo F
					instruction_format <= IF_F;
				else
					case a_opcode_high is
						when I_ADDI | I_ANDI | I_BEQZ | I_BNEZ | I_JALR | I_JR | I_LHI | I_LW
							| I_SEQI | I_SLEI | I_SLLI | I_SLTI | I_SNEI | I_SRAI | I_SRLI | I_SUBI
							| I_SW | I_XORI -- tipo I
							=> instruction_format <= IF_I;
						when J_J | J_JAL -- tipo J
							=> instruction_format <= IF_J;
						when IF_SF | IF_LF
							=> instruction_format <= IF_IF;
						when others -- sconociuta o NOP
							=> instruction_format <= IF_NOP;
					end case;
				end if;
				instruction_out <= instruction_buffer;
			end if;
		end process;
		
		async2: process(data_from_WB, dest_register_from_WB, a_rs1, a_rs2_rd, register_file_inst,
							a_opcode_high, dest_register_type_WB, fp_register_file_inst) begin
			-- Problema. Quando c'e un istruzione nello stadio di wb che ha come
			-- registro di destinazione uno dei registri sorgente dell'istruzione
			-- presente nello stadio di decode sarebbe necessario implementare
			-- lo split cycle, ma non si puo fare. Quindi si estende la forwarding
			-- unit anche allo stadio di decode
			
			if a_opcode_high = OPCODE_HIGH_F then -- istruzione di tipo F
			
				if dest_register_from_WB = a_rs1 and dest_register_type_WB = '1' then
					register_a <= data_from_WB;
				else
					register_a <= fp_register_file_inst(conv_integer(a_rs1));
				end if;
				
				if dest_register_from_WB = a_rs2_rd and dest_register_type_WB = '1' then
					register_b <= data_from_WB;
				else
					register_b <= fp_register_file_inst(conv_integer(a_rs2_rd));
				end if;				
			else -- altre itruzioni
				if dest_register_from_WB = a_rs1 and dest_register_type_WB = '0' then
					register_a <= data_from_WB;
				else
					register_a <= register_file_inst(conv_integer(a_rs1));
				end if;
			
				if dest_register_from_WB = a_rs2_rd and dest_register_type_WB = '0' then
					register_b <= data_from_WB;	
				else
					register_b <= register_file_inst(conv_integer(a_rs2_rd));				
				end if;
			end if;
		end process;
				
		
		pc_out <= pc_buffer;
		--segnali per il btb
		tkn_out <= tkn_buffer;
		
		-- uscite di debug
		register_file_debug <= register_file_inst;
		fp_register_file_debug <= fp_register_file_inst;
	end Arch1_Decode_Stage;
	

