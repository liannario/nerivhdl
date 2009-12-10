library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Global.all;

entity WriteBack_Stage is
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
		dest_register_type: out std_logic -- tipo del registro 0 => R, 1 => F		
	);
end WriteBack_Stage;

architecture Arch1_WriteBack_Stage of WriteBack_Stage is

	signal pc_buffer: std_logic_vector(PC_BITS-1 downto 0);
	signal instruction_buffer: std_logic_vector(PARALLELISM-1 downto 0) := (others => '1');
	signal instruction_format_buffer: std_logic_vector(2 downto 0) := IF_NOP;
	signal data_buffer: std_logic_vector(PARALLELISM-1 downto 0);
	
	alias a_opcode_high is instruction_buffer(31 downto 26); -- codice operativo istruzioni tipo I e J
	alias a_opcode_low is instruction_buffer(5 downto 0); -- codice operativo istruzioni tipo R
	alias a_rd_r is instruction_buffer(15 downto 11); -- registro destinatione instruzioni di tipo R
	alias a_rd_i is instruction_buffer(20 downto 16); -- registro destinazione istruzioni di tipo I
	
	begin
		-- operazioni asincrone: metto sulle uscite i registri
		-- da scrivere, che verrano poi aggiornati al clock successivo
		-- nello stadio di decode. Nota: la forwarding unit usa le stesse
		-- uscite che vanno anche allo stadio di decode per il write back.
		async: process(instruction_format_buffer, a_opcode_high, instruction_buffer, data_buffer) begin
			if instruction_format_buffer = IF_R then -- istruzioni di tipo R e F
				dest_register <= a_rd_r;
				dest_register_data <= data_buffer;
				dest_register_type <= '0';
			elsif instruction_format_buffer = IF_F then
				dest_register <= a_rd_r;
				dest_register_data <= data_buffer;
				dest_register_type <= '1';
			elsif instruction_format_buffer = IF_I or instruction_format_buffer = IF_J
			or instruction_format_buffer = IF_IF then -- istruzioni di tipo I, IF o J
				case a_opcode_high is
					when J_JAL | I_JALR => -- scrittura nel registro r31
						dest_register <= conv_std_logic_vector(31, REGISTER_ADDR_LEN);
						dest_register_data <= data_buffer;
						dest_register_type <= '0';						
						
					when J_J | I_JR | I_SW | IF_SF | I_BNEZ | I_BEQZ => -- nessuna scrittura nel register file
																				-- per comodità metto come registro destinazione	
																				-- R0 e la costante 0 come dato da scrivere
																				-- (scrittura che comunque non verrà fatta)
						dest_register <= (others => '0');
						dest_register_data <= (others => '0');
						dest_register_type <= '0';
					when IF_LF =>
						dest_register <= a_rd_i;
						dest_register_data <= data_buffer;						
						dest_register_type <= '1';
					when others => -- sicuramente istruzione di tipo I diversa da quelle sopra
						dest_register <= a_rd_i;
						dest_register_data <= data_buffer;
						dest_register_type <= '0';
				end case;
			else -- nop
				dest_register <= (others => '0');
				dest_register_data <= (others => '0');
				dest_register_type <= '0';
			end if;
		end process;
		
		-- operazioni sincrone: campionamento degli ingressi
		sync: process begin
			wait until clk'event and clk = '1';
			pc_buffer <= pc_in;
			instruction_buffer <= instruction_in;
			instruction_format_buffer <= instruction_format_in;
			data_buffer <= data_in;
		end process;
		
		-- ovviamente, questi segnali vengono esposti all'sterno solo per fini di testing
		pc_out <= pc_buffer;
		instruction_out <= instruction_buffer;
		instruction_format_out <= instruction_format_buffer;
		
	end Arch1_WriteBack_Stage;

