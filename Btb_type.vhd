library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Global.all;

package Btb is
		
	constant SLOT_BITS : integer := 6; -- lunghezza dello slot in bit
	constant SLOTS_NUM : integer := 2**SLOT_BITS; -- numero di slot del btb
	constant TAG_BITS: integer := PC_BITS-SLOT_BITS; -- lunghezza del tag in bit
	constant PRED_BITS: integer := 2; -- numero bit di predizione
	constant WAYS_NUM : integer := 2; -- n-associative
	
	type way_type is record
		tag_pc : std_logic_vector(TAG_BITS-1 downto 0);
		dest_pc : std_logic_vector(PC_BITS-1 downto 0);
		pred : std_logic_vector(PRED_BITS-1 downto 0);
		status: std_logic; -- 0 invalido 1 valido
		repl : std_logic; -- 1 se linea da sostituire
	end record;
	
	--	type slot_type is record 
--		way0 : way_type;
--		way1: way_type;
--	end record;
	
	type slot_type is array (0 to WAYS_NUM-1) of way_type;
	
	type btb_cache is array (0 to SLOTS_NUM-1) of slot_type;
	
end Btb;