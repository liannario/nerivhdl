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
	
	signal Btb_inst : btb_cache; -- Btb_inst(0)(0).tag_pc <= (others => '0'); Funziona
	
begin
	
	a_reset : process(reset)
	begin
	
		if(reset = '1') then
			for i in 0 to SLOTS_NUM-1 loop
				for j in 0 to WAYS_NUM-1 loop
					Btb_inst(i)(j).tag_pc <= (others => '0');
					Btb_inst(i)(j).dest_pc <= (others => '0');
					Btb_inst(i)(j).pred <= (others => '0');
					Btb_inst(i)(j).status <= '0';
					Btb_inst(i)(j).repl <= '0';
				end loop;
			end loop;
		end if;
		
	end process;
	
	a_read : process(rd, pc_if)
		
	variable tag : std_logic_vector(TAG_BITS-1 downto 0);
	variable index : integer;
	variable found : std_logic;
	variable found_index : integer := 0;
	
	begin
	
		if(rd = '1') then
			tag := pc_if(PC_BITS-1 downto SLOT_BITS);
			index := conv_integer(pc_if(SLOT_BITS-1 downto 0));
			found := '0';
			
			-- ricerca della linea di cache
			for i in 0 to SLOTS_NUM-1 loop
				if(Btb_inst(index)(i).tag_pc = tag and Btb_inst(index)(i).status = '1') then -- linea trovata e valida	
					found := '1';
					found_index := i;				
					pc_dest_if <= Btb_inst(index)(i).dest_pc; -- verificare assegnamento di tutti i bit. aggiorno pc_dest_if --downto				 
					case Btb_inst(index)(i).pred is -- emetto il bit di predizione
						when "11" => tkn_if <= '1';
						when "10" => tkn_if <= '1';
						when others => tkn_if <= '0'; 
					end case;					
					Btb_inst(index)(i).repl <= '0';
				end if;
			end loop;
			
			-- gestione della politica di rimpiazzamento
			if(found = '1') then -- la linea è stata trovata	
				for i in 0 to SLOTS_NUM-1 loop
					if(i /= found_index) then 			
						Btb_inst(index)(i).repl <= '1';		
					end if;
				end loop;
			else
				tkn_if <= '0'; -- anche nel caso non venga trovata la linea corrispondente
			end if;
		end if;
		
	end process;
	
	a_write : process(wr)
	
	variable tag : std_logic_vector(TAG_BITS-1 downto 0);
	variable index : integer;
	variable found : std_logic;
	variable found_invalid : std_logic;
	variable found_invalid_index : integer := 0;
	
	begin
	
	if(wr = '1') then
			tag := pc_ex(PC_BITS-1 downto SLOT_BITS);
			index := conv_integer(pc_ex(SLOT_BITS-1 downto 0));
			found := '0';
			found_invalid := '0';
			
			for i in 0 to SLOTS_NUM-1 loop
				if(Btb_inst(index)(i).tag_pc = tag and Btb_inst(index)(i).status = '1') then -- il controllo della validità potrebbe essere omesso
					found := '1';
					Btb_inst(index)(i).dest_pc <= pc_dest_ex; -- aggiorno indirizzo di destinazione --downto
					
					--aggiornamento bit di predizione
					if(pred_ok_ex = '1') then
						case Btb_inst(index)(i).pred is
							when "11" => Btb_inst(index)(i).pred <= "11";
							when "10" => Btb_inst(index)(i).pred <= "11";
							when "01" => Btb_inst(index)(i).pred <= "00";
							when "00" => Btb_inst(index)(i).pred <= "00";
							when others => Btb_inst(index)(i).pred <= "00";
						end case;
					else
						case Btb_inst(index)(i).pred is
							when "11" => Btb_inst(index)(i).pred <= "10";
							when "10" => Btb_inst(index)(i).pred <= "01";
							when "01" => Btb_inst(index)(i).pred <= "10";
							when "00" => Btb_inst(index)(i).pred <= "01";		
							when others => Btb_inst(index)(i).pred <= "00";
						end case;
					end if;
				end if;
			end loop;
			
			if(found = '0') then --linea non trovata -> scelgo la linea da rimpiazzare
				for i in 0 to SLOTS_NUM-1 loop
					if(Btb_inst(index)(i).status = '0') then -- trovata linea invalida
						found_invalid := '1';
						found_invalid_index := i;
						Btb_inst(index)(i).tag_pc <= tag; --downto
						Btb_inst(index)(i).dest_pc <= pc_dest_ex; --downto
						Btb_inst(index)(i).status <= '1';
						Btb_inst(index)(i).repl <= '0';
						if(pred_ok_ex = '1') then
							Btb_inst(index)(i).pred <= "00";
						else
							Btb_inst(index)(i).pred <= "11";
						end if;
						exit; --break
					end if;
				end loop;
				
				if(found_invalid = '1') then
					for i in 0 to SLOTS_NUM-1 loop
						if(i /= found_invalid_index and Btb_inst(index)(i).status = '1') then
							Btb_inst(index)(i).repl <= '1';
						end if;
					end loop;
				else -- non ci sono linee invalide
					for i in 0 to SLOTS_NUM-1 loop
						if(Btb_inst(index)(i).repl = '1') then -- trovata linea da rimpiazzare
							Btb_inst(index)(i).tag_pc <= tag; --downto
							Btb_inst(index)(i).dest_pc <= pc_dest_ex; --downto
							Btb_inst(index)(i).repl <= '0';
						else
							Btb_inst(index)(i).repl <= '1';
						end if;
					end loop;
				end if;
			end if;
	end if;
	
	end process;
	
end Behavioral;

