library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Global.all;
use work.Btb.all; 

entity Fetch_Stage is
	port (
		-- uscite standard
		clk: in std_logic;
		reset: in std_logic;
		force_jump: in std_logic;
		pc_for_jump: in std_logic_vector(PC_BITS-1 downto 0);
		instruction: out std_logic_vector(PARALLELISM-1 downto 0);
		pc: out std_logic_vector(PC_BITS-1 downto 0);
		-- segnali per il btb
		pc_dest_btb: in std_logic_vector(PC_BITS-1 downto 0);
		tkn_btb_in: in std_logic;
		tkn_btb_out: out std_logic;
		rd_btb: out std_logic
	);
end Fetch_Stage;

architecture Arch1_Fetch_Stage of Fetch_Stage is

-- segnale utilizzato internamente all'architecture per il program counter
signal pc_reg: std_logic_vector(PC_BITS-1 downto 0) := (others => '0');	

-- valore di inizializzazione del program counter (30 bit a 0)
constant PC_INIT: std_logic_vector(PC_BITS-1 downto 0) := (others => '0');

-- La memoria con il codice macchina del DLX
constant EPROM_inst: eprom_type(0 to 9) := (
												X"20010004",
												X"20220009",
												X"00411822",
												X"0BFFFFF0",
												X"FFFFFFFF",
												X"FFFFFFFF",
												X"FFFFFFFF",
												X"FFFFFFFF",
												X"FFFFFFFF",
												X"FFFFFFFF"
											);


begin
		
		sync: process(clk, reset) begin

			if reset = '1' then
				pc_reg <= PC_INIT;	
			else
			
			-- se il reset non è asserito verifica se si è 
			-- verificato un fronte di salita del clock	
				
				if clk'event and clk = '1' then
					if force_jump = '1' then
						pc_reg <= pc_for_jump + 1;
					-- segnali per il btb	
					elsif tkn_btb_in = TAKEN then
						pc_reg <= pc_dest_btb; 
					else
						pc_reg <= pc_reg + 1;
					end if;
				end if;
			end if;
			
		end process sync;
		

		async: process (pc_reg, reset, force_jump, pc_for_jump) 
		begin
			-- verifica se è asserito il reset e in caso affermativo prepara una NOP per lo stadio successivo (ID)
			-- e invia ID PC_INIT come indirizzo 
			if reset = '1' then
				instruction <= (others => '1');
				pc <= PC_INIT;
				--segnali per il btb
				rd_btb <= '0';
			else
				--segnali per il btb
				rd_btb <= '1';
				if force_jump = '1' then
					-- Se force_jump (da J&B EX) è asserito esegue il fetch della istruzione all'indirizzo di destinazione 
					-- del salto (ovvero a all'indirizzo pc_for_jump (opportunamente esteso) fornito da J&B di EX)
					instruction <= EPROM_inst(conv_integer(PC_EXT & pc_for_jump));
					
					-- Invia il program counter, con la destinazione del salto, all'uscita per essere 
					-- campionato dallo stadio successivo (ID)
					pc <= pc_for_jump;					
				else
					-- Altrimenti esegue un fetch tradizionale della istruzione successiva (il valore del 
					-- program counter è stato incrementato di +4 (, ovvero +1 con 30 bit), dal processo
					-- sync sul fronte di salita del clock)
					instruction <= EPROM_inst(conv_integer(PC_EXT & pc_reg)); 
					-- trasforma l'indice a 32 bit aggungendo i due bit più significativi a 00 per poter fare la 
					-- conversione a intero ma l'indirizzo deve ancora essere "interpretato" a 30 bit perchè la 
					-- EPROM contiene WORD a 32 bit e non byte
					
					
					-- Invia il program counter all'uscita per essere campionato dallo stadio successivo (ID)
					-- il segnale va inviato anche al btb per l'interrogazione --segnali per il btb
					pc <= pc_reg;
				end if;
			end if;
		end process async;	

		tkn_btb_out <= tkn_btb_in;
		
end Arch1_Fetch_Stage;

