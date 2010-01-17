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
    Port ( wr : in  STD_LOGIC; -- segnale write
           rd : in  STD_LOGIC; -- segnale read
           pc_if : in  std_logic_vector(PC_BITS-1 downto 0); -- pc proveniente da if
           pc_ex : in  std_logic_vector(PC_BITS-1 downto 0); -- pc proveniente da ex
           pc_dest_ex : in  std_logic_vector(PC_BITS-1 downto 0); -- destinazione salto proveniente da ex per aggiornare la cache
           pred_ok_ex : in  STD_LOGIC; -- predizione corretta o meno (proveniente da ex)
           reset : in  STD_LOGIC; -- reset
           tkn_if : out  STD_LOGIC; -- pc_if è presente nella cache ed è predetto taken
           pc_dest_if : out  std_logic_vector(PC_BITS-1 downto 0)); -- destinazione del salto se tkn_if = 1
end Btb_component;

architecture Behavioral of Btb_component is
	
	signal Btb_inst : btb_cache; -- Btb_inst(0, 0).tag_pc <= (others => '0'); Funziona
	
begin
	
	a_reset : process(reset, rd, pc_if, wr, pc_ex)	
	
	variable tag_rd : std_logic_vector(TAG_BITS-1 downto 0);
	variable index_rd : integer;
	variable found_rd : std_logic;
	variable found_index_rd : integer;
	
	variable tag_wr : std_logic_vector(TAG_BITS-1 downto 0);
	variable index_wr : integer;
	variable found_wr : std_logic;
	variable found_invalid_wr : std_logic;
	variable found_invalid_index_wr : integer;
	
	variable prova: integer := 0;
	
	begin
	
		if(reset = '1') then
		
			report "Reset";
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
				report "Sto leggendo";
				-- estraggo tag e index da pc_if
				tag_rd := pc_if(PC_BITS-1 downto SLOT_BITS);
				index_rd := conv_integer(pc_if(SLOT_BITS-1 downto 0));
				
				found_rd := '0';
				
				-- ricerca della linea di cache
				for i in 0 to WAYS_NUM-1 loop
					if(Btb_inst(index_rd, i).tag_pc = tag_rd and Btb_inst(index_rd, i).status = VALID) then -- linea trovata e valida	
						found_rd := '1';
						found_index_rd := i;				
						pc_dest_if <= Btb_inst(index_rd, i).dest_pc; -- aggiorno pc_dest_if --downto -- verificare assegnamento di tutti i bit. 			 
						case Btb_inst(index_rd, i).pred is -- emetto il bit di predizione
							when "11" => tkn_if <= TAKEN;     -- predetto taken
							when "10" => tkn_if <= TAKEN;
							when others => tkn_if <= UNTAKEN; -- predetto untaken
						end case;					
						Btb_inst(index_rd, i).repl <= '0'; -- aggiorno bit per il rimpiazzamento
					end if;
				end loop;
				
				-- gestione della politica di rimpiazzamento
				if(found_rd = '1') then -- la linea è stata trovata	
					for i in 0 to WAYS_NUM-1 loop
						if(i /= found_index_rd and Btb_inst(index_rd, i).status = VALID) then		
							Btb_inst(index_rd, i).repl <= '1';		
						end if;
					end loop;
				else -- la linea non è stata trovata
					--tkn_if <= UNTAKEN; -- anche nel caso non venga trovata la linea corrispondente
					--debug per vedere se funziona il btb in lettura
					--tkn_if <= TAKEN;
					--pc_dest_if <= conv_std_logic_vector(9, 30);
					if((prova rem 2) /= 0) then
						tkn_if <= TAKEN;
					else
						tkn_if <= UNTAKEN;
					end if;
					prova := prova + 1;
				end if;
			end if;
			
			-- Scrittura dallo stadio EX
			if(pc_ex'event and wr = '1') then
				report "Sto scrivendo";
				-- estraggo tag e index da pc_ex
				tag_wr := pc_ex(PC_BITS-1 downto SLOT_BITS);
				index_wr := conv_integer(pc_ex(SLOT_BITS-1 downto 0));
				
				found_wr := '0';
				found_invalid_wr := '0';
				
				for i in 0 to WAYS_NUM-1 loop
					if(Btb_inst(index_wr, i).tag_pc = tag_wr and Btb_inst(index_wr, i).status = VALID) then -- linea trovata (valida); il controllo della validità potrebbe essere omesso
						report "Scrittura: Linea trovata";
						found_wr := '1';
						Btb_inst(index_wr, i).dest_pc <= pc_dest_ex; -- aggiorno indirizzo di destinazione --downto
						
						--aggiornamento bit di predizione
						if(pred_ok_ex = PRED_OK) then -- predizione corretta
							case Btb_inst(index_wr, i).pred is
								when "11" => Btb_inst(index_wr, i).pred <= "11";
								when "10" => Btb_inst(index_wr, i).pred <= "11";
								when "01" => Btb_inst(index_wr, i).pred <= "00";
								when "00" => Btb_inst(index_wr, i).pred <= "00";
								when others => Btb_inst(index_wr, i).pred <= "00";
							end case;
						else -- predizione sbagliata
							case Btb_inst(index_wr, i).pred is
								when "11" => Btb_inst(index_wr, i).pred <= "10";
								when "10" => Btb_inst(index_wr, i).pred <= "01";
								when "01" => Btb_inst(index_wr, i).pred <= "10";
								when "00" => Btb_inst(index_wr, i).pred <= "01";		
								when others => Btb_inst(index_wr, i).pred <= "00";
							end case;
						end if;
						exit; --break
					end if;
				end loop;
				
				if(found_wr = '0') then --linea non trovata -> cerco linea invalida o valida (da rimpiazzare) per la prima scrittura
					report "Scrittura: Linea non trovata";
					for i in 0 to WAYS_NUM-1 loop
						if(Btb_inst(index_wr, i).status = INVALID) then -- trovata linea invalida
							report "Scrittura: Trovata linea invalida";
							found_invalid_wr := '1';
							found_invalid_index_wr := i;
							Btb_inst(index_wr, i).tag_pc <= tag_wr; --downto
							Btb_inst(index_wr, i).dest_pc <= pc_dest_ex; --downto
							Btb_inst(index_wr, i).status <= VALID; -- la linea ora è valida
							Btb_inst(index_wr, i).repl <= '0';
							if(pred_ok_ex = PRED_OK) then
								Btb_inst(index_wr, i).pred <= "00"; -- la linea non era nella cache quindi la predizione in lettura era stata untaken
							else
								Btb_inst(index_wr, i).pred <= "11";
							end if;
							exit; -- break altrimenti se ci fossero altre linee invalide scriverei lo stesso dato più volte
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
								Btb_inst(index_wr, i).tag_pc <= tag_wr; --downto
								Btb_inst(index_wr, i).dest_pc <= pc_dest_ex; --downto
								Btb_inst(index_wr, i).repl <= '0';
								if(pred_ok_ex = PRED_OK) then
									Btb_inst(index_wr, i).pred <= "00"; -- la linea non era nella cache quindi la predizione in lettura era stata untaken
								else
									Btb_inst(index_wr, i).pred <= "11";
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
	
--	a_read : process(rd, pc_if)
--		
--	variable tag : std_logic_vector(TAG_BITS-1 downto 0);
--	variable index : integer;
--	variable found : std_logic;
--	variable found_index : integer := 0;
--	
--	begin
--	
--		if(rd = '1') then
--			-- estraggo tag e index da pc_if
--			tag := pc_if(PC_BITS-1 downto SLOT_BITS);
--			index := conv_integer(pc_if(SLOT_BITS-1 downto 0));
--			
--			found := '0';
--			
--			-- ricerca della linea di cache
--			for i in 0 to WAYS_NUM-1 loop
--				if(Btb_inst(index, i).tag_pc = tag and Btb_inst(index, i).status = VALID) then -- linea trovata e valida	
--					found := '1';
--					found_index := i;				
--					pc_dest_if <= Btb_inst(index, i).dest_pc; -- aggiorno pc_dest_if --downto -- verificare assegnamento di tutti i bit. 			 
--					case Btb_inst(index, i).pred is -- emetto il bit di predizione
--						when "11" => tkn_if <= TAKEN;     -- predetto taken
--						when "10" => tkn_if <= TAKEN;
--						when others => tkn_if <= UNTAKEN; -- predetto untaken
--					end case;					
--					Btb_inst(index, i).repl <= '0'; -- aggiorno bit per il rimpiazzamento
--				end if;
--			end loop;
--			
--			-- gestione della politica di rimpiazzamento
--			if(found = '1') then -- la linea è stata trovata	
--				for i in 0 to WAYS_NUM-1 loop
--					if(i /= found_index and Btb_inst(index, i).status = VALID) then		
--						Btb_inst(index, i).repl <= '1';		
--					end if;
--				end loop;
--			else -- la linea non è stata trovata
--				tkn_if <= UNTAKEN; -- anche nel caso non venga trovata la linea corrispondente
--			end if;
--		end if;
--		
--	end process;
	
--	a_write : process(wr, pc_ex)
--	
--	variable tag : std_logic_vector(TAG_BITS-1 downto 0);
--	variable index : integer;
--	variable found : std_logic;
--	variable found_invalid : std_logic;
--	variable found_invalid_index : integer := 0;
--	
--	begin
--	
--		if(wr = '1') then
--				 "Sto scrivendo";
--			-- estraggo tag e index da pc_ex
--			tag := pc_ex(PC_BITS-1 downto SLOT_BITS);
--			index := conv_integer(pc_ex(SLOT_BITS-1 downto 0));
--			
--			found := '0';
--			found_invalid := '0';
--			
--			for i in 0 to WAYS_NUM-1 loop
--				if(Btb_inst(index, i).tag_pc = tag and Btb_inst(index, i).status = VALID) then -- linea trovata (valida); il controllo della validità potrebbe essere omesso
--					report "Linea trovata";
--					found := '1';
--					Btb_inst(index, i).dest_pc <= pc_dest_ex; -- aggiorno indirizzo di destinazione --downto
--					
--					--aggiornamento bit di predizione
--					if(pred_ok_ex = PRED_OK) then -- predizione corretta
--						case Btb_inst(index, i).pred is
--							when "11" => Btb_inst(index, i).pred <= "11";
--							when "10" => Btb_inst(index, i).pred <= "11";
--							when "01" => Btb_inst(index, i).pred <= "00";
--							when "00" => Btb_inst(index, i).pred <= "00";
--							when others => Btb_inst(index, i).pred <= "00";
--						end case;
--					else -- predizione sbagliata
--						case Btb_inst(index, i).pred is
--							when "11" => Btb_inst(index, i).pred <= "10";
--							when "10" => Btb_inst(index, i).pred <= "01";
--							when "01" => Btb_inst(index, i).pred <= "10";
--							when "00" => Btb_inst(index, i).pred <= "01";		
--							when others => Btb_inst(index, i).pred <= "00";
--						end case;
--					end if;
--					exit; --break
--				end if;
--			end loop;
--			
--			if(found = '0') then --linea non trovata -> cerco linea invalida o valida (da rimpiazzare) per la prima scrittura
--				report "Linea non trovata";
--				for i in 0 to WAYS_NUM-1 loop
--					if(Btb_inst(index, i).status = INVALID) then -- trovata linea invalida
--						report "Trovata linea invalida";
--						found_invalid := '1';
--						found_invalid_index := i;
--						Btb_inst(index, i).tag_pc <= tag; --downto
--						Btb_inst(index, i).dest_pc <= pc_dest_ex; --downto
--						Btb_inst(index, i).status <= VALID; -- la linea ora è valida
--						Btb_inst(index, i).repl <= '0';
--						if(pred_ok_ex = PRED_OK) then
--							Btb_inst(index, i).pred <= "00"; -- la linea non era nella cache quindi la predizione in lettura era stata untaken
--						else
--							Btb_inst(index, i).pred <= "11";
--						end if;
--						exit; -- break altrimenti se ci fossero altre linee invalide scriverei lo stesso dato più volte
--					end if;
--				end loop;
--				
--				if(found_invalid = '1') then -- trovata linea invalida
--					for i in 0 to WAYS_NUM-1 loop
--						if(i /= found_invalid_index and Btb_inst(index, i).status = VALID) then -- linea diversa da quella trovata e valida
--							Btb_inst(index, i).repl <= '1';
--						end if;
--					end loop;
--				else -- non ci sono linee invalide
--					for i in 0 to WAYS_NUM-1 loop
--						if(Btb_inst(index, i).repl = '1') then -- trovata la linea valida da rimpiazzare
--							Btb_inst(index, i).tag_pc <= tag; --downto
--							Btb_inst(index, i).dest_pc <= pc_dest_ex; --downto
--							Btb_inst(index, i).repl <= '0';
--							if(pred_ok_ex = PRED_OK) then
--								Btb_inst(index, i).pred <= "00"; -- la linea non era nella cache quindi la predizione in lettura era stata untaken
--							else
--								Btb_inst(index, i).pred <= "11";
--							end if;							
--						else
--							Btb_inst(index, i).repl <= '1';
--						end if;
--					end loop;
--				end if;
--			end if;
--		end if;
--	
--	end process;
	
end Behavioral;

