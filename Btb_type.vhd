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

	constant VALID : std_logic := '1';
	constant INVALID: std_logic := '0';
	constant TAKEN : std_logic := '1';
	constant UNTAKEN: std_logic := '0';
	constant PRED_OK: std_logic := '1';
	constant PRED_NOT_OK: std_logic := '0';
	constant TAKEN_STRONG: std_logic_vector(PRED_BITS-1 downto 0) := "11";
	constant TAKEN_WEAK: std_logic_vector(PRED_BITS-1 downto 0) := "10";
	constant UNTAKEN_WEAK: std_logic_vector(PRED_BITS-1 downto 0) := "01";
	constant UNTAKEN_STRONG: std_logic_vector(PRED_BITS-1 downto 0) := "00";
	
	-- struttura interna di ogni linea di cache
	type way_type is record
		tag_pc : std_logic_vector(TAG_BITS-1 downto 0); -- tag
		dest_pc : std_logic_vector(PC_BITS-1 downto 0); -- destinazione del branch
		pred : std_logic_vector(PRED_BITS-1 downto 0);	-- bit per algoritmo di predizione
		status: std_logic; -- 0 invalido 1 valido
		repl : std_logic; -- 1 se linea da sostituire
	end record;
	
	-- la cache � strutturata come una matrice SLOTS_NUM X WAYS_NUM
	type btb_cache is array (0 to SLOTS_NUM-1, 0 to WAYS_NUM-1) of way_type;
	
end Btb;