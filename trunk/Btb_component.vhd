----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Enrico Baioni, Raffaele Luca Iannario, Simone Tallevi Diotallevi
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

entity Btb_component is
    Port ( wr : in  STD_LOGIC; -- segnale write
           rd : in  STD_LOGIC; -- segnale read
           pc_if : in  std_logic_vector(PC_BITS-1 downto 0); -- pc proveniente da if
           pc_ex : in  std_logic_vector(PC_BITS-1 downto 0); -- pc proveniente da ex
           pc_dest_ex : in  std_logic_vector(PC_BITS-1 downto 0); -- destinazione salto proveniente da ex per aggiornare la cache
           pred_ok_ex : in  STD_LOGIC; -- predizione corretta o meno (proveniente da ex)
           reset : in  STD_LOGIC; -- reset
           tkn_if : out  STD_LOGIC; -- 1 se pc_if è presente nella cache e predetto taken
           pc_dest_if : out  std_logic_vector(PC_BITS-1 downto 0)); -- destinazione del salto se tkn_if = 1
end Btb_component;

architecture Behavioral of Btb_component is
	
	signal Btb_inst : btb_cache; -- es. di accesso: Btb_inst(0, 0).tag_pc <= (others => '0');
	
begin
	
	async : process(reset, rd, pc_if, wr, pc_ex)	
	
	variable tag_rd : std_logic_vector(TAG_BITS-1 downto 0);
	variable index_rd : integer;
	variable found_rd : std_logic;
	variable found_index_rd : integer;
	
	variable tag_wr : std_logic_vector(TAG_BITS-1 downto 0);
	variable index_wr : integer;
	variable found_wr : std_logic;
	variable found_invalid_wr : std_logic;
	variable found_invalid_index_wr : integer;
	
	begin
	
		if(reset = '1') then -- segnale di reset prioritario
		
			for i in 0 to SLOTS_NUM-1 loop
				for j in 0 to WAYS_NUM-1 loop
					Btb_inst(i, j).tag_pc <= (others => '0');
					Btb_inst(i, j).dest_pc <= (others => '0');
					Btb_inst(i, j).pred <= (others => '0');
					Btb_inst(i, j).status <= '0';
					Btb_inst(i, j).repl <= '0';
				end loop;
			end loop;
			tkn_if <= '0';
			pc_dest_if <= (others => '0');
			
		else
		
			-- Lettura dallo stadio IF
			if(pc_if'event and rd = '1') then
			
				-- estrazione tag e index da pc_if
				tag_rd := pc_if(PC_BITS-1 downto SLOT_BITS);
				index_rd := conv_integer(pc_if(SLOT_BITS-1 downto 0));
				
				found_rd := '0';
				
				-- ricerca della linea di cache
				for i in 0 to WAYS_NUM-1 loop
					if(Btb_inst(index_rd, i).tag_pc = tag_rd and Btb_inst(index_rd, i).status = VALID) then -- linea trovata e valida	
						found_rd := '1';
						found_index_rd := i;	
						pc_dest_if <= Btb_inst(index_rd, i).dest_pc; -- aggiornamento pc_dest_if 			 
						case Btb_inst(index_rd, i).pred is -- emissione bit di predizione
							when TAKEN_STRONG => tkn_if <= TAKEN;     -- predetto taken
							when TAKEN_WEAK => tkn_if <= TAKEN;
							when others => tkn_if <= UNTAKEN; 			-- predetto untaken
						end case;					
						Btb_inst(index_rd, i).repl <= '0'; -- aggiornamento bit di rimpiazzamento
					end if;
				end loop;
				
				-- gestione della politica di rimpiazzamento
				if(found_rd = '1') then -- linea trovata	
					for i in 0 to WAYS_NUM-1 loop
						if(i /= found_index_rd and Btb_inst(index_rd, i).status = VALID) then		
							Btb_inst(index_rd, i).repl <= '1';		
						end if;
					end loop;
				else -- linea non trovata
					tkn_if <= UNTAKEN; -- anche nel caso non venga trovata la linea corrispondente
				end if;
				
			end if;
			
			-- Scrittura dallo stadio EX
			
			if(pc_ex'event and wr = '1') then
				-- estrazione tag e index da pc_ex
				tag_wr := pc_ex(PC_BITS-1 downto SLOT_BITS);
				index_wr := conv_integer(pc_ex(SLOT_BITS-1 downto 0));
				
				found_wr := '0';
				found_invalid_wr := '0';
				
				for i in 0 to WAYS_NUM-1 loop
					if(Btb_inst(index_wr, i).tag_pc = tag_wr and Btb_inst(index_wr, i).status = VALID) then -- linea trovata e valida
						found_wr := '1';
						Btb_inst(index_wr, i).dest_pc <= pc_dest_ex; -- aggiornamento indirizzo di destinazione
						
						--aggiornamento bit di predizione
						if(pred_ok_ex = PRED_OK) then -- predizione corretta
							case Btb_inst(index_wr, i).pred is
								when TAKEN_STRONG => Btb_inst(index_wr, i).pred <= TAKEN_STRONG;
								when TAKEN_WEAK => Btb_inst(index_wr, i).pred <= TAKEN_STRONG;
								when UNTAKEN_WEAK => Btb_inst(index_wr, i).pred <= UNTAKEN_STRONG;
								when UNTAKEN_STRONG => Btb_inst(index_wr, i).pred <= UNTAKEN_STRONG;
								when others => Btb_inst(index_wr, i).pred <= UNTAKEN_STRONG;
							end case;
						else -- predizione errata
							case Btb_inst(index_wr, i).pred is
								when TAKEN_STRONG => Btb_inst(index_wr, i).pred <= TAKEN_WEAK;
								when TAKEN_WEAK => Btb_inst(index_wr, i).pred <= UNTAKEN_WEAK;
								when UNTAKEN_WEAK => Btb_inst(index_wr, i).pred <= TAKEN_WEAK;
								when UNTAKEN_STRONG => Btb_inst(index_wr, i).pred <= UNTAKEN_WEAK;		
								when others => Btb_inst(index_wr, i).pred <= UNTAKEN_STRONG;
							end case;
						end if;
						exit; --break
					end if;
				end loop;
				
				if(found_wr = '0') then -- linea non trovata
					-- cerco linea invalida o valida (da rimpiazzare) per la prima scrittura
					for i in 0 to WAYS_NUM-1 loop
						if(Btb_inst(index_wr, i).status = INVALID) then -- trovata linea invalida
							found_invalid_wr := '1';
							found_invalid_index_wr := i;
							Btb_inst(index_wr, i).tag_pc <= tag_wr;
							Btb_inst(index_wr, i).dest_pc <= pc_dest_ex;
							Btb_inst(index_wr, i).status <= VALID; -- la linea ora è valida
							Btb_inst(index_wr, i).repl <= '0';
							if(pred_ok_ex = PRED_OK) then
								Btb_inst(index_wr, i).pred <= UNTAKEN_STRONG; -- la linea non era nella cache quindi la predizione in lettura era stata untaken
							else
								Btb_inst(index_wr, i).pred <= TAKEN_STRONG;
							end if;
							exit; -- break altrimenti se ci fossero altre linee invalide si scriverebbe lo stesso dato più volte
						end if;
					end loop;
					
					if(found_invalid_wr = '1') then -- trovata linea invalida
						for i in 0 to WAYS_NUM-1 loop
							if(i /= found_invalid_index_wr and Btb_inst(index_wr, i).status = VALID) then -- linea diversa da quella trovata e valida
								Btb_inst(index_wr, i).repl <= '1';
							end if;
						end loop;
					else -- non ci sono linee invalide
						for i in 0 to WAYS_NUM-1 loop
							if(Btb_inst(index_wr, i).repl = '1') then -- trovata la linea valida da rimpiazzare
								Btb_inst(index_wr, i).tag_pc <= tag_wr;
								Btb_inst(index_wr, i).dest_pc <= pc_dest_ex;
								Btb_inst(index_wr, i).repl <= '0';
								if(pred_ok_ex = PRED_OK) then
									Btb_inst(index_wr, i).pred <= UNTAKEN_STRONG; -- la linea non era nella cache quindi la predizione in lettura era stata untaken
								else
									Btb_inst(index_wr, i).pred <= TAKEN_STRONG;
								end if;							
							else
								Btb_inst(index_wr, i).repl <= '1';
							end if;
						end loop;
					end if;
				end if;
				
			end if;
		end if;
		
	end process;
	
end Behavioral;

